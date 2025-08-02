import Foundation
import HealthKit

// MARK: - Global Helper Functions
func clamp(_ value: Double, min: Double, max: Double) -> Double {
    return Swift.max(min, Swift.min(max, value))
}

final class HealthKitManager {
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()
    
    // MARK: - Permissions
    let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage)!,
        HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        // Nutrition-specific read types
        HKObjectType.quantityType(forIdentifier: .height)!,
        HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
        HKObjectType.characteristicType(forIdentifier: .biologicalSex)!
    ]
    
    // Nutrition-specific write types
    let nutritionWriteTypes: Set<HKSampleType> = [
        HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
        HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
        HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
        HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!
    ]
    
    // Helper function to safely get HealthKit types
    private func safeQuantityType(_ identifier: HKQuantityTypeIdentifier) -> HKQuantityType? {
        return HKObjectType.quantityType(forIdentifier: identifier)
    }
    
    private func safeCategoryType(_ identifier: HKCategoryTypeIdentifier) -> HKCategoryType? {
        return HKObjectType.categoryType(forIdentifier: identifier)
    }
    
    private init() {}
    
    // MARK: - High-Frequency HRV Implementation
    
    /// Fetches all individual HRV SDNN samples for a specific date and returns their average
    /// This is the core implementation for elite-level HRV analysis
    func fetchHighFrequencyHRV(for date: Date, completion: @escaping (Double?) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            // print("❌ HRV SDNN type not available")
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
            if let _ = error {
                // print("❌ Error fetching HRV samples: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            let hrvSamples = (samples as? [HKQuantitySample]) ?? []
            // print("🔍 Fetched \(hrvSamples.count) individual HRV samples for \(date)")
            
            guard !hrvSamples.isEmpty else {
                // print("⚠️ No HRV samples found for \(date)")
                completion(nil)
                return
            }
            
            // Calculate the average of all individual HRV readings
            let hrvValues = hrvSamples.map { $0.quantity.doubleValue(for: HKUnit(from: "ms")) }
            let averageHRV = hrvValues.reduce(0, +) / Double(hrvValues.count)
            
            // print("📊 HRV Analysis for \(date):")
            // print("   Individual samples: \(hrvValues.count)")
            // print("   Values range: \(hrvValues.min() ?? 0) - \(hrvValues.max() ?? 0) ms")
            // print("   Average HRV: \(averageHRV) ms")
            
            completion(averageHRV)
        }
        
        healthStore.execute(query)
    }
    
    /// Implements HKHeartbeatSeriesQuery for future advanced beat-to-beat analysis
    /// This prepares the foundation for elite-level heart rate variability analysis
    func fetchBeatToBeatHeartRateSeries(for date: Date, completion: @escaping ([HKHeartbeatSeriesSample]?) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            // print("❌ Heart rate type not available")
            completion(nil)
            return
        }
        
        // Check if heartbeat series is available (iOS 13.0+)
        if #available(iOS 13.0, *) {
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
                if let _ = error {
                    // print("❌ Error fetching heartbeat series: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                let heartbeatSamples = (samples as? [HKHeartbeatSeriesSample]) ?? []
                // print("🔍 Fetched \(heartbeatSamples.count) heartbeat series samples for \(date)")
                
                if heartbeatSamples.isEmpty {
                    // print("⚠️ No heartbeat series data available, falling back to regular heart rate samples")
                    completion(nil)
                } else {
                    completion(heartbeatSamples)
                }
            }
            
            healthStore.execute(query)
        } else {
            // print("⚠️ Heartbeat series not available on this iOS version")
            completion(nil)
        }
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            // print("❌ HealthKit is not available on this device")
            completion(false)
            return
        }
        
        // Check current authorization status
        guard let sleepType = safeCategoryType(.sleepAnalysis) else {
            // print("❌ Sleep analysis type not available")
            completion(false)
            return
        }
        
        let status = healthStore.authorizationStatus(for: sleepType)
        // print("🔍 Current HealthKit authorization status: \(status.rawValue)")
        
        if status == .sharingAuthorized {
            // print("✅ HealthKit already authorized")
            completion(true)
            return
        }
        
        // print("🔐 Requesting HealthKit authorization...")
        // Allow writing body mass and nutrition data to Apple Health
        var shareTypes: Set<HKSampleType> = []
        if let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            shareTypes.insert(bodyMassType)
        }
        // Add nutrition write types
        shareTypes.formUnion(nutritionWriteTypes)

        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { success, error in
            if let _ = error {
                // print("❌ HealthKit authorization error: \(error.localizedDescription)")
            }
            // print("🔐 HealthKit authorization result: \(success)")
            completion(success)
        }
    }
    
    /// Forces a re-request of HealthKit authorization
    func forceReauthorization(completion: @escaping (Bool) -> Void) {
        // print("🔄 Force re-requesting HealthKit authorization...")
        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            if let _ = error {
                // print("❌ HealthKit re-authorization error: \(error.localizedDescription)")
            }
            // print("🔐 HealthKit re-authorization result: \(success)")
            completion(success)
        }
    }
    
    /// Fetches today's recovery and sleep scores for the Performance dashboard
    func fetchTodayScores(completion: @escaping (Int?, Int?, String?) -> Void) {
        fetchScores(for: Date(), completion: completion)
    }
    
    /// Fetches recovery and sleep scores for a specific date
    func fetchScores(for date: Date, completion: @escaping (Int?, Int?, String?) -> Void) {
        // Fetch recovery score
        Task {
            do {
                let recoveryScore = try await RecoveryScoreCalculator.shared.calculateRecoveryScore(for: date)
                let sleepScore = try await SleepScoreCalculator.shared.calculateSleepScore(for: date)
                
                DispatchQueue.main.async {
                    completion(recoveryScore.finalScore, sleepScore.finalScore, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, nil, error.localizedDescription)
                }
            }
        }
    }
    
    /// Checks if all required HealthKit permissions are granted
    func checkAuthorizationStatus() -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { 
            // print("❌ HealthKit is not available on this device")
            return false 
        }
        
        // Safely get the required types
        guard let sleepType = safeCategoryType(.sleepAnalysis),
              let hrvType = safeQuantityType(.heartRateVariabilitySDNN),
              let rhrType = safeQuantityType(.restingHeartRate) else {
            // print("❌ Required HealthKit types are not available")
            return false
        }
        
        let sleepStatus = healthStore.authorizationStatus(for: sleepType)
        let hrvStatus = healthStore.authorizationStatus(for: hrvType)
        let rhrStatus = healthStore.authorizationStatus(for: rhrType)
        
        // Check if all statuses are sharingAuthorized (raw value 1)
        let allAuthorized = sleepStatus.rawValue == 1 && 
                           hrvStatus.rawValue == 1 && 
                           rhrStatus.rawValue == 1
        
        // print("🔍 HealthKit Authorization Status:")
        // print("   Sleep Analysis: \(sleepStatus.rawValue) (\(sleepStatus))")
        // print("   HRV: \(hrvStatus.rawValue) (\(hrvStatus))")
        // print("   RHR: \(rhrStatus.rawValue) (\(rhrStatus))")
        // print("   All Authorized: \(allAuthorized)")
        
        // Additional debug info
        // print("🔍 Authorization Details:")
        // print("   Sleep Type Available: true")
        // print("   HRV Type Available: true")
        // print("   RHR Type Available: true")
        
        return allAuthorized
    }
    
    // MARK: - Enhanced Data Fetching for Recovery Score
    
    /// Fetches all required health data for a specific date
    func fetchData(for date: Date, completion: @escaping (DailyMetrics?) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        _ = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        let group = DispatchGroup()
        var hrv: Double?; var rhr: Double?; var respiratoryRate: Double?
        var walkingHR: Double?; var oxygenSaturation: Double?
        var sleep: (duration: TimeInterval, deep: TimeInterval, rem: TimeInterval, bedtime: Date, wake: Date)?
        
        // Fetch HRV (overnight average)
        group.enter()
        fetchHRV(for: date) { value in
            hrv = value
            group.leave()
        }
        
        // Fetch RHR
        group.enter()
        fetchRHR(for: date) { value in
            rhr = value
            group.leave()
        }
        
        // Fetch Respiratory Rate
        group.enter()
        fetchRespiratoryRate(for: date) { value in
            respiratoryRate = value
            group.leave()
        }
        
        // Fetch Walking Heart Rate (proxy for wrist temperature deviation)
        group.enter()
        fetchWalkingHeartRate(for: date) { value in
            walkingHR = value
            group.leave()
        }
        
        // Fetch Oxygen Saturation
        group.enter()
        fetchOxygenSaturation(for: date) { value in
            oxygenSaturation = value
            group.leave()
        }
        
        // Fetch Sleep Data
        group.enter()
        fetchSleep(for: date) { value in
            sleep = value
            group.leave()
        }
        
        group.notify(queue: .main) {
            let metrics = DailyMetrics(
                date: date,
                hrv: hrv,
                rhr: rhr,
                respiratoryRate: respiratoryRate,
                walkingHeartRate: walkingHR,
                oxygenSaturation: oxygenSaturation,
                sleepDuration: sleep?.duration,
                deepSleep: sleep?.deep,
                remSleep: sleep?.rem,
                bedtime: sleep?.bedtime,
                wakeTime: sleep?.wake
            )
            completion(metrics)
        }
    }
    
    /// Fetches respiratory rate for a specific date
    func fetchRespiratoryRate(for date: Date, completion: @escaping (Double?) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        guard let type = HKObjectType.quantityType(forIdentifier: .respiratoryRate) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let values = (samples as? [HKQuantitySample])?.map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) } ?? []
            let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
            completion(average)
        }
        healthStore.execute(query)
    }
    
    /// Fetches walking heart rate for a specific date (proxy for wrist temperature)
    func fetchWalkingHeartRate(for date: Date, completion: @escaping (Double?) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        guard let type = HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let values = (samples as? [HKQuantitySample])?.map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) } ?? []
            let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
            completion(average)
        }
        healthStore.execute(query)
    }
    
    /// Fetches oxygen saturation for a specific date
    func fetchOxygenSaturation(for date: Date, completion: @escaping (Double?) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        guard let type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let values = (samples as? [HKQuantitySample])?.map { $0.quantity.doubleValue(for: HKUnit.percent()) } ?? []
            let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
            completion(average)
        }
        healthStore.execute(query)
    }
    
    // MARK: - Background Refresh Support
    
    /// Triggers a background refresh of health data
    func performBackgroundRefresh(completion: @escaping () -> Void) {
        // print("🔄 Performing background health data refresh...")
        
        // Fetch today's data to ensure it's fresh
        fetchData(for: Date()) { _ in
            // print("✅ Background refresh completed")
            completion()
        }
    }
    
    // MARK: - Async Fetchers
    func fetchLatestHRV(completion: @escaping (Double?) -> Void) {
        fetchLatestQuantity(.heartRateVariabilitySDNN, unit: HKUnit(from: "ms"), completion: completion)
    }
    
    func fetchLatestRMSSD(completion: @escaping (Double?) -> Void) {
        // RMSSD is calculated from beat-to-beat data, not directly available from HealthKit
        completion(nil)
    }
    
    func fetchEnhancedHRV(for date: Date, completion: @escaping (EnhancedHRVData?) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        _ = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        let group = DispatchGroup()
        var sdnn: Double?; var heartRateSamples: [HKQuantitySample] = []
        
        // Fetch SDNN
        group.enter()
        fetchHRV(for: date) { value in
            sdnn = value
            group.leave()
        }
        
        // Fetch beat-to-beat heart rate data
        group.enter()
        fetchBeatToBeatHeartRate(for: date) { samples in
            heartRateSamples = samples
            group.leave()
        }
        
        group.notify(queue: .main) {
            guard let sdnn = sdnn else {
                completion(nil)
                return
            }
            
            // Calculate RMSSD and other metrics from beat-to-beat data
            let calculatedMetrics = self.calculateAdvancedHRVMetrics(from: heartRateSamples)
            
            let enhancedData = EnhancedHRVData(
                sdnn: sdnn,
                rmssd: calculatedMetrics.rmssd > 0 ? calculatedMetrics.rmssd : nil,
                heartRateSamples: heartRateSamples,
                calculatedMetrics: calculatedMetrics,
                hasBeatToBeatData: heartRateSamples.count >= 10,
                stressLevel: max(0, min(100, 100 - calculatedMetrics.rmssd))
            )
            
            completion(enhancedData)
        }
    }
    
    private func fetchRMSSD(for date: Date, completion: @escaping (Double?) -> Void) {
        // RMSSD is calculated from beat-to-beat data, not directly available from HealthKit
        completion(nil)
    }
    
    private func fetchBeatToBeatHeartRate(for date: Date, completion: @escaping ([HKQuantitySample]) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion([])
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, _ in
            let heartRateSamples = (samples as? [HKQuantitySample]) ?? []
            completion(heartRateSamples)
        }
        healthStore.execute(query)
    }
    
    private func calculateAdvancedHRVMetrics(from heartRateSamples: [HKQuantitySample]) -> AdvancedHRVMetrics {
        guard heartRateSamples.count >= 2 else {
            return AdvancedHRVMetrics(
                meanRR: 0,
                sdnn: 0,
                rmssd: 0,
                pnn50: 0,
                triangularIndex: 0,
                stressIndex: 0,
                autonomicBalance: 0,
                recoveryScore: 50,
                autonomicBalanceScore: 50
            )
        }
        
        // Convert heart rate to RR intervals (in milliseconds)
        let rrIntervals = heartRateSamples.enumerated().compactMap { index, sample -> Double? in
            guard index > 0 else { return nil }
            let currentHR = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            let previousHR = heartRateSamples[index - 1].quantity.doubleValue(for: HKUnit(from: "count/min"))
            
            // Calculate RR interval from heart rate: RR = 60000 / HR (ms)
            let currentRR = 60000 / currentHR
            let previousRR = 60000 / previousHR
            
            return abs(currentRR - previousRR)
        }
        
        guard !rrIntervals.isEmpty else {
            return AdvancedHRVMetrics(
                meanRR: 0,
                sdnn: 0,
                rmssd: 0,
                pnn50: 0,
                triangularIndex: 0,
                stressIndex: 0,
                autonomicBalance: 0,
                recoveryScore: 50,
                autonomicBalanceScore: 50
            )
        }
        
        // Calculate basic statistics
        let meanRR = rrIntervals.reduce(0, +) / Double(rrIntervals.count)
        let sdnn = sqrt(rrIntervals.map { pow($0 - meanRR, 2) }.reduce(0, +) / Double(rrIntervals.count))
        
        // Calculate RMSSD (Root Mean Square of Successive Differences)
        // RMSSD is the square root of the mean of the squared differences between adjacent RR intervals
        let rmssd = sqrt(rrIntervals.map { pow($0, 2) }.reduce(0, +) / Double(rrIntervals.count))
        
        // Calculate pNN50 (percentage of successive RR intervals that differ by more than 50ms)
        let nn50 = rrIntervals.filter { $0 > 50 }.count
        let pnn50 = Double(nn50) / Double(rrIntervals.count) * 100
        
        // Calculate triangular index (approximation)
        let triangularIndex = Double(rrIntervals.count) / Double(rrIntervals.filter { $0 > meanRR }.count)
        
        // Calculate stress index (approximation based on HRV)
        let stressIndex = 1000 / (sdnn * triangularIndex)
        
        // Calculate autonomic balance (ratio of RMSSD to SDNN)
        let autonomicBalance = rmssd / sdnn
        
        return AdvancedHRVMetrics(
            meanRR: meanRR,
            sdnn: sdnn,
            rmssd: rmssd,
            pnn50: pnn50,
            triangularIndex: triangularIndex,
            stressIndex: stressIndex,
            autonomicBalance: autonomicBalance,
            recoveryScore: min(100, max(0, rmssd * 2)), // Simple recovery score based on RMSSD
            autonomicBalanceScore: min(100, max(0, autonomicBalance * 100)) // Balance score
        )
    }
    
    func fetchLatestRHR(completion: @escaping (Double?) -> Void) {
        fetchLatestQuantity(.restingHeartRate, unit: HKUnit(from: "count/min"), completion: completion)
    }
    
    // MARK: - Weight Data Fetching
    
    /// Fetches the latest weight entry from HealthKit
    func fetchLatestWeight(completion: @escaping (Double?) -> Void) {
        fetchLatestQuantity(.bodyMass, unit: HKUnit.gramUnit(with: .kilo), completion: completion)
    }
    
    /// Fetches all weight entries from HealthKit for a date range
    func fetchWeightEntries(from startDate: Date, to endDate: Date, completion: @escaping ([WeightData]) -> Void) {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            // print("❌ Body mass type not available")
            completion([])
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: weightType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let _ = error {
                // print("❌ Error fetching weight entries: \(error.localizedDescription)")
                completion([])
                return
            }
            
            let weightSamples = (samples as? [HKQuantitySample]) ?? []
            let weightData = weightSamples.map { sample in
                WeightData(
                    date: sample.endDate,
                    weight: sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo)),
                    source: sample.sourceRevision.source.name
                )
            }
            
            // print("✅ Fetched \(weightData.count) weight entries from HealthKit")
            completion(weightData)
        }
        
        healthStore.execute(query)
    }
    
    /// Fetches recent weight entries (last 90 days)
    func fetchRecentWeightEntries(completion: @escaping ([WeightData]) -> Void) {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -90, to: endDate) ?? endDate
        
        fetchWeightEntries(from: startDate, to: endDate, completion: completion)
    }

    // MARK: - Full History Weight Fetch & Save

    /// Fetches the user's entire recorded weight history from Apple Health.
    /// The results array is sorted with the newest entry first.
    /// - Parameter completion: Callback delivering `[WeightData]` on the main queue.
    func fetchAllWeightEntries(completion: @escaping ([WeightData]) -> Void) {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            // print("❌ Body mass type not available")
            DispatchQueue.main.async { completion([]) }
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let _ = error {
                // print("❌ Error fetching all weight entries: \(error.localizedDescription)")
                DispatchQueue.main.async { completion([]) }
                return
            }

            let weightSamples = (samples as? [HKQuantitySample]) ?? []
            let data = weightSamples.map { sample in
                WeightData(
                    date: sample.endDate,
                    weight: sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo)),
                    source: sample.sourceRevision.source.name
                )
            }

            // print("✅ Fetched \(data.count) total weight entries from HealthKit")
            DispatchQueue.main.async { completion(data) }
        }

        healthStore.execute(query)
    }

    /// Saves a weight measurement to Apple Health.
    /// - Parameters:
    ///   - weight: Weight in kilograms.
    ///   - date: Timestamp for the sample (defaults to now).
    ///   - completion: Returns success flag and optional error.
    func saveWeightEntry(weight: Double, date: Date = Date(), completion: @escaping (Bool, Error?) -> Void) {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            let err = NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Body mass type not available"])
            DispatchQueue.main.async { completion(false, err) }
            return
        }

        let quantity = HKQuantity(unit: HKUnit.gramUnit(with: .kilo), doubleValue: weight)
        let sample = HKQuantitySample(type: weightType, quantity: quantity, start: date, end: date)

        healthStore.save(sample) { success, error in
            if let _ = error {
                // print("❌ Failed to save weight sample: \(error.localizedDescription)")
            } else {
                // print("✅ Saved weight (\(weight) kg) to HealthKit at \(date)")
            }
            DispatchQueue.main.async { completion(success, error) }
        }
    }
    
    func fetchLatestRespiratoryRate(completion: @escaping (Double?) -> Void) {
        fetchLatestQuantity(.respiratoryRate, unit: HKUnit(from: "count/min"), completion: completion)
    }
    
    func fetchLatestActiveEnergy(completion: @escaping (Double?) -> Void) {
        fetchLatestQuantity(.activeEnergyBurned, unit: HKUnit.kilocalorie(), completion: completion)
    }
    
    func fetchLatestSleep(completion: @escaping ((duration: TimeInterval, deep: TimeInterval, rem: TimeInterval, bedtime: Date, wake: Date)?) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil)
            return
        }
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let sleeps = (samples as? [HKCategorySample]) ?? []
            guard !sleeps.isEmpty else { completion(nil); return }
            let grouped = Dictionary(grouping: sleeps) { Calendar.current.startOfDay(for: $0.startDate) }
            let today = Calendar.current.startOfDay(for: Date())
            let todaySamples = grouped[today] ?? []
            let total = todaySamples.filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue || $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue || $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue || $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue }.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            let deep = todaySamples.filter { $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue }.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            let rem = todaySamples.filter { $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue }.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            let bedtime = todaySamples.min(by: { $0.startDate < $1.startDate })?.startDate
            let wake = todaySamples.max(by: { $0.endDate < $1.endDate })?.endDate
            if let bedtime = bedtime, let wake = wake {
                completion((duration: total, deep: deep, rem: rem, bedtime: bedtime, wake: wake))
            } else {
                completion(nil)
            }
        }
        healthStore.execute(query)
    }
    
    func fetchLatestWorkout(completion: @escaping (HKWorkout?) -> Void) {
        let workoutType = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: workoutType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            let workout = (samples as? [HKWorkout])?.first
            completion(workout)
        }
        healthStore.execute(query)
    }
    
    // MARK: - Public Query Execution
    public func execute(_ query: HKQuery) {
        healthStore.execute(query)
    }
    
    // MARK: - Helpers
    private func fetchLatestQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double?) -> Void) {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else {
            completion(nil)
            return
        }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            let value = (samples as? [HKQuantitySample])?.first?.quantity.doubleValue(for: unit)
            completion(value)
        }
        healthStore.execute(query)
    }
    
    // MARK: - Journal Integration
    func syncJournalWithHealthData() async {
        do {
            let calendar = Calendar.current
            let today = Date()
            let startDate = calendar.date(byAdding: .day, value: -30, to: today) ?? today
            
            // Fetch health data for the last 30 days
            let recoveryScores = try await fetchRecoveryScores(from: startDate, to: today)
            let sleepScores = try await fetchSleepScores(from: startDate, to: today)
            let hrvData = try await fetchHRVData(from: startDate, to: today)
            let rhrData = try await fetchRHRData(from: startDate, to: today)
            
            // Update journal entries with health data
            await updateJournalEntries(
                recoveryScores: recoveryScores,
                sleepScores: sleepScores,
                hrvData: hrvData,
                rhrData: rhrData
            )
            
        } catch {
            // print("Error syncing journal with health data: \(error)")
        }
    }
    
    private func updateJournalEntries(
        recoveryScores: [Date: Int],
        sleepScores: [Date: Int],
        hrvData: [Date: Double],
        rhrData: [Date: Double]
    ) async {
        // This would typically update SwiftData journal entries
        // For now, we'll just print the data for demonstration
        // print("Syncing journal entries with health data:")
        // print("Recovery scores: \(recoveryScores.count) entries")
        // print("Sleep scores: \(sleepScores.count) entries")
        // print("HRV data: \(hrvData.count) entries")
        // print("RHR data: \(rhrData.count) entries")
    }
    
    func getHealthDataForDate(_ date: Date) async -> (recoveryScore: Int?, sleepScore: Int?, hrv: Double?, rhr: Double?) {
        do {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            
            let recoveryScores = try await fetchRecoveryScores(from: startOfDay, to: endOfDay)
            let sleepScores = try await fetchSleepScores(from: startOfDay, to: endOfDay)
            let hrvData = try await fetchHRVData(from: startOfDay, to: endOfDay)
            let rhrData = try await fetchRHRData(from: startOfDay, to: endOfDay)
            
            return (
                recoveryScore: recoveryScores[date],
                sleepScore: sleepScores[date],
                hrv: hrvData[date],
                rhr: rhrData[date]
            )
        } catch {
            // print("Error fetching health data for date: \(error)")
            return (nil, nil, nil, nil)
        }
    }
    
    func getDetailedSleepScore(for date: Date) async -> SleepScoreResult? {
        do {
            return try await SleepScoreCalculator.shared.calculateSleepScore(for: date)
        } catch {
            // print("Error calculating detailed sleep score for \(date): \(error)")
            return nil
        }
    }
    
    func getDetailedSleepScores(from start: Date, to end: Date) async -> [Date: SleepScoreResult] {
        var result: [Date: SleepScoreResult] = [:]
        let calendar = Calendar.current
        
        // Calculate detailed sleep scores for each day in the range
        var currentDate = start
        while currentDate <= end {
            do {
                let sleepScore = try await SleepScoreCalculator.shared.calculateSleepScore(for: currentDate)
                result[currentDate] = sleepScore
            } catch {
                // If we can't calculate a score for a specific date, skip it
                // print("Could not calculate detailed sleep score for \(currentDate): \(error)")
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return result
    }
    
    // MARK: - Batch Fetchers for Journal/Trends
    func fetchHRVData(from start: Date, to end: Date) async throws -> [Date: Double] {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return [:] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample], error == nil else { cont.resume(returning: [:]); return }
                let grouped = Dictionary(grouping: samples) { Calendar.current.startOfDay(for: $0.startDate) }
                let result = grouped.mapValues { daySamples in
                    daySamples.map { $0.quantity.doubleValue(for: HKUnit(from: "ms")) }.average
                }
                cont.resume(returning: result)
            }
            self.healthStore.execute(query)
        }
    }
    
    func fetchRHRData(from start: Date, to end: Date) async throws -> [Date: Double] {
        guard let type = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else { return [:] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample], error == nil else { cont.resume(returning: [:]); return }
                let grouped = Dictionary(grouping: samples) { Calendar.current.startOfDay(for: $0.startDate) }
                let result = grouped.mapValues { daySamples in
                    daySamples.map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) }.average
                }
                cont.resume(returning: result)
            }
            self.healthStore.execute(query)
        }
    }
    
    func fetchSleepScores(from start: Date, to end: Date) async throws -> [Date: Int] {
        var result: [Date: Int] = [:]
        let calendar = Calendar.current
        
        // Calculate sleep scores for each day in the range
        var currentDate = start
        while currentDate <= end {
            do {
                let sleepScore = try await SleepScoreCalculator.shared.calculateSleepScore(for: currentDate)
                result[currentDate] = sleepScore.finalScore
            } catch {
                // If we can't calculate a score for a specific date, skip it
                // print("Could not calculate sleep score for \(currentDate): \(error)")
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return result
    }
    
    func fetchRecoveryScores(from start: Date, to end: Date) async throws -> [Date: Int] {
        // Fetch HRV, RHR, and sleep scores
        async let hrvMap = fetchHRVData(from: start, to: end)
        async let rhrMap = fetchRHRData(from: start, to: end)
        async let sleepMap = fetchSleepScores(from: start, to: end)
        let hrv = try await hrvMap
        let rhr = try await rhrMap
        let sleep = try await sleepMap
        // Use 60-day baseline for HRV and RHR
        let baseline = DynamicBaselineEngine.shared
        baseline.loadBaselines()
        let baseHRV = baseline.hrv60 ?? 35.0
        let baseRHR = baseline.rhr60 ?? 65.0
        var result: [Date: Int] = [:]
        let allDates = Set(hrv.keys).union(rhr.keys).union(sleep.keys)
        for date in allDates {
            guard let hrvVal = hrv[date], let rhrVal = rhr[date], let sleepScore = sleep[date] else { continue }
            // HRV (60%)
            let hrvRatio = hrvVal / baseHRV
            let hrvScoreRaw = 100 * (1 + log10(hrvRatio))
            let hrvContribution = min(max(hrvScoreRaw, 0), 120) * 0.60
            // RHR (25%)
            let rhrRatio = baseRHR / rhrVal
            let rhrScoreRaw = 100 * rhrRatio
            let rhrContribution = min(max(rhrScoreRaw, 50), 120) * 0.25
            // Sleep (15%)
            let sleepContribution = Double(sleepScore) * 0.15
            // Final
            let total = hrvContribution + rhrContribution + sleepContribution
            result[date] = Int(min(max(total, 0), 100))
        }
        return result
    }
    
    // MARK: - Historical Data Fetchers for Trends
    func fetchHRV(for date: Date, completion: @escaping (Double?) -> Void) {
        // Use the new high-frequency HRV fetching method
        fetchHighFrequencyHRV(for: date, completion: completion)
    }
    
    func fetchRHR(for date: Date, completion: @escaping (Double?) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        guard let type = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let values = (samples as? [HKQuantitySample])?.map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) } ?? []
            let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
            completion(average)
        }
        healthStore.execute(query)
    }
    
    func fetchSleep(for date: Date, completion: @escaping ((duration: TimeInterval, deep: TimeInterval, rem: TimeInterval, bedtime: Date, wake: Date)?) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let sleeps = (samples as? [HKCategorySample]) ?? []
            guard !sleeps.isEmpty else { completion(nil); return }
            
            let total = sleeps.filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue || $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue || $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue || $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue }.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            let deep = sleeps.filter { $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue }.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            let rem = sleeps.filter { $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue }.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            let bedtime = sleeps.min(by: { $0.startDate < $1.startDate })?.startDate
            let wake = sleeps.max(by: { $0.endDate < $1.endDate })?.endDate
            
            if let bedtime = bedtime, let wake = wake {
                completion((duration: total, deep: deep, rem: rem, bedtime: bedtime, wake: wake))
            } else {
                completion(nil)
            }
        }
        healthStore.execute(query)
    }
    
    func fetchWorkoutDates(completion: @escaping (Set<Date>) -> Void) {
        let workoutType = HKObjectType.workoutType()
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let workouts = (samples as? [HKWorkout]) ?? []
            let workoutDates = Set(workouts.map { Calendar.current.startOfDay(for: $0.startDate) })
            completion(workoutDates)
        }
        healthStore.execute(query)
    }

    // MARK: - Overnight Recovery Data Fetching
    
    /// Fetches the main sleep session for a given wake date
    /// Returns the sleep session's start and end times for overnight data analysis
    func fetchMainSleepSession(for wakeDate: Date, completion: @escaping (DateInterval?) -> Void) {
        let calendar = Calendar.current
        // Fetch sleep samples that end between previous day noon and this day noon
        let startOfWindow = calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: wakeDate)!))!
        let endOfWindow = calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: wakeDate))!
        
        // print("🔍 Sleep Session Detection: Looking for sleep between \(startOfWindow.formatted(date: .omitted, time: .shortened)) and \(endOfWindow.formatted(date: .omitted, time: .shortened))")
        
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            // print("❌ Sleep: HealthKit sleep type not available")
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfWindow, end: endOfWindow, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let sleepSamples = (samples as? [HKCategorySample]) ?? []
            
            if sleepSamples.isEmpty {
                // print("❌ Sleep: No sleep samples found in window")
                completion(nil)
                return
            }
            
           // print("✅ Sleep: Found \(sleepSamples.count) sleep samples")
            
            // Group sleep samples by session (continuous periods)
            let sleepSessions = self.groupSleepSamplesIntoSessions(sleepSamples)
            
            if sleepSessions.isEmpty {
                // print("❌ Sleep: No sleep sessions created from samples")
                completion(nil)
                return
            }
            
            // print("✅ Sleep: Created \(sleepSessions.count) sleep sessions")
            
            // Find the main sleep session (longest one)
            let mainSession = sleepSessions.max(by: { $0.totalDuration < $1.totalDuration }) ?? sleepSessions.first
            
            guard let session = mainSession else {
                // print("❌ Sleep: No main sleep session found")
                completion(nil)
                return
            }
            
            let sleepInterval = DateInterval(start: session.startTime, end: session.endTime)
            let _ = session.totalDuration / 3600 // Duration calculation for potential future use
            // print("✅ Sleep: Main session found: \(session.startTime.formatted(date: .omitted, time: .shortened)) - \(session.endTime.formatted(date: .omitted, time: .shortened)) (duration: \(String(format: "%.1f", durationHours))h)")
            completion(sleepInterval)
        }
        
        healthStore.execute(query)
    }
    
    /// Fetches HRV data within a specific date interval (for overnight recovery analysis)
    func fetchHRVForInterval(_ interval: DateInterval, completion: @escaping (Double?) -> Void) {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
            if let _ = error {
                completion(nil)
                return
            }
            
            let hrvSamples = (samples as? [HKQuantitySample]) ?? []
            
            guard !hrvSamples.isEmpty else {
                completion(nil)
                return
            }
            
            // Calculate the average of all HRV readings during the sleep interval
            let hrvValues = hrvSamples.map { $0.quantity.doubleValue(for: HKUnit(from: "ms")) }
            let averageHRV = hrvValues.reduce(0, +) / Double(hrvValues.count)
            
            completion(averageHRV)
        }
        
        healthStore.execute(query)
    }
    
    /// Fetches RHR data within a specific date interval (for overnight recovery analysis)
    func fetchRHRForInterval(_ interval: DateInterval, completion: @escaping (Double?) -> Void) {
        guard let type = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            // print("❌ RHR: HealthKit type not available")
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let values = (samples as? [HKQuantitySample])?.map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) } ?? []
            
            if values.isEmpty {
                // print("⚠️ RHR: No RHR data found during sleep session (\(interval.start.formatted(date: .omitted, time: .shortened)) - \(interval.end.formatted(date: .omitted, time: .shortened)))")
                
                // Fallback: Try to get RHR for the entire day
                self.fetchRHRForDay(containing: interval.start) { fallbackRHR in
                    if let fallbackRHR = fallbackRHR {
                        // print("✅ RHR: Using daily RHR as fallback: \(fallbackRHR) BPM")
                        completion(fallbackRHR)
                    } else {
                        // print("❌ RHR: No RHR data available for day either")
                        completion(nil)
                    }
                }
                return
            }
            
            // For recovery score, we want the lowest RHR during sleep (best recovery state)
            let lowestRHR = values.min()
            // print("✅ RHR: Found \(values.count) samples during sleep, lowest: \(lowestRHR ?? 0) BPM")
            completion(lowestRHR)
        }
        healthStore.execute(query)
    }
    
    /// Fallback method to fetch RHR for the entire day
    private func fetchRHRForDay(containing date: Date, completion: @escaping (Double?) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        guard let type = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let values = (samples as? [HKQuantitySample])?.map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) } ?? []
            let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
            completion(average)
        }
        healthStore.execute(query)
    }
    
    /// Fetches walking heart rate data within a specific date interval
    func fetchWalkingHeartRateForInterval(_ interval: DateInterval, completion: @escaping (Double?) -> Void) {
        guard let type = HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let values = (samples as? [HKQuantitySample])?.map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) } ?? []
            let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
            completion(average)
        }
        healthStore.execute(query)
    }
    
    /// Fetches respiratory rate data within a specific date interval
    func fetchRespiratoryRateForInterval(_ interval: DateInterval, completion: @escaping (Double?) -> Void) {
        guard let type = HKObjectType.quantityType(forIdentifier: .respiratoryRate) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let values = (samples as? [HKQuantitySample])?.map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) } ?? []
            let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
            completion(average)
        }
        healthStore.execute(query)
    }
    
    /// Fetches oxygen saturation data within a specific date interval
    func fetchOxygenSaturationForInterval(_ interval: DateInterval, completion: @escaping (Double?) -> Void) {
        guard let type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let values = (samples as? [HKQuantitySample])?.map { $0.quantity.doubleValue(for: HKUnit.percent()) } ?? []
            let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
            completion(average)
        }
        healthStore.execute(query)
    }
    
    // MARK: - Sleep Session Helper Methods
    
    private func groupSleepSamplesIntoSessions(_ samples: [HKCategorySample]) -> [SleepSession] {
        let sortedSamples = samples.sorted { $0.startDate < $1.startDate }
        var sessions: [SleepSession] = []
        var currentSessionSamples: [HKCategorySample] = []
        var sessionStart: Date?
        
        for sample in sortedSamples {
            let isSleepSample = self.isSleepStage(sample)
            
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
                        let session = self.createSleepSession(from: currentSessionSamples, startTime: start)
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
            let session = self.createSleepSession(from: currentSessionSamples, startTime: start)
            sessions.append(session)
        }
        
        return sessions
    }
    
    private func isSleepStage(_ sample: HKCategorySample) -> Bool {
        let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
        return value == .asleepUnspecified || value == .asleepDeep || value == .asleepREM || value == .asleepCore || value == .inBed
    }
    
    private func createSleepSession(from samples: [HKCategorySample], startTime: Date) -> SleepSession {
        let endTime = samples.max(by: { $0.endDate < $1.endDate })?.endDate ?? startTime
        return SleepSession(startTime: startTime, endTime: endTime, samples: samples)
    }
}

// MARK: - Data Models (now in SharedDataModels.swift)

// MARK: - Extensions
extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self.average * divisor).rounded() / divisor
    }
} 

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

extension HealthKitManager {
    /// Fetches 90-day averages for HRV, RHR, and sleep duration, and prints them to the console
    func printNinetyDayAverages() async {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -89, to: endDate) ?? endDate
        // print("\n===== 90-Day Baseline Averages =====")
        do {
            let hrvData = try await fetchHRVData(from: startDate, to: endDate)
            let rhrData = try await fetchRHRData(from: startDate, to: endDate)
            let sleepData = try await fetchSleepScores(from: startDate, to: endDate)
            let sleepDurations: [Double] = try await withThrowingTaskGroup(of: Double?.self) { group in
                for offset in 0..<90 {
                    if let date = calendar.date(byAdding: .day, value: offset, to: startDate) {
                        group.addTask {
                            await withCheckedContinuation { cont in
                                HealthKitManager.shared.fetchSleep(for: date) { value in
                                    cont.resume(returning: value?.duration)
                                }
                            }
                        }
                    }
                }
                var durations: [Double] = []
                for try await d in group {
                    if let d = d { durations.append(d) }
                }
                return durations
            }
            let _ = Array(hrvData.values).average
            let _ = Array(rhrData.values).average
            let _ = Array(sleepData.values).map { Double($0) }.average
            let _ = sleepDurations.average / 3600 // hours
            // print("HRV (ms) 90d avg: \(hrvAvg)")
            // print("RHR (bpm) 90d avg: \(rhrAvg)")
            // print("Sleep Score 90d avg: \(sleepScoreAvg)")
            // print("Sleep Duration 90d avg: \(sleepDurationAvg) hours")
            // print("====================================\n")
        } catch {
            // print("Failed to fetch 90-day averages: \(error)")
        }
    }

    /// Prints a formatted summary of 90-day averages for recovery and sleep metrics
    func printNinetyDayRecoveryInfo() async {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -89, to: endDate) ?? endDate
        // print("\n===== 90-Day Recovery & Sleep Baseline Averages =====")
        do {
            let _ = try await fetchHRVData(from: startDate, to: endDate)
            let _ = try await fetchRHRData(from: startDate, to: endDate)
            let _ = try await fetchSleepScores(from: startDate, to: endDate)
            let sleepResults = await getDetailedSleepScores(from: startDate, to: endDate)
            // Time Asleep, Time in Bed, Deep, REM, Efficiency, Avg HR (asleep)
            var timeInBed: [Double] = []
            var timeAsleep: [Double] = []
            var deepSleep: [Double] = []
            var remSleep: [Double] = []
            var sleepEfficiency: [Double] = []
            var avgHR: [Double] = []
            var bedtimes: [Date] = []
            var waketimes: [Date] = []
            for result in sleepResults.values {
                timeInBed.append(result.details.timeInBed)
                timeAsleep.append(result.details.timeAsleep)
                deepSleep.append(result.details.deepSleepDuration)
                remSleep.append(result.details.remSleepDuration)
                sleepEfficiency.append(result.details.sleepEfficiency * 100)
                if let hr = result.details.averageHeartRate { avgHR.append(hr) }
                if let bt = result.details.bedtime { bedtimes.append(bt) }
                if let wt = result.details.wakeTime { waketimes.append(wt) }
            }
            let avgBedtime = bedtimes.isEmpty ? nil : bedtimes.reduce(0) { $0 + $1.timeIntervalSince1970 } / Double(bedtimes.count)
            let avgWaketime = waketimes.isEmpty ? nil : waketimes.reduce(0) { $0 + $1.timeIntervalSince1970 } / Double(waketimes.count)
            let _ = avgBedtime.map { Date(timeIntervalSince1970: $0).formatted(date: .omitted, time: .shortened) + " UTC" } ?? "-"
            let _ = avgWaketime.map { Date(timeIntervalSince1970: $0).formatted(date: .omitted, time: .shortened) + " UTC" } ?? "-"
            // print("\nYour 90-Day Baseline Averages\n")
            // print("RHR: \(Array(rhrData.values).average.rounded(toPlaces: 1)) bpm")
            // print("HRV: \(Array(hrvData.values).average.rounded(toPlaces: 1)) ms")
            // print("Sleep Score: \(Array(sleepScores.values).map { Double($0) }.average.rounded(toPlaces: 1)) / 100")
            // print("Time Asleep (Sleep Duration): \((timeAsleep.average / 3600).rounded(toPlaces: 2)) hours")
            // print("\nAverages from Daily Logs (April-July)\n")
            // print("Time in Bed: \((timeInBed.average / 3600).rounded(toPlaces: 2)) hours")
            // print("Sleep Efficiency: \(sleepEfficiency.average.rounded(toPlaces: 1))%")
            // print("Deep Sleep: \((deepSleep.average / 3600).rounded(toPlaces: 2)) hours")
            // print("REM Sleep: \((remSleep.average / 3600).rounded(toPlaces: 2)) hours")
            // print("Average Heart Rate (while asleep): \(avgHR.average.rounded(toPlaces: 1)) bpm")
            // print("Baseline Bedtime (set by app): \(bedtimeStr)")
            // print("Baseline Wake Time (set by app): \(waketimeStr)")
            // print("====================================\n")
        } catch {
            // print("Failed to fetch 90-day recovery info: \(error)")
        }
    }
    
    // MARK: - Sleep Data Synchronization
    
    /// Syncs the latest sleep data to the backend server
    /// This function fetches the most recently completed night's sleep data and sends it to the Sleep Lab
    func syncLatestSleepDataToServer() async {
        // print("🔄 Starting sleep data sync to server...")
        
        // Check HealthKit authorization first
        guard checkAuthorizationStatus() else {
            // print("❌ HealthKit not authorized - cannot sync sleep data")
            return
        }
        
        // Get yesterday's date (the most recent completed sleep session)
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        
        do {
            // Fetch the detailed sleep score for yesterday
            let sleepResult = try await SleepScoreCalculator.shared.calculateSleepScore(for: yesterday)
            
            // Create SleepData object from the result
            let sleepData = try SleepData(from: sleepResult, date: yesterday)
            
            // print("📊 Sleep data prepared for sync:")
            // print("   Date: \(sleepData.session_date)")
            // print("   Sleep Score: \(sleepData.score)")
            // print("   Time Asleep: \(String(format: "%.0f", sleepData.time_asleep_minutes)) minutes")
            // print("   Deep Sleep: \(String(format: "%.0f", sleepData.deep_sleep_minutes)) minutes")
            // print("   REM Sleep: \(String(format: "%.0f", sleepData.rem_sleep_minutes)) minutes")
            
            // Send to server
            try await APIService.shared.postSleepData(sleepData: sleepData)
            
            // print("✅ Sleep data sync completed successfully")
            
            // Store last sync timestamp
            UserDefaults.standard.set(Date(), forKey: "lastSleepDataSync")
            
        } catch is SleepScoreError {
            // print("❌ Failed to calculate sleep score for sync")
        } catch is APIError {
            // print("❌ Failed to sync sleep data to server")
        } catch {
            // print("❌ Unexpected error during sleep data sync: \(error.localizedDescription)")
        }
    }
    
    /// Syncs sleep data for a specific date to the server
    /// - Parameter date: The date to sync sleep data for
    func syncSleepDataToServer(for date: Date) async {
        // print("🔄 Starting sleep data sync for \(date) to server...")
        
        guard checkAuthorizationStatus() else {
            // print("❌ HealthKit not authorized - cannot sync sleep data")
            return
        }
        
        do {
            let sleepResult = try await SleepScoreCalculator.shared.calculateSleepScore(for: date)
            let sleepData = try SleepData(from: sleepResult, date: date)
            
            // print("📊 Sleep data for \(date) prepared for sync:")
            // print("   Sleep Score: \(sleepData.score)")
            // print("   Time Asleep: \(String(format: "%.0f", sleepData.time_asleep_minutes)) minutes")
            
            try await APIService.shared.postSleepData(sleepData: sleepData)
            
            // print("✅ Sleep data sync for \(date) completed successfully")
            
        } catch {
            // print("❌ Failed to sync sleep data for \(date): \(error.localizedDescription)")
        }
    }
    
    /// Checks if sleep data sync is needed and performs it
    /// This can be called on app launch to ensure recent data is synced
    func checkAndSyncSleepDataIfNeeded() async {
        let lastSyncDate = UserDefaults.standard.object(forKey: "lastSleepDataSync") as? Date
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // If we haven't synced today, sync yesterday's data
        if let lastSync = lastSyncDate {
            let lastSyncDay = calendar.startOfDay(for: lastSync)
            if lastSyncDay < today {
                // print("🔄 Sleep data sync needed - last sync was \(lastSync)")
                await syncLatestSleepDataToServer()
            } else {
                // print("✅ Sleep data already synced today")
            }
        } else {
            // print("🔄 No previous sync found - performing initial sync")
            await syncLatestSleepDataToServer()
        }
    }

    /// Fetches all available 90-day averages from Apple Health and prints only the summary in the required format.
    func printNinetyDaySummary() async {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -89, to: endDate) ?? endDate
        do {
            let _ = try await fetchHRVData(from: startDate, to: endDate)
            let _ = try await fetchRHRData(from: startDate, to: endDate)
            let _ = try await fetchSleepScores(from: startDate, to: endDate)
            let sleepResults = await getDetailedSleepScores(from: startDate, to: endDate)
            // Time Asleep, Time in Bed, Deep, REM, Efficiency, Avg HR (asleep), Sleep Onset
            var timeInBed: [Double] = []
            var timeAsleep: [Double] = []
            var deepSleep: [Double] = []
            var remSleep: [Double] = []
            var sleepEfficiency: [Double] = []
            var avgHR: [Double] = []
            var bedtimes: [Date] = []
            var waketimes: [Date] = []
            var sleepOnset: [Double] = []
            for result in sleepResults.values {
                timeInBed.append(result.details.timeInBed)
                timeAsleep.append(result.details.timeAsleep)
                deepSleep.append(result.details.deepSleepDuration)
                remSleep.append(result.details.remSleepDuration)
                sleepEfficiency.append(result.details.sleepEfficiency * 100)
                if let hr = result.details.averageHeartRate { avgHR.append(hr) }
                if let bt = result.details.bedtime { bedtimes.append(bt) }
                if let wt = result.details.wakeTime { waketimes.append(wt) }
                sleepOnset.append(result.timeToFallAsleep)
            }
            let avgBedtime = bedtimes.isEmpty ? nil : bedtimes.reduce(0) { $0 + $1.timeIntervalSince1970 } / Double(bedtimes.count)
            let avgWaketime = waketimes.isEmpty ? nil : waketimes.reduce(0) { $0 + $1.timeIntervalSince1970 } / Double(waketimes.count)
            let _ = avgBedtime.map { Date(timeIntervalSince1970: $0).formatted(date: .omitted, time: .shortened) + " UTC" } ?? "-"
            let _ = avgWaketime.map { Date(timeIntervalSince1970: $0).formatted(date: .omitted, time: .shortened) + " UTC" } ?? "-"

            // Fetch 90-day Recovery and Stress scores
            var recoveryScores: [Int] = []
            var stressScores: [Double] = []
            var currentDate = startDate
            while currentDate <= endDate {
                if let recoveryResult = try? await RecoveryScoreCalculator.shared.calculateRecoveryScore(for: currentDate) {
                    recoveryScores.append(recoveryResult.finalScore)
                    stressScores.append(recoveryResult.stressComponent.score)
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }

            // print("\nYour 90-Day Baseline Averages\n")
            // print("RHR: \(Array(rhrData.values).average.rounded(toPlaces: 1)) bpm")
            // print("HRV: \(Array(hrvData.values).average.rounded(toPlaces: 1)) ms")
            // print("Sleep Score: \(Array(sleepScores.values).map { Double($0) }.average.rounded(toPlaces: 1)) / 100")
            // print("Recovery Score: \((recoveryScores.map { Double($0) }.average).rounded(toPlaces: 1)) / 100")
            // print("Stress: \(stressScores.average.rounded(toPlaces: 1)) / 100")
            // print("Time Asleep (Sleep Duration): \((timeAsleep.average / 3600).rounded(toPlaces: 2)) hours")
            // print("Sleep Onset: \(sleepOnset.average.rounded(toPlaces: 1)) min")
            // print("\nAverages from Daily Logs (April-July)\n")
            // print("Time in Bed: \((timeInBed.average / 3600).rounded(toPlaces: 2)) hours")
            // print("Sleep Efficiency: \(sleepEfficiency.average.rounded(toPlaces: 1))%")
            // print("Deep Sleep: \((deepSleep.average / 3600).rounded(toPlaces: 2)) hours")
            // print("REM Sleep: \((remSleep.average / 3600).rounded(toPlaces: 2)) hours")
            // print("Average Heart Rate (while asleep): \(avgHR.average.rounded(toPlaces: 1)) bpm")
            // print("Baseline Bedtime (set by app): \(bedtimeStr)")
            // print("Baseline Wake Time (set by app): \(waketimeStr)")
            // print("====================================\n")
        } catch {
            // No output if error
        }
    }
    
    // MARK: - Nutrition HealthKit Integration
    
    /// Requests authorization for nutrition-specific HealthKit data types
    func requestNutritionAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw FuelLogError.healthKitNotAvailable
        }
        
        // Combine existing write types with nutrition write types
        var allWriteTypes: Set<HKSampleType> = []
        if let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            allWriteTypes.insert(bodyMassType)
        }
        allWriteTypes.formUnion(nutritionWriteTypes)
        
        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: allWriteTypes, read: readTypes) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }
    
    /// Fetches user physical data from HealthKit for nutrition calculations
    func fetchUserPhysicalData() async throws -> UserPhysicalData {
        async let weight = fetchLatestWeightAsync()
        async let height = fetchLatestHeightAsync()
        async let dateOfBirth = fetchDateOfBirthAsync()
        async let biologicalSex = fetchBiologicalSexAsync()
        
        let (weightValue, heightValue, birthDate, sex) = await (weight, height, dateOfBirth, biologicalSex)
        
        // Calculate age from date of birth
        let age: Int?
        if let birthDate = birthDate {
            let calendar = Calendar.current
            let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
            age = ageComponents.year
        } else {
            age = nil
        }
        
        // Calculate BMR if we have all required data
        let bmr: Double?
        if let weight = weightValue, let height = heightValue, let age = age, let sex = sex {
            bmr = calculateBMR(weight: weight, height: height, age: age, biologicalSex: sex)
        } else {
            bmr = nil
        }
        
        return UserPhysicalData(
            weight: weightValue,
            height: heightValue,
            age: age,
            biologicalSex: sex,
            bmr: bmr,
            tdee: nil // TDEE will be calculated separately based on activity level
        )
    }
    
    /// Calculates BMR using Mifflin-St Jeor formula
    func calculateBMR(weight: Double, height: Double, age: Int, biologicalSex: HKBiologicalSex) -> Double {
        let baseRate: Double
        switch biologicalSex {
        case .male:
            baseRate = (10 * weight) + (6.25 * height) - (5 * Double(age)) + 5
        case .female:
            baseRate = (10 * weight) + (6.25 * height) - (5 * Double(age)) - 161
        default:
            // Use average of male and female formulas for other/unknown
            let maleRate = (10 * weight) + (6.25 * height) - (5 * Double(age)) + 5
            let femaleRate = (10 * weight) + (6.25 * height) - (5 * Double(age)) - 161
            baseRate = (maleRate + femaleRate) / 2
        }
        return max(baseRate, 1000) // Minimum 1000 calories BMR
    }
    
    /// Writes nutrition data to HealthKit
    func writeNutritionData(_ foodLog: FoodLog) async throws {
        let samples = try createNutritionSamples(from: foodLog)
        
        return try await withCheckedThrowingContinuation { continuation in
            healthStore.save(samples) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    /// Creates HealthKit nutrition samples from a FoodLog entry
    private func createNutritionSamples(from foodLog: FoodLog) throws -> [HKQuantitySample] {
        var samples: [HKQuantitySample] = []
        
        // Energy consumed
        if let energyType = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: foodLog.calories)
            let energySample = HKQuantitySample(
                type: energyType,
                quantity: energyQuantity,
                start: foodLog.timestamp,
                end: foodLog.timestamp
            )
            samples.append(energySample)
        }
        
        // Protein
        if let proteinType = HKObjectType.quantityType(forIdentifier: .dietaryProtein) {
            let proteinQuantity = HKQuantity(unit: .gram(), doubleValue: foodLog.protein)
            let proteinSample = HKQuantitySample(
                type: proteinType,
                quantity: proteinQuantity,
                start: foodLog.timestamp,
                end: foodLog.timestamp
            )
            samples.append(proteinSample)
        }
        
        // Carbohydrates
        if let carbType = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            let carbQuantity = HKQuantity(unit: .gram(), doubleValue: foodLog.carbohydrates)
            let carbSample = HKQuantitySample(
                type: carbType,
                quantity: carbQuantity,
                start: foodLog.timestamp,
                end: foodLog.timestamp
            )
            samples.append(carbSample)
        }
        
        // Fat
        if let fatType = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal) {
            let fatQuantity = HKQuantity(unit: .gram(), doubleValue: foodLog.fat)
            let fatSample = HKQuantitySample(
                type: fatType,
                quantity: fatQuantity,
                start: foodLog.timestamp,
                end: foodLog.timestamp
            )
            samples.append(fatSample)
        }
        
        return samples
    }
    
    // MARK: - Private Helper Methods for Physical Data
    
    private func fetchLatestHeight() async -> Double? {
        guard let heightType = HKObjectType.quantityType(forIdentifier: .height) else {
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                let height = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: .meterUnit(with: .centi))
                continuation.resume(returning: height)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchDateOfBirth() async -> Date? {
        return await withCheckedContinuation { continuation in
            do {
                let dateOfBirth = try healthStore.dateOfBirthComponents()
                continuation.resume(returning: Calendar.current.date(from: dateOfBirth))
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func fetchBiologicalSex() async -> HKBiologicalSex? {
        return await withCheckedContinuation { continuation in
            do {
                let biologicalSex = try healthStore.biologicalSex()
                continuation.resume(returning: biologicalSex.biologicalSex)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
    
    // MARK: - Async Wrapper Methods
    
    private func fetchLatestWeightAsync() async -> Double? {
        return await withCheckedContinuation { continuation in
            fetchLatestWeight { weight in
                continuation.resume(returning: weight)
            }
        }
    }
    
    private func fetchLatestHeightAsync() async -> Double? {
        return await fetchLatestHeight()
    }
    
    private func fetchDateOfBirthAsync() async -> Date? {
        return await fetchDateOfBirth()
    }
    
    private func fetchBiologicalSexAsync() async -> HKBiologicalSex? {
        return await fetchBiologicalSex()
    }
} 
