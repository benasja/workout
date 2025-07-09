import SwiftUI
import SwiftData
import Charts

struct CorrelationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyJournal.date, order: .reverse) private var journals: [DailyJournal]
    @State private var selectedMetric = "Recovery"
    @State private var selectedFactor = "Alcohol"
    
    let metrics = ["Recovery", "Sleep", "HRV", "RHR"]
    let factors = ["Alcohol", "Late Caffeine", "Late Meal", "High Stress", "Magnesium", "Ashwagandha"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Metric Selector
                    MetricSelector(selectedMetric: $selectedMetric, metrics: metrics)
                    
                    // Factor Selector
                    FactorSelector(selectedFactor: $selectedFactor, factors: factors)
                    
                    // Correlation Chart
                    if journals.count >= 7 {
                        CorrelationChartView(
                            journals: journals,
                            metric: selectedMetric,
                            factor: selectedFactor
                        )
                    } else {
                        InsufficientDataCard()
                    }
                    
                    // Statistical Insights
                    if journals.count >= 7 {
                        StatisticalInsightsView(
                            journals: journals,
                            metric: selectedMetric,
                            factor: selectedFactor
                        )
                    }
                    
                    // All Correlations Summary
                    if journals.count >= 7 {
                        AllCorrelationsView(journals: journals)
                    }
                }
                .padding()
            }
            .navigationTitle("Correlations")
        }
    }
}

struct MetricSelector: View {
    @Binding var selectedMetric: String
    let metrics: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Metric")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(metrics, id: \.self) { metric in
                    Button(action: { selectedMetric = metric }) {
                        HStack {
                            Image(systemName: iconForMetric(metric))
                                .font(.title3)
                                .foregroundColor(selectedMetric == metric ? .white : .blue)
                            Text(metric)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(selectedMetric == metric ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedMetric == metric ? Color.blue : Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    private func iconForMetric(_ metric: String) -> String {
        switch metric {
        case "Recovery": return "heart.fill"
        case "Sleep": return "bed.double.fill"
        case "HRV": return "waveform.path.ecg"
        case "RHR": return "heart.circle.fill"
        default: return "chart.line.uptrend.xyaxis"
        }
    }
}

struct FactorSelector: View {
    @Binding var selectedFactor: String
    let factors: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lifestyle Factor")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(factors, id: \.self) { factor in
                        Button(action: { selectedFactor = factor }) {
                            HStack {
                                Image(systemName: iconForFactor(factor))
                                    .font(.caption)
                                    .foregroundColor(selectedFactor == factor ? .white : .blue)
                                Text(factor)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedFactor == factor ? .white : .primary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedFactor == factor ? Color.blue : Color.blue.opacity(0.1))
                            .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func iconForFactor(_ factor: String) -> String {
        switch factor {
        case "Alcohol": return "wineglass"
        case "Late Caffeine": return "cup.and.saucer"
        case "Late Meal": return "clock"
        case "High Stress": return "exclamationmark.triangle"
        case "Magnesium": return "pills"
        case "Ashwagandha": return "leaf"
        default: return "tag"
        }
    }
}

struct CorrelationChartView: View {
    let journals: [DailyJournal]
    let metric: String
    let factor: String
    
    var chartData: [CorrelationDataPoint] {
        let factorKey = factor.lowercased().replacingOccurrences(of: " ", with: "")
        let _ = factorKey.replacingOccurrences(of: "late", with: "after2PM")
        
        return journals.compactMap { journal in
            guard let metricValue = getMetricValue(journal, metric: metric) else { return nil }
            
            let hasFactor: Bool
            switch factor {
            case "Alcohol": hasFactor = journal.consumedAlcohol
            case "Late Caffeine": hasFactor = journal.caffeineAfter2PM
            case "Late Meal": hasFactor = journal.ateLate
            case "High Stress": hasFactor = journal.highStressDay
            case "Magnesium": hasFactor = journal.tookMagnesium
            case "Ashwagandha": hasFactor = journal.tookAshwagandha
            default: hasFactor = false
            }
            
            return CorrelationDataPoint(
                date: journal.date,
                value: metricValue,
                hasFactor: hasFactor,
                factor: factor
            )
        }
    }
    
    var body: some View {
        ModernCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("\(metric) vs \(factor)")
                        .font(.headline)
                    Spacer()
                }
                
                if chartData.count >= 7 {
                    let factorDays = chartData.filter { $0.hasFactor }.count
                    let nonFactorDays = chartData.filter { !$0.hasFactor }.count
                    if factorDays < 2 || nonFactorDays < 2 {
                        Text("Not enough variation in \(factor) to show a correlation.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(height: 200)
                    } else {
                        Chart(chartData) { dataPoint in
                            LineMark(
                                x: .value("Date", dataPoint.date),
                                y: .value("Value", dataPoint.value)
                            )
                            .foregroundStyle(Color.blue)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            
                            PointMark(
                                x: .value("Date", dataPoint.date),
                                y: .value("Value", dataPoint.value)
                            )
                            .foregroundStyle(dataPoint.hasFactor ? Color.red : Color.blue)
                            .symbolSize(100)
                        }
                        .frame(height: 200)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.month().day())
                            }
                        }
                        // Legend
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                                Text("Normal Day")
                                    .font(.caption)
                            }
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text("\(factor) Day")
                                    .font(.caption)
                            }
                        }
                    }
                } else {
                    Text("Insufficient data for chart")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(height: 200)
                }
            }
        }
    }
    
    private func getMetricValue(_ journal: DailyJournal, metric: String) -> Double? {
        switch metric {
        case "Recovery": return journal.recoveryScore.map { Double($0) }
        case "Sleep": return journal.sleepScore.map { Double($0) }
        case "HRV": return journal.hrv
        case "RHR": return journal.rhr
        default: return nil
        }
    }
}

struct CorrelationDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let hasFactor: Bool
    let factor: String
}

struct StatisticalInsightsView: View {
    let journals: [DailyJournal]
    let metric: String
    let factor: String
    
    var insights: [String] {
        var insights: [String] = []
        
        let _ = factor.lowercased().replacingOccurrences(of: " ", with: "")
        
        let factorDays = journals.filter { journal in
            let hasFactor: Bool
            switch factor {
            case "Alcohol": hasFactor = journal.consumedAlcohol
            case "Late Caffeine": hasFactor = journal.caffeineAfter2PM
            case "Late Meal": hasFactor = journal.ateLate
            case "High Stress": hasFactor = journal.highStressDay
            case "Magnesium": hasFactor = journal.tookMagnesium
            case "Ashwagandha": hasFactor = journal.tookAshwagandha
            default: hasFactor = false
            }
            return hasFactor && getMetricValue(journal, metric: metric) != nil
        }
        
        let nonFactorDays = journals.filter { journal in
            let hasFactor: Bool
            switch factor {
            case "Alcohol": hasFactor = journal.consumedAlcohol
            case "Late Caffeine": hasFactor = journal.caffeineAfter2PM
            case "Late Meal": hasFactor = journal.ateLate
            case "High Stress": hasFactor = journal.highStressDay
            case "Magnesium": hasFactor = journal.tookMagnesium
            case "Ashwagandha": hasFactor = journal.tookAshwagandha
            default: hasFactor = false
            }
            return !hasFactor && getMetricValue(journal, metric: metric) != nil
        }
        
        if factorDays.count >= 3 && nonFactorDays.count >= 3 {
            let factorValues = factorDays.compactMap { getMetricValue($0, metric: metric) }
            let nonFactorValues = nonFactorDays.compactMap { getMetricValue($0, metric: metric) }
            
            let factorAvg = factorValues.reduce(0, +) / Double(factorValues.count)
            let nonFactorAvg = nonFactorValues.reduce(0, +) / Double(nonFactorValues.count)
            let difference = nonFactorAvg - factorAvg
            
            let factorStdDev = calculateStandardDeviation(factorValues)
            let _ = calculateStandardDeviation(nonFactorValues)
            
            insights.append("Average \(metric) on \(factor) days: \(String(format: "%.1f", factorAvg))")
            insights.append("Average \(metric) on normal days: \(String(format: "%.1f", nonFactorAvg))")
            insights.append("Difference: \(String(format: "%.1f", abs(difference))) (\(difference > 0 ? "worse" : "better") on \(factor) days)")
            
            if abs(difference) > factorStdDev {
                insights.append("This difference is statistically significant")
            }
            
            insights.append("Data points: \(factorDays.count) \(factor) days, \(nonFactorDays.count) normal days")
        }
        
        return insights
    }
    
    var body: some View {
        ModernCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "function")
                        .font(.title2)
                        .foregroundColor(.purple)
                    Text("Statistical Analysis")
                        .font(.headline)
                    Spacer()
                }
                
                ForEach(insights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption)
                            .foregroundColor(.purple)
                            .padding(.top, 2)
                        Text(insight)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    private func getMetricValue(_ journal: DailyJournal, metric: String) -> Double? {
        switch metric {
        case "Recovery": return journal.recoveryScore.map { Double($0) }
        case "Sleep": return journal.sleepScore.map { Double($0) }
        case "HRV": return journal.hrv
        case "RHR": return journal.rhr
        default: return nil
        }
    }
    
    private func calculateStandardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}

struct AllCorrelationsView: View {
    let journals: [DailyJournal]
    
    var correlationMatrix: [CorrelationResult] {
        let metrics = ["Recovery", "Sleep", "HRV", "RHR"]
        let factors = ["Alcohol", "Late Caffeine", "Late Meal", "High Stress", "Magnesium", "Ashwagandha"]
        
        var results: [CorrelationResult] = []
        
        for metric in metrics {
            for factor in factors {
                if let correlation = calculateCorrelation(metric: metric, factor: factor) {
                    results.append(correlation)
                }
            }
        }
        
        return results.sorted { abs($0.correlationStrength) > abs($1.correlationStrength) }
    }
    
    var body: some View {
        ModernCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "tablecells")
                        .font(.title2)
                        .foregroundColor(.green)
                    Text("All Correlations")
                        .font(.headline)
                    Spacer()
                }
                
                LazyVStack(spacing: 12) {
                    ForEach(correlationMatrix.prefix(8), id: \.id) { correlation in
                        CorrelationRow(correlation: correlation)
                    }
                }
            }
        }
    }
    
    private func calculateCorrelation(metric: String, factor: String) -> CorrelationResult? {
        let factorDays = journals.filter { journal in
            let hasFactor: Bool
            switch factor {
            case "Alcohol": hasFactor = journal.consumedAlcohol
            case "Late Caffeine": hasFactor = journal.caffeineAfter2PM
            case "Late Meal": hasFactor = journal.ateLate
            case "High Stress": hasFactor = journal.highStressDay
            case "Magnesium": hasFactor = journal.tookMagnesium
            case "Ashwagandha": hasFactor = journal.tookAshwagandha
            default: hasFactor = false
            }
            return hasFactor && getMetricValue(journal, metric: metric) != nil
        }
        
        let nonFactorDays = journals.filter { journal in
            let hasFactor: Bool
            switch factor {
            case "Alcohol": hasFactor = journal.consumedAlcohol
            case "Late Caffeine": hasFactor = journal.caffeineAfter2PM
            case "Late Meal": hasFactor = journal.ateLate
            case "High Stress": hasFactor = journal.highStressDay
            case "Magnesium": hasFactor = journal.tookMagnesium
            case "Ashwagandha": hasFactor = journal.tookAshwagandha
            default: hasFactor = false
            }
            return !hasFactor && getMetricValue(journal, metric: metric) != nil
        }
        
        guard factorDays.count >= 3 && nonFactorDays.count >= 3 else { return nil }
        
        let factorValues = factorDays.compactMap { getMetricValue($0, metric: metric) }
        let nonFactorValues = nonFactorDays.compactMap { getMetricValue($0, metric: metric) }
        
        let factorAvg = factorValues.reduce(0, +) / Double(factorValues.count)
        let nonFactorAvg = nonFactorValues.reduce(0, +) / Double(nonFactorValues.count)
        let difference = nonFactorAvg - factorAvg
        
        let strength = abs(difference) / max(factorAvg, nonFactorAvg) * 100
        
        return CorrelationResult(
            metric: metric,
            factor: factor,
            correlationStrength: strength,
            difference: difference,
            factorDays: factorDays.count,
            normalDays: nonFactorDays.count
        )
    }
    
    private func getMetricValue(_ journal: DailyJournal, metric: String) -> Double? {
        switch metric {
        case "Recovery": return journal.recoveryScore.map { Double($0) }
        case "Sleep": return journal.sleepScore.map { Double($0) }
        case "HRV": return journal.hrv
        case "RHR": return journal.rhr
        default: return nil
        }
    }
}

struct CorrelationResult {
    let id = UUID()
    let metric: String
    let factor: String
    let correlationStrength: Double
    let difference: Double
    let factorDays: Int
    let normalDays: Int
}

struct CorrelationRow: View {
    let correlation: CorrelationResult
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(correlation.metric) vs \(correlation.factor)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(correlation.factorDays) factor days, \(correlation.normalDays) normal days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f%%", correlation.correlationStrength))
                    .font(.headline)
                    .foregroundColor(correlation.correlationStrength > 15 ? .red : .green)
                
                Text(correlation.difference > 0 ? "Worse" : "Better")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct InsufficientDataCard: View {
    var body: some View {
        ModernCard {
            VStack(spacing: 16) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                
                Text("Insufficient Data")
                    .font(.headline)
                
                Text("Track at least 7 days of journal entries with health data to see correlations.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 200)
        }
    }
} 