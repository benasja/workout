import SwiftUI
import Charts

struct DailyPerformance: Identifiable {
    let id = UUID()
    let date: Date
    let recoveryScore: Int
    let sleepScore: Int
    let hrv: Double?
    let rhr: Double?
    let sleepDuration: TimeInterval?
    let deepSleep: TimeInterval?
    let remSleep: TimeInterval?
    let hrvDelta: Double?
    let rhrDelta: Double?
    let sleepDelta: Double?
    let directive: String
}

@MainActor
class PerformanceDashboardViewModel: ObservableObject {
    @Published var today: DailyPerformance?
    @Published var history: [DailyPerformance] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var calibrating = false
    @Published var lastRefreshTime: Date = Date()

    func load() async {
        isLoading = true
        error = nil
        calibrating = false
        let hk = HealthKitManager.shared
        let baseline = DynamicBaselineEngine.shared
        baseline.loadBaselines()
        await withCheckedContinuation { cont in
            hk.requestAuthorization { granted in
                cont.resume()
            }
        }
        
        // Only update baselines if they're missing or very old (more than 24 hours)
        if baseline.calibrating || baseline.shouldUpdateBaselines() {
            await withCheckedContinuation { cont in
                baseline.updateAndStoreBaselines {
                    cont.resume()
                }
            }
        }
        calibrating = baseline.calibrating
        // Fetch today
        let group = DispatchGroup()
        var hrv: Double?; var rhr: Double?; var sleep: (duration: TimeInterval, deep: TimeInterval, rem: TimeInterval, bedtime: Date, wake: Date)?
        group.enter(); hk.fetchLatestHRV { v in hrv = v; group.leave() }
        group.enter(); hk.fetchLatestRHR { v in rhr = v; group.leave() }
        group.enter(); hk.fetchLatestSleep { s in sleep = s; group.leave() }
        group.notify(queue: .main) {
            Task {
                let hrvDelta = (hrv != nil && baseline.hrv60 != nil) ? hrv! - baseline.hrv60! : nil
                let rhrDelta = (rhr != nil && baseline.rhr60 != nil) ? rhr! - baseline.rhr60! : nil
                let sleepDelta = (sleep != nil && baseline.sleepDuration14 != nil) ? (sleep!.duration - baseline.sleepDuration14!) / 3600 : nil
                
                // Use the comprehensive recovery and sleep score calculators
                let recoveryScore: Int
                let sleepScore: Int
                let directive: String
                
                do {
                    // The new RecoveryScoreCalculator will automatically check for stored scores first
                    // and only calculate new ones if none exist for that date
                    // Since RecoveryScoreCalculator is @MainActor, we can call it directly
                    let recoveryResult = try await RecoveryScoreCalculator.shared.calculateRecoveryScore(for: Date())
                    recoveryScore = recoveryResult.finalScore
                    sleepScore = Int(recoveryResult.sleepComponent.score)
                    directive = recoveryResult.directive
                } catch {
                    // Fallback to simple calculation if comprehensive calculation fails
                    let fallbackSleepScore: Int
                    do {
                        let detailedSleepScore = try await SleepScoreCalculator.shared.calculateSleepScore(for: Date())
                        fallbackSleepScore = detailedSleepScore.finalScore
                    } catch {
                        fallbackSleepScore = Self.calculateSleepScore(sleep: sleep, baseline: baseline)
                    }
                    recoveryScore = Self.calculateRecoveryScore(hrv: hrv, rhr: rhr, sleepScore: fallbackSleepScore, baseline: baseline)
                    sleepScore = fallbackSleepScore
                    directive = Self.generateDirective(recoveryScore: recoveryScore, sleepScore: sleepScore)
                }
                
                await MainActor.run {
                    self.today = DailyPerformance(
                        date: Date(),
                        recoveryScore: recoveryScore,
                        sleepScore: sleepScore,
                        hrv: hrv,
                        rhr: rhr,
                        sleepDuration: sleep?.duration,
                        deepSleep: sleep?.deep,
                        remSleep: sleep?.rem,
                        hrvDelta: hrvDelta,
                        rhrDelta: rhrDelta,
                        sleepDelta: sleepDelta,
                        directive: directive
                    )
                    self.isLoading = false
                    self.lastRefreshTime = Date()
                }
            }
        }
    }
    
    static nonisolated func calculateRecoveryScore(hrv: Double?, rhr: Double?, sleepScore: Int, baseline: DynamicBaselineEngine) -> Int {
        guard let hrv = hrv, let rhr = rhr, let baseHRV = baseline.hrv60, let baseRHR = baseline.rhr60 else { return 0 }
        // HRV (60%)
        let hrvRatio = hrv / baseHRV
        let hrvScoreRaw = 100 * (1 + log10(hrvRatio))
        let hrvContribution = min(max(hrvScoreRaw, 0), 120) * 0.60
        // RHR (25%)
        let rhrRatio = baseRHR / rhr
        let rhrScoreRaw = 100 * rhrRatio
        let rhrContribution = min(max(rhrScoreRaw, 50), 120) * 0.25
        // Sleep (15%)
        let sleepContribution = Double(sleepScore) * 0.15
        // Final
        let total = hrvContribution + rhrContribution + sleepContribution
        return Int(min(max(total, 0), 100))
    }
    static nonisolated func calculateSleepScore(sleep: (duration: TimeInterval, deep: TimeInterval, rem: TimeInterval, bedtime: Date, wake: Date)?, baseline: DynamicBaselineEngine) -> Int {
        guard let sleep = sleep, let baseBed = baseline.bedtime14 else { return 0 }
        
        // V4.0 Sleep Score Calculation
        // Duration (30%)
        let hours = sleep.duration / 3600
        let durationPoints = getDurationPoints(hours: hours)
        let durationContribution = Double(durationPoints) * 0.30
        
        // Deep Sleep (25%)
        let deepMinutes = sleep.deep / 60
        let deepPoints = getDeepSleepPoints(minutes: deepMinutes)
        let deepContribution = Double(deepPoints) * 0.25
        
        // REM Sleep (20%)
        let remMinutes = sleep.rem / 60
        let remPoints = getREMPoints(minutes: remMinutes)
        let remContribution = Double(remPoints) * 0.20
        
        // Efficiency (15%) - Simplified calculation
        let efficiency = 85.0 // Default efficiency, could be calculated from time in bed vs time asleep
        let efficiencyPoints = getEfficiencyPoints(efficiency: efficiency)
        let efficiencyContribution = Double(efficiencyPoints) * 0.15
        
        // Consistency (10%)
        let bedtimeDeviation = abs(minutesBetween(sleep.bedtime, baseBed))
        let consistencyPoints = getConsistencyPoints(deviation: bedtimeDeviation)
        let consistencyContribution = Double(consistencyPoints) * 0.10
        
        // Final score
        let total = durationContribution + deepContribution + remContribution + efficiencyContribution + consistencyContribution
        return Int(min(max(total, 0), 100))
    }
    
    // V4.0 Helper functions
    static nonisolated func getDurationPoints(hours: Double) -> Int {
        switch hours {
        case let h where h > 8.0: return 30
        case 7.5..<8.0: return 29
        case 7.0..<7.5: return 27
        case 6.5..<7.0: return 25
        case 6.0..<6.5: return 20
        case 5.5..<6.0: return 15
        case 5.0..<5.5: return 10
        case 4.5..<5.0: return 5
        default: return 0
        }
    }
    
    static nonisolated func getDeepSleepPoints(minutes: Double) -> Int {
        switch minutes {
        case let m where m >= 105: return 25
        case 90..<105: return 22
        case 75..<90: return 18
        case 60..<75: return 14
        case 45..<60: return 8
        default: return 0
        }
    }
    
    static nonisolated func getREMPoints(minutes: Double) -> Int {
        switch minutes {
        case let m where m >= 120: return 20
        case 105..<120: return 18
        case 90..<105: return 16
        case 75..<90: return 13
        case 60..<75: return 10
        case 0..<60: return Int((minutes / 60.0) * 5.0)
        default: return 0
        }
    }
    
    static nonisolated func getEfficiencyPoints(efficiency: Double) -> Int {
        switch efficiency {
        case let e where e >= 95: return 15
        case 92.5..<95: return 12
        case 90..<92.5: return 10
        case 85..<90: return 5
        default: return 0
        }
    }
    
    static nonisolated func getConsistencyPoints(deviation: Double) -> Int {
        if deviation <= 0 {
            return 10
        } else {
            let penaltyPoints = deviation / 10.0
            let score = max(0, 10.0 - penaltyPoints)
            return Int(score)
        }
    }
    static nonisolated func normalizeScore(_ value: Double, min: Double, max: Double) -> Double {
        if value < min { return (value / min) * 60 }
        if value > max { return (max / value) * 60 }
        return 100 - (abs(((min+max)/2) - value) * 5)
    }
    static nonisolated func minutesBetween(_ d1: Date, _ d2: Date) -> Double {
        abs(d1.timeIntervalSince1970 - d2.timeIntervalSince1970) / 60.0
    }
    static nonisolated func generateDirective(recoveryScore: Int, sleepScore: Int) -> String {
        if recoveryScore > 85 {
            return "Primed for peak performance. Your body is ready for a high-strain workout."
        } else if recoveryScore < 55 {
            return "Nervous system under strain. Prioritize active recovery. A light walk or stretching is recommended."
        } else if sleepScore < 60 {
            return "Sleep was not restorative. Focus on your wind-down routine tonight."
        } else {
            return "Maintain your current habits for continued progress."
        }
    }

    static func performance(for date: Date, completion: @escaping (DailyPerformance?) -> Void) {
        Task {
            do {
                let recoveryResult = try await RecoveryScoreCalculator.shared.calculateRecoveryScore(for: date)
                let baseline = DynamicBaselineEngine.shared
                baseline.loadBaselines()
                
                let hrvDelta = (recoveryResult.hrvComponent.currentValue != nil && baseline.hrv60 != nil) ? recoveryResult.hrvComponent.currentValue! - baseline.hrv60! : nil
                let rhrDelta = (recoveryResult.rhrComponent.currentValue != nil && baseline.rhr60 != nil) ? recoveryResult.rhrComponent.currentValue! - baseline.rhr60! : nil
                
                let perf = DailyPerformance(
                    date: date,
                    recoveryScore: recoveryResult.finalScore,
                    sleepScore: Int(recoveryResult.sleepComponent.score),
                    hrv: recoveryResult.hrvComponent.currentValue,
                    rhr: recoveryResult.rhrComponent.currentValue,
                    sleepDuration: nil, // Will be available in sleep component details
                    deepSleep: nil,
                    remSleep: nil,
                    hrvDelta: hrvDelta,
                    rhrDelta: rhrDelta,
                    sleepDelta: nil,
                    directive: recoveryResult.directive
                )
                completion(perf)
            } catch {
                completion(nil)
            }
        }
    }
}

struct PerformanceDashboardView: View {
    @StateObject var vm = PerformanceDashboardViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                HStack {
                    Text("Performance")
                        .font(.largeTitle.bold())
                    Spacer()
                    Button(action: {
                        Task { await vm.load() }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    .disabled(vm.isLoading)
                }
                
                if vm.isLoading {
                    ProgressView("Loading health data...")
                        .padding()
                } else if let error = vm.error {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else if vm.calibrating {
                    VStack(spacing: 8) {
                        Text("Calibrating baselines...")
                            .font(.headline)
                            .foregroundColor(.orange)
                        Text("More data needed for accurate scores. Continue using your device normally.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if let today = vm.today {
                    VStack(spacing: 24) {
                        HStack(spacing: 32) {
                            NavigationLink(destination: RecoveryDetailView()) {
                                CircularScoreGauge(
                                    score: today.recoveryScore,
                                    label: "Recovery",
                                    gradient: Gradient(colors: [.red, .orange, .yellow, .green])
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            NavigationLink(destination: SleepDetailView()) {
                                CircularScoreGauge(
                                    score: today.sleepScore,
                                    label: "Sleep",
                                    gradient: Gradient(colors: [.blue, .cyan])
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .frame(height: 180)
                        
                        if !vm.isLoading {
                            Text("Last updated: \(vm.lastRefreshTime, style: .time)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear {
            Task { await vm.load() }
        }
    }
}

struct MetricDeltaView: View {
    let title: String
    let value: Double?
    let delta: Double?
    let unit: String
    var format: String = "%.0f"
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            if let value = value {
                HStack(spacing: 4) {
                    if title == "Sleep" {
                        Text(formatDuration(value))
                            .font(.title3.bold())
                    } else {
                        Text(String(format: format, value) + " " + unit)
                            .font(.title3.bold())
                    }
                    if let delta = delta {
                        if title == "Sleep" {
                            let minutes = Int((delta * 60).rounded())
                            let isPositive = minutes > 0
                            Text(String(format: "%+d min", minutes))
                                .font(.caption2)
                                .foregroundColor(isPositive ? .green : .red)
                        } else if title == "RHR" && abs(delta) < 0.01 {
                            Text("0")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text(delta > 0 ? "+\(String(format: format, delta))" : "\(String(format: format, delta))")
                                .font(.caption2)
                                .foregroundColor(delta > 0 ? .red : .green)
                        }
                    }
                }
            } else {
                Text("-")
                    .font(.title3.bold())
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 60)
    }
    private func formatDuration(_ hours: Double) -> String {
        let totalMinutes = Int((hours * 60).rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return String(format: "%d:%02dh", h, m)
    }
}

struct CircularScoreGauge: View {
    let score: Int
    let label: String
    let gradient: Gradient
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 18)
            Circle()
                .trim(from: 0, to: CGFloat(score)/100)
                .stroke(AngularGradient(gradient: gradient, center: .center), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack {
                Text("\(score)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text(label)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 140, height: 140)
    }
}

struct MetricView: View {
    let title: String
    let value: Double?
    let unit: String
    var format: String = "%.0f"
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            if let value = value {
                Text(String(format: format, value) + " " + unit)
                    .font(.title3.bold())
            } else {
                Text("-")
                    .font(.title3.bold())
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 60)
    }
} 