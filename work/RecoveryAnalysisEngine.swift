import Foundation
import SwiftUI

// MARK: - Recovery Analysis Insight Structure
struct RecoveryAnalysisInsight {
    let headline: String
    let componentBreakdown: [ComponentInsight]
    let recommendation: String
}

// MARK: - Recovery Analysis Engine
/// Generates a three-layered insight object (headline, component breakdown, recommendation)
/// from a `RecoveryScoreResult` produced by `RecoveryScoreCalculator`.
struct RecoveryAnalysisEngine {
    static func generateInsights(from result: RecoveryScoreResult) -> RecoveryAnalysisInsight {
        // -----------------------------
        // Helper formatting functions
        // -----------------------------
        func percentString(_ value: Double) -> String {
            String(format: "%.0f%%", value)
        }
        func formatBpm(_ bpm: Double) -> String {
            "\(Int(round(bpm))) bpm"
        }
        func formatMs(_ ms: Double) -> String {
            "\(Int(round(ms))) ms"
        }
        // -----------------------------
        // Status helper based on score
        // -----------------------------
        func status(for score: Double) -> InsightStatus {
            switch score {
            case 90...: return .optimal
            case 80..<90: return .good
            case 65..<80: return .fair
            default: return .poor
            }
        }

        // -----------------------------
        // Build Component Insights
        // -----------------------------
        var components: [ComponentInsight] = []

        // HRV Component (higher better)
        let hrvC = result.hrvComponent
        if let current = hrvC.currentValue, let baseline = hrvC.baseline {
            let delta = (current - baseline) / baseline * 100
            let analysis = delta >= 0 ?
            "Your HRV of \(formatMs(current)) is \(percentString(abs(delta))) above baseline, indicating strong autonomic recovery." :
            "Your HRV of \(formatMs(current)) is \(percentString(abs(delta))) below baseline, suggesting reduced recovery.";
            components.append(ComponentInsight(
                metricName: "Heart Rate Variability",
                userValue: formatMs(current),
                optimalRange: "vs. \(formatMs(baseline)) baseline",
                analysis: analysis,
                status: status(for: hrvC.score)
            ))
        }

        // RHR Component (lower better)
        let rhrC = result.rhrComponent
        if let current = rhrC.currentValue, let baseline = rhrC.baseline {
            let delta = (baseline - current) / baseline * 100
            let analysis = delta >= 0 ?
            "Your Resting HR of \(formatBpm(current)) is \(percentString(abs(delta))) below baseline, signaling a well-recovered cardiovascular system." :
            "Your Resting HR of \(formatBpm(current)) is \(percentString(abs(delta))) above baseline, indicating potential fatigue.";
            components.append(ComponentInsight(
                metricName: "Resting Heart Rate",
                userValue: formatBpm(current),
                optimalRange: "vs. \(formatBpm(baseline)) baseline",
                analysis: analysis,
                status: status(for: rhrC.score)
            ))
        }

        // Sleep Component (score based, no baseline)
        let sleepC = result.sleepComponent
        if let current = sleepC.currentValue {
            let analysis: String
            if current >= 85 {
                analysis = "Last night’s sleep score of \(Int(current)) contributed positively to today’s recovery."
            } else if current >= 70 {
                analysis = "Sleep score of \(Int(current)) provided a reasonable boost to recovery."
            } else if current >= 50 {
                analysis = "Sleep score of \(Int(current)) may limit recovery. Prioritize sleep quality tonight."
            } else {
                analysis = "Low sleep score of \(Int(current)) is significantly constraining recovery today."
            }
            components.append(ComponentInsight(
                metricName: "Sleep Quality",
                userValue: "\(Int(current)) / 100",
                optimalRange: "",
                analysis: analysis,
                status: status(for: sleepC.score)
            ))
        }

        // (Removed Physiological Stress component from component breakdown to simplify UI)

        // -----------------------------
        // Determine primary driver & limiter
        // -----------------------------
        let primaryDriver = components.max { a, b in
            let aScore: Double = {
                switch a.status {
                case .optimal: return 4
                case .good: return 3
                case .fair: return 2
                case .poor: return 1
                }
            }()
            let bScore: Double = {
                switch b.status {
                case .optimal: return 4
                case .good: return 3
                case .fair: return 2
                case .poor: return 1
                }
            }()
            return aScore < bScore
        } ?? components.first!

        let primaryLimiter = components.min { a, b in
            let aScore: Double = {
                switch a.status {
                case .optimal: return 4
                case .good: return 3
                case .fair: return 2
                case .poor: return 1
                }
            }()
            let bScore: Double = {
                switch b.status {
                case .optimal: return 4
                case .good: return 3
                case .fair: return 2
                case .poor: return 1
                }
            }()
            return aScore < bScore
        } ?? components.first!

        // -----------------------------
        // Headline generation
        // -----------------------------
        let headline: String
        if components.allSatisfy({ $0.status == .optimal || $0.status == .good }) {
            headline = "Your body is in a stable, well-recovered state, ready for a productive day."
        } else if primaryDriver.metricName == primaryLimiter.metricName {
            headline = "Mixed signals detected – monitor your recovery closely today."
        } else {
            switch primaryLimiter.metricName {
            case "Heart Rate Variability":
                headline = "Suboptimal HRV is limiting your body’s ability to recover."
            case "Resting Heart Rate":
                headline = "Elevated Resting Heart Rate is constraining today’s readiness."
            case "Sleep Quality":
                headline = "Suboptimal sleep is the primary factor limiting recovery."
            case "Physiological Stress":
                headline = "Elevated stress is curbing recovery capacity today."
            default:
                headline = "One or more factors are limiting your recovery today."
            }
        }

        // -----------------------------
        // Training Recommendation
        // -----------------------------
        let recommendation: String
        switch result.finalScore {
        case 85...100:
            recommendation = "Your body is primed. Push maximal intensity or aim for a personal record today."
        case 65...84:
            recommendation = "You are well-recovered. Execute your planned workout with discipline and focus."
        case 40...64:
            recommendation = "Recovery is compromised. Reduce training volume by ~25% or adopt lower intensity."
        default:
            recommendation = "Recovery is low. Take a strategic rest day with active recovery only."
        }

        return RecoveryAnalysisInsight(headline: headline, componentBreakdown: components, recommendation: recommendation)
    }
} 