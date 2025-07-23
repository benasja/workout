import Foundation
import HealthKit

// MARK: - Sleep Score Result Structure
struct SleepScoreResult {
    let finalScore: Int
    let keyFindings: [String]
    let efficiencyComponent: Double
    let qualityComponent: Double
    let timingComponent: Double
    let details: SleepScoreDetails
    
    // Convenience properties for easier access
    var directive: String {
        if finalScore >= 85 {
            return "Excellent sleep quality. Your body is well-rested and ready for optimal performance."
        } else if finalScore >= 70 {
            return "Good sleep quality. Maintain your current sleep habits for continued improvement."
        } else if finalScore >= 50 {
            return "Fair sleep quality. Consider improving your sleep routine for better recovery."
        } else {
            return "Poor sleep quality. Focus on sleep hygiene and consider adjusting your schedule."
        }
    }
    
    // Sleep timing properties
    var bedtime: Date? { details.bedtime }
    var wakeTime: Date? { details.wakeTime }
    var timeInBed: TimeInterval { details.timeInBed }
    var timeAsleep: TimeInterval { details.timeAsleep }
    
    // Sleep stage properties
    var deepSleep: TimeInterval { details.deepSleepDuration }
    var remSleep: TimeInterval { details.remSleepDuration }
    var coreSleep: TimeInterval { 
        timeAsleep - deepSleep - remSleep 
    }
    
    // Efficiency properties
    var sleepEfficiency: Double { details.sleepEfficiency }
    var timeToFallAsleep: Double {
        // Estimate time to fall asleep as the difference between time in bed and time asleep
        // This is a rough approximation
        let fallAsleepTime = timeInBed - timeAsleep
        return max(0, fallAsleepTime / 60) // Convert to minutes
    }
    
    // Percentage properties
    var deepSleepPercentage: Double { details.deepSleepPercentage }
    var remSleepPercentage: Double { details.remSleepPercentage }
}

struct SleepScoreDetails {
    let timeInBed: TimeInterval
    let timeAsleep: TimeInterval
    let deepSleepDuration: TimeInterval
    let remSleepDuration: TimeInterval
    let averageHeartRate: Double?
    let dailyRestingHeartRate: Double?
    let bedtime: Date?
    let wakeTime: Date?
    let sleepEfficiency: Double
    let deepSleepPercentage: Double
    let remSleepPercentage: Double
    let heartRateDipPercentage: Double?
    
    init(timeInBed: TimeInterval, timeAsleep: TimeInterval, deepSleepDuration: TimeInterval, remSleepDuration: TimeInterval, averageHeartRate: Double?, dailyRestingHeartRate: Double?, bedtime: Date?, wakeTime: Date?, sleepEfficiency: Double, deepSleepPercentage: Double, remSleepPercentage: Double) {
        self.timeInBed = timeInBed
        self.timeAsleep = timeAsleep
        self.deepSleepDuration = deepSleepDuration
        self.remSleepDuration = remSleepDuration
        self.averageHeartRate = averageHeartRate
        self.dailyRestingHeartRate = dailyRestingHeartRate
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.sleepEfficiency = sleepEfficiency
        self.deepSleepPercentage = deepSleepPercentage
        self.remSleepPercentage = remSleepPercentage
        
        // Calculate heart rate dip percentage safely
        if let hr = averageHeartRate, let rhr = dailyRestingHeartRate, rhr > 0 {
            self.heartRateDipPercentage = (1 - (hr / rhr))
        } else {
            self.heartRateDipPercentage = nil
        }
    }
}

// MARK: - Sleep Score Calculator
final class SleepScoreCalculator {
    static let shared = SleepScoreCalculator()
    private let healthStore = HealthKitManager.shared.healthStore
    private let baselineEngine = DynamicBaselineEngine.shared
    private var sleepScoreCache: [String: SleepScoreResult] = [:]
    
    private init() {}
    
    // MARK: - Cache Management
    func clearCache() {
        sleepScoreCache.removeAll()
        print("🗑️ Sleep score cache cleared")
    }
    
    // MARK: - Main Sleep Score Calculation
    func calculateSleepScore(for date: Date) async throws -> SleepScoreResult {
        // Check cache first
        let calendar = Calendar.current
        let cacheKey = "\(calendar.component(.year, from: date))-\(calendar.component(.month, from: date))-\(calendar.component(.day, from: date))"
        
        if let cachedResult = sleepScoreCache[cacheKey] {
            print("📋 Using cached sleep score for \(cacheKey)")
            return cachedResult
        }
        
        // Check HealthKit authorization first
        guard HealthKitManager.shared.checkAuthorizationStatus() else {
            print("❌ HealthKit authorization not granted for sleep score calculation")
            throw SleepScoreError.healthKitNotAvailable
        }
        
        // Always use the date as the 'wake date' for sleep
        let sleepDate = date
        let cal = Calendar.current
        print("🔍 Attempting to calculate sleep score for recovery...")
        print("   Sleep Date (wake date): \(sleepDate)")
        print("   Sleep Date components: year: \(cal.component(.year, from: sleepDate)) month: \(cal.component(.month, from: sleepDate)) day: \(cal.component(.day, from: sleepDate))")
        
        // Fetch all required data - use try-catch for individual components
        let sleepData: (timeInBed: TimeInterval, timeAsleep: TimeInterval, deepSleepDuration: TimeInterval, remSleepDuration: TimeInterval, bedtime: Date?, wakeTime: Date?)
        let heartRateData: Double?
        let restingHeartRate: Double?
        let baselineData: (bedtime: Date?, wakeTime: Date?)
        let enhancedHRVData: EnhancedHRVData?
        
        do {
            sleepData = try await fetchDetailedSleepData(for: sleepDate)
        } catch {
            print("❌ Failed to fetch sleep data: \(error)")
            throw error
        }
        
        do {
            heartRateData = try await fetchHeartRateData(for: sleepDate)
        } catch {
            print("⚠️ Failed to fetch heart rate data, using fallback: \(error)")
            heartRateData = nil
        }
        
        do {
            restingHeartRate = try await fetchRestingHeartRate(for: sleepDate)
        } catch {
            print("⚠️ Failed to fetch RHR data, using fallback: \(error)")
            restingHeartRate = nil
        }
        
        do {
            baselineData = try await fetchBaselineData()
        } catch {
            print("⚠️ Failed to fetch baseline data, using fallback: \(error)")
            baselineData = (nil, nil)
        }
        
        do {
            enhancedHRVData = try await fetchEnhancedHRVData(for: date)
        } catch {
            print("⚠️ Failed to fetch enhanced HRV data, using fallback: \(error)")
            enhancedHRVData = nil
        }
        
        // Validate sleep data
        guard sleepData.timeInBed > 0, sleepData.timeAsleep > 0 else {
            print("⚠️ Invalid sleep data - time in bed: \(sleepData.timeInBed), time asleep: \(sleepData.timeAsleep)")
            throw SleepScoreError.noSleepData
        }
        
        // Only use actual heart rate data - don't use fallback values that could skew scores
        let effectiveHeartRate = heartRateData
        let effectiveRHR = restingHeartRate
        
        // Only adjust heart rate if we have both values
        let adjustedHeartRate: Double?
        if let hr = effectiveHeartRate, let rhr = effectiveRHR {
            // Ensure heart rate during sleep is reasonable (should be lower than RHR)
            adjustedHeartRate = min(hr, rhr * 1.1) // Cap at 110% of RHR
        } else {
            adjustedHeartRate = effectiveHeartRate
        }
        
        print("💓 Heart Rate Data:")
        print("   Average HR: \(heartRateData ?? 0) (using \(adjustedHeartRate ?? 0))")
        print("   RHR: \(restingHeartRate ?? 0) (using \(effectiveRHR ?? 0))")
        print("🌙 Sleep Data Validation:")
        print("   Time in Bed: \(sleepData.timeInBed / 3600) hours")
        print("   Time Asleep: \(sleepData.timeAsleep / 3600) hours")
        print("   Sleep Efficiency: \((sleepData.timeAsleep / sleepData.timeInBed) * 100)%")
        
        // Calculate components using the NEW RE-CALIBRATED algorithm
        let restorationComponent = calculateRestorationComponent(
            timeAsleep: sleepData.timeAsleep,
            deepSleepDuration: sleepData.deepSleepDuration,
            remSleepDuration: sleepData.remSleepDuration,
            averageHeartRate: adjustedHeartRate,
            dailyRestingHeartRate: effectiveRHR,
            enhancedHRV: enhancedHRVData
        )
        
        let efficiencyComponent = calculateEfficiencyComponent(
            timeInBed: sleepData.timeInBed,
            timeAsleep: sleepData.timeAsleep
        )
        
        let consistencyComponent = calculateConsistencyComponent(
            bedtime: sleepData.bedtime,
            wakeTime: sleepData.wakeTime,
            baselineBedtime: baselineData.bedtime,
            baselineWakeTime: baselineData.wakeTime
        )
        
        // FINAL CALIBRATION: New weights
        let componentScore = 
            (restorationComponent * 0.50) +
            (efficiencyComponent * 0.25) +
            (consistencyComponent * 0.25)
        
        // Apply the new continuous Duration Multiplier
        let hoursAsleep = sleepData.timeAsleep / 3600
        let durationMultiplier = calculateDurationMultiplier(hoursAsleep: hoursAsleep)
        let totalSleepScore = componentScore * durationMultiplier
        
        // Apply final clamping to ensure score is between 0 and 100
        let finalScore = Int(round(clamp(totalSleepScore, min: 0, max: 100)))
        
        // Debug: Print component values
        print("🔍 RE-CALIBRATED Sleep Score Debug:")
        print("   Restoration Component: \(restorationComponent)")
        print("   Efficiency Component: \(efficiencyComponent)")
        print("   Consistency Component: \(consistencyComponent)")
        print("   Component Score: \(componentScore)")
        print("   Hours Asleep: \(hoursAsleep)")
        print("   Duration Multiplier: \(durationMultiplier)")
        print("   Total Score: \(totalSleepScore)")
        print("   Final Score: \(finalScore)")
        print("   Time in Bed: \(sleepData.timeInBed / 3600) hours")
        print("   Time Asleep: \(sleepData.timeAsleep / 3600) hours")
        print("   Deep Sleep: \(sleepData.deepSleepDuration / 3600) hours")
        print("   REM Sleep: \(sleepData.remSleepDuration / 3600) hours")
        print("   Heart Rate: \(adjustedHeartRate ?? 0)")
        print("   RHR: \(effectiveRHR ?? 0)")
        print("   Baseline Bedtime: \(baselineData.bedtime?.description ?? "nil")")
        print("   Baseline Wake: \(baselineData.wakeTime?.description ?? "nil")")
        
        // Helper function to calculate heart rate dip percentage
        func calculateHeartRateDipPercentage() -> Double? {
            if let hr = adjustedHeartRate, let rhr = effectiveRHR, rhr > 0 {
                return (1 - (hr / rhr))
            } else {
                return nil
            }
        }
        
        // Generate key findings
        let keyFindings = generateKeyFindings(
            restorationComponent: restorationComponent,
            efficiencyComponent: efficiencyComponent,
            consistencyComponent: consistencyComponent,
            details: SleepScoreDetails(
                timeInBed: sleepData.timeInBed,
                timeAsleep: sleepData.timeAsleep,
                deepSleepDuration: sleepData.deepSleepDuration,
                remSleepDuration: sleepData.remSleepDuration,
                averageHeartRate: adjustedHeartRate,
                dailyRestingHeartRate: effectiveRHR,
                bedtime: sleepData.bedtime,
                wakeTime: sleepData.wakeTime,
                sleepEfficiency: sleepData.timeAsleep / sleepData.timeInBed,
                deepSleepPercentage: sleepData.deepSleepDuration / sleepData.timeAsleep,
                remSleepPercentage: sleepData.remSleepDuration / sleepData.timeAsleep
            )
        )
        
        let result = SleepScoreResult(
            finalScore: finalScore,
            keyFindings: keyFindings,
            efficiencyComponent: efficiencyComponent,
            qualityComponent: restorationComponent, // Renamed to restoration
            timingComponent: consistencyComponent, // Renamed to consistency
            details: SleepScoreDetails(
                timeInBed: sleepData.timeInBed,
                timeAsleep: sleepData.timeAsleep,
                deepSleepDuration: sleepData.deepSleepDuration,
                remSleepDuration: sleepData.remSleepDuration,
                averageHeartRate: adjustedHeartRate,
                dailyRestingHeartRate: effectiveRHR,
                bedtime: sleepData.bedtime,
                wakeTime: sleepData.wakeTime,
                sleepEfficiency: sleepData.timeAsleep / sleepData.timeInBed,
                deepSleepPercentage: sleepData.deepSleepDuration / sleepData.timeAsleep,
                remSleepPercentage: sleepData.remSleepDuration / sleepData.timeAsleep
            )
        )
        
        // Cache the result
        sleepScoreCache[cacheKey] = result
        print("📋 Cached sleep score for \(cacheKey)")
        
        return result
    }
    
    // MARK: - Data Fetching
    private func fetchDetailedSleepData(for date: Date) async throws -> (timeInBed: TimeInterval, timeAsleep: TimeInterval, deepSleepDuration: TimeInterval, remSleepDuration: TimeInterval, bedtime: Date?, wakeTime: Date?) {
        let calendar = Calendar.current
        // Fetch sleep samples that end between previous day noon and this day noon
        let startOfWindow = calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: date)!))!
        let endOfWindow = calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: date))!
        
        print("🌙 Fetching sleep data for wake date: \(date)")
        print("   Start of window: \(startOfWindow)")
        print("   End of window: \(endOfWindow)")
        
        // Check authorization status for sleep data specifically
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw SleepScoreError.healthKitNotAvailable
        }
        
        let sleepAuthStatus = healthStore.authorizationStatus(for: sleepType)
        print("🔍 Sleep Authorization Status: \(sleepAuthStatus.rawValue) (\(sleepAuthStatus))")
        
        guard sleepAuthStatus.rawValue == 1 else {
            print("❌ Sleep data authorization not granted: \(sleepAuthStatus) (raw value: \(sleepAuthStatus.rawValue))")
            throw SleepScoreError.healthKitNotAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startOfWindow, end: endOfWindow, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let sleepSamples = (samples as? [HKCategorySample]) ?? []
                print("🌙 Sleep samples found: \(sleepSamples.count)")
                
                guard !sleepSamples.isEmpty else {
                    print("❌ No sleep samples found for wake date: \(date)")
                    continuation.resume(throwing: SleepScoreError.noSleepData)
                    return
                }
                
                // Group sleep samples by session (continuous periods)
                let sleepSessions = SleepScoreCalculator.groupSleepSamplesIntoSessions(sleepSamples)
                print("🌙 Found \(sleepSessions.count) sleep sessions")
                
                // Find the main sleep session (longest one)
                let mainSession = sleepSessions.max(by: { $0.totalDuration < $1.totalDuration }) ?? sleepSessions.first
                
                guard let session = mainSession else {
                    print("❌ No valid sleep session found")
                    continuation.resume(throwing: SleepScoreError.noSleepData)
                    return
                }
                
                print("🌙 Main sleep session:")
                print("   Start: \(session.startTime)")
                print("   End: \(session.endTime)")
                print("   Duration: \(session.totalDuration / 3600) hours")
                print("   Time Asleep: \(session.timeAsleep / 3600) hours")
                
                // Calculate time in bed for the main session only
                let timeInBed = session.totalDuration
                let timeAsleep = session.timeAsleep
                
                // Calculate deep sleep duration (only for main session)
                let deepSleepDuration = session.samples.filter { sample in
                    HKCategoryValueSleepAnalysis(rawValue: sample.value) == .asleepDeep
                }.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                
                // Calculate REM sleep duration (only for main session)
                let remSleepDuration = session.samples.filter { sample in
                    HKCategoryValueSleepAnalysis(rawValue: sample.value) == .asleepREM
                }.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                
                // Get bedtime and wake time from main session
                let bedtime = session.startTime
                let wakeTime = session.endTime
                
                continuation.resume(returning: (timeInBed, timeAsleep, deepSleepDuration, remSleepDuration, bedtime, wakeTime))
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchHeartRateData(for date: Date) async throws -> Double? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw SleepScoreError.healthKitNotAvailable
        }
        
        // Check authorization status for heart rate data
        let hrAuthStatus = healthStore.authorizationStatus(for: heartRateType)
        print("🔍 Heart Rate Authorization Status: \(hrAuthStatus.rawValue) (\(hrAuthStatus))")
        
        guard hrAuthStatus.rawValue == 1 else {
            print("❌ Heart rate data authorization not granted: \(hrAuthStatus) (raw value: \(hrAuthStatus.rawValue))")
            return nil // Return nil instead of throwing error for heart rate
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let heartRateSamples = (samples as? [HKQuantitySample]) ?? []
                
                // Filter heart rate samples to only include those during sleep hours (10 PM to 8 AM)
                let sleepStartHour = 22 // 10 PM
                let sleepEndHour = 8 // 8 AM
                
                let sleepHeartRateSamples = heartRateSamples.filter { sample in
                    let hour = calendar.component(.hour, from: sample.startDate)
                    return hour >= sleepStartHour || hour < sleepEndHour
                }
                
                let values = sleepHeartRateSamples.map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) }
                let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
                
                print("💓 Heart Rate Analysis:")
                print("   Total samples: \(heartRateSamples.count)")
                print("   Sleep samples: \(sleepHeartRateSamples.count)")
                print("   Average HR: \(average ?? 0)")
                
                continuation.resume(returning: average)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchRestingHeartRate(for date: Date) async throws -> Double? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        guard let rhrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            throw SleepScoreError.healthKitNotAvailable
        }
        
        // Check authorization status for resting heart rate data
        let rhrAuthStatus = healthStore.authorizationStatus(for: rhrType)
        print("🔍 RHR Authorization Status: \(rhrAuthStatus.rawValue) (\(rhrAuthStatus))")
        
        guard rhrAuthStatus.rawValue == 1 else {
            print("❌ RHR data authorization not granted: \(rhrAuthStatus) (raw value: \(rhrAuthStatus.rawValue))")
            return nil // Return nil instead of throwing error for RHR
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: rhrType, predicate: predicate, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let rhr = (samples as? [HKQuantitySample])?.first?.quantity.doubleValue(for: HKUnit(from: "count/min"))
                continuation.resume(returning: rhr)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchBaselineData() async throws -> (bedtime: Date?, wakeTime: Date?) {
        baselineEngine.loadBaselines()
        
        print("🔄 Baseline Data Debug:")
        print("   Baseline Bedtime: \(baselineEngine.bedtime14?.description ?? "nil")")
        print("   Baseline Wake: \(baselineEngine.wake14?.description ?? "nil")")
        print("   Calibrating: \(baselineEngine.calibrating)")
        
        // If baseline data is missing, try to calculate it from recent data
        if baselineEngine.bedtime14 == nil || baselineEngine.wake14 == nil {
            print("⚠️ Missing baseline data, calculating from recent sleep data...")
            return try await calculateFallbackBaseline()
        }
        
        return (baselineEngine.bedtime14, baselineEngine.wake14)
    }
    
    private func fetchEnhancedHRVData(for date: Date) async throws -> EnhancedHRVData? {
        return try await withCheckedThrowingContinuation { continuation in
            HealthKitManager.shared.fetchEnhancedHRV(for: date) { enhancedData in
                continuation.resume(returning: enhancedData)
            }
        }
    }
    
    private func calculateFallbackBaseline() async throws -> (bedtime: Date?, wakeTime: Date?) {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -14, to: endDate) ?? endDate
        
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw SleepScoreError.healthKitNotAvailable
        }
        
        // Check authorization status for baseline calculation
        let sleepAuthStatus = healthStore.authorizationStatus(for: sleepType)
        print("🔍 Baseline Sleep Authorization Status: \(sleepAuthStatus.rawValue) (\(sleepAuthStatus))")
        
        guard sleepAuthStatus.rawValue == 1 else {
            print("❌ Sleep data authorization not granted for baseline calculation: \(sleepAuthStatus) (raw value: \(sleepAuthStatus.rawValue))")
            throw SleepScoreError.healthKitNotAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let sleepSamples = (samples as? [HKCategorySample]) ?? []
                let grouped = Dictionary(grouping: sleepSamples) { Calendar.current.startOfDay(for: $0.startDate) }
                
                var bedtimes: [Date] = []
                var wakeTimes: [Date] = []
                
                for (_, daySamples) in grouped {
                    if let bedtime = daySamples.min(by: { $0.startDate < $1.startDate })?.startDate,
                       let wakeTime = daySamples.max(by: { $0.endDate < $1.endDate })?.endDate {
                        bedtimes.append(bedtime)
                        wakeTimes.append(wakeTime)
                    }
                }
                
                let avgBedtime = bedtimes.isEmpty ? nil : Date(timeIntervalSince1970: bedtimes.map { $0.timeIntervalSince1970 }.reduce(0, +) / Double(bedtimes.count))
                let avgWakeTime = wakeTimes.isEmpty ? nil : Date(timeIntervalSince1970: wakeTimes.map { $0.timeIntervalSince1970 }.reduce(0, +) / Double(wakeTimes.count))
                
                print("📊 Fallback Baseline Calculated:")
                print("   Average Bedtime: \(avgBedtime?.description ?? "nil")")
                print("   Average Wake Time: \(avgWakeTime?.description ?? "nil")")
                print("   Data Points: \(bedtimes.count)")
                
                continuation.resume(returning: (avgBedtime, avgWakeTime))
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Recalibrated Component Calculations
    
    /// Duration Multiplier (The Gatekeeper) - RE-CALIBRATED VERSION
    /// This new multiplier acts as a hard cap on your potential score based purely on sleep duration.
    /// For the user's example (6.5h sleep), this should result in a score in the 70-78 range.
    private func calculateDurationMultiplier(hoursAsleep: Double) -> Double {
        if hoursAsleep < 6.0 {
            // A steep but linear penalty for sleep under 6 hours.
            // Maps the range [5.0, 6.0) to a multiplier of [0.60, 0.80)
            // An hour of sleep in this range is worth 20 points on the multiplier.
            let progress = (hoursAsleep - 5.0) / 1.0 // Progress through the 1-hour window
            return 0.60 + (progress * 0.20)
        } else if hoursAsleep < 7.5 {
            // A gentler linear ramp up to the optimal score.
            // Maps the range [6.0, 7.5) to a multiplier of [0.80, 1.0)
            // An hour and a half of sleep in this range is worth 20 points.
            let progress = (hoursAsleep - 6.0) / 1.5 // Progress through the 1.5-hour window
            return 0.80 + (progress * 0.20)
        } else if hoursAsleep <= 9.0 {
            // The optimal plateau. Any duration in this range gets the full score.
            return 1.0
        } else {
            // A slight, gradual penalty for potential oversleeping/sickness.
            return max(0.9, 1.0 - (hoursAsleep - 9.0) * 0.1)
        }
    }
    
    /// Restoration Component (45% Weight) - The Core of Sleep Quality
    /// RE-CALIBRATED: More forgiving for deep sleep values just below minimum threshold
    private func calculateRestorationComponent(
        timeAsleep: TimeInterval,
        deepSleepDuration: TimeInterval,
        remSleepDuration: TimeInterval,
        averageHeartRate: Double?,
        dailyRestingHeartRate: Double?,
        enhancedHRV: EnhancedHRVData?
    ) -> Double {
        guard timeAsleep > 0 else { return 0 }
        
        // Deep Sleep Score (40% of restoration component) - MORE FORGIVING
        let deepSleepPercentage = deepSleepDuration / timeAsleep
        let deepScore = normalizeDeepSleepPercentageRecalibrated(deepSleepPercentage)
        
        // REM Sleep Score (40% of restoration component)
        let remSleepPercentage = remSleepDuration / timeAsleep
        let remScore = normalizeREMSleepPercentage(remSleepPercentage)
        
        // HR Dip score (20% of restoration component) - only calculate if we have both values
        let hrDipScore: Double
        if let avgHR = averageHeartRate, let rhr = dailyRestingHeartRate {
            hrDipScore = calculateHeartRateDipScore(averageHeartRate: avgHR, dailyRestingHeartRate: rhr)
        } else {
            hrDipScore = 75.0 // Higher neutral score when heart rate data is missing
        }
        
        // Calculate weighted average
        let restorationScore = (deepScore * 0.40) + (remScore * 0.40) + (hrDipScore * 0.20)
        
        print("🔍 RE-CALIBRATED Restoration Component Debug:")
        print("   Deep Sleep: \(deepSleepPercentage * 100)% -> \(deepScore)")
        print("   REM Sleep: \(remSleepPercentage * 100)% -> \(remScore)")
        print("   HR Dip: \(hrDipScore)")
        print("   Final Restoration Score: \(restorationScore)")
        
        return restorationScore
    }
    
    /// RE-CALIBRATED: Normalizes Deep Sleep percentage - MORE FORGIVING for values just below minimum
    private func normalizeDeepSleepPercentageRecalibrated(_ percentage: Double) -> Double {
        let idealMin = 0.13 // 13%
        let idealMax = 0.23 // 23%
        
        if percentage >= idealMin && percentage <= idealMax {
            return 100.0 // Perfect score for ideal range
        } else if percentage < idealMin {
            // MORE FORGIVING: Smoother curve for values below ideal
            // Give more credit for values close to the minimum (like 10-12%)
            if percentage >= 0.10 { // 10% or above gets significant credit
                let ratio = percentage / idealMin
                return 60 + (ratio * 40) // Maps 10% -> 91, 12% -> 97
            } else {
                // Still penalize very low values
                let ratio = percentage / 0.10
                return clamp(ratio * 60, min: 0, max: 60)
            }
        } else {
            // Above ideal: linear decrease from 100 to 0
            let excess = percentage - idealMax
            let maxExcess = 0.30 - idealMax // Allow up to 30% before zero score
            let ratio = 1.0 - (excess / maxExcess)
            return clamp(ratio * 100, min: 0, max: 100)
        }
    }
    
    /// Normalizes REM Sleep percentage against ideal 20-25% range
    private func normalizeREMSleepPercentage(_ percentage: Double) -> Double {
        let idealMin = 0.20 // 20%
        let idealMax = 0.25 // 25%
        
        if percentage >= idealMin && percentage <= idealMax {
            return 100.0 // Perfect score for ideal range
        } else if percentage < idealMin {
            // Below ideal: linear decrease from 100 to 0
            let ratio = percentage / idealMin
            return clamp(ratio * 100, min: 0, max: 100)
        } else {
            // Above ideal: linear decrease from 100 to 0
            let excess = percentage - idealMax
            let maxExcess = 0.35 - idealMax // Allow up to 35% before zero score
            let ratio = 1.0 - (excess / maxExcess)
            return clamp(ratio * 100, min: 0, max: 100)
        }
    }
    
    /// Calculates Heart Rate Dip Score
    /// Formula: 1 - (Average_Sleeping_HR / Daily_RHR)
    private func calculateHeartRateDipScore(averageHeartRate: Double, dailyRestingHeartRate: Double) -> Double {
        guard dailyRestingHeartRate > 0 else { return 75.0 } // Higher neutral score if no RHR data
        
        let hrDip = 1.0 - (averageHeartRate / dailyRestingHeartRate)
        
        // Normalize the dip to a 0-100 score
        // A dip of 0.15 (15%) or more is excellent
        // A dip of 0.05 (5%) or less is poor
        if hrDip >= 0.15 {
            return 100.0 // Excellent dip
        } else if hrDip >= 0.10 {
            return 80.0 + (hrDip - 0.10) * 400.0 // Good dip
        } else if hrDip >= 0.05 {
            return 60.0 + (hrDip - 0.05) * 400.0 // Fair dip
        } else if hrDip >= 0.0 {
            return 60.0 * (hrDip / 0.05) // Poor dip
        } else {
            return 0.0 // Negative dip (sleeping HR higher than RHR)
        }
    }
    
    /// Efficiency Component (30% Weight)
    /// Metric: Sleep_Efficiency = (Time_Asleep / Time_in_Bed)
    /// Scoring: Efficiency_Score = Sleep_Efficiency * 100
    private func calculateEfficiencyComponent(timeInBed: TimeInterval, timeAsleep: TimeInterval) -> Double {
        guard timeInBed > 0 else { return 0 }
        
        let sleepEfficiency = timeAsleep / timeInBed
        let efficiencyScore = sleepEfficiency * 100
        
        print("🔍 RE-CALIBRATED Efficiency Component Debug:")
        print("   Time in Bed: \(timeInBed / 3600) hours")
        print("   Time Asleep: \(timeAsleep / 3600) hours")
        print("   Sleep Efficiency: \(sleepEfficiency * 100)%")
        print("   Efficiency Score: \(efficiencyScore)")
        
        return efficiencyScore
    }
    
    /// Consistency Component (25% Weight)
    /// Metric: Compare last night's bedtime to the 14-day average bedtime
    /// Scoring: Consistency_Score = 100 * exp(-0.005 * totalDeviationInMinutes)
    private func calculateConsistencyComponent(
        bedtime: Date?,
        wakeTime: Date?,
        baselineBedtime: Date?,
        baselineWakeTime: Date?
    ) -> Double {
        guard let bedtime = bedtime, let baselineBedtime = baselineBedtime else {
            return 75.0 // Higher neutral score when baseline data is missing
        }
        
        // Calculate deviation in minutes
        let totalDeviationInMinutes = abs(bedtime.timeIntervalSince(baselineBedtime)) / 60.0
        
        // Apply the RE-CALIBRATED scoring formula
        let consistencyScore = 100 * Foundation.exp(-0.005 * totalDeviationInMinutes)
        
        print("🔍 RE-CALIBRATED Consistency Component Debug:")
        print("   Bedtime: \(bedtime)")
        print("   Baseline Bedtime: \(baselineBedtime)")
        print("   Total Deviation: \(totalDeviationInMinutes) minutes")
        print("   Consistency Score: \(consistencyScore)")
        
        return consistencyScore
    }
    
    // MARK: - Helper Functions
    
    /// Normalizes a percentage value against optimal ranges
    /// Returns a score between 0-100 based on how well the value fits the optimal range
    private func normalizeScore(_ percentage: Double, min: Double, max: Double) -> Double {
        let percentageValue = percentage * 100 // Convert to percentage
        
        if percentageValue >= min && percentageValue <= max {
            return 100.0 // Perfect score for ideal range
        } else if percentageValue < min {
            // Below ideal: linear decrease from 100 to 0
            let ratio = percentageValue / min
            return clamp(ratio * 100, min: 0, max: 100)
        } else {
            // Above ideal: linear decrease from 100 to 0
            let excess = percentageValue - max
            let maxExcess = (max + 10) - max // Allow up to 10% above max before zero score
            let ratio = 1.0 - (excess / maxExcess)
            return clamp(ratio * 100, min: 0, max: 100)
        }
    }
    
    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        return Swift.max(min, Swift.min(value, max))
    }
    
    private func normalize(value: Double, min: Double, max: Double) -> Double {
        if value >= min && value <= max {
            return 100 // Perfect score within optimal range
        } else if value < min {
            // Penalize values below minimum, but less harshly
            let deviation = min - value
            return Swift.max(0, 100 - (deviation * 5)) // Reduced penalty from 10 to 5
        } else {
            // Penalize values above maximum, but less harshly
            let deviation = value - max
            return Swift.max(0, 100 - (deviation * 5)) // Reduced penalty from 10 to 5
        }
    }
    
    private func calculateHeartRateDip(heartRate: Double?, rhr: Double?) -> Double? {
        guard let heartRate = heartRate, let rhr = rhr, rhr > 0 else { return nil }
        return 1 - (heartRate / rhr)
    }
    
    private func calculateEnhancedHRVScore(enhancedHRV: EnhancedHRVData?) -> Double {
        guard let enhanced = enhancedHRV, enhanced.hasBeatToBeatData else {
            return 75 // Neutral score if no enhanced data
        }
        
        // Calculate sleep-specific HRV score
        let baseScore = enhanced.calculatedMetrics.recoveryScore
        let autonomicBonus = enhanced.calculatedMetrics.autonomicBalanceScore * 0.3
        let stressPenalty = enhanced.stressLevel * 0.2
        
        let finalScore = baseScore + autonomicBonus - stressPenalty
        
        print("🔍 Enhanced HRV Sleep Score:")
        print("   Base Score: \(baseScore)")
        print("   Autonomic Bonus: \(autonomicBonus)")
        print("   Stress Penalty: \(stressPenalty)")
        print("   Final Enhanced Score: \(finalScore)")
        
        return max(0, min(100, finalScore))
    }
    
    private func generateKeyFindings(
        restorationComponent: Double,
        efficiencyComponent: Double,
        consistencyComponent: Double,
        details: SleepScoreDetails
    ) -> [String] {
        var findings: [String] = []
        
        // Restoration findings
        let restorationScore = restorationComponent * 100
        if restorationScore >= 80 {
            findings.append("Excellent restorative sleep quality (\(Int(restorationScore))%)")
        } else if restorationScore >= 60 {
            findings.append("Good restorative sleep quality (\(Int(restorationScore))%)")
        } else {
            findings.append("Restorative sleep quality could improve (\(Int(restorationScore))%)")
        }
        
        // Efficiency findings
        let efficiency = details.sleepEfficiency * 100
        if efficiency >= 90 {
            findings.append("Excellent sleep efficiency (\(Int(efficiency))%)")
        } else if efficiency >= 80 {
            findings.append("Good sleep efficiency (\(Int(efficiency))%)")
        } else {
            findings.append("Sleep efficiency could improve (\(Int(efficiency))%)")
        }
        
        // Duration findings
        let hoursAsleep = details.timeAsleep / 3600
        let hoursAsleepStr = "\(Double(round(10 * hoursAsleep) / 10))"
        if hoursAsleep >= 7.5 && hoursAsleep <= 8.5 {
            findings.append("Optimal sleep duration (\(hoursAsleepStr) hours)")
        } else if hoursAsleep < 7 {
            findings.append("Sleep duration below recommended (\(hoursAsleepStr) hours)")
        } else {
            findings.append("Sleep duration above recommended (\(hoursAsleepStr) hours)")
        }
        
        // Deep sleep findings
        let deepPercentage = details.deepSleepPercentage * 100
        let deepPercentageStr = "\(Double(round(10 * deepPercentage) / 10))"
        if deepPercentage >= 13 && deepPercentage <= 23 {
            findings.append("Deep sleep within optimal range (\(deepPercentageStr)%)")
        } else if deepPercentage < 13 {
            findings.append("Deep sleep below optimal (\(deepPercentageStr)%)")
        } else {
            findings.append("Deep sleep above optimal (\(deepPercentageStr)%)")
        }
        
        // REM sleep findings
        let remPercentage = details.remSleepPercentage * 100
        let remPercentageStr = "\(Double(round(10 * remPercentage) / 10))"
        if remPercentage >= 20 && remPercentage <= 25 {
            findings.append("REM sleep within optimal range (\(remPercentageStr)%)")
        } else if remPercentage < 20 {
            findings.append("REM sleep below optimal (\(remPercentageStr)%)")
        } else {
            findings.append("REM sleep above optimal (\(remPercentageStr)%)")
        }
        
        // Heart rate dip findings
        if let hrDip = details.heartRateDipPercentage {
            let dipPercent = hrDip * 100
            let dipPercentStr = "\(Double(round(10 * dipPercent) / 10))"
            if dipPercent >= 10 {
                findings.append("Strong heart rate recovery during sleep (\(dipPercentStr)% dip)")
            } else if dipPercent >= 5 {
                findings.append("Moderate heart rate recovery during sleep (\(dipPercentStr)% dip)")
            } else {
                findings.append("Limited heart rate recovery during sleep (\(dipPercentStr)% dip)")
            }
        }
        
        // Consistency findings
        let consistencyScore = consistencyComponent * 100
        if consistencyScore >= 80 {
            findings.append("Consistent sleep schedule maintained")
        } else if consistencyScore >= 60 {
            findings.append("Minor deviation from usual sleep schedule")
        } else {
            findings.append("Significant deviation from usual sleep schedule")
        }
        
        return findings
    }
    
    // MARK: - Sleep Session Helper
    
    private struct SleepSession {
        let startTime: Date
        let endTime: Date
        let samples: [HKCategorySample]
        let totalDuration: TimeInterval
        let timeAsleep: TimeInterval
    }
    
    private static func groupSleepSamplesIntoSessions(_ samples: [HKCategorySample]) -> [SleepSession] {
        guard !samples.isEmpty else { return [] }
        
        // Filter out "In Bed" samples that span too long (more than 12 hours)
        let filteredSamples = samples.filter { sample in
            let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            if value == .inBed {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                return duration <= 12 * 3600 // Max 12 hours for "In Bed"
            }
            return true
        }
        
        // Sort samples by start time
        let sortedSamples = filteredSamples.sorted { $0.startDate < $1.startDate }
        
        var sessions: [SleepSession] = []
        var currentSessionSamples: [HKCategorySample] = []
        var sessionStart: Date?
        
        for sample in sortedSamples {
            let isSleepSample = SleepScoreCalculator.isSleepStage(sample)
            
            if isSleepSample {
                if sessionStart == nil {
                    sessionStart = sample.startDate
                }
                currentSessionSamples.append(sample)
            } else {
                // If we have a gap longer than 30 minutes, start a new session
                if let lastSample = currentSessionSamples.last,
                   sample.startDate.timeIntervalSince(lastSample.endDate) > 30 * 60 {
                    // End current session
                    if let start = sessionStart, !currentSessionSamples.isEmpty {
                        let session = SleepScoreCalculator.createSleepSession(from: currentSessionSamples, startTime: start)
                        sessions.append(session)
                    }
                    
                    // Start new session
                    sessionStart = sample.startDate
                    currentSessionSamples = [sample]
                } else {
                    currentSessionSamples.append(sample)
                }
            }
        }
        
        // Add the last session
        if let start = sessionStart, !currentSessionSamples.isEmpty {
            let session = SleepScoreCalculator.createSleepSession(from: currentSessionSamples, startTime: start)
            sessions.append(session)
        }
        
        return sessions
    }
    
    private static func isSleepStage(_ sample: HKCategorySample) -> Bool {
        let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
        return value == .asleepUnspecified || value == .asleepDeep || value == .asleepREM || value == .asleepCore || value == .inBed
    }
    
    private static func createSleepSession(from samples: [HKCategorySample], startTime: Date) -> SleepSession {
        let endTime = samples.max(by: { $0.endDate < $1.endDate })?.endDate ?? startTime
        let totalDuration = endTime.timeIntervalSince(startTime)
        
        let timeAsleep = samples.filter { sample in
            let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            return value == .asleepUnspecified || value == .asleepDeep || value == .asleepREM || value == .asleepCore
        }.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        
        return SleepSession(
            startTime: startTime,
            endTime: endTime,
            samples: samples,
            totalDuration: totalDuration,
            timeAsleep: timeAsleep
        )
    }
}

// MARK: - Errors
enum SleepScoreError: Error, LocalizedError {
    case healthKitNotAvailable
    case noSleepData
    case insufficientData
    case noHeartRateData
    
    var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device"
        case .noSleepData:
            return "No sleep data available for the specified date"
        case .insufficientData:
            return "Insufficient data to calculate sleep score"
        case .noHeartRateData:
            return "No heart rate data available for sleep analysis"
        }
    }
} 