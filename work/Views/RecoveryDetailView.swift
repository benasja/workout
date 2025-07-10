import SwiftUI

struct RecoveryScoreBreakdown {
    static let hrvMax: Double = 50
    static let rhrMax: Double = 25
    static let sleepMax: Double = 15
    static let stressMax: Double = 10
}

struct RecoveryDetailView: View {
    @EnvironmentObject var dateModel: PerformanceDateModel
    @State private var recoveryResult: RecoveryScoreResult?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var biomarkerData: [String: (value: Double, change: Double?, trend: [Double])] = [:]
    
    var selectedDate: Date { dateModel.selectedDate }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DateSliderView(selectedDate: $dateModel.selectedDate)
                if isLoading {
                    loadingOverlay
                } else if let error = errorMessage {
                    errorOverlay(error)
                } else if let result = recoveryResult {
                    // Main Score Card
                    VStack(spacing: 8) {
                        Text("Recovery Score")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text("\(result.finalScore)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .cornerRadius(16)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Recovery Score: \(result.finalScore)")
                    
                    // How It Was Calculated Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How It Was Calculated")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        VStack(spacing: 8) {
                            ScoreBreakdownRow(
                                component: "HRV Component",
                                score: result.hrvComponent.score,
                                maxScore: RecoveryScoreBreakdown.hrvMax
                            )
                            ScoreBreakdownRow(
                                component: "RHR Component",
                                score: result.rhrComponent.score,
                                maxScore: RecoveryScoreBreakdown.rhrMax
                            )
                            ScoreBreakdownRow(
                                component: "Sleep Component",
                                score: result.sleepComponent.score,
                                maxScore: RecoveryScoreBreakdown.sleepMax
                            )
                            ScoreBreakdownRow(
                                component: "Stress Component",
                                score: result.stressComponent.score,
                                maxScore: RecoveryScoreBreakdown.stressMax
                            )
                        }
                    }
                    .padding(16)
                    .background(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .cornerRadius(16)
                    
                    // Recovery Insights Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recovery Insights")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(generateInsightsList(from: result), id: \.self) { insight in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                    Text(insight)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .cornerRadius(16)
                    
                    // Biomarkers Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        BiomarkerCard(
                            title: "Resting HRV",
                            value: biomarkerData["hrv"]?.value ?? 0,
                            unit: "ms",
                            color: .green
                        )
                        BiomarkerCard(
                            title: "Resting HR",
                            value: biomarkerData["rhr"]?.value ?? 0,
                            unit: "bpm",
                            color: .blue
                        )
                        BiomarkerCard(
                            title: "Wrist Temp",
                            value: biomarkerData["temperature"]?.value ?? 0,
                            unit: "°C",
                            color: .orange
                        )
                        BiomarkerCard(
                            title: "Respiratory Rate",
                            value: biomarkerData["respiratory"]?.value ?? 0,
                            unit: "rpm",
                            color: .purple
                        )
                        BiomarkerCard(
                            title: "Oxygen Saturation",
                            value: biomarkerData["oxygen"]?.value ?? 0,
                            unit: "%",
                            color: .cyan
                        )
                    }
                } else {
                    EmptyStateView(
                        icon: "heart.text.square",
                        title: "No Recovery Data",
                        message: "Recovery data will appear here once you have sufficient health data for the selected date.",
                        actionTitle: nil,
                        action: nil
                    )
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Recovery")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadRecoveryData()
        }
        .onChange(of: selectedDate) { _, _ in
            loadRecoveryData()
        }
    }
    
    // MARK: - Helper Methods
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            ProgressView("Loading...")
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                .foregroundColor(.white)
                .padding()
                .background(Color(red: 0.2, green: 0.2, blue: 0.2))
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
                Button("Retry") { loadRecoveryData() }
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }
    
    private func loadRecoveryData() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await RecoveryScoreCalculator.shared.calculateRecoveryScore(for: selectedDate)
                await loadBiomarkerData(for: selectedDate)
                await MainActor.run {
                    self.recoveryResult = result
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadBiomarkerData(for date: Date) async {
        let calendar = Calendar.current
        var hrvTrend: [Double] = []
        for i in 0..<7 {
            let trendDate = calendar.date(byAdding: .day, value: -i, to: date) ?? date
            if let hrv = await fetchHRV(for: trendDate) {
                hrvTrend.insert(hrv, at: 0)
            }
        }
        var rhrTrend: [Double] = []
        for i in 0..<7 {
            let trendDate = calendar.date(byAdding: .day, value: -i, to: date) ?? date
            if let rhr = await fetchRHR(for: trendDate) {
                rhrTrend.insert(rhr, at: 0)
            }
        }
        let hrvChange = calculatePercentageChange(current: hrvTrend.last, previous: hrvTrend.dropLast().last)
        let rhrChange = calculatePercentageChange(current: rhrTrend.last, previous: rhrTrend.dropLast().last)
        await MainActor.run {
            if let currentHRV = hrvTrend.last {
                biomarkerData["hrv"] = (value: currentHRV, change: hrvChange, trend: hrvTrend)
            }
            if let currentRHR = rhrTrend.last {
                biomarkerData["rhr"] = (value: currentRHR, change: rhrChange, trend: rhrTrend)
            }
            biomarkerData["temperature"] = (value: 36.8, change: 0.5, trend: [36.5, 36.6, 36.7, 36.8, 36.9, 36.8, 36.8])
            biomarkerData["respiratory"] = (value: 16, change: -2.0, trend: [17, 16.5, 16.2, 16.0, 15.8, 16.1, 16.0])
            biomarkerData["oxygen"] = (value: 98, change: 0.0, trend: [97, 98, 98, 98, 99, 98, 98])
        }
    }
    private func fetchHRV(for date: Date) async -> Double? {
        return await withCheckedContinuation { continuation in
            HealthKitManager.shared.fetchHRV(for: date) { hrv in
                continuation.resume(returning: hrv)
            }
        }
    }
    private func fetchRHR(for date: Date) async -> Double? {
        return await withCheckedContinuation { continuation in
            HealthKitManager.shared.fetchRHR(for: date) { rhr in
                continuation.resume(returning: rhr)
            }
        }
    }
    private func calculatePercentageChange(current: Double?, previous: Double?) -> Double? {
        guard let current = current, let previous = previous, previous != 0 else { return nil }
        return ((current - previous) / previous) * 100
    }
    private func generateInsightsList(from result: RecoveryScoreResult) -> [String] {
        var insights: [String] = []
        
        // HRV Insights - based on the actual ratio and score
        if let hrvValue = result.hrvComponent.currentValue, let baseline = result.hrvComponent.baseline {
            let ratio = hrvValue / baseline
            let percentageDiff = (ratio - 1) * 100
            
            if ratio >= 1.1 {
                insights.append("Your HRV is \(Int(percentageDiff))% above baseline - excellent recovery")
            } else if ratio >= 1.0 {
                insights.append("Your HRV is \(Int(percentageDiff))% above baseline - good recovery")
            } else if ratio >= 0.9 {
                insights.append("Your HRV is \(Int(abs(percentageDiff)))% below baseline - moderate recovery")
            } else {
                insights.append("Your HRV is \(Int(abs(percentageDiff)))% below baseline - consider rest")
            }
            
            // Add context about the score
            if result.hrvComponent.score >= 80 {
                insights.append("HRV score indicates good readiness despite baseline comparison")
            } else if result.hrvComponent.score < 60 {
                insights.append("HRV score suggests reduced recovery readiness")
            }
        }
        
        // RHR Insights
        if let rhrValue = result.rhrComponent.currentValue, let baseline = result.rhrComponent.baseline {
            let ratio = baseline / rhrValue
            let percentageDiff = (ratio - 1) * 100
            
            if ratio >= 1.05 {
                insights.append("Your RHR is \(Int(percentageDiff))% below baseline - good cardiovascular recovery")
            } else if ratio >= 1.0 {
                insights.append("Your RHR is at baseline level - normal cardiovascular status")
            } else if ratio >= 0.95 {
                insights.append("Your RHR is \(Int(abs(percentageDiff)))% above baseline - may indicate stress")
            } else {
                insights.append("Your RHR is \(Int(abs(percentageDiff)))% above baseline - consider stress management")
            }
        }
        
        // Sleep Insights
        if result.sleepComponent.score >= 80 {
            insights.append("Excellent sleep quality supports your recovery")
        } else if result.sleepComponent.score >= 70 {
            insights.append("Good sleep quality contributes to recovery")
        } else if result.sleepComponent.score < 60 {
            insights.append("Poor sleep quality may be limiting recovery")
        }
        
        // Stress Insights
        if result.stressComponent.score < 70 {
            insights.append("Elevated stress indicators detected - consider stress management")
        } else if result.stressComponent.score >= 90 {
            insights.append("Low stress indicators - good autonomic balance")
        }
        
        // Overall Recovery Insights
        if result.finalScore >= 85 {
            insights.append("You're primed for high-intensity training")
        } else if result.finalScore >= 70 {
            insights.append("Good recovery status - moderate training recommended")
        } else if result.finalScore >= 50 {
            insights.append("Moderate recovery - consider light training or rest")
        } else {
            insights.append("Focus on rest and recovery activities today")
        }
        
        return insights.isEmpty ? ["No specific insights available for this date"] : insights
    }
}

// MARK: - Supporting Views

struct BiomarkerCard: View {
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
                if unit == "ms" || unit == "bpm" {
                    // HRV and RHR should be displayed as integers
                    Text("\(Int(value))")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                } else if unit == "%" {
                    // Percentages should be displayed as integers
                    Text("\(Int(value))")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                } else {
                    // Other values can have decimals
                    Text("\(String(format: "%.1f", value))")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                Text(unit)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(red: 0.2, green: 0.2, blue: 0.2))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(unit == "ms" || unit == "bpm" || unit == "%" ? "\(Int(value))" : String(format: "%.1f", value)) \(unit)")
    }
}

struct RecoveryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        RecoveryDetailView()
    }
} 