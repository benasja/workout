import Foundation

enum RecoveryScoreError: Error {
    case healthKitNotAuthorized
    case noDataAvailable
    case calculationFailed
}

struct RecoveryScoreResult {
    let finalScore: Int
    let hrvComponent: RecoveryComponent
    let rhrComponent: RecoveryComponent
    let sleepComponent: RecoveryComponent
    let stressComponent: RecoveryComponent
    let date: Date
    let directive: String
    
    struct RecoveryComponent {
        let score: Double
        let weight: Double
        let contribution: Double
        let baseline: Double?
        let currentValue: Double?
        let description: String
    }
}

class RecoveryScoreCalculator {
    static let shared = RecoveryScoreCalculator()
    private let baselineEngine = DynamicBaselineEngine.shared
    
    private init() {}
    
    /// Calculates the comprehensive Recovery Score for a given date using the FINAL CALIBRATED algorithm
    /// Total_Recovery_Score = (HRV_Component * 0.50) + (RHR_Component * 0.25) + (Sleep_Component * 0.15) + (Stress_Component * 0.10)
    func calculateRecoveryScore(for date: Date) async throws -> RecoveryScoreResult {
        
        // Use the same date logic as SleepScoreCalculator - date is the wake date
        let sleepDate = date
        
        // Fetch all required health data for the date
        let metrics = try await fetchHealthMetrics(for: date, sleepDate: sleepDate)
        
        // Get baseline data
        baselineEngine.loadBaselines()
        
        // Calculate each component using the FINAL CALIBRATED algorithm
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
        
        // Calculate final weighted score using the FINAL CALIBRATED formula
        let totalRecoveryScore = 
            hrvComponent.contribution +
            rhrComponent.contribution +
            sleepComponent.contribution +
            stressComponent.contribution
        
        // Apply final clamping to ensure score is between 0 and 100
        let finalScore = Int(round(clamp(totalRecoveryScore, min: 0, max: 100)))
        
        // Generate directive
        let directive = generateDirective(
            finalScore: finalScore,
            hrvComponent: hrvComponent,
            rhrComponent: rhrComponent,
            sleepComponent: sleepComponent,
            stressComponent: stressComponent
        )
        
        return RecoveryScoreResult(
            finalScore: finalScore,
            hrvComponent: hrvComponent,
            rhrComponent: rhrComponent,
            sleepComponent: sleepComponent,
            stressComponent: stressComponent,
            date: date,
            directive: directive
        )
    }
    
    // MARK: - Recalibrated Component Calculations
    
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
        
        // Generate description based on performance
        let description: String
        if hrvRatio >= 1.2 {
            description = "Excellent HRV - \(String(format: "%.1f", hrv))ms (baseline: \(String(format: "%.1f", baseline))ms, +\(String(format: "%.1f", (hrvRatio-1)*100))%)"
        } else if hrvRatio >= 1.0 {
            description = "Good HRV - \(String(format: "%.1f", hrv))ms (baseline: \(String(format: "%.1f", baseline))ms, +\(String(format: "%.1f", (hrvRatio-1)*100))%)"
        } else if hrvRatio >= 0.8 {
            description = "Reduced HRV - \(String(format: "%.1f", hrv))ms (baseline: \(String(format: "%.1f", baseline))ms, -\(String(format: "%.1f", (1-hrvRatio)*100))%)"
        } else {
            description = "Low HRV - \(String(format: "%.1f", hrv))ms (baseline: \(String(format: "%.1f", baseline))ms, -\(String(format: "%.1f", (1-hrvRatio)*100))%)"
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
        guard let rhr = currentRHR, let baseline = baselineRHR, baseline > 0, rhr > 0 else {
            return RecoveryScoreResult.RecoveryComponent(
                score: 50.0, // Neutral score when data is missing
                weight: 0.25,
                contribution: 12.5,
                baseline: baselineRHR,
                currentValue: currentRHR,
                description: "RHR data unavailable"
            )
        }
        
        // Calculate the ratio of baseline RHR to today's RHR (lower RHR is better)
        let rhrRatio = baseline / rhr
        
        // Apply FINAL CALIBRATED piecewise function
        let rhrScore = calculateRhrScore(rhrRatio: rhrRatio)
        let contribution = rhrScore * 0.25
        
        // Generate description
        let description: String
        if rhrRatio >= 1.05 {
            description = "Excellent RHR - \(String(format: "%.0f", rhr)) BPM (baseline: \(String(format: "%.0f", baseline)) BPM, -\(String(format: "%.1f", (1-rhrRatio)*100))%)"
        } else if rhrRatio >= 1.0 {
            description = "Good RHR - \(String(format: "%.0f", rhr)) BPM (baseline: \(String(format: "%.0f", baseline)) BPM, -\(String(format: "%.1f", (1-rhrRatio)*100))%)"
        } else if rhrRatio >= 0.95 {
            description = "Elevated RHR - \(String(format: "%.0f", rhr)) BPM (baseline: \(String(format: "%.0f", baseline)) BPM, +\(String(format: "%.1f", (1/rhrRatio-1)*100))%)"
        } else {
            description = "High RHR - \(String(format: "%.0f", rhr)) BPM (baseline: \(String(format: "%.0f", baseline)) BPM, +\(String(format: "%.1f", (1/rhrRatio-1)*100))%)"
        }
        
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
        
        let contribution = Double(score) * 0.15
        
        let description: String
        if score >= 85 {
            description = "Excellent sleep quality (\(score)/100)"
        } else if score >= 70 {
            description = "Good sleep quality (\(score)/100)"
        } else if score >= 50 {
            description = "Fair sleep quality (\(score)/100)"
        } else {
            description = "Poor sleep quality (\(score)/100)"
        }
        
        return RecoveryScoreResult.RecoveryComponent(
            score: Double(score),
            weight: 0.15,
            contribution: contribution,
            baseline: nil,
            currentValue: Double(score),
            description: description
        )
    }
    
    /// Stress Component (10% Weight)
    /// Measures deviation from the norm using WalkingHeartRateAverage, RespiratoryRate, and OxygenSaturation
    /// More sensitive scoring that better reflects stress levels
    // User-provided fixed baselines for stress metrics
    private let userFixedStressBaselines: (walkingHR: Double, respiratoryRate: Double, oxygenSaturation: Double, stress: Double) = (0, 0, 0, 87.9)

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

        // Use user-provided fixed baselines if available
        let fixedWalkingHR = userFixedStressBaselines.walkingHR
        let fixedRespiratoryRate = userFixedStressBaselines.respiratoryRate
        let fixedOxygenSaturation = userFixedStressBaselines.oxygenSaturation
        let fixedStress = userFixedStressBaselines.stress

        // Calculate respiratory rate deviation
        if let respRate = respiratoryRate, fixedRespiratoryRate > 0 {
            let deviation = abs((respRate - fixedRespiratoryRate) / fixedRespiratoryRate) * 100
            deviations.append(deviation * 1.5)
            availableMetrics.append("Respiratory Rate")
        }
        // Calculate oxygen saturation deviation
        if let oxSat = oxygenSaturation, fixedOxygenSaturation > 0 {
            let deviation = abs((oxSat - fixedOxygenSaturation) / fixedOxygenSaturation) * 100
            deviations.append(deviation * 2.0)
            availableMetrics.append("Oxygen Saturation")
        }
        // Calculate walking heart rate deviation
        if let walkHR = walkingHR, fixedWalkingHR > 0 {
            let deviation = abs((walkHR - fixedWalkingHR) / fixedWalkingHR) * 100
            deviations.append(deviation * 1.2)
            availableMetrics.append("Walking Heart Rate")
        }

        // If no metrics, use fixed stress value
        if deviations.isEmpty {
            return RecoveryScoreResult.RecoveryComponent(
                score: fixedStress,
                weight: 0.10,
                contribution: fixedStress * 0.10,
                baseline: nil,
                currentValue: nil,
                description: "User fixed stress baseline"
            )
        }

        // Calculate weighted average deviation
        let averageDeviation = deviations.reduce(0, +) / Double(deviations.count)
        let stressScore: Double
        if averageDeviation <= 5.0 {
            stressScore = 100 - (averageDeviation * 2.0)
        } else if averageDeviation <= 15.0 {
            stressScore = 90 - ((averageDeviation - 5.0) * 3.0)
        } else {
            let excessDeviation = averageDeviation - 15.0
            stressScore = max(0, 75 - (excessDeviation * excessDeviation * 0.5))
        }
        let clampedStressScore = clamp(stressScore, min: 0, max: 100)
        let contribution = clampedStressScore * 0.10
        let description = "Stress level based on user baseline - \(String(format: "%.1f", averageDeviation))% deviation from baseline"
        return RecoveryScoreResult.RecoveryComponent(
            score: clampedStressScore,
            weight: 0.10,
            contribution: contribution,
            baseline: nil,
            currentValue: averageDeviation,
            description: description
        )
    }
    
    // MARK: - Helper Methods
    
    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        return Swift.max(min, Swift.min(value, max))
    }
    
    private func fetchHealthMetrics(for date: Date, sleepDate: Date) async throws -> (hrv: Double?, rhr: Double?, sleepScore: Int?, walkingHeartRate: Double?, respiratoryRate: Double?, oxygenSaturation: Double?, enhancedHRV: EnhancedHRVData?) {
        // Check authorization first
        guard HealthKitManager.shared.checkAuthorizationStatus() else {
            throw RecoveryScoreError.healthKitNotAuthorized
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let group = DispatchGroup()
            var hrv: Double?; var rhr: Double?; var sleepScore: Int? = nil
            var walkingHR: Double?; var respiratoryRate: Double?; var oxygenSaturation: Double?
            var enhancedHRV: EnhancedHRVData?
            
            // Fetch Enhanced HRV (includes beat-to-beat analysis)
            group.enter()
            HealthKitManager.shared.fetchEnhancedHRV(for: date) { enhancedData in
                enhancedHRV = enhancedData
                hrv = enhancedData?.sdnn
                group.leave()
            }
            
            // Fetch RHR
            group.enter()
            HealthKitManager.shared.fetchRHR(for: date) { value in
                rhr = value
                group.leave()
            }
            
            // Fetch Sleep Score - use the same date logic as SleepScoreCalculator
            group.enter()
            Task {
                do {
                    let sleepResult = try await SleepScoreCalculator.shared.calculateSleepScore(for: sleepDate)
                    sleepScore = sleepResult.finalScore
                } catch {
                    // Don't set a random value - keep it nil so the sleep component can handle missing data
                    sleepScore = nil
                }
                group.leave()
            }
            
            // Fetch Walking Heart Rate
            group.enter()
            HealthKitManager.shared.fetchWalkingHeartRate(for: date) { value in
                walkingHR = value
                group.leave()
            }
            
            // Fetch Respiratory Rate
            group.enter()
            HealthKitManager.shared.fetchRespiratoryRate(for: date) { value in
                respiratoryRate = value
                group.leave()
            }
            
            // Fetch Oxygen Saturation
            group.enter()
            HealthKitManager.shared.fetchOxygenSaturation(for: date) { value in
                oxygenSaturation = value
                group.leave()
            }
            
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
} 