import Foundation
import HealthKit

// MARK: - Sleep Component Structure
struct SleepComponent {
    let score: Double
    let weight: Double
    let contribution: Double
    let description: String
}

// MARK: - Sleep Score Result Structure
struct SleepScoreResult {
    let finalScore: Int
    let keyFindings: [String]
    let efficiencyComponent: Double
    let qualityComponent: Double
    let timingComponent: Double
    let details: SleepScoreDetails
    
    // New: Detailed component breakdowns
    let durationComponent: SleepComponent
    let deepSleepComponent: SleepComponent
    let remSleepComponent: SleepComponent
    let consistencyComponent: SleepComponent
    let efficiencyComponentDescription: String?
    let efficiencyComponentScore: Int? // Add this to store the actual efficiency points
    
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
        // print("🗑️ Sleep score cache cleared")
    }
    
    // MARK: - Main Sleep Score Calculation
    func calculateSleepScore(for date: Date) async throws -> SleepScoreResult {
        // Check cache first
        let calendar = Calendar.current
        let cacheKey = "\(calendar.component(.year, from: date))-\(calendar.component(.month, from: date))-\(calendar.component(.day, from: date))"
        
        if let cachedResult = sleepScoreCache[cacheKey] {
            // print("📋 Using cached sleep score for \(cacheKey)")
            return cachedResult
        }
        
        // Check HealthKit authorization first
        guard HealthKitManager.shared.checkAuthorizationStatus() else {
            // print("❌ HealthKit authorization not granted for sleep score calculation")
            throw SleepScoreError.healthKitNotAvailable
        }
        
        // Always use the date as the 'wake date' for sleep
        let sleepDate = date
        // Remove or comment out unused variables like 'cal'
        // print("🔍 Attempting to calculate sleep score for recovery...")
        // print("   Sleep Date (wake date): \(sleepDate)")
        // print("   Sleep Date components: year: \(cal.component(.year, from: sleepDate)) month: \(cal.component(.month, from: sleepDate)) day: \(cal.component(.day, from: sleepDate))")
        
        // Fetch all required data - use try-catch for individual components
        let sleepData: (timeInBed: TimeInterval, timeAsleep: TimeInterval, deepSleepDuration: TimeInterval, remSleepDuration: TimeInterval, bedtime: Date?, wakeTime: Date?)
        let heartRateData: Double?
        let restingHeartRate: Double?
        let baselineData: (bedtime: Date?, wakeTime: Date?)
        
        do {
            sleepData = try await fetchDetailedSleepData(for: sleepDate)
        } catch {
            // print("❌ Failed to fetch sleep data: \(error)")
            throw error
        }
        
        do {
            heartRateData = try await fetchHeartRateData(for: sleepDate)
        } catch {
            // print("⚠️ Failed to fetch heart rate data, using fallback: \(error)")
            heartRateData = nil
        }
        
        do {
            restingHeartRate = try await fetchRestingHeartRate(for: sleepDate)
        } catch {
            // print("⚠️ Failed to fetch RHR data, using fallback: \(error)")
            restingHeartRate = nil
        }
        
        do {
            baselineData = try await fetchBaselineData()
        } catch {
            // print("⚠️ Failed to fetch baseline data, using fallback: \(error)")
            baselineData = (nil, nil)
        }
        

        
        // Validate sleep data
        guard sleepData.timeInBed > 0, sleepData.timeAsleep > 0 else {
            // print("⚠️ Invalid sleep data - time in bed: \(sleepData.timeInBed), time asleep: \(sleepData.timeAsleep)")
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
        
        // print("💓 Heart Rate Data:")
        // print("   Average HR: \(heartRateData ?? 0) (using \(adjustedHeartRate ?? 0))")
        // print("   RHR: \(restingHeartRate ?? 0) (using \(effectiveRHR ?? 0))")
        // print("🌙 Sleep Data Validation:")
        // print("   Time in Bed: \(sleepData.timeInBed / 3600) hours")
        // print("   Time Asleep: \(sleepData.timeAsleep / 3600) hours")
        // print("   Sleep Efficiency: \((sleepData.timeAsleep / sleepData.timeInBed) * 100)%")
        
        // Calculate components using the NEW RE-CALIBRATED algorithm
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
        
        // =============================
        // SLEEP SCORE V4.0 - CORRECTED SYSTEM
        // =============================
        
        // Calculate individual component scores using V3.0 point system
        let durationPoints = getDurationPoints(for: sleepData.timeAsleep)
        let deepSleepPoints = getDeepSleepPoints(for: sleepData.deepSleepDuration)
        let remSleepPoints = getREMPoints(for: sleepData.remSleepDuration)
        let efficiencyPoints = getEfficiencyPoints(timeAsleep: sleepData.timeAsleep, timeInBed: sleepData.timeInBed)
        let consistencyPoints = Int(consistencyComponent)
        
        // Calculate final score using V4.0 weights - convert to percentage scale for consistency
        let durationScorePercent = (Double(durationPoints) / 30.0) * 100
        let deepSleepScorePercent = (Double(deepSleepPoints) / 25.0) * 100
        let remSleepScorePercent = (Double(remSleepPoints) / 20.0) * 100
        let efficiencyScorePercent = (Double(efficiencyPoints) / 15.0) * 100
        let consistencyScorePercent = (Double(consistencyPoints) / 10.0) * 100
        
        let finalScore = Int(round(
            (durationScorePercent * 0.30) +      // 30% weight
            (deepSleepScorePercent * 0.25) +     // 25% weight
            (remSleepScorePercent * 0.20) +      // 20% weight
            (efficiencyScorePercent * 0.15) +    // 15% weight
            (consistencyScorePercent * 0.10)     // 10% weight
        ))

        // =============================
        // Debug: Print V4.0 Sleep Score breakdown
        // print("🌙 Sleep Score V4.0 Debug:")
        // print("   Duration: \(durationPoints)/30 (30% weight)")
        // print("   Deep Sleep: \(deepSleepPoints)/25 (25% weight)")
        // print("   REM Sleep: \(remSleepPoints)/20 (20% weight)")
        // print("   Efficiency: \(efficiencyPoints)/15 (15% weight)")
        // print("   Consistency: \(consistencyPoints)/10 (10% weight)")
        // print("   Final Score: \(finalScore)/100")
        // print("   Time in Bed: \(sleepData.timeInBed / 3600) hours")
        // print("   Time Asleep: \(sleepData.timeAsleep / 3600) hours")
        // print("   Deep Sleep: \(sleepData.deepSleepDuration / 3600) hours")
        // print("   REM Sleep: \(sleepData.remSleepDuration / 3600) hours")
        // print("   Heart Rate: \(adjustedHeartRate ?? 0)")
        // print("   RHR: \(effectiveRHR ?? 0)")
        // print("   Baseline Bedtime: \(baselineData.bedtime?.description ?? "nil")")
        // print("   Baseline Wake: \(baselineData.wakeTime?.description ?? "nil")")
        

        
        // Generate key findings
        let keyFindings = generateKeyFindings(
            durationPoints: durationPoints,
            deepSleepPoints: deepSleepPoints,
            remSleepPoints: remSleepPoints,
            efficiencyPoints: efficiencyPoints,
            consistencyPoints: consistencyPoints,
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
        
        // Generate detailed component descriptions
        let durationComponent = generateDurationComponentDescription(
            timeAsleep: sleepData.timeAsleep,
            durationScore: durationPoints
        )
        
        let deepSleepComponent = generateDeepSleepComponentDescription(
            deepSleepDuration: sleepData.deepSleepDuration,
            timeAsleep: sleepData.timeAsleep,
            deepSleepPoints: deepSleepPoints
        )
        
        let remSleepComponent = generateREMComponentDescription(
            remSleepDuration: sleepData.remSleepDuration,
            timeAsleep: sleepData.timeAsleep,
            remScore: Double(remSleepPoints)
        )
        
        let consistencyComponentDesc = generateConsistencyComponentDescription(
            bedtime: sleepData.bedtime,
            wakeTime: sleepData.wakeTime,
            baselineBedtime: baselineData.bedtime,
            baselineWakeTime: baselineData.wakeTime,
            consistencyScore: consistencyComponent
        )
        
        let efficiencyComponentDesc = generateEfficiencyComponentDescription(
            efficiencyPoints: efficiencyPoints,
            sleepEfficiency: sleepData.timeAsleep / sleepData.timeInBed
        )
        let result = SleepScoreResult(
            finalScore: finalScore,
            keyFindings: keyFindings,
            efficiencyComponent: efficiencyComponent,
            qualityComponent: 0.0, // No longer used
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
            ),
            durationComponent: durationComponent,
            deepSleepComponent: deepSleepComponent,
            remSleepComponent: remSleepComponent,
            consistencyComponent: consistencyComponentDesc,
            efficiencyComponentDescription: efficiencyComponentDesc.description,
            efficiencyComponentScore: getEfficiencyPoints(timeAsleep: sleepData.timeAsleep, timeInBed: sleepData.timeInBed)
        )
        
        // Cache the result
        sleepScoreCache[cacheKey] = result
        // print("📋 Cached sleep score for \(cacheKey)")
        
        return result
    }
    
    // MARK: - Data Fetching
    private func fetchDetailedSleepData(for date: Date) async throws -> (timeInBed: TimeInterval, timeAsleep: TimeInterval, deepSleepDuration: TimeInterval, remSleepDuration: TimeInterval, bedtime: Date?, wakeTime: Date?) {
        let calendar = Calendar.current
        // Fetch sleep samples that end between previous day noon and this day noon
        let startOfWindow = calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: date)!))!
        let endOfWindow = calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: date))!
        
        // print("🌙 Fetching sleep data for wake date: \(date)")
        // print("   Start of window: \(startOfWindow)")
        // print("   End of window: \(endOfWindow)")
        
        // Check authorization status for sleep data specifically
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw SleepScoreError.healthKitNotAvailable
        }
        
        let sleepAuthStatus = healthStore.authorizationStatus(for: sleepType)
        // print("🔍 Sleep Authorization Status: \(sleepAuthStatus.rawValue) (\(sleepAuthStatus))")
        
        guard sleepAuthStatus.rawValue == 1 else {
            // print("❌ Sleep data authorization not granted: \(sleepAuthStatus) (raw value: \(sleepAuthStatus.rawValue))")
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
                // print("🌙 Sleep samples found: \(sleepSamples.count)")
                
                guard !sleepSamples.isEmpty else {
                    // print("❌ No sleep samples found for wake date: \(date)")
                    continuation.resume(throwing: SleepScoreError.noSleepData)
                    return
                }
                
                // Group sleep samples by session (continuous periods)
                let sleepSessions = SleepScoreCalculator.groupSleepSamplesIntoSessions(sleepSamples)
                // print("🌙 Found \(sleepSessions.count) sleep sessions")
                
                // Find the main sleep session (longest one)
                let mainSession = sleepSessions.max(by: { $0.totalDuration < $1.totalDuration }) ?? sleepSessions.first
                
                guard let session = mainSession else {
                    // print("❌ No valid sleep session found")
                    continuation.resume(throwing: SleepScoreError.noSleepData)
                    return
                }
                
                // print("🌙 Main sleep session:")
                // print("   Start: \(session.startTime)")
                // print("   End: \(session.endTime)")
                // print("   Duration: \(session.totalDuration / 3600) hours")
                // print("   Time Asleep: \(session.timeAsleep / 3600) hours")
                
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
        // print("🔍 Heart Rate Authorization Status: \(hrAuthStatus.rawValue) (\(hrAuthStatus))")
        
        guard hrAuthStatus.rawValue == 1 else {
            // print("❌ Heart rate data authorization not granted: \(hrAuthStatus) (raw value: \(hrAuthStatus.rawValue))")
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
                
                // print("💓 Heart Rate Analysis:")
                // print("   Total samples: \(heartRateSamples.count)")
                // print("   Sleep samples: \(sleepHeartRateSamples.count)")
                // print("   Average HR: \(average ?? 0)")
                
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
        // print("🔍 RHR Authorization Status: \(rhrAuthStatus.rawValue) (\(rhrAuthStatus))")
        
        guard rhrAuthStatus.rawValue == 1 else {
            // print("❌ RHR data authorization not granted: \(rhrAuthStatus) (raw value: \(rhrAuthStatus.rawValue))")
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
        
        // print("🔄 Baseline Data Debug:")
        // print("   Baseline Bedtime: \(baselineEngine.bedtime14?.description ?? "nil")")
        // print("   Baseline Wake: \(baselineEngine.wake14?.description ?? "nil")")
        // print("   Calibrating: \(baselineEngine.calibrating)")
        
        // If baseline data is missing, try to calculate it from recent data
        if baselineEngine.bedtime14 == nil || baselineEngine.wake14 == nil {
            // print("⚠️ Missing baseline data, calculating from recent sleep data...")
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
        // print("🔍 Baseline Sleep Authorization Status: \(sleepAuthStatus.rawValue) (\(sleepAuthStatus))")
        
        guard sleepAuthStatus.rawValue == 1 else {
            // print("❌ Sleep data authorization not granted for baseline calculation: \(sleepAuthStatus) (raw value: \(sleepAuthStatus.rawValue))")
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
                
                // print("📊 Fallback Baseline Calculated:")
                // print("   Average Bedtime: \(avgBedtime?.description ?? "nil")")
                // print("   Average Wake Time: \(avgWakeTime?.description ?? "nil")")
                // print("   Data Points: \(bedtimes.count)")
                
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
    


    

    
    /// Efficiency Component (30% Weight)
    /// Metric: Sleep_Efficiency = (Time_Asleep / Time_in_Bed)
    /// Scoring: Efficiency_Score = Sleep_Efficiency * 100
    private func calculateEfficiencyComponent(timeInBed: TimeInterval, timeAsleep: TimeInterval) -> Double {
        guard timeInBed > 0 else { return 0 }
        
        let sleepEfficiency = timeAsleep / timeInBed
        let efficiencyScore = sleepEfficiency * 100
        
        // print("🔍 RE-CALIBRATED Efficiency Component Debug:")
        // print("   Time in Bed: \(timeInBed / 3600) hours")
        // print("   Time Asleep: \(timeAsleep / 3600) hours")
        // print("   Sleep Efficiency: \(sleepEfficiency * 100)%")
        // print("   Efficiency Score: \(efficiencyScore)")
        
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
        guard let bedtime = bedtime else { return 0 }
        
        // Get reasonable target bedtime
        let targetBedtime = getReasonableTargetBedtime(baselineBedtime: baselineBedtime, actualBedtime: bedtime)
        
        // Calculate deviation in minutes
        let calendar = Calendar.current
        let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: bedtime)
        let targetComponents = calendar.dateComponents([.hour, .minute], from: targetBedtime)
        
        let actualMinutes = (bedtimeComponents.hour ?? 0) * 60 + (bedtimeComponents.minute ?? 0)
        let targetMinutes = (targetComponents.hour ?? 0) * 60 + (targetComponents.minute ?? 0)
        
        // Calculate deviation - one-sided window: perfect score until target, then linear penalty
        let deviationInMinutes: Double
        if actualMinutes >= targetMinutes {
            // Actual time is later than target - apply penalty
            deviationInMinutes = Double(actualMinutes - targetMinutes)
        } else {
            // Actual time is earlier than target
            let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: bedtime)
            let hour = bedtimeComponents.hour ?? 0
            
            if hour < 12 {
                // After midnight (0-11 AM) - this is very late
                deviationInMinutes = Double((24 * 60 - targetMinutes) + actualMinutes)
            } else {
                // Before midnight but earlier than target - perfect score
                deviationInMinutes = 0.0
            }
        }
        
        // New scoring system: one-sided window with linear penalty
        // Perfect score (10 points): Any time before or at target (11:45 PM)
        // Linear penalty: -1 point per 10 minutes after target
        
        if deviationInMinutes == 0 {
            // Before or at target - perfect score
            return 10.0
        } else {
            // After target - apply linear penalty
            let penaltyPoints = deviationInMinutes / 10.0
            let score = max(0, 10.0 - penaltyPoints)
            return score
        }
    }
    
    // MARK: - Sleep Score V4.0 Helpers

    private func getDurationPoints(for timeAsleepInSeconds: Double) -> Int {
        let minutes = timeAsleepInSeconds / 60
        switch minutes {
        case let m where m > 480: return 30
        case 470...480: return 29
        case 460..<470: return 28
        case 450..<460: return 27
        case 440..<450: return 26
        case 430..<440: return 25
        case 420..<430: return 25
        case 410..<420: return 24
        case 400..<410: return 22
        case 390..<400: return 20
        case 380..<390: return 18
        case 370..<380: return 16
        case 360..<370: return 15
        case 330..<360: return 10
        case 300..<330: return 5
        default: return 0
        }
    }

    private func getDeepSleepPoints(for deepSleepInSeconds: Double) -> Int {
        let minutes = deepSleepInSeconds / 60
        switch minutes {
        case let m where m >= 105: return 25
        case 90..<105: return 22
        case 75..<90: return 18
        case 60..<75: return 14
        case 45..<60: return 8
        default: return 0
        }
    }

    private func getREMPoints(for remSleepInSeconds: Double) -> Int {
        let minutes = remSleepInSeconds / 60
        switch minutes {
        case let m where m >= 120: return 20  // 2h+ (bonus, now capped at 20)
        case 105..<120: return 18             // 1h 45m - 2h
        case 90..<105: return 16              // 1h 30m - 1h 45m
        case 75..<90: return 13               // 1h 15m - 1h 30m
        case 60..<75: return 10               // 1h - 1h 15m
        case 0..<60: return Int((minutes / 60.0) * 5.0)  // Proportional, up to 5
        default: return 0
        }
    }

    private func getEfficiencyPoints(timeAsleep: Double, timeInBed: Double) -> Int {
        guard timeInBed > 0 else { return 0 }
        let efficiency = (timeAsleep / timeInBed) * 100
        switch efficiency {
        case let e where e >= 95: return 15
        case 92.5..<95: return 12
        case 90..<92.5: return 10
        case 85..<90: return 5
        default: return 0
        }
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
        
        // print("🔍 Enhanced HRV Sleep Score:")
        // print("   Base Score: \(baseScore)")
        // print("   Autonomic Bonus: \(autonomicBonus)")
        // print("   Stress Penalty: \(stressPenalty)")
        // print("   Final Enhanced Score: \(finalScore)")
        
        return max(0, min(100, finalScore))
    }
    
    private func generateKeyFindings(
        durationPoints: Int,
        deepSleepPoints: Int,
        remSleepPoints: Int,
        efficiencyPoints: Int,
        consistencyPoints: Int,
        details: SleepScoreDetails
    ) -> [String] {
        var findings: [String] = []
        
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
        let remMinutes = details.remSleepDuration / 60
        let remPercentage = details.remSleepPercentage * 100
        let remPercentageStr = "\(Double(round(10 * remPercentage) / 10))"
        if remMinutes >= 120 {
            findings.append("Excellent REM sleep duration (\(Int(remMinutes)) min)")
        } else if remPercentage >= 20 && remPercentage <= 25 {
            findings.append("REM sleep within optimal range (\(remPercentageStr)%)")
        } else if remPercentage < 20 {
            findings.append("REM sleep below optimal (\(remPercentageStr)%)")
        } else {
            findings.append("REM sleep above optimal (\(remPercentageStr)%)")
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
        

        
        // Consistency findings
        let consistencyScore = consistencyPoints
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

    // MARK: - Component Description Generators

    private func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        return "\(hours)h \(minutes)m"
    }

    private func generateDurationComponentDescription(timeAsleep: TimeInterval, durationScore: Int) -> SleepComponent {
        let hoursAsleep = timeAsleep / 3600
        let timeAsleepStr = formatTimeInterval(timeAsleep)
        
        let description: String
        if hoursAsleep >= 7.5 && hoursAsleep <= 8.5 {
            description = "Sleep Duration: \(timeAsleepStr) (optimal range 7h 30m - 8h 30m). Score: \(durationScore)/30 (30% of total). V4.0 scoring system."
        } else if hoursAsleep >= 6.0 && hoursAsleep < 7.5 {
            description = "Sleep Duration: \(timeAsleepStr) (below optimal range 7h 30m - 8h 30m). Score: \(durationScore)/30 (30% of total). V4.0 scoring system."
        } else if hoursAsleep < 6.0 {
            description = "Sleep Duration: \(timeAsleepStr) (significantly below recommended minimum). Score: \(durationScore)/30 (30% of total). V4.0 scoring system."
        } else {
            description = "Sleep Duration: \(timeAsleepStr) (above optimal range 7h 30m - 8h 30m). Score: \(durationScore)/30 (30% of total). V4.0 scoring system."
        }
        
        return SleepComponent(score: Double(durationScore), weight: 30, contribution: Double(durationScore) * 0.3, description: description)
    }

    private func generateDeepSleepComponentDescription(
        deepSleepDuration: TimeInterval,
        timeAsleep: TimeInterval,
        deepSleepPoints: Int
    ) -> SleepComponent {
        let deepTimeStr = formatTimeInterval(deepSleepDuration)
        let deepPercentage = deepSleepDuration / timeAsleep
        
        let description: String
        let deepMinutes = deepSleepDuration / 60
        if deepMinutes >= 105 {
            description = "Deep Sleep: \(deepTimeStr) (excellent). Score: \(deepSleepPoints)/25 (25% of total). V4.0 scoring system."
        } else if deepPercentage >= 0.13 && deepPercentage <= 0.23 {
            description = "Deep Sleep: \(deepTimeStr) (optimal range 13-23%). Score: \(deepSleepPoints)/25 (25% of total). V4.0 scoring system."
        } else if deepPercentage < 0.13 {
            description = "Deep Sleep: \(deepTimeStr) (below optimal range 13-23%). Score: \(deepSleepPoints)/25 (25% of total). V4.0 scoring system."
        } else {
            description = "Deep Sleep: \(deepTimeStr) (above optimal range 13-23%). Score: \(deepSleepPoints)/25 (25% of total). V4.0 scoring system."
        }
        return SleepComponent(score: Double(deepSleepPoints), weight: 25, contribution: Double(deepSleepPoints) * 0.25, description: description)
    }

    private func generateConsistencyComponentDescription(
        bedtime: Date?,
        wakeTime: Date?,
        baselineBedtime: Date?,
        baselineWakeTime: Date?,
        consistencyScore: Double
    ) -> SleepComponent {
        guard let bedtime = bedtime else {
            return SleepComponent(score: consistencyScore, weight: 10, contribution: consistencyScore * 0.10, description: "Sleep Consistency: \(Int(consistencyScore))/10 (10% of total, bedtime data unavailable).")
        }
        
        // Get a more reasonable baseline using 7-day average with validation
        let reasonableTargetBedtime = getReasonableTargetBedtime(baselineBedtime: baselineBedtime, actualBedtime: bedtime)
        
        // Fix the bedtime deviation calculation by comparing only the time components
        let calendar = Calendar.current
        let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: bedtime)
        let targetComponents = calendar.dateComponents([.hour, .minute], from: reasonableTargetBedtime)
        
        // Convert to minutes since midnight for easier comparison
        let actualMinutes = (bedtimeComponents.hour ?? 0) * 60 + (bedtimeComponents.minute ?? 0)
        let targetMinutes = (targetComponents.hour ?? 0) * 60 + (targetComponents.minute ?? 0)
        
        // Calculate deviation, handling midnight wrap-around
        let deviationInMinutes: Double
        let timingDirection: String
        
        if actualMinutes >= targetMinutes {
            // Actual time is later than target (or same)
            deviationInMinutes = Double(actualMinutes - targetMinutes)
            timingDirection = "later"
        } else {
            // Actual time is earlier than target (crossed midnight)
            // For example: target 23:45 (1415 min) vs actual 00:29 (29 min)
            // Deviation = (1440 - 1415) + 29 = 25 + 29 = 54 minutes later
            deviationInMinutes = Double((24 * 60 - targetMinutes) + actualMinutes)
            timingDirection = "later"
        }
        
        let consistencyScoreInt = Int(consistencyScore)
        
        // Format actual and target bedtimes
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let actualBedtimeStr = timeFormatter.string(from: bedtime)
        let targetBedtimeStr = timeFormatter.string(from: reasonableTargetBedtime)
        
        // Determine if early or late
        // let timingDirection = actualTime > targetTime ? "later" : "earlier" // This line is no longer needed
        
        // Determine if using baseline or default
        let sourceDescription: String
        if let sevenDayBaseline = DynamicBaselineEngine.shared.bedtime7, isReasonableBedtime(sevenDayBaseline) {
            sourceDescription = "7-day average"
        } else if let baseline = baselineBedtime, isReasonableBedtime(baseline) {
            sourceDescription = "recent average"
        } else {
            sourceDescription = "recommended range"
        }
        
        let description = "Sleep Consistency: \(consistencyScoreInt)/10 (10% of total). You went to bed at \(actualBedtimeStr), but your target bedtime is \(targetBedtimeStr) (\(sourceDescription)). You were \(String(format: "%.0f", deviationInMinutes)) minutes \(timingDirection) than optimal. Score: Perfect (10/10) if before or at target, then -1 point per 10 minutes after target. V4.0 scoring system."
        
        return SleepComponent(score: consistencyScore, weight: 10, contribution: consistencyScore * 0.10, description: description)
    }
    
    // Helper function to get a reasonable target bedtime
    private func getReasonableTargetBedtime(baselineBedtime: Date?, actualBedtime: Date) -> Date {
        // Use 7-day baseline from DynamicBaselineEngine if available and reasonable
        let sevenDayBaseline = DynamicBaselineEngine.shared.bedtime7
        
        if let baseline = sevenDayBaseline ?? baselineBedtime, isReasonableBedtime(baseline) {
            return baseline
        }
        
        // If baseline is unreasonable (like 1:37 AM), create a smart default
        let calendar = Calendar.current
        let actualComponents = calendar.dateComponents([.hour, .minute], from: actualBedtime)
        let actualHour = actualComponents.hour ?? 22
        
        // Smart default logic: If your actual bedtime is very late, suggest an earlier target
        let defaultHour: Int
        if actualHour >= 0 && actualHour <= 3 {
            // If you're going to bed between midnight and 3 AM, suggest 11:45 PM as target
            defaultHour = 23
        } else if actualHour >= 20 && actualHour <= 23 {
            // If you're going to bed between 8 PM and 11 PM, use that as target
            defaultHour = actualHour
        } else if actualHour >= 4 && actualHour <= 6 {
            // If you're going to bed between 4 AM and 6 AM, suggest 11:45 PM as target
            defaultHour = 23
        } else {
            // For any other unusual times, default to 11:45 PM
            defaultHour = 23
        }
        
        let today = calendar.startOfDay(for: actualBedtime)
        let targetDate = calendar.date(bySettingHour: defaultHour, minute: 45, second: 0, of: today) ?? actualBedtime
        return targetDate
    }
    
    // Helper function to validate if a bedtime is reasonable
    private func isReasonableBedtime(_ bedtime: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: bedtime)
        guard let hour = components.hour else { return false }
        
        // Consider reasonable bedtime between 8 PM and 11:59 PM (not after midnight)
        // This is more strict - we don't want to suggest going to bed after midnight as a target
        return hour >= 20 && hour <= 23
    }

    private func generateREMComponentDescription(remSleepDuration: TimeInterval, timeAsleep: TimeInterval, remScore: Double) -> SleepComponent {
        let remTimeStr = formatTimeInterval(remSleepDuration)
        let remPercentage = remSleepDuration / timeAsleep
        
        let description: String
        let remMinutes = remSleepDuration / 60
        if remMinutes >= 120 {
            description = "REM Sleep: \(remTimeStr) (excellent). Score: \(Int(remScore))/20 (20% of total). V4.0 scoring system."
        } else if remPercentage >= 0.20 && remPercentage <= 0.25 {
            description = "REM Sleep: \(remTimeStr) (optimal range 20-25%). Score: \(Int(remScore))/20 (20% of total). V4.0 scoring system."
        } else if remPercentage < 0.20 {
            description = "REM Sleep: \(remTimeStr) (below optimal range 20-25%). Score: \(Int(remScore))/20 (20% of total). V4.0 scoring system."
        } else {
            description = "REM Sleep: \(remTimeStr) (above optimal range 20-25%). Score: \(Int(remScore))/20 (20% of total). V4.0 scoring system."
        }
        return SleepComponent(score: remScore, weight: 20, contribution: remScore * 0.2, description: description)
    }

    private func generateEfficiencyComponentDescription(efficiencyPoints: Int, sleepEfficiency: Double) -> SleepComponent {
        // sleepEfficiency is already a percentage (0-1), so multiply by 100 for display
        let efficiency = sleepEfficiency * 100
        
        let description: String
        if efficiency >= 95 {
            description = "Sleep Efficiency: \(String(format: "%.1f", efficiency))% (excellent). Score: \(efficiencyPoints)/15 (15% of total). V4.0 scoring system."
        } else if efficiency >= 90 {
            description = "Sleep Efficiency: \(String(format: "%.1f", efficiency))% (good). Score: \(efficiencyPoints)/15 (15% of total). V4.0 scoring system."
        } else if efficiency >= 85 {
            description = "Sleep Efficiency: \(String(format: "%.1f", efficiency))% (fair). Score: \(efficiencyPoints)/15 (15% of total). V4.0 scoring system."
        } else {
            description = "Sleep Efficiency: \(String(format: "%.1f", efficiency))% (could improve). Score: \(efficiencyPoints)/15 (15% of total). V4.0 scoring system."
        }
        return SleepComponent(score: Double(efficiencyPoints), weight: 15, contribution: Double(efficiencyPoints) * 0.15, description: description)
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