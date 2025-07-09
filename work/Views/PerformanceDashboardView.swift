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
        await withCheckedContinuation { cont in
            baseline.updateAndStoreBaselines {
                cont.resume()
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
            let hrvDelta = (hrv != nil && baseline.hrv60 != nil) ? hrv! - baseline.hrv60! : nil
            let rhrDelta = (rhr != nil && baseline.rhr60 != nil) ? rhr! - baseline.rhr60! : nil
            let sleepDelta = (sleep != nil && baseline.sleepDuration14 != nil) ? (sleep!.duration - baseline.sleepDuration14!) / 3600 : nil
            let sleepScore = Self.calculateSleepScore(sleep: sleep, baseline: baseline)
            let recoveryScore = Self.calculateRecoveryScore(hrv: hrv, rhr: rhr, sleepScore: sleepScore, baseline: baseline)
            let directive = Self.generateDirective(recoveryScore: recoveryScore, sleepScore: sleepScore)
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
    
    static func calculateRecoveryScore(hrv: Double?, rhr: Double?, sleepScore: Int, baseline: DynamicBaselineEngine) -> Int {
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
    static func calculateSleepScore(sleep: (duration: TimeInterval, deep: TimeInterval, rem: TimeInterval, bedtime: Date, wake: Date)?, baseline: DynamicBaselineEngine) -> Int {
        guard let sleep = sleep, let baseBed = baseline.bedtime14, let baseWake = baseline.wake14 else { return 0 }
        // Duration (40%)
        let hours = sleep.duration / 3600
        let optimal = 8.0
        let deviation = abs(hours - optimal)
        let durationScore = 100 * exp(-0.5 * pow(deviation / 1.5, 2))
        let durationContribution = durationScore * 0.40
        // Restorative (40%)
        let deepPct = sleep.duration > 0 ? (sleep.deep / sleep.duration) * 100 : 0
        let remPct = sleep.duration > 0 ? (sleep.rem / sleep.duration) * 100 : 0
        let deepScore = normalizeScore(deepPct, min: 13, max: 23)
        let remScore = normalizeScore(remPct, min: 20, max: 25)
        let restorativeContribution = ((deepScore * 0.5) + (remScore * 0.5)) * 0.40
        // Consistency (20%)
        let bedtimeDeviation = abs(minutesBetween(sleep.bedtime, baseBed))
        let wakeDeviation = abs(minutesBetween(sleep.wake, baseWake))
        let totalDeviation = bedtimeDeviation + wakeDeviation
        let consistencyScore = max(0, 100 - (totalDeviation / 1.8))
        let consistencyContribution = consistencyScore * 0.20
        // Final
        let total = durationContribution + restorativeContribution + consistencyContribution
        return Int(min(max(total, 0), 100))
    }
    static func normalizeScore(_ value: Double, min: Double, max: Double) -> Double {
        if value < min { return (value / min) * 60 }
        if value > max { return (max / value) * 60 }
        return 100 - (abs(((min+max)/2) - value) * 5)
    }
    static func minutesBetween(_ d1: Date, _ d2: Date) -> Double {
        abs(d1.timeIntervalSince1970 - d2.timeIntervalSince1970) / 60.0
    }
    static func generateDirective(recoveryScore: Int, sleepScore: Int) -> String {
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
}

struct PerformanceDashboardView: View {
    @StateObject var vm = PerformanceDashboardViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                HStack {
                    Text("Recovery & Sleep")
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
                    HStack(spacing: 32) {
                        CircularScoreGauge(
                            score: today.recoveryScore,
                            label: "Recovery",
                            gradient: Gradient(colors: [.red, .orange, .yellow, .green])
                        )
                        CircularScoreGauge(
                            score: today.sleepScore,
                            label: "Sleep",
                            gradient: Gradient(colors: [.blue, .cyan])
                        )
                    }
                    .frame(height: 180)
                    VStack(spacing: 8) {
                        HStack(spacing: 24) {
                            MetricDeltaView(title: "HRV", value: today.hrv, delta: today.hrvDelta, unit: "ms")
                            MetricDeltaView(title: "RHR", value: today.rhr, delta: today.rhrDelta, unit: "bpm")
                        }
                        HStack(spacing: 24) {
                            MetricDeltaView(title: "Sleep", value: today.sleepDuration.map { $0/3600 }, delta: today.sleepDelta, unit: "h", format: "%.1f")
                            let deepRem: Double? = {
                                if let deep = today.deepSleep, let rem = today.remSleep {
                                    return (deep + rem) / 3600
                                } else {
                                    return nil
                                }
                            }()
                            MetricView(title: "Deep+REM", value: deepRem, unit: "h", format: "%.1f")
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Directive")
                            .font(.headline)
                        Text(today.directive)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 8)
                }
                Divider()
                // Trends and history would go here (omitted for brevity)
                if !vm.isLoading {
                    Text("Last updated: \(vm.lastRefreshTime, style: .time)")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                    Text(String(format: format, value) + " " + unit)
                        .font(.title3.bold())
                    if let delta = delta {
                        Text(delta > 0 ? "+\(String(format: format, delta))" : "\(String(format: format, delta))")
                            .font(.caption2)
                            .foregroundColor(delta > 0 ? .red : .green)
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