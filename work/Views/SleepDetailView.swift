import SwiftUI
import Foundation

struct SleepScoreBreakdown {
    static let durationMax: Double = 25
    static let efficiencyMax: Double = 25
    static let deepMax: Double = 20
    static let remMax: Double = 20
    static let onsetMax: Double = 10
}

// MARK: - Time Formatting Utility
func formatTimeInHoursAndMinutes(_ hours: Double) -> String {
    let totalMinutes = Int(hours * 60)
    let hoursPart = totalMinutes / 60
    let minutesPart = totalMinutes % 60
    
    if hoursPart > 0 && minutesPart > 0 {
        return "\(hoursPart)h \(minutesPart)min"
    } else if hoursPart > 0 {
        return "\(hoursPart)h"
    } else {
        return "\(minutesPart)min"
    }
}

struct SleepDetailView: View {
    @EnvironmentObject var dateModel: PerformanceDateModel
    @State private var sleepResult: SleepScoreResult?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var biomarkerData: [String: (value: Double, change: Double?, trend: [Double])] = [:]
    @State private var loadingWorkItem: DispatchWorkItem? = nil
    
    var selectedDate: Date { dateModel.selectedDate }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DateSliderView(selectedDate: $dateModel.selectedDate)
                if isLoading {
                    loadingOverlay
                } else if let error = errorMessage {
                    errorOverlay(error)
                } else if let result = sleepResult {
                    // Main Score Card
                    VStack(spacing: 8) {
                        Text("Sleep Score")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text("\(result.finalScore)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(AppColors.secondaryBackground)
                    .cornerRadius(16)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Sleep Score: \(result.finalScore)")
                    
                    // How It Was Calculated Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How It Was Calculated")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        VStack(spacing: 8) {
                            ScoreBreakdownRow(
                                component: "Sleep Duration",
                                score: calculateDurationScore(from: result),
                                maxScore: SleepScoreBreakdown.durationMax
                            )
                            ScoreBreakdownRow(
                                component: "Sleep Efficiency",
                                score: result.efficiencyComponent,
                                maxScore: SleepScoreBreakdown.efficiencyMax
                            )
                            ScoreBreakdownRow(
                                component: "Deep Sleep",
                                score: calculateDeepSleepScore(from: result),
                                maxScore: SleepScoreBreakdown.deepMax
                            )
                            ScoreBreakdownRow(
                                component: "REM Sleep",
                                score: calculateREMSleepScore(from: result),
                                maxScore: SleepScoreBreakdown.remMax
                            )
                            ScoreBreakdownRow(
                                component: "Sleep Onset",
                                score: calculateOnsetScore(from: result),
                                maxScore: SleepScoreBreakdown.onsetMax
                            )
                        }
                    }
                    .padding(16)
                    .background(AppColors.secondaryBackground)
                    .cornerRadius(16)
                    
                    // Sleep Insights Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sleep Insights")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(generateInsightsList(from: result), id: \.self) { insight in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                    Text(insight)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(AppColors.secondaryBackground)
                    .cornerRadius(16)
                    
                    // Sleep Metrics Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        SleepMetricCard(
                            title: "Time in Bed",
                            value: result.timeInBed / 3600,
                            unit: "h",
                            color: .blue
                        )
                        SleepMetricCard(
                            title: "Time Asleep",
                            value: result.timeAsleep / 3600,
                            unit: "h",
                            color: .green
                        )
                        SleepMetricCard(
                            title: "Time in REM",
                            value: result.remSleep / 3600,
                            unit: "h",
                            color: .purple
                        )
                        SleepMetricCard(
                            title: "Time in Deep",
                            value: result.deepSleep / 3600,
                            unit: "h",
                            color: .indigo
                        )
                        SleepMetricCard(
                            title: "Sleep Efficiency",
                            value: result.sleepEfficiency * 100,
                            unit: "%",
                            color: .orange
                        )
                        SleepMetricCard(
                            title: "Time to Fall Asleep",
                            value: result.timeToFallAsleep,
                            unit: "min",
                            color: .red
                        )
                    }
                } else {
                    EmptyStateView(
                        icon: "bed.double",
                        title: "No Sleep Data",
                        message: "Sleep data will appear here once you have sufficient sleep data for the selected date.",
                        actionTitle: nil,
                        action: nil
                    )
                }
            }
            .padding()
        }
        .background(AppColors.background)
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadSleepData()
        }
        .onChange(of: selectedDate) { _, _ in
            loadSleepData()
        }
    }
    
    // MARK: - Helper Methods
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            ProgressView("Loading...")
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                .foregroundColor(.primary)
                .padding()
                .background(AppColors.secondaryBackground)
                .cornerRadius(12)
        }
    }
    private func errorOverlay(_ error: String) -> some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                Button("Retry") { loadSleepData() }
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }
    
    private func loadSleepData() {
        isLoading = false
        errorMessage = nil
        loadingWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            self.isLoading = true
        }
        loadingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
        Task {
            do {
                let result = try await SleepScoreCalculator.shared.calculateSleepScore(for: selectedDate)
                await loadBiomarkerData(for: selectedDate)
                await MainActor.run {
                    self.loadingWorkItem?.cancel()
                    self.sleepResult = result
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.loadingWorkItem?.cancel()
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    private func loadBiomarkerData(for date: Date) async {
        let timeInBedTrend = generateSampleTrend(baseValue: 8.0, variation: 0.5)
        let timeAsleepTrend = generateSampleTrend(baseValue: 7.5, variation: 0.3)
        let remSleepTrend = generateSampleTrend(baseValue: 1.8, variation: 0.2)
        let deepSleepTrend = generateSampleTrend(baseValue: 1.2, variation: 0.2)
        let efficiencyTrend = generateSampleTrend(baseValue: 90.0, variation: 5.0)
        let fallAsleepTrend = generateSampleTrend(baseValue: 15.0, variation: 5.0)
        await MainActor.run {
            biomarkerData["timeInBed"] = (value: timeInBedTrend.last ?? 8.0, change: nil, trend: timeInBedTrend)
            biomarkerData["timeAsleep"] = (value: timeAsleepTrend.last ?? 7.5, change: nil, trend: timeAsleepTrend)
            biomarkerData["remSleep"] = (value: remSleepTrend.last ?? 1.8, change: nil, trend: remSleepTrend)
            biomarkerData["deepSleep"] = (value: deepSleepTrend.last ?? 1.2, change: nil, trend: deepSleepTrend)
            biomarkerData["efficiency"] = (value: efficiencyTrend.last ?? 90.0, change: nil, trend: efficiencyTrend)
            biomarkerData["fallAsleep"] = (value: fallAsleepTrend.last ?? 15.0, change: nil, trend: fallAsleepTrend)
        }
    }
    private func generateSampleTrend(baseValue: Double, variation: Double) -> [Double] {
        return (0..<7).map { _ in
            baseValue + Double.random(in: -variation...variation)
        }
    }
    private func generateInsightsList(from result: SleepScoreResult) -> [String] {
        var insights: [String] = []
        let hoursAsleep = result.timeAsleep / 3600
        let formattedTime = formatTimeInHoursAndMinutes(hoursAsleep)
        if hoursAsleep >= 7.0 && hoursAsleep <= 9.0 {
            insights.append("Optimal sleep duration of \(formattedTime)")
        } else if hoursAsleep < 7.0 {
            insights.append("Sleep duration of \(formattedTime) may be insufficient")
        } else {
            insights.append("Sleep duration of \(formattedTime) is longer than typical")
        }
        let efficiency = result.sleepEfficiency * 100
        if efficiency >= 90 {
            insights.append("Excellent sleep efficiency of \(Int(efficiency))%")
        } else if efficiency >= 80 {
            insights.append("Good sleep efficiency of \(Int(efficiency))%")
        } else {
            insights.append("Sleep efficiency of \(Int(efficiency))% could be improved")
        }
        let deepPercentage = result.deepSleepPercentage * 100
        if deepPercentage >= 13 && deepPercentage <= 23 {
            insights.append("Optimal deep sleep of \(String(format: "%.1f", deepPercentage))%")
        } else if deepPercentage < 13 {
            insights.append("Deep sleep of \(String(format: "%.1f", deepPercentage))% is below optimal range")
        } else {
            insights.append("Deep sleep of \(String(format: "%.1f", deepPercentage))% is above typical range")
        }
        let remPercentage = result.remSleepPercentage * 100
        if remPercentage >= 20 && remPercentage <= 25 {
            insights.append("Optimal REM sleep of \(String(format: "%.1f", remPercentage))%")
        } else if remPercentage < 20 {
            insights.append("REM sleep of \(String(format: "%.1f", remPercentage))% is below optimal range")
        } else {
            insights.append("REM sleep of \(String(format: "%.1f", remPercentage))% is above typical range")
        }
        let fallAsleepTime = result.timeToFallAsleep
        if fallAsleepTime <= 15 {
            insights.append("Quick sleep onset of \(Int(fallAsleepTime)) minutes")
        } else if fallAsleepTime <= 30 {
            insights.append("Normal sleep onset of \(Int(fallAsleepTime)) minutes")
        } else {
            insights.append("Sleep onset took \(Int(fallAsleepTime)) minutes - consider sleep hygiene")
        }
        if result.finalScore >= 85 {
            insights.append("Exceptional sleep quality - your body is well-rested")
        } else if result.finalScore >= 70 {
            insights.append("Good sleep quality - maintain your current routine")
        } else if result.finalScore >= 50 {
            insights.append("Fair sleep quality - consider improving sleep habits")
        } else {
            insights.append("Poor sleep quality - focus on sleep hygiene and schedule")
        }
        return insights.isEmpty ? ["No specific insights available for this date"] : insights
    }
    
    // MARK: - Score Calculation Helpers
    
    private func calculateDurationScore(from result: SleepScoreResult) -> Double {
        let hoursAsleep = result.timeAsleep / 3600
        let optimal = 8.0
        let deviation = abs(hoursAsleep - optimal)
        return 100 * Foundation.exp(-0.5 * Foundation.pow(deviation / 1.5, 2))
    }
    
    private func calculateDeepSleepScore(from result: SleepScoreResult) -> Double {
        let deepPercentage = result.deepSleepPercentage * 100
        return normalizeScore(deepPercentage, min: 13, maxValue: 23)
    }
    
    private func calculateREMSleepScore(from result: SleepScoreResult) -> Double {
        let remPercentage = result.remSleepPercentage * 100
        return normalizeScore(remPercentage, min: 20, maxValue: 25)
    }
    
    private func calculateOnsetScore(from result: SleepScoreResult) -> Double {
        let fallAsleepTime = result.timeToFallAsleep
        // Use a smooth exponential decay curve instead of discrete steps
        if fallAsleepTime <= 10 {
            return 100
        } else if fallAsleepTime <= 60 {
            // Smooth curve from 100 to 0 over 50 minutes
            let normalizedTime = (fallAsleepTime - 10) / 50.0
            return 100 * Foundation.exp(-2.0 * normalizedTime)
        } else {
            return max(0, 100 * Foundation.exp(-2.0 * (60 - 10) / 50.0) - (fallAsleepTime - 60) * 0.5)
        }
    }
    
    private func normalizeScore(_ value: Double, min: Double, maxValue: Double) -> Double {
        if value < min {
            // Smooth curve for values below minimum
            return 60 * (value / min) * (value / min)
        }
        if value > maxValue {
            // Smooth curve for values above maximum
            let excess = value - maxValue
            let penalty = excess * 3.0
            return max(60, 100 - penalty)
        }
        // Smooth curve within optimal range
        let optimal = (min + maxValue) / 2
        let deviation = abs(value - optimal)
        let maxDeviation = (maxValue - min) / 2
        let normalizedDeviation = deviation / maxDeviation
        return 100 - (normalizedDeviation * normalizedDeviation * 40)
    }
}

// MARK: - Supporting Views

struct SleepMetricCard: View {
    let title: String
    let value: Double
    let unit: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            HStack(alignment: .bottom, spacing: 2) {
                if unit == "h" {
                    Text(formatTimeInHoursAndMinutes(value))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                } else if unit == "%" {
                    Text("\(Int(value))")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(unit)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                } else {
                    Text("\(Int(value))")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(unit)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppColors.secondaryBackground)
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(unit == "h" ? formatTimeInHoursAndMinutes(value) : "\(Int(value)) \(unit)")")
    }
}

struct SleepDetailView_Previews: PreviewProvider {
    static var previews: some View {
        SleepDetailView()
    }
} 
