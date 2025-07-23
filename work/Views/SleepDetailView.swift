import SwiftUI
import Foundation

struct SleepScoreBreakdown {
    static let durationMax: Double = 25
    static let efficiencyMax: Double = 25
    static let deepMax: Double = 20
    static let remMax: Double = 20
    static let onsetMax: Double = 10
}

struct SleepDetailView: View {
    @EnvironmentObject var dateModel: PerformanceDateModel
    @StateObject private var healthStats = HealthStatsViewModel()
    
    var selectedDate: Date { dateModel.selectedDate }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DateSliderView(selectedDate: $dateModel.selectedDate)
                
                if healthStats.isLoading {
                    loadingOverlay
                } else if let error = healthStats.errorMessage {
                    errorOverlay(error)
                } else if let sleepResult = healthStats.sleepResult {
                    // Main Score Card
                    VStack(spacing: 8) {
                        Text("Sleep Score")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text("\(sleepResult.finalScore)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(AppColors.secondaryBackground)
                    .cornerRadius(16)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Sleep Score: \(sleepResult.finalScore)")
                    
                    // How It Was Calculated Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How It Was Calculated")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        VStack(spacing: 8) {
                            ForEach(healthStats.sleepComponents) { component in
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
                    
                    // Sleep Insights Card (Three-Layer Model)

                    VStack(alignment: .leading, spacing: 16) {
                        // Headline
                        Text(SleepAnalysisEngine.generateInsights(from: sleepResult).headline)
                            .font(.headline)
                            .foregroundColor(.primary)

                        // Component Breakdown
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(SleepAnalysisEngine.generateInsights(from: sleepResult).componentBreakdown) { component in
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
                                        Text(component.analysis)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }

                        // Actionable Recommendation
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text(SleepAnalysisEngine.generateInsights(from: sleepResult).recommendation)
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
                    
                    // Sleep Metrics Grid - Using Professional BiomarkerTrendCard
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        sleepBiomarkerCards
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
            Task {
                await healthStats.loadData(for: selectedDate)
            }
        }
        .onChange(of: selectedDate) { _, newDate in
            Task {
                await healthStats.loadData(for: newDate)
            }
        }
    }
    
    // MARK: - Professional Sleep Biomarker Cards
    
    @ViewBuilder
    private var sleepBiomarkerCards: some View {
        let sleepTrends = healthStats.getSleepBiomarkerTrends()
        
        if let timeInBedData = sleepTrends["timeInBed"] {
            BiomarkerTrendCard(
                title: "Time in Bed",
                value: timeInBedData.currentValue,
                unit: timeInBedData.unit,
                percentageChange: timeInBedData.percentageChange,
                trendData: timeInBedData.trend,
                color: timeInBedData.color
            )
        }
        
        if let timeAsleepData = sleepTrends["timeAsleep"] {
            BiomarkerTrendCard(
                title: "Time Asleep",
                value: timeAsleepData.currentValue,
                unit: timeAsleepData.unit,
                percentageChange: timeAsleepData.percentageChange,
                trendData: timeAsleepData.trend,
                color: timeAsleepData.color
            )
        }
        
        if let remSleepData = sleepTrends["remSleep"] {
            BiomarkerTrendCard(
                title: "Time in REM",
                value: remSleepData.currentValue,
                unit: remSleepData.unit,
                percentageChange: remSleepData.percentageChange,
                trendData: remSleepData.trend,
                color: remSleepData.color
            )
        }
        
        if let deepSleepData = sleepTrends["deepSleep"] {
            BiomarkerTrendCard(
                title: "Time in Deep",
                value: deepSleepData.currentValue,
                unit: deepSleepData.unit,
                percentageChange: deepSleepData.percentageChange,
                trendData: deepSleepData.trend,
                color: deepSleepData.color
            )
        }
        
        if let efficiencyData = sleepTrends["efficiency"] {
            BiomarkerTrendCard(
                title: "Sleep Efficiency",
                value: efficiencyData.currentValue,
                unit: efficiencyData.unit,
                percentageChange: efficiencyData.percentageChange,
                trendData: efficiencyData.trend,
                color: efficiencyData.color
            )
        }
        
        if let fallAsleepData = sleepTrends["fallAsleep"] {
            BiomarkerTrendCard(
                title: "Time to Fall Asleep",
                value: fallAsleepData.currentValue,
                unit: fallAsleepData.unit,
                percentageChange: fallAsleepData.percentageChange,
                trendData: fallAsleepData.trend,
                color: fallAsleepData.color
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView("Loading sleep data...")
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
            
            Text("Unable to load sleep data")
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
    
    // MARK: - Insight Status Colour Helper
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

struct SleepDetailView_Previews: PreviewProvider {
    static var previews: some View {
        SleepDetailView()
    }
} 
