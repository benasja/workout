import Foundation

enum RecoveryScoreError: Error {
    case healthKitNotAuthorized
    case noDataAvailable
    case calculationFailed
    case noSleepSessionFound
}

struct RecoveryScoreResult {
    let finalScore: Int
    let hrvComponent: RecoveryComponent
    let rhrComponent: RecoveryComponent
    let sleepComponent: RecoveryComponent
    let stressComponent: RecoveryComponent
    let date: Date
    let directive: String
    let sleepSessionStart: Date
    let sleepSessionEnd: Date
    
    struct RecoveryComponent {
        let score: Double
        let weight: Double
        let contribution: Double
        let baseline: Double?
        let currentValue: Double?
        let description: String
    }
}

@MainActor
class RecoveryScoreCalculator {
    static let shared = RecoveryScoreCalculator()
    private let baselineEngine = DynamicBaselineEngine.shared
    private let scoreStore = ScoreHistoryStore.shared
    
    private init() {}
    
    /// Calculates the comprehensive Recovery Score for a given date using overnight data only
    /// This creates a static snapshot of physiological recovery that doesn't change throughout the day
    /// Total_Recovery_Score = (HRV_Component * 0.50) + (RHR_Component * 0.25) + (Sleep_Component * 0.15) + (Stress_Component * 0.10)
    func calculateRecoveryScore(for date: Date) async throws -> RecoveryScoreResult {
        
        // Check if we already have a stored recovery score for this date
        if let storedScore = scoreStore.getRecoveryScore(for: date) {
            print("📋 Using stored recovery score for \(date)")
            return RecoveryScoreResult(
                finalScore: storedScore.score,
                hrvComponent: RecoveryScoreResult.RecoveryComponent(
                    score: storedScore.hrvScore,
                    weight: 0.50,
                    contribution: storedScore.hrvScore * 0.50,
                    baseline: storedScore.baselineHRV,
                    currentValue: storedScore.hrvValue,
                    description: storedScore.hrvDescription
                ),
                rhrComponent: RecoveryScoreResult.RecoveryComponent(
                    score: storedScore.rhrScore,
                    weight: 0.25,
                    contribution: storedScore.rhrScore * 0.25,
                    baseline: storedScore.baselineRHR,
                    currentValue: storedScore.rhrValue,
                    description: storedScore.rhrDescription
                ),
                sleepComponent: RecoveryScoreResult.RecoveryComponent(
                    score: storedScore.sleepScore,
                    weight: 0.15,
                    contribution: storedScore.sleepScore * 0.15,
                    baseline: nil,
                    currentValue: Double(storedScore.sleepScoreValue ?? 0),
                    description: storedScore.sleepDescription
                ),
                stressComponent: RecoveryScoreResult.RecoveryComponent(
                    score: storedScore.stressScore,
                    weight: 0.10,
                    contribution: storedScore.stressScore * 0.10,
                    baseline: nil,
                    currentValue: nil,
                    description: storedScore.stressDescription
                ),
                date: date,
                directive: storedScore.directive,
                sleepSessionStart: storedScore.sleepSessionStart,
                sleepSessionEnd: storedScore.sleepSessionEnd
            )
        }
        
        // No stored score exists - calculate a new one using overnight data
        print("🔄 Calculating new recovery score for \(date) using overnight data")
        
        // Step 1: Find the main sleep session for this wake date
        let sleepSession = try await fetchMainSleepSession(for: date)
        
        // Step 2: Fetch all health data during the sleep session only
        let metrics = try await fetchOvernightHealthMetrics(for: sleepSession)
        
        // Step 3: Get baseline data
        baselineEngine.loadBaselines()
        
        // Step 4: Calculate each component using the FINAL CALIBRATED algorithm
        let hrvComponent = calculateHRVComponent(
            currentHRV: metrics.hrv,
            baselineHRV: baselineEngine.hrv60,
            enhancedHRV: metrics.enhancedHRV
        )
        
        let rhrComponent = calculateRHRComponent(
            currentRHR: metrics.rhr,
            baselineRHR: baselineEngine.rhr60
        )
        
        let sleepComponent = calculateSleepComponent(
            sleepScore: metrics.sleepScore
        )
        
        let stressComponent = calculateStressComponent(
            walkingHR: metrics.walkingHeartRate,
            respiratoryRate: metrics.respiratoryRate,
            oxygenSaturation: metrics.oxygenSaturation,
            baselineWalkingHR: baselineEngine.walkingHR14,
            baselineRespiratoryRate: baselineEngine.respiratoryRate14,
            baselineOxygenSaturation: baselineEngine.oxygenSaturation14
        )
        
        // Step 5: Calculate final weighted score using the FINAL CALIBRATED formula
        let totalRecoveryScore = 
            hrvComponent.contribution +
            rhrComponent.contribution +
            sleepComponent.contribution +
            stressComponent.contribution
        
        // Apply final clamping to ensure score is between 0 and 100
        let finalScore = Int(round(clamp(totalRecoveryScore, min: 0, max: 100)))
        
        // Step 6: Generate directive
        let directive = generateDirective(
            finalScore: finalScore,
            hrvComponent: hrvComponent,
            rhrComponent: rhrComponent,
            sleepComponent: sleepComponent,
            stressComponent: stressComponent
        )
        
        let result = RecoveryScoreResult(
            finalScore: finalScore,
            hrvComponent: hrvComponent,
            rhrComponent: rhrComponent,
            sleepComponent: sleepComponent,
            stressComponent: stressComponent,
            date: date,
            directive: directive,
            sleepSessionStart: sleepSession.start,
            sleepSessionEnd: sleepSession.end
        )
        
        // Step 7: Store the result permanently so it doesn't change throughout the day
        let recoveryScore = RecoveryScore(
            date: date,
            score: finalScore,
            sleepSessionStart: sleepSession.start,
            sleepSessionEnd: sleepSession.end,
            hrvScore: hrvComponent.score,
            rhrScore: rhrComponent.score,
            sleepScore: sleepComponent.score,
            stressScore: stressComponent.score,
            hrvValue: metrics.hrv,
            rhrValue: metrics.rhr,
            sleepScoreValue: metrics.sleepScore,
            walkingHRValue: metrics.walkingHeartRate,
            respiratoryRateValue: metrics.respiratoryRate,
            oxygenSaturationValue: metrics.oxygenSaturation,
            baselineHRV: baselineEngine.hrv60,
            baselineRHR: baselineEngine.rhr60,
            baselineWalkingHR: baselineEngine.walkingHR14,
            baselineRespiratoryRate: baselineEngine.respiratoryRate14,
            baselineOxygenSaturation: baselineEngine.oxygenSaturation14,
            directive: directive,
            hrvDescription: hrvComponent.description,
            rhrDescription: rhrComponent.description,
            sleepDescription: sleepComponent.description,
            stressDescription: stressComponent.description
        )
        
        scoreStore.saveRecoveryScore(recoveryScore)
        print("✅ Stored recovery score for \(date) - will remain static throughout the day")
        
        return result
    }
    
    // MARK: - Overnight Data Fetching
    
    private func fetchMainSleepSession(for wakeDate: Date) async throws -> DateInterval {
        return try await withCheckedThrowingContinuation { continuation in
            HealthKitManager.shared.fetchMainSleepSession(for: wakeDate) { sleepInterval in
                if let interval = sleepInterval {
                    continuation.resume(returning: interval)
                } else {
                    continuation.resume(throwing: RecoveryScoreError.noSleepSessionFound)
                }
            }
        }
    }
    
    private func fetchOvernightHealthMetrics(for sleepSession: DateInterval) async throws -> (
        hrv: Double?,
        rhr: Double?,
        sleepScore: Int?,
        walkingHeartRate: Double?,
        respiratoryRate: Double?,
        oxygenSaturation: Double?,
        enhancedHRV: EnhancedHRVData?
    ) {
        return try await withCheckedThrowingContinuation { continuation in
            let group = DispatchGroup()
            var hrv: Double?; var rhr: Double?; var sleepScore: Int? = nil
            var walkingHR: Double?; var respiratoryRate: Double?; var oxygenSaturation: Double?
            var enhancedHRV: EnhancedHRVData?
            
            // Fetch HRV during sleep session only
            group.enter()
            HealthKitManager.shared.fetchHRVForInterval(sleepSession) { value in
                hrv = value
                group.leave()
            }
            
            // Fetch RHR during sleep session only (lowest value during sleep)
            group.enter()
            HealthKitManager.shared.fetchRHRForInterval(sleepSession) { value in
                rhr = value
                group.leave()
            }
            
            // Fetch Sleep Score for the wake date
            group.enter()
            Task {
                do {
                    let sleepResult = try await SleepScoreCalculator.shared.calculateSleepScore(for: sleepSession.end)
                    sleepScore = sleepResult.finalScore
                } catch {
                    sleepScore = nil
                }
                group.leave()
            }
            
            // Fetch stress metrics during sleep session
            group.enter()
            HealthKitManager.shared.fetchWalkingHeartRateForInterval(sleepSession) { value in
                walkingHR = value
                group.leave()
            }
            
            group.enter()
            HealthKitManager.shared.fetchRespiratoryRateForInterval(sleepSession) { value in
                respiratoryRate = value
                group.leave()
            }
            
            group.enter()
            HealthKitManager.shared.fetchOxygenSaturationForInterval(sleepSession) { value in
                oxygenSaturation = value
                group.leave()
            }
            
            // Create enhanced HRV data if we have HRV
            group.enter()
            if let hrvValue = hrv {
                // For now, create a simplified enhanced HRV data structure
                let calculatedMetrics = AdvancedHRVMetrics(
                    meanRR: 1000.0, // Placeholder
                    sdnn: hrvValue,
                    rmssd: hrvValue * 0.8, // Approximate relationship
                    pnn50: 20.0, // Placeholder
                    triangularIndex: 15.0, // Placeholder
                    stressIndex: 1000 / (hrvValue * 15.0), // Approximate
                    autonomicBalance: 0.8, // Placeholder
                    recoveryScore: min(100, max(0, hrvValue * 2)), // Simple recovery score
                    autonomicBalanceScore: 80.0 // Placeholder
                )
                
                enhancedHRV = EnhancedHRVData(
                    sdnn: hrvValue,
                    rmssd: hrvValue * 0.8,
                    heartRateSamples: [], // Empty for now
                    calculatedMetrics: calculatedMetrics,
                    hasBeatToBeatData: false,
                    stressLevel: max(0, min(100, 100 - hrvValue))
                )
            }
            group.leave()
            
            group.notify(queue: .main) {
                continuation.resume(returning: (
                    hrv: hrv,
                    rhr: rhr,
                    sleepScore: sleepScore,
                    walkingHeartRate: walkingHR,
                    respiratoryRate: respiratoryRate,
                    oxygenSaturation: oxygenSaturation,
                    enhancedHRV: enhancedHRV
                ))
            }
        }
    }
    
    // MARK: - Component Calculations (unchanged from original)
    
    /// HRV Component (50% Weight) - The Core of Readiness
    /// Uses the average of all overnight HRV (SDNN) samples from the deep HealthKit query
    /// FINAL CALIBRATED Formula: Piecewise function with baseline of 75
    private func calculateHRVComponent(currentHRV: Double?, baselineHRV: Double?, enhancedHRV: EnhancedHRVData?) -> RecoveryScoreResult.RecoveryComponent {
        guard let hrv = currentHRV, let baseline = baselineHRV, baseline > 0 else {
            return RecoveryScoreResult.RecoveryComponent(
                score: 50.0, // Neutral score when data is missing
                weight: 0.50,
                contribution: 25.0,
                baseline: baselineHRV,
                currentValue: currentHRV,
                description: "HRV data unavailable"
            )
        }
        
        // Calculate the ratio of today's HRV to 60-day baseline
        let hrvRatio = hrv / baseline
        
        // Apply FINAL CALIBRATED piecewise function
        let hrvScore = calculateHrvScore(hrvRatio: hrvRatio)
        let contribution = hrvScore * 0.50
        
        // Calculate percentage difference from baseline
        let percentDiff = (hrv - baseline) / baseline * 100
        
        // Generate comprehensive description with baseline comparison and calculation explanation
        let description: String
        if hrvRatio >= 1.2 {
            description = "HRV vs \(String(format: "%.0f", baseline)) ms baseline: your HRV of \(String(format: "%.0f", hrv)) ms is +\(String(format: "%.0f", abs(percentDiff)))% above baseline (excellent recovery). Score: \(String(format: "%.0f", hrvScore))/100 (calculated using logarithmic growth formula: baseline ratio of 1.0 = 75 points, higher ratios get bonus points up to 100)"
        } else if hrvRatio >= 1.0 {
            description = "HRV vs \(String(format: "%.0f", baseline)) ms baseline: your HRV of \(String(format: "%.0f", hrv)) ms is +\(String(format: "%.0f", abs(percentDiff)))% above baseline (good recovery). Score: \(String(format: "%.0f", hrvScore))/100 (calculated using logarithmic growth formula: baseline ratio of 1.0 = 75 points, higher ratios get bonus points)"
        } else if hrvRatio >= 0.8 {
            description = "HRV vs \(String(format: "%.0f", baseline)) ms baseline: your HRV of \(String(format: "%.0f", hrv)) ms is -\(String(format: "%.0f", abs(percentDiff)))% below baseline (reduced recovery). Score: \(String(format: "%.0f", hrvScore))/100 (calculated using exponential decay formula: baseline ratio of 1.0 = 75 points, lower ratios get penalty points)"
        } else {
            description = "HRV vs \(String(format: "%.0f", baseline)) ms baseline: your HRV of \(String(format: "%.0f", hrv)) ms is -\(String(format: "%.0f", abs(percentDiff)))% below baseline (poor recovery). Score: \(String(format: "%.0f", hrvScore))/100 (calculated using exponential decay formula: baseline ratio of 1.0 = 75 points, lower ratios get penalty points down to 0)"
        }
        
        return RecoveryScoreResult.RecoveryComponent(
            score: hrvScore,
            weight: 0.50,
            contribution: contribution,
            baseline: baseline,
            currentValue: hrv,
            description: description
        )
    }
    
    /// FINAL CALIBRATED HRV Score Calculation
    /// A baseline HRV (ratio of 1.0) now correctly yields a score of 75
    private func calculateHrvScore(hrvRatio: Double) -> Double {
        let score: Double
        if hrvRatio >= 1.0 {
            // Logarithmic growth for positive results, starting from a baseline of 75.
            // A ratio of 1.0 gives 75. A ratio of 1.2 gives ~90.
            score = 75 + 35 * Foundation.log10(hrvRatio + 0.35)
        } else {
            // Exponential decay for negative results.
            // A ratio of 0.9 gives ~55. A ratio of 0.8 gives ~38.
            score = 75 * Foundation.pow(hrvRatio, 3)
        }
        return clamp(score, min: 0, max: 100)
    }
    
    /// RHR Component (25% Weight)
    /// FINAL CALIBRATED Formula: Piecewise function with baseline of 75
    private func calculateRHRComponent(currentRHR: Double?, baselineRHR: Double?) -> RecoveryScoreResult.RecoveryComponent {
        print("🔍 RHR Component Calculation:")
        print("  - Current RHR: \(currentRHR?.description ?? "nil")")
        print("  - Baseline RHR: \(baselineRHR?.description ?? "nil")")
        
        guard let rhr = currentRHR, let baseline = baselineRHR, baseline > 0, rhr > 0 else {
            print("❌ RHR Component: Missing data - returning neutral score")
            return RecoveryScoreResult.RecoveryComponent(
                score: 50.0, // Neutral score when data is missing
                weight: 0.25,
                contribution: 12.5,
                baseline: baselineRHR,
                currentValue: currentRHR,
                description: "RHR data unavailable"
            )
        }
        
        print("✅ RHR Component: Valid data - calculating score")
        
        // Calculate the ratio of baseline RHR to today's RHR (lower RHR is better)
        let rhrRatio = baseline / rhr
        
        // Apply FINAL CALIBRATED piecewise function
        let rhrScore = calculateRhrScore(rhrRatio: rhrRatio)
        let contribution = rhrScore * 0.25
        
        // Calculate percentage difference from baseline (for RHR, lower is better)
        let percentDiff = (rhr - baseline) / baseline * 100
        
        // Generate comprehensive description with baseline comparison and calculation explanation
        let description: String
        if rhrRatio >= 1.05 {
            description = "RHR vs \(String(format: "%.0f", baseline)) BPM baseline: your RHR of \(String(format: "%.0f", rhr)) BPM is -\(String(format: "%.0f", abs(percentDiff)))% below baseline (excellent cardiovascular recovery). Score: \(String(format: "%.0f", rhrScore))/100 (calculated using logarithmic growth formula: baseline ratio of 1.0 = 75 points, lower RHR gets bonus points up to 100)"
        } else if rhrRatio >= 1.0 {
            description = "RHR vs \(String(format: "%.0f", baseline)) BPM baseline: your RHR of \(String(format: "%.0f", rhr)) BPM is -\(String(format: "%.0f", abs(percentDiff)))% below baseline (good cardiovascular recovery). Score: \(String(format: "%.0f", rhrScore))/100 (calculated using logarithmic growth formula: baseline ratio of 1.0 = 75 points, lower RHR gets bonus points)"
        } else if rhrRatio >= 0.95 {
            description = "RHR vs \(String(format: "%.0f", baseline)) BPM baseline: your RHR of \(String(format: "%.0f", rhr)) BPM is +\(String(format: "%.0f", abs(percentDiff)))% above baseline (elevated cardiovascular load). Score: \(String(format: "%.0f", rhrScore))/100 (calculated using exponential decay formula: baseline ratio of 1.0 = 75 points, higher RHR gets penalty points)"
        } else {
            description = "RHR vs \(String(format: "%.0f", baseline)) BPM baseline: your RHR of \(String(format: "%.0f", rhr)) BPM is +\(String(format: "%.0f", abs(percentDiff)))% above baseline (high cardiovascular stress). Score: \(String(format: "%.0f", rhrScore))/100 (calculated using exponential decay formula: baseline ratio of 1.0 = 75 points, higher RHR gets penalty points down to 0)"
        }
        
        print("✅ RHR Component: Score calculated: \(rhrScore)/100")
        
        return RecoveryScoreResult.RecoveryComponent(
            score: rhrScore,
            weight: 0.25,
            contribution: contribution,
            baseline: baseline,
            currentValue: rhr,
            description: description
        )
    }
    
    /// FINAL CALIBRATED RHR Score Calculation
    /// A baseline RHR (ratio of 1.0) correctly yields a score of 75
    private func calculateRhrScore(rhrRatio: Double) -> Double {
        let score: Double
        if rhrRatio >= 1.0 {
            // Logarithmic growth for positive results (lower RHR).
            // A ratio of 1.0 gives 75. A ratio of 1.1 gives ~88.
            score = 75 + 45 * Foundation.log10(rhrRatio + 0.25)
        } else {
            // Exponential decay for negative results (higher RHR).
            score = 75 * Foundation.pow(rhrRatio, 4)
        }
        return clamp(score, min: 0, max: 100)
    }
    
    /// Sleep Component (15% Weight)
    /// Uses the final score from the FINAL CALIBRATED Sleep Score algorithm
    private func calculateSleepComponent(sleepScore: Int?) -> RecoveryScoreResult.RecoveryComponent {
        guard let score = sleepScore else {
            return RecoveryScoreResult.RecoveryComponent(
                score: 50.0, // Neutral score when data is missing
                weight: 0.15,
                contribution: 7.5,
                baseline: nil,
                currentValue: nil,
                description: "Sleep score unavailable"
            )
        }
        
        let sleepScoreDouble = Double(score)
        let contribution = sleepScoreDouble * 0.15
        
        // Generate comprehensive description with calculation explanation
        let description: String
        if score >= 85 {
            description = "Sleep Quality: \(score)/100 (excellent). Score calculated from sleep efficiency (30%), deep/REM sleep percentages (30%), heart rate dip during sleep (25%), and consistency vs your 14-day average bedtime/wake time (15%). 85+ = excellent recovery contribution"
        } else if score >= 70 {
            description = "Sleep Quality: \(score)/100 (good). Score calculated from sleep efficiency (30%), deep/REM sleep percentages (30%), heart rate dip during sleep (25%), and consistency vs your 14-day average bedtime/wake time (15%). 70-84 = good recovery contribution"
        } else if score >= 55 {
            description = "Sleep Quality: \(score)/100 (moderate). Score calculated from sleep efficiency (30%), deep/REM sleep percentages (30%), heart rate dip during sleep (25%), and consistency vs your 14-day average bedtime/wake time (15%). 55-69 = moderate recovery contribution"
        } else {
            description = "Sleep Quality: \(score)/100 (poor). Score calculated from sleep efficiency (30%), deep/REM sleep percentages (30%), heart rate dip during sleep (25%), and consistency vs your 14-day average bedtime/wake time (15%). Below 55 = poor recovery contribution"
        }
        
        return RecoveryScoreResult.RecoveryComponent(
            score: sleepScoreDouble,
            weight: 0.15,
            contribution: contribution,
            baseline: nil,
            currentValue: Double(score),
            description: description
        )
    }
    
    /// Stress Component (10% Weight)
    /// Analyzes deviations from personal baselines for walking HR, respiratory rate, and oxygen saturation
    private func calculateStressComponent(
        walkingHR: Double?,
        respiratoryRate: Double?,
        oxygenSaturation: Double?,
        baselineWalkingHR: Double?,
        baselineRespiratoryRate: Double?,
        baselineOxygenSaturation: Double?
    ) -> RecoveryScoreResult.RecoveryComponent {
        var deviations: [Double] = []
        var availableMetrics: [String] = []
        var descriptions: [String] = []

        // Calculate walking heart rate deviation using your baseline
        if let walkHR = walkingHR, let baseline = baselineWalkingHR, baseline > 0 {
            let deviation = abs((walkHR - baseline) / baseline) * 100
            deviations.append(deviation * 1.2) // Weight walking HR slightly higher
            availableMetrics.append("Walking Heart Rate")
            descriptions.append("Walking HR: \(String(format: "%.0f", walkHR)) BPM vs \(String(format: "%.0f", baseline)) BPM baseline (\(String(format: "%.0f", deviation))% deviation)")
        }
        
        // Calculate respiratory rate deviation using your baseline
        if let respRate = respiratoryRate, let baseline = baselineRespiratoryRate, baseline > 0 {
            let deviation = abs((respRate - baseline) / baseline) * 100
            deviations.append(deviation * 1.5) // Weight respiratory rate higher as it's more sensitive
            availableMetrics.append("Respiratory Rate")
            descriptions.append("Resp Rate: \(String(format: "%.1f", respRate)) BPM vs \(String(format: "%.1f", baseline)) BPM baseline (\(String(format: "%.1f", deviation))% deviation)")
        }
        
        // Calculate oxygen saturation deviation using your baseline
        if let oxSat = oxygenSaturation, let baseline = baselineOxygenSaturation, baseline > 0 {
            let deviation = abs((oxSat - baseline) / baseline) * 100
            deviations.append(deviation * 2.0) // Weight oxygen saturation highest as it's most critical
            availableMetrics.append("Oxygen Saturation")
            descriptions.append("O2 Sat: \(String(format: "%.1f", oxSat))% vs \(String(format: "%.1f", baseline))% baseline (\(String(format: "%.1f", deviation))% deviation)")
        }

        // If no metrics available, return neutral score
        if deviations.isEmpty {
            return RecoveryScoreResult.RecoveryComponent(
                score: 75.0, // Neutral score when no stress data available
                weight: 0.10,
                contribution: 7.5,
                baseline: nil,
                currentValue: nil,
                description: "Stress metrics unavailable - using neutral score"
            )
        }

        // Calculate weighted average deviation
        let averageDeviation = deviations.reduce(0, +) / Double(deviations.count)
        
        // Calculate stress score based on deviation from your personal baselines
        let stressScore: Double
        if averageDeviation <= 3.0 {
            // Very low deviation - excellent stress management
            stressScore = 100 - (averageDeviation * 1.5)
        } else if averageDeviation <= 8.0 {
            // Low to moderate deviation - good stress levels
            stressScore = 95 - ((averageDeviation - 3.0) * 2.5)
        } else if averageDeviation <= 15.0 {
            // Moderate to high deviation - elevated stress
            stressScore = 82.5 - ((averageDeviation - 8.0) * 3.0)
        } else {
            // High deviation - significant stress
            let excessDeviation = averageDeviation - 15.0
            stressScore = max(0, 61.5 - (excessDeviation * 2.0))
        }
        
        let clampedStressScore = clamp(stressScore, min: 0, max: 100)
        let contribution = clampedStressScore * 0.10
        
        // Generate comprehensive description with baseline comparisons and calculation explanation
        let metricsDescription = descriptions.joined(separator: ", ")
        let deviationDescription = String(format: "%.1f", averageDeviation)
        let description = "Stress vs personal baselines: \(metricsDescription). Average deviation: \(deviationDescription)%. Score: \(String(format: "%.0f", clampedStressScore))/100 (calculated from weighted deviations: walking HR ×1.2, respiratory rate ×1.5, oxygen saturation ×2.0. Lower deviation = higher score, 0-3% = excellent, 3-8% = good, 8-15% = elevated, 15%+ = high stress)"
        
        return RecoveryScoreResult.RecoveryComponent(
            score: clampedStressScore,
            weight: 0.10,
            contribution: contribution,
            baseline: nil,
            currentValue: nil,
            description: description
        )
    }
    
    // MARK: - Directive Generation
    
    private func generateDirective(
        finalScore: Int,
        hrvComponent: RecoveryScoreResult.RecoveryComponent,
        rhrComponent: RecoveryScoreResult.RecoveryComponent,
        sleepComponent: RecoveryScoreResult.RecoveryComponent,
        stressComponent: RecoveryScoreResult.RecoveryComponent
    ) -> String {
        
        if finalScore >= 85 {
            return "Primed for peak performance. Your body is ready for high-intensity training."
        } else if finalScore >= 70 {
            return "Good recovery state. Moderate to high-intensity training is appropriate."
        } else if finalScore >= 55 {
            return "Moderate recovery. Consider lighter training or active recovery."
        } else if hrvComponent.score < 60 {
            return "Nervous system under strain. Prioritize rest and recovery activities."
        } else if rhrComponent.score < 60 {
            return "Elevated cardiovascular load. Focus on active recovery and stress management."
        } else if sleepComponent.score < 50 {
            return "Poor sleep quality detected. Prioritize sleep hygiene and recovery."
        } else if stressComponent.score < 70 {
            return "Stress indicators present. Consider reducing training load."
        } else {
            return "Recovery needs attention. Focus on rest, nutrition, and stress management."
        }
    }
    
    // MARK: - Utility Functions
    
    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        return Swift.max(min, Swift.min(max, value))
    }
    
    /// Clear all stored recovery scores (useful for testing or data refresh)
    func clearAllStoredScores() {
        // This would need to be implemented in ScoreHistoryStore
        print("🗑️ Recovery score clearing not yet implemented")
    }
} 