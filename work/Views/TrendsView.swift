import SwiftUI
import Charts

struct TrendsView: View {
    @StateObject private var vm = TrendsViewModel()
    @State private var selectedPeriod: TrendsViewModel.Period = .days30
    @State private var selectedMetric: TrendsViewModel.Metric = .recovery
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Metric", selection: $selectedMetric) {
                ForEach(TrendsViewModel.Metric.allCases, id: \.self) { metric in
                    Text(metric.displayName).tag(metric)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding([.top, .horizontal])
            Picker("Period", selection: $selectedPeriod) {
                ForEach(TrendsViewModel.Period.allCases, id: \.self) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            if let chartData = vm.chartData(for: selectedMetric, period: selectedPeriod) {
                Chart(chartData) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(selectedMetric.displayName, point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(selectedMetric.color)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    if point.isWorkout {
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value(selectedMetric.displayName, point.value)
                        )
                        .symbol(Circle())
                        .symbolSize(80)
                        .foregroundStyle(.orange)
                    }
                }
                .frame(height: 240)
                .padding(.horizontal)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: selectedPeriod.axisStride)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day(.defaultDigits))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            } else {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            }
            Spacer()
        }
        .navigationTitle("Trends")
        .onAppear { vm.load() }
    }
}

class TrendsViewModel: ObservableObject {
    enum Metric: String, CaseIterable {
        case recovery, sleep, hrv, rhr
        var displayName: String {
            switch self {
            case .recovery: return "Recovery"
            case .sleep: return "Sleep"
            case .hrv: return "HRV"
            case .rhr: return "RHR"
            }
        }
        var color: Color {
            switch self {
            case .recovery: return .green
            case .sleep: return .blue
            case .hrv: return .purple
            case .rhr: return .red
            }
        }
    }
    enum Period: Int, CaseIterable {
        case days7 = 7, days14 = 14, days30 = 30, days90 = 90
        var displayName: String {
            switch self {
            case .days7: return "7D"
            case .days14: return "14D"
            case .days30: return "30D"
            case .days90: return "90D"
            }
        }
        var axisStride: Int {
            switch self {
            case .days7: return 1
            case .days14: return 2
            case .days30: return 7
            case .days90: return 14
            }
        }
    }
    struct ChartPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let isWorkout: Bool
    }
    @Published private(set) var history: [DailyPerformance] = []
    @Published private(set) var workoutDates: Set<Date> = []
    
    func load() {
        Task {
            let baseline = DynamicBaselineEngine.shared
            baseline.loadBaselines()
            
            // Use real HealthKit data instead of demo data
            let hk = HealthKitManager.shared
            var history: [DailyPerformance] = []
            let calendar = Calendar.current
            
            // Fetch historical data for the last 90 days
            for offset in (0..<90).reversed() {
                let day = calendar.date(byAdding: .day, value: -offset, to: Date())!
                
                // Fetch data for this specific day
                let group = DispatchGroup()
                var hrv: Double?
                var rhr: Double?
                var sleep: (duration: TimeInterval, deep: TimeInterval, rem: TimeInterval, bedtime: Date, wake: Date)?
                
                group.enter()
                hk.fetchHRV(for: day) { value in
                    hrv = value
                    group.leave()
                }
                
                group.enter()
                hk.fetchRHR(for: day) { value in
                    rhr = value
                    group.leave()
                }
                
                group.enter()
                hk.fetchSleep(for: day) { value in
                    sleep = value
                    group.leave()
                }
                
                group.notify(queue: .main) {
                    let sleepScore = PerformanceDashboardViewModel.calculateSleepScore(sleep: sleep, baseline: baseline)
                    let recoveryScore = PerformanceDashboardViewModel.calculateRecoveryScore(hrv: hrv, rhr: rhr, sleepScore: sleepScore, baseline: baseline)
                    
                    let performance = DailyPerformance(
                        date: day,
                        recoveryScore: recoveryScore,
                        sleepScore: sleepScore,
                        hrv: hrv,
                        rhr: rhr,
                        sleepDuration: sleep?.duration,
                        deepSleep: sleep?.deep,
                        remSleep: sleep?.rem,
                        hrvDelta: nil,
                        rhrDelta: nil,
                        sleepDelta: nil,
                        directive: ""
                    )
                    
                    history.append(performance)
                    
                    // Update the published property when we have all data
                    if history.count == 90 {
                        Task { @MainActor in
                            self.history = history
                        }
                    }
                }
            }
            
            // Fetch workout dates from HealthKit
            hk.fetchWorkoutDates { dates in
                Task { @MainActor in
                    self.workoutDates = dates
                }
            }
        }
    }
    func chartData(for metric: Metric, period: Period) -> [ChartPoint]? {
        let slice = Array(history.suffix(period.rawValue))
        guard !slice.isEmpty else { return nil }
        return slice
            .sorted { $0.date < $1.date }
            .compactMap { day in
                let value: Double = {
                    switch metric {
                    case .recovery: return Double(day.recoveryScore)
                    case .sleep: return Double(day.sleepScore)
                    case .hrv: return day.hrv ?? 0
                    case .rhr: return day.rhr ?? 0
                    }
                }()
                let isWorkout = workoutDates.contains(Calendar.current.startOfDay(for: day.date))
                // Filter out NaN, zero, or negative values for chart clarity
                if value.isNaN || value == 0 { return nil }
                return ChartPoint(date: day.date, value: value, isWorkout: isWorkout)
            }
    }
} 