import SwiftUI

struct RecoveryScoreBreakdown {
    static let hrvMax: Double = 50
    static let rhrMax: Double = 25
    static let sleepMax: Double = 15
    static let stressMax: Double = 10
}

struct RecoveryDetailView: View {
    @EnvironmentObject var dateModel: PerformanceDateModel
    @EnvironmentObject var tabSelectionModel: TabSelectionModel
    @State private var recoveryResult: RecoveryScoreResult?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var biomarkerData: [String: (value: Double, change: Double?, trend: [Double])] = [:]
    @State private var scrollToTopTrigger = false
    @State private var loadingWorkItem: DispatchWorkItem? = nil
    
    var selectedDate: Date { dateModel.selectedDate }
    
    var body: some View {
        ScrollViewReader { proxy in
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
                        .background(AppColors.secondaryBackground)
                        .cornerRadius(16)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Recovery Score: \(result.finalScore)")
                        
                        // How It Was Calculated Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How It Was Calculated")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
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
                        .background(AppColors.secondaryBackground)
                        .cornerRadius(16)
                        
                        // Recovery Insights Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recovery Insights")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
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
                        .background(AppColors.secondaryBackground)
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
                .id("recoveryRoot")
                .padding()
            }
            .onChange(of: scrollToTopTrigger) { _, _ in
                withAnimation {
                    proxy.scrollTo("recoveryRoot", anchor: .top)
                }
            }
        }
        .background(AppColors.background)
        .navigationTitle("Recovery")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadRecoveryData()
        }
        .onChange(of: selectedDate) { _, _ in
            loadRecoveryData()
        }
        .onChange(of: tabSelectionModel.selection) { old, new in
            if new == 2 && old == 2 {
                // Tab reselected, pop to root
                scrollToTopTrigger.toggle()
            }
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
                Button("Retry") { loadRecoveryData() }
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }
    
    private func loadRecoveryData() {
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
                let result = try await RecoveryScoreCalculator.shared.calculateRecoveryScore(for: selectedDate)
                await loadBiomarkerData(for: selectedDate)
                await MainActor.run {
                    self.loadingWorkItem?.cancel()
                    self.recoveryResult = result
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
    private func feedbackLabel(for score: Double) -> String {
        switch score {
        case 90...:
            return "Excellent"
        case 80..<90:
            return "Good"
        case 70..<80:
            return "Fair"
        case 60..<70:
            return "Poor"
        default:
            return "Critical"
        }
    }
    private func generateInsightsList(from result: RecoveryScoreResult) -> [String] {
        var insights: [String] = []
        // User baselines
        let baselineHRV = 62.1
        let baselineRHR = 60.4
        let baselineSleep = 53.7
        let baselineStress = 87.9
        let baselineWalkingHR = 95.0
        let baselineRespiratory = 15.0
        let baselineOxygen = 99.0
        // HRV
        if let hrvValue = result.hrvComponent.currentValue, let _ = result.hrvComponent.baseline {
            let diff = hrvValue - baselineHRV
            if abs(diff) < 2 {
                insights.append("Excellent: HRV matches your baseline (")
            } else if abs(diff) < 5 {
                insights.append("Good: HRV is close to your baseline (")
            } else if abs(diff) < 10 {
                insights.append("Fair: HRV is somewhat off baseline (")
            } else {
                insights.append("Poor: HRV is far from your baseline (")
            }
        }
        // RHR
        if let rhrValue = result.rhrComponent.currentValue, let _ = result.rhrComponent.baseline {
            let diff = rhrValue - baselineRHR
            if abs(diff) < 2 {
                insights.append("Excellent: RHR matches your baseline (")
            } else if abs(diff) < 5 {
                insights.append("Good: RHR is close to your baseline (")
            } else if abs(diff) < 10 {
                insights.append("Fair: RHR is somewhat off baseline (")
            } else {
                insights.append("Poor: RHR is far from your baseline (")
            }
        }
        // Sleep Score
        let sleepDiff = result.sleepComponent.score - baselineSleep
        if abs(sleepDiff) < 2 {
            insights.append("Excellent: Sleep score matches your baseline (")
        } else if abs(sleepDiff) < 5 {
            insights.append("Good: Sleep score is close to your baseline (")
        } else if abs(sleepDiff) < 10 {
            insights.append("Fair: Sleep score is somewhat off baseline (")
        } else {
            insights.append("Poor: Sleep score is far from your baseline (")
        }
        // Stress
        let stressDiff = result.stressComponent.score - baselineStress
        if abs(stressDiff) < 5 {
            insights.append("Excellent: Stress matches your baseline (")
        } else if abs(stressDiff) < 10 {
            insights.append("Good: Stress is close to your baseline (")
        } else if abs(stressDiff) < 20 {
            insights.append("Fair: Stress is somewhat off baseline (")
        } else {
            insights.append("Poor: Stress is far from your baseline (")
        }
        // Walking HR
        if let walkHR = result.stressComponent.currentValue {
            let diff = walkHR - baselineWalkingHR
            if abs(diff) < 2 {
                insights.append("Excellent: Walking HR matches your baseline (")
            } else if abs(diff) < 5 {
                insights.append("Good: Walking HR is close to your baseline (")
            } else if abs(diff) < 10 {
                insights.append("Fair: Walking HR is somewhat off baseline (")
            } else {
                insights.append("Poor: Walking HR is far from your baseline (")
            }
        }
        // Respiratory Rate
        if let resp = result.stressComponent.currentValue {
            let diff = resp - baselineRespiratory
            if abs(diff) < 2 {
                insights.append("Excellent: Respiratory rate matches your baseline (")
            } else if abs(diff) < 5 {
                insights.append("Good: Respiratory rate is close to your baseline (")
            } else if abs(diff) < 10 {
                insights.append("Fair: Respiratory rate is somewhat off baseline (")
            } else {
                insights.append("Poor: Respiratory rate is far from your baseline (")
            }
        }
        // Oxygen Saturation
        if let oxygen = result.stressComponent.currentValue {
            let diff = oxygen - baselineOxygen
            if abs(diff) < 1 {
                insights.append("Excellent: Oxygen saturation matches your baseline (")
            } else if abs(diff) < 2 {
                insights.append("Good: Oxygen saturation is close to your baseline (")
            } else if abs(diff) < 5 {
                insights.append("Fair: Oxygen saturation is somewhat off baseline (")
            } else {
                insights.append("Poor: Oxygen saturation is far from your baseline (")
            }
        }
        // Add more metrics as needed
        return insights
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
                        .foregroundColor(.primary)
                } else if unit == "%" {
                    // Percentages should be displayed as integers
                    Text("\(Int(value))")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                } else {
                    // Other values can have decimals
                    Text("\(String(format: "%.1f", value))")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                Text(unit)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppColors.secondaryBackground)
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
