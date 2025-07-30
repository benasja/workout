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
                                .foregroundColor(AppColors.textSecondary)
                            Text("\(recoveryResult.finalScore)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.success)
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
                                        maxScore: component.maxScore,
                                        description: component.description
                                    )
                                }
                            }
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
        
        // Use HRV data from recovery score calculation for consistency
        if let recoveryResult = healthStats.recoveryResult,
           let hrvValue = recoveryResult.hrvComponent.currentValue {
            BiomarkerTrendCard(
                title: "Resting HRV",
                value: hrvValue,
                unit: "ms",
                percentageChange: biomarkerTrends["hrv"]?.percentageChange,
                trendData: biomarkerTrends["hrv"]?.trend ?? [],
                color: .green
            )
        }
        
        // Use RHR data from recovery score calculation for consistency
        if let recoveryResult = healthStats.recoveryResult,
           let rhrValue = recoveryResult.rhrComponent.currentValue {
            BiomarkerTrendCard(
                title: "Resting HR",
                value: rhrValue,
                unit: "bpm",
                percentageChange: biomarkerTrends["rhr"]?.percentageChange,
                trendData: biomarkerTrends["rhr"]?.trend ?? [],
                color: .blue
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
            Image(systemName: "moon.zzz")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("Recovery Data Not Yet Available")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if error.contains("not yet available") {
                Text("Your recovery score will be calculated once you complete your sleep session and wake up.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
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
