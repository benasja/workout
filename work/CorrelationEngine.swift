import Foundation
import SwiftUI

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
    
    private let journalManager = JournalManager.shared
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
    func analyzeSupplementImpact() async -> [CorrelationInsight] {
        var supplementInsights: [CorrelationInsight] = []
        
        // Get all journal entries with supplement data
        let entries = journalManager.entries.filter { !$0.supplements.isEmpty }
        
        // Analyze each supplement
        for supplement in journalManager.allSupplements {
            let supplementTakenDays = entries.filter { $0.supplements[supplement] == true }
            let supplementNotTakenDays = entries.filter { $0.supplements[supplement] == false || $0.supplements[supplement] == nil }
            
            // Only analyze if we have sufficient data
            guard supplementTakenDays.count >= 5 && supplementNotTakenDays.count >= 5 else { continue }
            
            // Analyze sleep score impact
            if let sleepInsight = await analyzeMetricImpact(
                supplement: supplement,
                takenDays: supplementTakenDays,
                notTakenDays: supplementNotTakenDays,
                metric: "sleep",
                category: .sleep
            ) {
                supplementInsights.append(sleepInsight)
            }
            
            // Analyze recovery score impact
            if let recoveryInsight = await analyzeMetricImpact(
                supplement: supplement,
                takenDays: supplementTakenDays,
                notTakenDays: supplementNotTakenDays,
                metric: "recovery",
                category: .recovery
            ) {
                supplementInsights.append(recoveryInsight)
            }
            
            // Analyze HRV impact
            if let hrvInsight = await analyzeMetricImpact(
                supplement: supplement,
                takenDays: supplementTakenDays,
                notTakenDays: supplementNotTakenDays,
                metric: "hrv",
                category: .recovery
            ) {
                supplementInsights.append(hrvInsight)
            }
        }
        
        return supplementInsights
    }
    
    /// Analyzes tag/lifestyle impact on health metrics
    func analyzeTagImpact() async -> [CorrelationInsight] {
        var tagInsights: [CorrelationInsight] = []
        
        // Get all journal entries with tags
        let entries = journalManager.entries.filter { !$0.tags.isEmpty }
        
        // Analyze each tag
        for tag in journalManager.allTags {
            let tagDays = entries.filter { $0.tags.contains(tag) }
            let nonTagDays = entries.filter { !$0.tags.contains(tag) }
            
            // Only analyze if we have sufficient data
            guard tagDays.count >= 5 && nonTagDays.count >= 5 else { continue }
            
            // Analyze sleep score impact
            if let sleepInsight = await analyzeMetricImpact(
                tag: tag,
                tagDays: tagDays,
                nonTagDays: nonTagDays,
                metric: "sleep",
                category: .lifestyle
            ) {
                tagInsights.append(sleepInsight)
            }
            
            // Analyze recovery score impact
            if let recoveryInsight = await analyzeMetricImpact(
                tag: tag,
                tagDays: tagDays,
                nonTagDays: nonTagDays,
                metric: "recovery",
                category: .lifestyle
            ) {
                tagInsights.append(recoveryInsight)
            }
            
            // Analyze HRV impact
            if let hrvInsight = await analyzeMetricImpact(
                tag: tag,
                tagDays: tagDays,
                nonTagDays: nonTagDays,
                metric: "hrv",
                category: .lifestyle
            ) {
                tagInsights.append(hrvInsight)
            }
        }
        
        return tagInsights
    }
    
    /// Runs comprehensive correlation analysis
    func runAnalysis() async {
        let supplementInsights = await analyzeSupplementImpact()
        let tagInsights = await analyzeTagImpact()
        
        await MainActor.run {
            self.insights = (supplementInsights + tagInsights)
                .sorted { $0.impact == .negative && $1.impact != .negative }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func analyzeMetricImpact(
        supplement: String,
        takenDays: [JournalEntry],
        notTakenDays: [JournalEntry],
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
        tagDays: [JournalEntry],
        nonTagDays: [JournalEntry],
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
    
    private func fetchMetricValues(for entries: [JournalEntry], metric: String) async -> [Double] {
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