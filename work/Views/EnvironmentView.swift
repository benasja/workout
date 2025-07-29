import SwiftUI
import Charts

struct EnvironmentView: View {
    @State private var latestData: LatestEnvironmentalData?
    @State private var historicalData: [EnvironmentalData] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastRefreshTime = Date()
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header with refresh info
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Environmental Monitor")
                                .font(.largeTitle.bold())
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("Last updated: \(lastRefreshTime, style: .time)")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            Task { await refreshData() }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .foregroundColor(AppColors.primary)
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal)
                    
                    // Real-time Metric Cards
                    metricsSection
                    
                    // Historical Trend Charts
                    trendsSection
                    
                    // Error state
                    if let errorMessage = errorMessage {
                        ErrorCard(message: errorMessage) {
                            Task { await refreshData() }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                    }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            Task { await loadInitialData() }
        }
        }
    }
    
    // MARK: - Metrics Section
    
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Conditions")
                .font(.title2.bold())
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // Temperature Card
                EnvMetricCard(
                    title: "Temperature",
                    value: latestData != nil ? String(format: "%.1f°C", latestData!.temperature) : "--",
                    icon: "thermometer.sun.fill",
                    color: .orange,
                    isLoading: isLoading
                )
                
                // Humidity Card
                EnvMetricCard(
                    title: "Humidity",
                    value: latestData != nil ? String(format: "%.1f%%", latestData!.humidity) : "--",
                    icon: "humidity.fill",
                    color: .cyan,
                    isLoading: isLoading
                )
                
                // Air Quality Card
                EnvMetricCard(
                    title: "Air Quality",
                    value: latestData != nil ? String(format: "%.0f ppm", latestData!.airQuality) : "--",
                    icon: "wind",
                    color: airQualityColor,
                    isLoading: isLoading
                )
                
                // Luminosity Card
                EnvMetricCard(
                    title: "Luminosity",
                    value: latestData != nil ? String(format: "%.0f lux", latestData!.luminosity) : "--",
                    icon: "sun.max.fill",
                    color: .yellow,
                    isLoading: isLoading
                )
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Trends Section
    
    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("24-Hour Trends")
                .font(.title2.bold())
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal)
            
            // Temperature Chart
            TrendChart(
                title: "Temperature",
                data: historicalData,
                valueKeyPath: \.temperature,
                color: .orange,
                unit: "°C",
                isLoading: isLoading
            )
            .padding(.horizontal)
            
            // Humidity Chart
            TrendChart(
                title: "Humidity",
                data: historicalData,
                valueKeyPath: \.humidity,
                color: .cyan,
                unit: "%",
                isLoading: isLoading
            )
            .padding(.horizontal)
            
            // Air Quality Chart
            TrendChart(
                title: "Air Quality",
                data: historicalData,
                valueKeyPath: \.airQuality,
                color: .gray,
                unit: "ppm",
                isLoading: isLoading
            )
            .padding(.horizontal)
            
            // Luminosity Chart
            TrendChart(
                title: "Luminosity",
                data: historicalData,
                valueKeyPath: \.luminosity,
                color: .yellow,
                unit: "lux",
                isLoading: isLoading
            )
            .padding(.horizontal)
        }
    }
    
    // MARK: - Computed Properties
    
    private var airQualityColor: Color {
        guard let airQuality = latestData?.airQuality else { return .gray }
        
        switch airQuality {
        case 0..<50:
            return .green
        case 50..<100:
            return .yellow
        case 100..<150:
            return .orange
        default:
            return .red
        }
    }
    
    // MARK: - Data Loading Methods
    
    private func loadInitialData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await fetchLatestData() }
            group.addTask { await fetchHistoricalData() }
        }
    }
    
    private func refreshData() async {
        isLoading = true
        errorMessage = nil
        
        await loadInitialData()
        lastRefreshTime = Date()
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func fetchLatestData() async {
        do {
            let data = try await APIService.shared.fetchLatestEnvironmentalData()
            await MainActor.run {
                self.latestData = data
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch latest data: \(error.localizedDescription)"
            }
            print("❌ Error fetching latest environmental data: \(error)")
        }
    }
    
    private func fetchHistoricalData() async {
        do {
            let data = try await APIService.shared.fetchEnvironmentalHistory()
            await MainActor.run {
                self.historicalData = data.sorted { $0.timestamp < $1.timestamp }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch historical data: \(error.localizedDescription)"
            }
            print("❌ Error fetching environmental history: \(error)")
        }
    }
}

// MARK: - Metric Card Component

struct EnvMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let isLoading: Bool
    var isFullWidth: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            } else {
                Text(value)
                    .font(.title.bold())
                    .foregroundColor(AppColors.textPrimary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.secondaryBackground)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Trend Chart Component

struct TrendChart: View {
    let title: String
    let data: [EnvironmentalData]
    let valueKeyPath: KeyPath<EnvironmentalData, Double>
    let color: Color
    let unit: String
    let isLoading: Bool
    
    private var chartData: [(Date, Double)] {
        data.map { item in
            (item.date, item[keyPath: valueKeyPath])
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            
            if isLoading {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(height: 200)
                    .overlay(
                        ProgressView("Loading chart...")
                            .foregroundColor(AppColors.textSecondary)
                    )
            } else if chartData.isEmpty {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(height: 200)
                    .overlay(
                        VStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title2)
                                .foregroundColor(AppColors.textSecondary)
                            Text("No data available")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    )
            } else {
                Chart {
                    ForEach(chartData, id: \.0) { date, value in
                        LineMark(
                            x: .value("Time", date),
                            y: .value(title, value)
                        )
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        
                        AreaMark(
                            x: .value("Time", date),
                            y: .value(title, value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [color.opacity(0.3), color.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.hour())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.secondaryBackground)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
            }
        }
    }
}

// MARK: - Error Card Component

struct ErrorCard: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Error")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }
            
            Text(message)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.leading)
            
            Button("Retry") {
                retryAction()
            }
            .foregroundColor(AppColors.primary)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.secondaryBackground)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

struct EnvironmentView_Previews: PreviewProvider {
    static var previews: some View {
        EnvironmentView()
            .preferredColorScheme(.dark)
    }
} 
