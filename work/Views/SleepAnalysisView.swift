import SwiftUI
import Charts
import SwiftData

struct SleepAnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyJournal.date, order: .reverse) private var journals: [DailyJournal]
    @State private var sleepHistory: [DailyPerformance] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedRange: SleepRange = .week
    
    enum SleepRange: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Text("Sleep Analysis")
                            .font(.largeTitle.bold())
                        Spacer()
                        Picker("Range", selection: $selectedRange) {
                            ForEach(SleepRange.allCases) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 140)
                    }
                    .padding(.top)
                    
                    if isLoading {
                        ProgressView("Loading sleep data...")
                            .padding()
                    } else if let error = error {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        SleepChartView(history: filteredHistory)
                        SleepScoreTrendView(history: filteredHistory)
                        SleepTipsCard()
                        SleepFactorAnalysisCard()
                    }
                }
                .padding()
            }
            .navigationTitle("Sleep")
            .onAppear(perform: loadData)
        }
    }
    
    var filteredHistory: [DailyPerformance] {
        let days = selectedRange == .week ? 7 : 30
        return Array(sleepHistory.prefix(days).reversed())
    }
    
    func loadData() {
        isLoading = true
        error = nil
        Task {
            let vm = PerformanceDashboardViewModel()
            await vm.load()
            await MainActor.run {
                self.sleepHistory = vm.history
                self.isLoading = false
            }
        }
    }
}

// Helper to calculate trend percentage
fileprivate func calculateTrend<T: BinaryFloatingPoint>(_ values: [T?]) -> Double? {
    let valid = values.compactMap { $0 }
    guard valid.count >= 2 else { return nil }
    let last = valid[valid.count - 1]
    let prev = valid[valid.count - 2]
    guard prev != 0 else { return nil }
    return Double((last - prev) / prev * 100)
}

struct SleepChartView: View {
    let history: [DailyPerformance]
    var body: some View {
        let durations = history.compactMap { $0.sleepDuration.map { $0 / 3600 } }
        let trend = calculateTrend(durations)
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Text("Sleep Duration (h:mm)")
                        .font(.headline)
                    if let trend = trend {
                        Image(systemName: trend >= 0 ? "arrow.up" : "arrow.down")
                            .font(.caption2)
                            .foregroundColor(trend >= 0 ? .green : .red)
                        Text("\(String(format: "%.1f", abs(trend)))%")
                            .font(.caption2)
                            .foregroundColor(trend >= 0 ? .green : .red)
                    }
                }
                if history.isEmpty {
                    Text("No sleep data available.")
                        .foregroundColor(.secondary)
                } else {
                    Chart(history) { perf in
                        if let duration = perf.sleepDuration {
                            BarMark(
                                x: .value("Date", perf.date, unit: .day),
                                y: .value("Hours", duration/3600)
                            )
                            .foregroundStyle(Color.blue)
                        }
                    }
                    .frame(height: 180)
                    .chartYAxis {
                        AxisMarks(position: .leading) {
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 1)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                }
            }
        }
    }
}

struct SleepScoreTrendView: View {
    let history: [DailyPerformance]
    var body: some View {
        let scores = history.map { Double($0.sleepScore) }
        let trend = calculateTrend(scores)
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Text("Sleep Score Trend")
                        .font(.headline)
                    if let trend = trend {
                        Image(systemName: trend >= 0 ? "arrow.up" : "arrow.down")
                            .font(.caption2)
                            .foregroundColor(trend >= 0 ? .green : .red)
                        Text("\(String(format: "%.1f", abs(trend)))%")
                            .font(.caption2)
                            .foregroundColor(trend >= 0 ? .green : .red)
                    }
                }
                if history.isEmpty {
                    Text("No sleep score data available.")
                        .foregroundColor(.secondary)
                } else {
                    Chart(history) { perf in
                        LineMark(
                            x: .value("Date", perf.date, unit: .day),
                            y: .value("Score", perf.sleepScore)
                        )
                        .foregroundStyle(Color.purple)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        PointMark(
                            x: .value("Date", perf.date, unit: .day),
                            y: .value("Score", perf.sleepScore)
                        )
                        .foregroundStyle(Color.purple)
                    }
                    .frame(height: 120)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 1)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                }
            }
        }
    }
}

struct SleepTipsCard: View {
    @Query(sort: \DailyJournal.date, order: .reverse) private var journals: [DailyJournal]
    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tips for Better Sleep")
                    .font(.headline)
                ForEach(tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                        Text(tip)
                            .font(.subheadline)
                    }
                }
            }
        }
    }
    var tips: [String] {
        var tips: [String] = [
            "Aim for a consistent bedtime and wake time.",
            "Avoid caffeine and alcohol late in the day.",
            "Create a relaxing wind-down routine.",
            "Keep your bedroom cool, dark, and quiet.",
            "Limit screen time before bed."
        ]
        // Add personalized tips based on journal analysis
        let alcoholDays = journals.filter { $0.consumedAlcohol && $0.sleepScore != nil }
        if alcoholDays.count >= 2 {
            tips.append("Your sleep score is lower on days you consume alcohol. Try to limit alcohol intake for better sleep.")
        }
        let magnesiumDays = journals.filter { $0.tookMagnesium && $0.sleepScore != nil }
        if magnesiumDays.count >= 2 {
            tips.append("You tend to have a higher sleep score on days you take magnesium. Consider making it a habit.")
        }
        return tips
    }
}

struct SleepFactorAnalysisCard: View {
    @Query(sort: \DailyJournal.date, order: .reverse) private var journals: [DailyJournal]
    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Lifestyle Factors & Sleep")
                    .font(.headline)
                ForEach(factorImpacts, id: \.self) { impact in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(.blue)
                        Text(impact)
                            .font(.subheadline)
                    }
                }
            }
        }
    }
    var factorImpacts: [String] {
        var impacts: [String] = []
        // Alcohol
        let alcoholDays = journals.filter { $0.consumedAlcohol && $0.sleepScore != nil }
        let nonAlcoholDays = journals.filter { !$0.consumedAlcohol && $0.sleepScore != nil }
        if alcoholDays.count >= 2 && nonAlcoholDays.count >= 2 {
            let avgAlcohol = Double(alcoholDays.map { $0.sleepScore! }.reduce(0, +)) / Double(alcoholDays.count)
            let avgNonAlcohol = Double(nonAlcoholDays.map { $0.sleepScore! }.reduce(0, +)) / Double(nonAlcoholDays.count)
            let diff = avgNonAlcohol - avgAlcohol
            if diff > 5 {
                impacts.append("Alcohol is associated with a \(String(format: "%.1f", diff)) point lower sleep score.")
            }
        }
        // Magnesium
        let magDays = journals.filter { $0.tookMagnesium && $0.sleepScore != nil }
        let nonMagDays = journals.filter { !$0.tookMagnesium && $0.sleepScore != nil }
        if magDays.count >= 2 && nonMagDays.count >= 2 {
            let avgMag = Double(magDays.map { $0.sleepScore! }.reduce(0, +)) / Double(magDays.count)
            let avgNonMag = Double(nonMagDays.map { $0.sleepScore! }.reduce(0, +)) / Double(nonMagDays.count)
            let diff = avgMag - avgNonMag
            if diff > 5 {
                impacts.append("Magnesium is associated with a \(String(format: "%.1f", diff)) point higher sleep score.")
            }
        }
        // Stress
        let stressDays = journals.filter { $0.highStressDay && $0.sleepScore != nil }
        let nonStressDays = journals.filter { !$0.highStressDay && $0.sleepScore != nil }
        if stressDays.count >= 2 && nonStressDays.count >= 2 {
            let avgStress = Double(stressDays.map { $0.sleepScore! }.reduce(0, +)) / Double(stressDays.count)
            let avgNonStress = Double(nonStressDays.map { $0.sleepScore! }.reduce(0, +)) / Double(nonStressDays.count)
            let diff = avgNonStress - avgStress
            if diff > 5 {
                impacts.append("High stress is associated with a \(String(format: "%.1f", diff)) point lower sleep score.")
            }
        }
        if impacts.isEmpty {
            impacts.append("Track more days to discover how your habits affect your sleep.")
        }
        return impacts
    }
} 