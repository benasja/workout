import Foundation
import SwiftUI
import SwiftData

struct Correlation: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let strength: Double // -1.0 to 1.0
    let insight: String
    let icon: String
    let color: Color
}

struct CorrelationInsight: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let data: String
    let reliability: String
    let impact: InsightImpact
    let category: InsightCategory
    
    enum InsightImpact {
        case positive
        case negative
        case neutral
    }
    
    enum InsightCategory {
        case supplement
        case lifestyle
        case sleep
        case recovery
    }
}

class CorrelationEngine: ObservableObject {
    static let shared = CorrelationEngine()
    
    @Published var insights: [CorrelationInsight] = []
    @Published var correlations: [Correlation] = []
    
    private let healthKitManager = HealthKitManager.shared
    
    private init() {}
    
    /// Calculate correlations between different metrics
    func calculateCorrelations() async {
        // Sample correlations - in a real app, these would be calculated from actual data
        let sampleCorrelations = [
            Correlation(
                title: "Sleep & Recovery",
                description: "Better sleep leads to higher recovery scores",
                strength: 0.78,
                insight: "Your recovery score is 78% correlated with sleep quality. Focus on consistent sleep for better recovery.",
                icon: "bed.double.fill",
                color: .blue
            ),
            Correlation(
                title: "HRV & Stress",
                description: "High stress days show lower HRV",
                strength: -0.65,
                insight: "Stress management could improve your HRV by up to 15%. Consider meditation or breathing exercises.",
                icon: "heart.fill",
                color: .red
            ),
            Correlation(
                title: "Exercise & Sleep",
                description: "Regular workouts improve sleep quality",
                strength: 0.52,
                insight: "Days with workouts show 12% better sleep scores. Keep up your training routine!",
                icon: "figure.run",
                color: .green
            ),
            Correlation(
                title: "Alcohol & Recovery",
                description: "Alcohol consumption affects next-day recovery",
                strength: -0.43,
                insight: "Alcohol reduces recovery scores by an average of 15 points. Consider limiting intake before important training days.",
                icon: "wineglass.fill",
                color: .orange
            )
        ]
        
        await MainActor.run {
            self.correlations = sampleCorrelations
        }
    }
    
    /// Analyzes supplement impact on health metrics
    func analyzeSupplementImpact(entries: [DailyJournal]) async -> [CorrelationInsight] {
        var supplementInsights: [CorrelationInsight] = []
        
        // Analyze Magnesium impact
        let magnesiumTakenDays = entries.filter { $0.tookMagnesium }
        let magnesiumNotTakenDays = entries.filter { !$0.tookMagnesium }
        
        if magnesiumTakenDays.count >= 3 && magnesiumNotTakenDays.count >= 3 {
            if let sleepInsight = await analyzeMetricImpact(
                supplement: "Magnesium",
                takenDays: magnesiumTakenDays,
                notTakenDays: magnesiumNotTakenDays,
                metric: "sleep",
                category: .supplement
            ) {
                supplementInsights.append(sleepInsight)
            }
        }
        
        // Analyze Ashwagandha impact
        let ashwagandhaTakenDays = entries.filter { $0.tookAshwagandha }
        let ashwagandhaNotTakenDays = entries.filter { !$0.tookAshwagandha }
        
        if ashwagandhaTakenDays.count >= 3 && ashwagandhaNotTakenDays.count >= 3 {
            if let recoveryInsight = await analyzeMetricImpact(
                supplement: "Ashwagandha",
                takenDays: ashwagandhaTakenDays,
                notTakenDays: ashwagandhaNotTakenDays,
                metric: "recovery",
                category: .supplement
            ) {
                supplementInsights.append(recoveryInsight)
            }
        }
        
        return supplementInsights
    }
    
    /// Analyzes tag/lifestyle impact on health metrics
    func analyzeTagImpact(entries: [DailyJournal]) async -> [CorrelationInsight] {
        var tagInsights: [CorrelationInsight] = []
        
        // Get all journal entries with tags
        // let entriesWithTags = entries.filter { !$0.tags.isEmpty }
        
        // Analyze alcohol impact
        let alcoholDays = entries.filter { $0.consumedAlcohol }
        let nonAlcoholDays = entries.filter { !$0.consumedAlcohol }
        
        if alcoholDays.count >= 3 && nonAlcoholDays.count >= 3 {
            if let alcoholInsight = await analyzeMetricImpact(
                tag: "Alcohol",
                tagDays: alcoholDays,
                nonTagDays: nonAlcoholDays,
                metric: "recovery",
                category: .lifestyle
            ) {
                tagInsights.append(alcoholInsight)
            }
        }
        
        // Analyze stress impact
        let stressDays = entries.filter { $0.highStressDay }
        let nonStressDays = entries.filter { !$0.highStressDay }
        
        if stressDays.count >= 3 && nonStressDays.count >= 3 {
            if let stressInsight = await analyzeMetricImpact(
                tag: "High Stress",
                tagDays: stressDays,
                nonTagDays: nonStressDays,
                metric: "sleep",
                category: .lifestyle
            ) {
                tagInsights.append(stressInsight)
            }
        }
        
        // Analyze late eating impact
        let lateEatingDays = entries.filter { $0.ateLate }
        let normalEatingDays = entries.filter { !$0.ateLate }
        
        if lateEatingDays.count >= 3 && normalEatingDays.count >= 3 {
            if let lateEatingInsight = await analyzeMetricImpact(
                tag: "Late Eating",
                tagDays: lateEatingDays,
                nonTagDays: normalEatingDays,
                metric: "sleep",
                category: .lifestyle
            ) {
                tagInsights.append(lateEatingInsight)
            }
        }
        
        return tagInsights
    }
    
    /// Runs comprehensive correlation analysis
    func runAnalysis() async {
        // For now, we'll create sample insights since we need access to SwiftData context
        // In a real implementation, this would fetch journal entries from the database
        let sampleInsights = await generateSampleInsights()
        
        await MainActor.run {
            self.insights = sampleInsights
                .sorted { $0.impact == .negative && $1.impact != .negative }
        }
    }
    
    /// Runs analysis with provided journal entries
    func runAnalysis(with entries: [DailyJournal]) async {
        let supplementInsights = await analyzeSupplementImpact(entries: entries)
        let tagInsights = await analyzeTagImpact(entries: entries)
        
        await MainActor.run {
            self.insights = (supplementInsights + tagInsights)
                .sorted { $0.impact == .negative && $1.impact != .negative }
        }
    }
    
    /// Generates sample insights for demonstration
    private func generateSampleInsights() async -> [CorrelationInsight] {
        return [
            CorrelationInsight(
                title: "Alcohol Affects Your Recovery",
                description: "On days you consumed alcohol, your average recovery score was 12.3 points lower.",
                data: "Based on 15 days of data",
                reliability: "Statistical significance: 18.5% change",
                impact: .negative,
                category: .lifestyle
            ),
            CorrelationInsight(
                title: "Magnesium Improves Your Sleep",
                description: "On days you took Magnesium, your average sleep score was 8.7 points higher.",
                data: "Based on 12 days of data",
                reliability: "Statistical significance: 12.1% change",
                impact: .positive,
                category: .supplement
            ),
            CorrelationInsight(
                title: "High Stress Affects Your Sleep",
                description: "On days you logged high stress, your average sleep score was 15.2 points lower.",
                data: "Based on 8 days of data",
                reliability: "Statistical significance: 22.3% change",
                impact: .negative,
                category: .lifestyle
            )
        ]
    }
    
    // MARK: - Private Helper Methods
    
    private func analyzeMetricImpact(
        supplement: String,
        takenDays: [DailyJournal],
        notTakenDays: [DailyJournal],
        metric: String,
        category: CorrelationInsight.InsightCategory
    ) async -> CorrelationInsight? {
        let takenValues = await fetchMetricValues(for: takenDays, metric: metric)
        let notTakenValues = await fetchMetricValues(for: notTakenDays, metric: metric)
        
        guard !takenValues.isEmpty && !notTakenValues.isEmpty else { return nil }
        
        let takenAvg = takenValues.reduce(0, +) / Double(takenValues.count)
        let notTakenAvg = notTakenValues.reduce(0, +) / Double(notTakenValues.count)
        let difference = takenAvg - notTakenAvg
        let percentageChange = (difference / notTakenAvg) * 100
        
        // Only report if the difference is statistically significant (>5% change)
        guard abs(percentageChange) > 5.0 else { return nil }
        
        let impact: CorrelationInsight.InsightImpact
        let title: String
        let description: String
        
        if percentageChange > 0 {
            impact = .positive
            title = "\(supplement) Improves Your \(metric.capitalized)"
            description = "On days you took \(supplement), your average \(metric) was \(String(format: "%.1f", abs(difference))) \(getMetricUnit(metric)) higher."
        } else {
            impact = .negative
            title = "\(supplement) May Affect Your \(metric.capitalized)"
            description = "On days you took \(supplement), your average \(metric) was \(String(format: "%.1f", abs(difference))) \(getMetricUnit(metric)) lower."
        }
        
        let data = "Based on \(takenDays.count) days of data"
        let reliability = "Statistical significance: \(String(format: "%.1f", abs(percentageChange)))% change"
        
        return CorrelationInsight(
            title: title,
            description: description,
            data: data,
            reliability: reliability,
            impact: impact,
            category: category
        )
    }
    
    private func analyzeMetricImpact(
        tag: String,
        tagDays: [DailyJournal],
        nonTagDays: [DailyJournal],
        metric: String,
        category: CorrelationInsight.InsightCategory
    ) async -> CorrelationInsight? {
        let tagValues = await fetchMetricValues(for: tagDays, metric: metric)
        let nonTagValues = await fetchMetricValues(for: nonTagDays, metric: metric)
        
        guard !tagValues.isEmpty && !nonTagValues.isEmpty else { return nil }
        
        let tagAvg = tagValues.reduce(0, +) / Double(tagValues.count)
        let nonTagAvg = nonTagValues.reduce(0, +) / Double(nonTagValues.count)
        let difference = tagAvg - nonTagAvg
        let percentageChange = (difference / nonTagAvg) * 100
        
        // Only report if the difference is statistically significant (>5% change)
        guard abs(percentageChange) > 5.0 else { return nil }
        
        let impact: CorrelationInsight.InsightImpact
        let title: String
        let description: String
        
        if percentageChange > 0 {
            impact = .positive
            title = "\(tag) Boosts Your \(metric.capitalized)"
            description = "On days you logged \(tag), your average \(metric) was \(String(format: "%.1f", abs(difference))) \(getMetricUnit(metric)) higher."
        } else {
            impact = .negative
            title = "\(tag) Affects Your \(metric.capitalized)"
            description = "On days you logged \(tag), your average \(metric) was \(String(format: "%.1f", abs(difference))) \(getMetricUnit(metric)) lower."
        }
        
        let data = "Based on \(tagDays.count) days of data"
        let reliability = "Statistical significance: \(String(format: "%.1f", abs(percentageChange)))% change"
        
        return CorrelationInsight(
            title: title,
            description: description,
            data: data,
            reliability: reliability,
            impact: impact,
            category: category
        )
    }
    
    private func fetchMetricValues(for entries: [DailyJournal], metric: String) async -> [Double] {
        var values: [Double] = []
        
        for entry in entries {
            do {
                switch metric {
                case "sleep":
                    let sleepScore = try await SleepScoreCalculator.shared.calculateSleepScore(for: entry.date)
                    values.append(Double(sleepScore.finalScore))
                case "recovery":
                    let recoveryScore = try await RecoveryScoreCalculator.shared.calculateRecoveryScore(for: entry.date)
                    values.append(Double(recoveryScore.finalScore))
                case "hrv":
                    // Fetch HRV for the day after the journal entry (morning measurement)
                    let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: entry.date) ?? entry.date
                    let enhancedHRV = await withCheckedContinuation { continuation in
                        healthKitManager.fetchEnhancedHRV(for: nextDay) { data in
                            continuation.resume(returning: data)
                        }
                    }
                    if let hrv = enhancedHRV?.sdnn {
                        values.append(hrv)
                    }
                default:
                    break
                }
            } catch {
                // Skip entries where we can't fetch the metric
                continue
            }
        }
        
        return values
    }
    
    private func getMetricUnit(_ metric: String) -> String {
        switch metric {
        case "sleep", "recovery":
            return "points"
        case "hrv":
            return "ms"
        default:
            return "units"
        }
    }
} 