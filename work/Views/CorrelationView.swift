import SwiftUI
import SwiftData

struct CorrelationView: View {
    @StateObject private var correlationEngine = CorrelationEngine.shared
    @State private var isLoading = false
    @State private var selectedTimeRange: TimeRange = .month
    
    enum TimeRange: String, CaseIterable {
        case week = "7 Days"
        case month = "30 Days"
        case quarter = "90 Days"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Time Range Picker
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView("Analyzing correlations...")
                            .padding()
                    } else if correlationEngine.correlations.isEmpty {
                        EmptyCorrelationView()
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(correlationEngine.correlations) { correlation in
                                CorrelationCard(correlation: correlation)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Correlations")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        refreshCorrelations()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .onAppear {
                if correlationEngine.correlations.isEmpty {
                    refreshCorrelations()
                }
            }
        }
    }
    
    private func refreshCorrelations() {
        isLoading = true
        Task {
            await correlationEngine.calculateCorrelations()
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct EmptyCorrelationView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Correlations Found")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Track your habits and health metrics for at least a week to discover meaningful correlations.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct CorrelationCard: View {
    let correlation: Correlation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: correlation.icon)
                    .font(.title2)
                    .foregroundColor(correlation.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(correlation.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(correlation.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(String(format: "%.2f", correlation.strength))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(correlation.color)
            }
            
            // Correlation strength indicator
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(correlation.color)
                        .frame(width: geometry.size.width * abs(correlation.strength), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
            
            Text(correlation.insight)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(12)
    }
}

#Preview {
    CorrelationView()
}