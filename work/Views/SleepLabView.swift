import SwiftUI

// MARK: - Data Models
// This is the single, correct definition for your data models.
// Ensure these structs are not defined anywhere else in your project.


struct CorrelationData: Codable, Identifiable {
    // Use the unique session_date as the ID
    var id: String { session_date }

    let session_date: String
    let sleep_score: Int
    let environmental_averages: EnvironmentalAverages

    var displayDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        if let date = formatter.date(from: session_date) {
            if Calendar.current.isDateInToday(date) {
                return "Today"
            } else if Calendar.current.isDateInYesterday(date) {
                return "Yesterday"
            }
            return date.formatted(.dateTime.month().day())
        }
        return session_date
    }
}

struct EnvironmentalAverages: Codable {
    let avg_temperature: Double? // Optional to handle null from server
    let avg_humidity: Double?    // Optional to handle null from server
    let avg_air_quality: Double? // Optional to handle null from server
}


// MARK: - Main View
struct SleepLabView: View {
    @State private var correlationData: [CorrelationData] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ZStack {
                // Use a dark background consistent with the app's theme
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()

                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if correlationData.isEmpty {
                    emptyStateView
                } else {
                    dataListView
                }
            }
            .navigationTitle("Sleep Lab")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoading {
                        ProgressView()
                    }
                }
            }
            .onAppear {
                Task {
                    await fetchCorrelationData()
                }
            }
            .refreshable {
                await fetchCorrelationData()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews
    private var dataListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Correlation Insights")
                    .font(.title2.bold())
                    .padding(.horizontal)
                
                Text("Comparing your sleep quality with the environmental data recorded by your bedside sensor.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 10)

                // Correctly sort by date string (descending) and pass data
                LazyVStack(spacing: 16) {
                    ForEach(correlationData.sorted(by: { $0.session_date > $1.session_date })) { data in
                        SleepCorrelationCard(data: data)
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Fetching correlation insights...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("Connection Issue")
                .font(.headline)
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Try Again") {
                Task {
                    await fetchCorrelationData()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            Text("No Correlation Data Yet")
                .font(.title2.bold())
            Text("Make sure your bedside sensor is running and sleep data is synced. Insights will appear here after a few nights of data collection.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Data Fetching
    private func fetchCorrelationData() async {
        if !correlationData.isEmpty { // Don't show full loading screen on refresh
            isLoading = false
        } else {
            isLoading = true
        }
        errorMessage = nil
        
        do {
            let data = try await APIService.shared.fetchCorrelationData()
            self.correlationData = data
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        self.isLoading = false
    }
}

// MARK: - Reusable Card View
struct SleepCorrelationCard: View {
    let data: CorrelationData
    
    private var sleepScoreColor: Color {
        switch data.sleep_score {
        case 85...100: return .green
        case 70..<85: return .blue
        case 50..<70: return .orange
        default: return .red
        }
    }
    
    private var environmentalRatingColor: Color {
        guard let rating = data.environmental_averages.avg_air_quality else { return .gray }
        switch rating {
        case 0...50: return .green
        case 51...100: return .blue
        case 101...150: return .orange
        case 151...200: return .red
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with date and sleep score
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.displayDate)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let airQuality = data.environmental_averages.avg_air_quality {
                        Text("Air Quality: \(String(format: "%.0f", airQuality)) ppm")
                            .font(.caption)
                            .foregroundColor(environmentalRatingColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(environmentalRatingColor.opacity(0.1))
                            .cornerRadius(6)
                    } else {
                        Text("Air Quality: --")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(data.sleep_score)%")
                        .font(.title.bold())
                        .foregroundColor(sleepScoreColor)
                    
                    Text("Sleep Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Environmental metrics
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // Temperature metric
                if let temp = data.environmental_averages.avg_temperature {
                    EnvironmentalMetric(
                        icon: "thermometer.sun.fill",
                        title: "Temperature",
                        value: String(format: "%.1f°C", temp),
                        color: .orange
                    )
                } else {
                    EnvironmentalMetric(
                        icon: "thermometer.sun.fill",
                        title: "Temperature",
                        value: "--",
                        color: .gray
                    )
                }
                
                // Humidity metric
                if let humidity = data.environmental_averages.avg_humidity {
                    EnvironmentalMetric(
                        icon: "humidity.fill",
                        title: "Humidity",
                        value: String(format: "%.1f%%", humidity),
                        color: .cyan
                    )
                } else {
                    EnvironmentalMetric(
                        icon: "humidity.fill",
                        title: "Humidity",
                        value: "--",
                        color: .gray
                    )
                }
                
                // Air Quality metric
                if let airQuality = data.environmental_averages.avg_air_quality {
                    EnvironmentalMetric(
                        icon: "wind",
                        title: "Air Quality",
                        value: String(format: "%.0f ppm", airQuality),
                        color: .gray
                    )
                } else {
                    EnvironmentalMetric(
                        icon: "wind",
                        title: "Air Quality",
                        value: "--",
                        color: .gray
                    )
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Reusable Metric View
struct EnvironmentalMetric: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title3.weight(.semibold))
        }
    }
}

// MARK: - Preview
struct SleepLabView_Previews: PreviewProvider {
    static var previews: some View {
        SleepLabView()
    }
}
