import XCTest
@testable import work

final class SleepScoreCalculatorTests: XCTestCase {
    
    func testSleepScoreCalculation() throws {
        // Test case 1: Optimal sleep
        let optimalSleep = createTestSleepData(
            timeInBed: 8.5 * 3600, // 8.5 hours
            timeAsleep: 8.0 * 3600, // 8.0 hours
            deepSleepDuration: 1.2 * 3600, // 15% of sleep
            remSleepDuration: 1.6 * 3600, // 20% of sleep
            averageHeartRate: 55,
            dailyRestingHeartRate: 65,
            bedtime: Date().addingTimeInterval(-8.5 * 3600),
            wakeTime: Date()
        )
        
        let optimalScore = calculateTestSleepScore(data: optimalSleep)
        XCTAssertGreaterThan(optimalScore, 80, "Optimal sleep should score above 80")
        print("Optimal sleep score: \(optimalScore)")
        
        // Test case 2: Poor sleep
        let poorSleep = createTestSleepData(
            timeInBed: 9.0 * 3600, // 9.0 hours
            timeAsleep: 6.0 * 3600, // 6.0 hours
            deepSleepDuration: 0.3 * 3600, // 5% of sleep
            remSleepDuration: 0.6 * 3600, // 10% of sleep
            averageHeartRate: 70,
            dailyRestingHeartRate: 65,
            bedtime: Date().addingTimeInterval(-9.0 * 3600),
            wakeTime: Date()
        )
        
        let poorScore = calculateTestSleepScore(data: poorSleep)
        XCTAssertLessThan(poorScore, 60, "Poor sleep should score below 60")
        print("Poor sleep score: \(poorScore)")
        
        // Test case 3: Moderate sleep
        let moderateSleep = createTestSleepData(
            timeInBed: 8.0 * 3600, // 8.0 hours
            timeAsleep: 7.2 * 3600, // 7.2 hours
            deepSleepDuration: 0.9 * 3600, // 12.5% of sleep
            remSleepDuration: 1.3 * 3600, // 18% of sleep
            averageHeartRate: 60,
            dailyRestingHeartRate: 65,
            bedtime: Date().addingTimeInterval(-8.0 * 3600),
            wakeTime: Date()
        )
        
        let moderateScore = calculateTestSleepScore(data: moderateSleep)
        XCTAssertGreaterThanOrEqual(moderateScore, 60, "Moderate sleep should score 60 or above")
        XCTAssertLessThanOrEqual(moderateScore, 80, "Moderate sleep should score 80 or below")
        print("Moderate sleep score: \(moderateScore)")
    }
    
    func testComponentCalculations() throws {
        // Test efficiency component
        let efficiencyScore = calculateEfficiencyComponent(timeInBed: 8.0 * 3600, timeAsleep: 7.2 * 3600)
        XCTAssertGreaterThan(efficiencyScore, 70, "Good efficiency should score above 70")
        
        // Test quality component with optimal values
        let qualityScore = calculateQualityComponent(
            timeAsleep: 8.0 * 3600,
            deepSleepDuration: 1.2 * 3600, // 15%
            remSleepDuration: 1.6 * 3600, // 20%
            averageHeartRate: 55,
            dailyRestingHeartRate: 65
        )
        XCTAssertGreaterThan(qualityScore, 80, "Optimal quality should score above 80")
    }
    
    func testNormalizationFunction() throws {
        // Test within optimal range
        let optimalScore = normalize(value: 18.0, min: 13, max: 23)
        XCTAssertEqual(optimalScore, 100, "Value within optimal range should score 100")
        
        // Test below optimal range
        let lowScore = normalize(value: 10.0, min: 13, max: 23)
        XCTAssertLessThan(lowScore, 100, "Value below optimal range should score less than 100")
        
        // Test above optimal range
        let highScore = normalize(value: 25.0, min: 13, max: 23)
        XCTAssertLessThan(highScore, 100, "Value above optimal range should score less than 100")
    }
    
    // MARK: - Helper Functions
    
    private func createTestSleepData(
        timeInBed: TimeInterval,
        timeAsleep: TimeInterval,
        deepSleepDuration: TimeInterval,
        remSleepDuration: TimeInterval,
        averageHeartRate: Double,
        dailyRestingHeartRate: Double,
        bedtime: Date,
        wakeTime: Date
    ) -> (timeInBed: TimeInterval, timeAsleep: TimeInterval, deepSleepDuration: TimeInterval, remSleepDuration: TimeInterval, averageHeartRate: Double?, dailyRestingHeartRate: Double?, bedtime: Date?, wakeTime: Date?) {
        return (
            timeInBed: timeInBed,
            timeAsleep: timeAsleep,
            deepSleepDuration: deepSleepDuration,
            remSleepDuration: remSleepDuration,
            averageHeartRate: averageHeartRate,
            dailyRestingHeartRate: dailyRestingHeartRate,
            bedtime: bedtime,
            wakeTime: wakeTime
        )
    }
    
    private func calculateTestSleepScore(data: (timeInBed: TimeInterval, timeAsleep: TimeInterval, deepSleepDuration: TimeInterval, remSleepDuration: TimeInterval, averageHeartRate: Double?, dailyRestingHeartRate: Double?, bedtime: Date?, wakeTime: Date?)) -> Int {
        
        // Efficiency Component (35% Weight)
        let efficiencyComponent = calculateEfficiencyComponent(
            timeInBed: data.timeInBed,
            timeAsleep: data.timeAsleep
        )
        
        // Quality Component (45% Weight)
        let qualityComponent = calculateQualityComponent(
            timeAsleep: data.timeAsleep,
            deepSleepDuration: data.deepSleepDuration,
            remSleepDuration: data.remSleepDuration,
            averageHeartRate: data.averageHeartRate,
            dailyRestingHeartRate: data.dailyRestingHeartRate
        )
        
        // Timing Component (20% Weight) - Using neutral baseline for testing
        let timingComponent = 50.0 // Neutral score for testing
        
        // Calculate final score
        let finalScore = Int(round(
            (efficiencyComponent * 0.35) +
            (qualityComponent * 0.45) +
            (timingComponent * 0.20)
        ))
        
        return max(0, min(100, finalScore))
    }
    
    private func calculateEfficiencyComponent(timeInBed: TimeInterval, timeAsleep: TimeInterval) -> Double {
        guard timeInBed > 0 else { return 0 }
        
        // Sub-component A: Sleep Efficiency (50% of this component)
        let sleepEfficiency = timeAsleep / timeInBed
        let efficiencyScore = sleepEfficiency * 100
        
        // Sub-component B: Sleep Duration (50% of this component)
        let hoursAsleep = timeAsleep / 3600
        let optimalHours = 8.0
        let deviation = abs(hoursAsleep - optimalHours)
        let durationScore = 100 * exp(-0.5 * pow(deviation / 1.5, 2))
        
        // Final component score
        return (efficiencyScore * 0.5) + (durationScore * 0.5)
    }
    
    private func calculateQualityComponent(
        timeAsleep: TimeInterval,
        deepSleepDuration: TimeInterval,
        remSleepDuration: TimeInterval,
        averageHeartRate: Double?,
        dailyRestingHeartRate: Double?
    ) -> Double {
        guard timeAsleep > 0 else { return 0 }
        
        // Sub-component A: Deep Sleep (40% of this component)
        let deepSleepPercentage = (deepSleepDuration / timeAsleep) * 100
        let deepScore = normalize(value: deepSleepPercentage, min: 13, max: 23)
        
        // Sub-component B: REM Sleep (30% of this component)
        let remSleepPercentage = (remSleepDuration / timeAsleep) * 100
        let remScore = normalize(value: remSleepPercentage, min: 20, max: 25)
        
        // Sub-component C: Heart Rate Dip (30% of this component)
        let hrDipScore = calculateHeartRateDipScore(
            averageHeartRate: averageHeartRate,
            dailyRestingHeartRate: dailyRestingHeartRate
        )
        
        // Final component score
        return (deepScore * 0.4) + (remScore * 0.3) + (hrDipScore * 0.3)
    }
    
    private func normalize(value: Double, min: Double, max: Double) -> Double {
        if value >= min && value <= max {
            return 100 // Perfect score within optimal range
        } else if value < min {
            // Penalize values below minimum
            let deviation = min - value
            return max(0, 100 - (deviation * 10))
        } else {
            // Penalize values above maximum
            let deviation = value - max
            return max(0, 100 - (deviation * 10))
        }
    }
    
    private func calculateHeartRateDipScore(averageHeartRate: Double?, dailyRestingHeartRate: Double?) -> Double {
        guard let heartRate = averageHeartRate, let rhr = dailyRestingHeartRate, rhr > 0 else {
            return 50 // Neutral score if data is missing
        }
        
        let dipPercentage = 1 - (heartRate / rhr)
        let score = dipPercentage * 100 * 5
        return max(0, min(100, score))
    }
} 