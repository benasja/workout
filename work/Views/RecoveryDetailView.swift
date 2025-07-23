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
    @StateObject private var healthStats = HealthStatsViewModel()
    @State private var scrollToTopTrigger = false
    
    var selectedDate: Date { dateModel.selectedDate }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    DateSliderView(selectedDate: $dateModel.selectedDate)
                    
                    if healthStats.isLoading {
                        loadingOverlay
                    } else if let error = healthStats.errorMessage {
                        errorOverlay(error)
                    } else if let recoveryResult = healthStats.recoveryResult {
                        // Main Score Card
                        VStack(spacing: 8) {
                            Text("Recovery Score")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("\(recoveryResult.finalScore)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(AppColors.secondaryBackground)
                        .cornerRadius(16)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Recovery Score: \(recoveryResult.finalScore)")
                        
                        // How It Was Calculated Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How It Was Calculated")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            VStack(spacing: 8) {
                                ForEach(healthStats.recoveryComponents) { component in
                                    ScoreBreakdownRow(
                                        component: component.name,
                                        score: component.score,
                                        maxScore: component.maxScore
                                    )
                                }
                            }
                        }
                        .padding(16)
                        .background(AppColors.secondaryBackground)
                        .cornerRadius(16)
                        
                        // Recovery Insights Card (Three-Layer Model)
                        VStack(alignment: .leading, spacing: 16) {
                            // Headline
                            Text(RecoveryAnalysisEngine.generateInsights(from: recoveryResult).headline)
                                .font(.headline)
                                .foregroundColor(.primary)

                            // Component Breakdown
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(RecoveryAnalysisEngine.generateInsights(from: recoveryResult).componentBreakdown) { component in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(color(for: component.status))
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack {
                                                Text(component.metricName)
                                                    .font(.subheadline)
                                                    .foregroundColor(.primary)
                                                Spacer()
                                                Text(component.userValue)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                            if !component.optimalRange.isEmpty {
                                                Text(component.optimalRange)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            Text(component.analysis)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }

                            // Recommendation Box
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.yellow)
                                Text(RecoveryAnalysisEngine.generateInsights(from: recoveryResult).recommendation)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .background(AppColors.tertiaryBackground)
                            .cornerRadius(12)
                        }
                        .padding(16)
                        .background(AppColors.secondaryBackground)
                        .cornerRadius(16)
                        
                        // Biomarkers Grid - Using Centralized Data
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            recoveryBiomarkerCards
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
            Task {
                await healthStats.loadData(for: selectedDate)
            }
        }
        .onChange(of: selectedDate) { _, newDate in
            Task {
                await healthStats.loadData(for: newDate)
            }
        }
        .onChange(of: tabSelectionModel.selection) { old, new in
            if new == 2 && old == 2 {
                // Tab reselected, pop to root
                scrollToTopTrigger.toggle()
            }
        }
    }
    
    // MARK: - Recovery Biomarker Cards Using Centralized Data
    
    @ViewBuilder
    private var recoveryBiomarkerCards: some View {
        let biomarkerTrends = healthStats.biomarkerTrends
        
        if let hrvData = biomarkerTrends["hrv"] {
            BiomarkerTrendCard(
                title: "Resting HRV",
                value: hrvData.currentValue,
                unit: hrvData.unit,
                percentageChange: hrvData.percentageChange,
                trendData: hrvData.trend,
                color: hrvData.color
            )
        }
        
        if let rhrData = biomarkerTrends["rhr"] {
            BiomarkerTrendCard(
                title: "Resting HR",
                value: rhrData.currentValue,
                unit: rhrData.unit,
                percentageChange: rhrData.percentageChange,
                trendData: rhrData.trend,
                color: rhrData.color
            )
        }
        
        // Additional biomarkers with fallback data if not available from centralized source
        BiomarkerTrendCard(
            title: "Wrist Temp",
            value: 36.8,
            unit: "°C",
            percentageChange: 0.5,
            trendData: [36.5, 36.6, 36.7, 36.8, 36.9, 36.8, 36.8],
            color: .orange
        )
        
        BiomarkerTrendCard(
            title: "Respiratory Rate",
            value: 16,
            unit: "rpm",
            percentageChange: -2.0,
            trendData: [17, 16.5, 16.2, 16.0, 15.8, 16.1, 16.0],
            color: .purple
        )
        
        BiomarkerTrendCard(
            title: "Oxygen Saturation",
            value: 98,
            unit: "%",
            percentageChange: 0.0,
            trendData: [97, 98, 98, 98, 99, 98, 98],
            color: .cyan
        )
    }
    
    // MARK: - Helper Methods
    
    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView("Loading recovery data...")
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                .foregroundColor(.primary)
            
            if healthStats.isCalculatingBaseline {
                Text("Calculating historical baseline...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(12)
    }
    
    private func errorOverlay(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Unable to load recovery data")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await healthStats.refresh()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Helper Colour Mapper
    private func color(for status: InsightStatus) -> Color {
        switch status {
        case .optimal, .good:
            return .green
        case .fair:
            return .orange
        case .poor:
            return .red
        }
    }
}

struct RecoveryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        RecoveryDetailView()
    }
} 
