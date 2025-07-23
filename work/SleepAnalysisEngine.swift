import Foundation
import SwiftUI

// MARK: - Insight Status Enum
enum InsightStatus {
    case optimal, good, fair, poor
}

// MARK: - Component Insight Structure
struct ComponentInsight: Identifiable {
    let id = UUID()
    let metricName: String      // e.g., "Deep Sleep"
    let userValue: String       // e.g., "50m"
    let optimalRange: String    // e.g., "75-95m"
    let analysis: String        // Personalized analysis text
    let status: InsightStatus   // Status indicator for UI colouring
}

// MARK: - Sleep Analysis Insight Structure
struct SleepAnalysisInsight {
    let headline: String
    let componentBreakdown: [ComponentInsight]
    let recommendation: String
}

// MARK: - Sleep Analysis Engine
/// Generates a three-layered insight (headline, component breakdown, recommendation)
/// from an existing `SleepScoreResult`.
struct SleepAnalysisEngine {
    /// Produces a structured `SleepAnalysisInsight` for a single night.
    /// - Parameter result: The sleep score result calculated for a given night.
    /// - Returns: A fully built `SleepAnalysisInsight` ready for UI consumption.
    static func generateInsights(from result: SleepScoreResult) -> SleepAnalysisInsight {
        // -----------------------------------------
        // Helper Closures
        // -----------------------------------------
        func formatTime(_ seconds: TimeInterval) -> String {
            let mins = Int(seconds / 60)
            if mins >= 60 {
                let hrs = mins / 60
                let rem = mins % 60
                return rem == 0 ? "\(hrs)h" : "\(hrs)h \(rem)m"
            } else {
                return "\(mins)m"
            }
        }

        func status(for value: Double, in range: ClosedRange<Double>) -> InsightStatus {
            // Within range is optimal
            if range.contains(value) {
                return .optimal
            }
            // Compute percentage deviation outside range
            let deviation: Double
            if value < range.lowerBound {
                deviation = (range.lowerBound - value) / range.lowerBound
            } else {
                deviation = (value - range.upperBound) / range.upperBound
            }
            // Map deviation to qualitative buckets
            if deviation < 0.05 {
                return .good
            } else if deviation < 0.15 {
                return .fair
            } else {
                return .poor
            }
        }

        // -----------------------------------------
        // Metric Calculations
        // -----------------------------------------
        let timeAsleep = result.timeAsleep                // seconds
        let deepSleep = result.deepSleep                  // seconds
        let remSleep  = result.remSleep                   // seconds
        let efficiency = result.sleepEfficiency           // 0-1
        let onset = result.timeToFallAsleep               // minutes

        // Personalised optimal ranges
        let deepLower  = timeAsleep * 0.13
        let deepUpper  = timeAsleep * 0.23
        let remLower   = timeAsleep * 0.20
        let remUpper   = timeAsleep * 0.25

        // Fixed optimal ranges
        let durationRangeMinutes: ClosedRange<Double> = 420...540          // 7-9h in minutes
        let efficiencyRange: ClosedRange<Double> = 0.90...0.95            // 90-95 %
        let onsetRangeMinutes: ClosedRange<Double> = 0...15               // ≤15 min

        // Component assembly helper
        func makeComponent(name: String, userValue: String, optimal: String, value: Double, range: ClosedRange<Double>) -> ComponentInsight {
            let s = status(for: value, in: range)
            let analysis: String
            switch s {
            case .optimal:
                analysis = "Your \(name) met the optimal range."
            case .good:
                analysis = "Your \(name) was close to optimal – small adjustments could make it perfect."
            case .fair:
                analysis = "Your \(name) was outside the optimal range. Aim for improvement."
            case .poor:
                analysis = "Your \(name) was well outside the optimal range and needs attention."
            }
            return ComponentInsight(metricName: name, userValue: userValue, optimalRange: optimal, analysis: analysis, status: s)
        }

        // Duration (convert to minutes for range comparison)
        let durationMins = result.timeAsleep / 60
        let durationComp = makeComponent(
            name: "Duration",
            userValue: formatTime(result.timeAsleep),
            optimal: "7-9h",
            value: durationMins,
            range: durationRangeMinutes
        )

        // Deep Sleep
        let deepComp = makeComponent(
            name: "Deep Sleep",
            userValue: formatTime(deepSleep),
            optimal: "\(formatTime(deepLower))–\(formatTime(deepUpper))",
            value: deepSleep,
            range: deepLower...deepUpper
        )

        // REM Sleep
        let remComp: ComponentInsight
        if remSleep >= 120 * 60 { // 120 minutes in seconds
            remComp = ComponentInsight(
                metricName: "REM Sleep",
                userValue: formatTime(remSleep),
                optimalRange: "2h+",
                analysis: "Excellent REM sleep duration (2h+)",
                status: .optimal
            )
        } else {
            remComp = makeComponent(
                name: "REM Sleep",
                userValue: formatTime(remSleep),
                optimal: "\(formatTime(remLower))–\(formatTime(remUpper))",
                value: remSleep,
                range: remLower...remUpper
            )
        }

        // Efficiency (%) – compare using fractional values
        let efficiencyComp = makeComponent(
            name: "Efficiency",
            userValue: String(format: "%.0f%%", efficiency * 100),
            optimal: "90-95%",
            value: efficiency,
            range: efficiencyRange
        )

        // Sleep Onset
        let onsetComp = makeComponent(
            name: "Onset",
            userValue: String(format: "%.0f min", onset),
            optimal: "≤15m",
            value: onset,
            range: onsetRangeMinutes
        )

        var components = [durationComp, deepComp, remComp, efficiencyComp, onsetComp]

        // -----------------------------------------
        // Determine weakest & strongest components
        // -----------------------------------------
        // Simple severity ranking: optimal=0, good=1, fair=2, poor=3
        func severity(of status: InsightStatus) -> Int {
            switch status {
            case .optimal: return 0
            case .good:    return 1
            case .fair:    return 2
            case .poor:    return 3
            }
        }

        let weakest = components.max { severity(of: $0.status) < severity(of: $1.status) } ?? durationComp
        let strongest = components.min { severity(of: $0.status) < severity(of: $1.status) } ?? durationComp

        // -----------------------------------------
        // Headline Generation
        // -----------------------------------------
        let headline: String
        if severity(of: weakest.status) == 0 {
            headline = "Your sleep was well balanced across all key metrics. Great job!"
        } else {
            // Build positive phrase
            let positivePhrase: String
            switch strongest.metricName {
            case "Efficiency": positivePhrase = "sleep was highly efficient"
            case "Duration":  positivePhrase = "sleep duration was on point"
            case "Deep Sleep": positivePhrase = "Deep Sleep was strong"
            case "REM Sleep":  positivePhrase = "REM Sleep was strong"
            case "Onset":     positivePhrase = "you fell asleep quickly"
            default:           positivePhrase = "overall sleep quality was solid"
            }
            // Build negative phrase
            let negativePhrase: String
            switch weakest.metricName {
            case "Deep Sleep": negativePhrase = "a lack of Deep Sleep may impact physical recovery today"
            case "REM Sleep":  negativePhrase = "low REM Sleep could affect mental clarity"
            case "Duration":   negativePhrase = "short sleep duration may leave you under-rested"
            case "Efficiency": negativePhrase = "restlessness reduced your sleep efficiency"
            case "Onset":      negativePhrase = "long sleep onset delayed restorative processes"
            default:            negativePhrase = "imbalances could impact your day"
            }
            headline = "While your \(positivePhrase), \(negativePhrase)."
        }

        // -----------------------------------------
        // Actionable Recommendation
        // -----------------------------------------
        let recommendation: String
        switch weakest.metricName {
        case "Deep Sleep":
            recommendation = "To improve Deep Sleep, avoid caffeine after 2 PM and keep your room cool (≈19 °C)."
        case "Duration":
            recommendation = "Aim to be in bed 30 minutes earlier tonight to meet your sleep need."
        case "REM Sleep":
            recommendation = "Avoid alcohol before bed and maintain a consistent wake-up time to support REM Sleep."
        case "Efficiency":
            recommendation = "Limit screen time before bed and ensure a dark, quiet bedroom to boost efficiency."
        case "Onset":
            recommendation = "Create a calming wind-down routine to help you fall asleep faster."
        default:
            recommendation = "Maintain good sleep hygiene for continued improvements."
        }

        // Return packaged insight
        return SleepAnalysisInsight(
            headline: headline,
            componentBreakdown: components,
            recommendation: recommendation
        )
    }
} 