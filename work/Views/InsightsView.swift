import SwiftUI

struct InsightsView: View {
    @StateObject private var correlationEngine = CorrelationEngine.shared
    @State private var isLoading = false
    @State private var showingEmptyState = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if correlationEngine.insights.isEmpty {
                    emptyStateView
                } else {
                    insightsList
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        refreshInsights()
                    }
                    .foregroundColor(.blue)
                }
            }
            .onAppear {
                if correlationEngine.insights.isEmpty {
                    refreshInsights()
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)
            
            Text("Analyzing your data...")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("This may take a few moments as we analyze patterns between your lifestyle factors and health metrics.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lightbulb")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("No Insights Yet")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                Text("Personalized insights will appear here once you have:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("At least 7 days of journal entries")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("Consistent supplement tracking")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("HealthKit data synced")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }
            }
            
            Button("Start Journaling") {
                // Navigate to journal
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding()
    }
    
    private var insightsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(correlationEngine.insights) { insight in
                    InsightCard(insight: insight)
                }
            }
            .padding()
        }
    }
    
    private func refreshInsights() {
        isLoading = true
        
        Task {
            await correlationEngine.runAnalysis()
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct InsightCard: View {
    let insight: CorrelationInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon and title
            HStack(spacing: 12) {
                Image(systemName: iconForInsight)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(insight.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            // Data and reliability
            HStack {
                Text(insight.data)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text(insight.reliability)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Impact indicator
            HStack {
                Image(systemName: impactIcon)
                    .foregroundColor(impactColor)
                Text(impactText)
                    .font(.caption)
                    .foregroundColor(impactColor)
                Spacer()
            }
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(impactColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var iconForInsight: String {
        switch insight.category {
        case .supplement:
            return "pills"
        case .lifestyle:
            return "person.fill"
        case .sleep:
            return "bed.double.fill"
        case .recovery:
            return "heart.fill"
        }
    }
    
    private var iconColor: Color {
        switch insight.category {
        case .supplement:
            return .purple
        case .lifestyle:
            return .blue
        case .sleep:
            return .indigo
        case .recovery:
            return .red
        }
    }
    
    private var impactIcon: String {
        switch insight.impact {
        case .positive:
            return "arrow.up.circle.fill"
        case .negative:
            return "arrow.down.circle.fill"
        case .neutral:
            return "minus.circle.fill"
        }
    }
    
    private var impactColor: Color {
        switch insight.impact {
        case .positive:
            return .green
        case .negative:
            return .red
        case .neutral:
            return .gray
        }
    }
    
    private var impactText: String {
        switch insight.impact {
        case .positive:
            return "Positive Impact"
        case .negative:
            return "Negative Impact"
        case .neutral:
            return "Neutral Impact"
        }
    }
}

struct InsightsView_Previews: PreviewProvider {
    static var previews: some View {
        InsightsView()
    }
} 