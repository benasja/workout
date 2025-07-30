import Foundation
import HealthKit

// MARK: - BaselineMetrics Structure
struct BaselineMetrics {
    let hrv: Double?
    let rhr: Double?
    let sleepDuration: Double?
    let bedtime: Date?
    let wakeTime: Date?
    let walkingHeartRate: Double?
    let respiratoryRate: Double?
    let oxygenSaturation: Double?
    let calculatedAt: Date
    let period: Int // number of days used for calculation
    
    init(hrv: Double? = nil, rhr: Double? = nil, sleepDuration: Double? = nil, bedtime: Date? = nil, wakeTime: Date? = nil, walkingHeartRate: Double? = nil, respiratoryRate: Double? = nil, oxygenSaturation: Double? = nil, period: Int, calculatedAt: Date = Date()) {
        self.hrv = hrv
        self.rhr = rhr
        self.sleepDuration = sleepDuration
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.walkingHeartRate = walkingHeartRate
        self.respiratoryRate = respiratoryRate
        self.oxygenSaturation = oxygenSaturation
        self.period = period
        self.calculatedAt = calculatedAt
    }
}

final class DynamicBaselineEngine {
    static let shared = DynamicBaselineEngine()
    private let healthStore = HKHealthStore()
    
    // Baseline values
    private(set) var hrv60: Double?
    private(set) var hrv14: Double?
    private(set) var rhr60: Double?
    private(set) var rhr14: Double?
    private(set) var sleepDuration14: Double?
    private(set) var bedtime14: Date?
    private(set) var wake14: Date?
    
    // More responsive sleep consistency baseline
    private(set) var bedtime7: Date?
    private(set) var wake7: Date?
    
    // New baselines for Recovery Score algorithm
    private(set) var walkingHR14: Double?
    private(set) var respiratoryRate14: Double?
    private(set) var oxygenSaturation14: Double?
    
    // Calibration status
    var calibrating: Bool {
        return hrv60 == nil || rhr60 == nil || hrv14 == nil || rhr14 == nil || bedtime14 == nil || wake14 == nil
    }
    
    // Check if baselines should be updated (only if they're more than 24 hours old)
    func shouldUpdateBaselines() -> Bool {
        if let dict = UserDefaults.standard.dictionary(forKey: baselineKey),
           let lastUpdated = dict["lastUpdated"] as? Double {
            let lastUpdateDate = Date(timeIntervalSince1970: lastUpdated)
            let hoursSinceUpdate = Date().timeIntervalSince(lastUpdateDate) / 3600
            return hoursSinceUpdate > 24 // Only update if more than 24 hours old
        }
        return true // Update if no timestamp found
    }
    
    private init() {}
    
    func loadBaselines() {
        
        if let dict = UserDefaults.standard.dictionary(forKey: baselineKey) {
            hrv60 = dict["hrv60"] as? Double
            hrv14 = dict["hrv14"] as? Double
            rhr60 = dict["rhr60"] as? Double
            rhr14 = dict["rhr14"] as? Double
            sleepDuration14 = dict["sleepDuration14"] as? Double
            if let bed = dict["bedtime14"] as? Double { bedtime14 = Date(timeIntervalSince1970: bed) }
            if let wake = dict["wake14"] as? Double { wake14 = Date(timeIntervalSince1970: wake) }
            if let bed7 = dict["bedtime7"] as? Double { bedtime7 = Date(timeIntervalSince1970: bed7) }
            if let wake7Time = dict["wake7"] as? Double { wake7 = Date(timeIntervalSince1970: wake7Time) }
            walkingHR14 = dict["walkingHR14"] as? Double
            respiratoryRate14 = dict["respiratoryRate14"] as? Double
            oxygenSaturation14 = dict["oxygenSaturation14"] as? Double
            
            // Debug: Print the bedtime values being loaded
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            print("📋 DEBUG: Baseline data loaded from UserDefaults:")
            print("   Bedtime 14-day: \(bedtime14.map { formatter.string(from: $0) } ?? "nil")")
            print("   Bedtime 7-day: \(bedtime7.map { formatter.string(from: $0) } ?? "nil")")
            print("   Wake 14-day: \(wake14.map { formatter.string(from: $0) } ?? "nil")")
            print("   Wake 7-day: \(wake7.map { formatter.string(from: $0) } ?? "nil")")
        } else {
            print("⚠️ DEBUG: No baseline data found in UserDefaults - will calculate from HealthKit")
        }
    }
    
    func updateAndStoreBaselines(completion: @escaping () -> Void) {
        // Comment out all print statements
        // print("🔄 Calculating baselines from your Apple Health data...")
        
        let group = DispatchGroup()
        
        // Fetch 60-day HRV average
        group.enter()
        fetchRollingAverage(.heartRateVariabilitySDNN, unit: HKUnit(from: "ms"), days: 60) { value in
            self.hrv60 = value
            // print("📊 HRV 60-day baseline: \(value?.description ?? "nil")")
            group.leave()
        }
        
        // Fetch 14-day HRV average
        group.enter()
        fetchRollingAverage(.heartRateVariabilitySDNN, unit: HKUnit(from: "ms"), days: 14) { value in
            self.hrv14 = value
            // print("📊 HRV 14-day baseline: \(value?.description ?? "nil")")
            group.leave()
        }
        
        // Fetch 60-day RHR average
        group.enter()
        fetchRollingAverage(.restingHeartRate, unit: HKUnit(from: "count/min"), days: 60) { value in
            self.rhr60 = value
            // print("📊 RHR 60-day baseline: \(value?.description ?? "nil")")
            group.leave()
        }
        
        // Fetch 14-day RHR average
        group.enter()
        fetchRollingAverage(.restingHeartRate, unit: HKUnit(from: "count/min"), days: 14) { value in
            self.rhr14 = value
            // print("📊 RHR 14-day baseline: \(value?.description ?? "nil")")
            group.leave()
        }
        
        // Fetch 14-day sleep averages
        group.enter()
        fetchSleepAverages(days: 14) { duration, bedtime, wakeTime in
            self.sleepDuration14 = duration
            self.bedtime14 = bedtime
            self.wake14 = wakeTime
            // print("📊 Sleep 14-day baselines:")
            // print("   Duration: \((duration ?? 0) / 3600) hours")
            // print("   Bedtime: \(bedtime?.description ?? "nil")")
            // print("   Wake time: \(wakeTime?.description ?? "nil")")
            group.leave()
        }
        
        // Fetch 7-day sleep averages for more responsive consistency
        group.enter()
        fetchSleepAverages(days: 7) { duration, bedtime, wakeTime in
            self.bedtime7 = bedtime
            self.wake7 = wakeTime
            // print("📊 Sleep 7-day baselines:")
            // print("   Bedtime: \(bedtime?.description ?? "nil")")
            // print("   Wake time: \(wakeTime?.description ?? "nil")")
            group.leave()
        }
        
        // Fetch 14-day walking HR average
        group.enter()
        fetchRollingAverage(.walkingHeartRateAverage, unit: HKUnit(from: "count/min"), days: 14) { value in
            self.walkingHR14 = value
            // print("📊 Walking HR 14-day baseline: \(value?.description ?? "nil")")
            group.leave()
        }
        
        // Fetch 14-day respiratory rate average
        group.enter()
        fetchRollingAverage(.respiratoryRate, unit: HKUnit(from: "count/min"), days: 14) { value in
            self.respiratoryRate14 = value
            // print("📊 Respiratory Rate 14-day baseline: \(value?.description ?? "nil")")
            group.leave()
        }
        
        // Fetch 14-day oxygen saturation average
        group.enter()
        fetchRollingAverage(.oxygenSaturation, unit: HKUnit.percent(), days: 14) { value in
            self.oxygenSaturation14 = value
            // print("📊 Oxygen Saturation 14-day baseline: \(value?.description ?? "nil")")
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.persistBaselines()
            // print("✅ Baseline calculation completed and persisted")
            completion()
        }
    }
    
    // MARK: - Rolling Averages
    private func fetchRollingAverage(_ id: HKQuantityTypeIdentifier, unit: HKUnit, days: Int, completion: @escaping (Double?) -> Void) {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { completion(nil); return }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let values = (samples as? [HKQuantitySample])?.map { $0.quantity.doubleValue(for: unit) } ?? []
            let avg = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
            completion(avg)
        }
        healthStore.execute(query)
    }
    
    private func fetchSleepAverages(days: Int, completion: @escaping (Double?, Date?, Date?) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { completion(nil, nil, nil); return }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let sleeps = (samples as? [HKCategorySample]) ?? []
            let grouped = Dictionary(grouping: sleeps) { Calendar.current.startOfDay(for: $0.startDate) }
            let durations = grouped.values.map { daySamples in
                daySamples.filter { sample in
                    let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                    return value == .asleepUnspecified || value == .asleepDeep || value == .asleepREM || value == .asleepCore
                }.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            }
            let avgDuration = durations.isEmpty ? nil : durations.reduce(0, +) / Double(durations.count)
            
            // Calculate average time of day for bedtime and wake time
            let bedtimes = grouped.values.compactMap { $0.min(by: { $0.startDate < $1.startDate })?.startDate }
            let wakes = grouped.values.compactMap { $0.max(by: { $0.endDate < $1.endDate })?.endDate }
            
            let calendar = Calendar.current
            let today = Date()
            
            // Debug: Print the raw bedtimes from HealthKit
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            print("🔍 DEBUG: Raw bedtimes from HealthKit (last \(days) days):")
            for (index, bedtime) in bedtimes.enumerated() {
                print("   Day \(index + 1): \(formatter.string(from: bedtime))")
            }
            print("   Total bedtimes found: \(bedtimes.count)")
            
            // Calculate average bedtime (time of day)
            let avgBedtime: Date?
            if !bedtimes.isEmpty {
                // Use circular averaging for bedtime (handles midnight wrap-around)
                let avgBedtimeComponents = self.calculateCircularTimeAverage(bedtimes)
                
                // Use a reference date that's more appropriate (yesterday to avoid timezone issues)
                let referenceDate = calendar.date(byAdding: .day, value: -1, to: today) ?? today
                var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
                components.hour = avgBedtimeComponents.hour
                components.minute = avgBedtimeComponents.minute
                avgBedtime = calendar.date(from: components)
            } else {
                avgBedtime = nil
            }
            
            // Calculate average wake time (time of day)
            let avgWakeTime: Date?
            if !wakes.isEmpty {
                let wakeMinutes = wakes.map { date in
                    let components = calendar.dateComponents([.hour, .minute], from: date)
                    return (components.hour ?? 0) * 60 + (components.minute ?? 0)
                }
                let avgWakeMinutes = wakeMinutes.reduce(0, +) / wakeMinutes.count
                let avgWakeHour = avgWakeMinutes / 60
                let avgWakeMinute = avgWakeMinutes % 60
                
                // Use a reference date that's more appropriate (yesterday to avoid timezone issues)
                let referenceDate = calendar.date(byAdding: .day, value: -1, to: today) ?? today
                var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
                components.hour = avgWakeHour
                components.minute = avgWakeMinute
                avgWakeTime = calendar.date(from: components)
            } else {
                avgWakeTime = nil
            }
            
            // print("📊 Sleep Baseline Calculation:")
            // print("   Bedtimes found: \(bedtimes.count)")
            // print("   Wake times found: \(wakes.count)")
            // print("   Average bedtime: \(avgBedtime?.description ?? "nil")")
            // print("   Average wake time: \(avgWakeTime?.description ?? "nil")")
            
            completion(avgDuration, avgBedtime, avgWakeTime)
        }
        healthStore.execute(query)
    }
    
    // MARK: - Circular Time Averaging
    
    /// Calculates the average time using circular statistics to handle midnight wrap-around
    /// This is essential for bedtime averaging since times like 11 PM and 1 AM should average to midnight, not noon
    private func calculateCircularTimeAverage(_ times: [Date]) -> (hour: Int, minute: Int) {
        guard !times.isEmpty else { return (hour: 22, minute: 0) } // Default to 10 PM
        
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        // Debug: Print the input times
        print("🔍 DEBUG: Circular averaging input times:")
        for (index, time) in times.enumerated() {
            print("   Time \(index + 1): \(formatter.string(from: time))")
        }
        
        // Convert times to angles (0-360 degrees, where 0 = midnight)
        let angles = times.map { time -> Double in
            let components = calendar.dateComponents([.hour, .minute], from: time)
            let totalMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            // Convert to degrees: 24 hours = 360 degrees
            return Double(totalMinutes) * 360.0 / (24.0 * 60.0)
        }
        
        // Debug: Print the angles
        print("🔍 DEBUG: Converted angles (degrees):")
        for (index, angle) in angles.enumerated() {
            print("   Angle \(index + 1): \(String(format: "%.1f", angle))°")
        }
        
        // Calculate circular mean using trigonometry
        let sinSum = angles.reduce(0.0) { $0 + sin($1 * .pi / 180.0) }
        let cosSum = angles.reduce(0.0) { $0 + cos($1 * .pi / 180.0) }
        
        let meanAngle = atan2(sinSum, cosSum) * 180.0 / .pi
        
        // Debug: Print intermediate calculations
        print("🔍 DEBUG: Circular mean calculation:")
        print("   sinSum: \(String(format: "%.3f", sinSum))")
        print("   cosSum: \(String(format: "%.3f", cosSum))")
        print("   meanAngle: \(String(format: "%.1f", meanAngle))°")
        
        // Convert back to time (handle negative angles)
        let normalizedAngle = meanAngle < 0 ? meanAngle + 360 : meanAngle
        let totalMinutes = Int((normalizedAngle / 360.0) * 24.0 * 60.0)
        
        let hour = (totalMinutes / 60) % 24
        let minute = totalMinutes % 60
        
        let result = (hour: hour, minute: minute)
        
        // Debug: Print the result
        print("🔍 DEBUG: Circular averaging result:")
        print("   normalizedAngle: \(String(format: "%.1f", normalizedAngle))°")
        print("   totalMinutes: \(totalMinutes)")
        print("   Result: \(hour):\(String(format: "%02d", minute))")
        
        return result
    }
    
    // MARK: - Persistence (UserDefaults for simplicity)
    private let baselineKey = "DynamicBaselines"
    
    private func persistBaselines() {
        let dict: [String: Any?] = [
            "hrv60": hrv60,
            "hrv14": hrv14,
            "rhr60": rhr60,
            "rhr14": rhr14,
            "sleepDuration14": sleepDuration14,
            "bedtime14": bedtime14?.timeIntervalSince1970,
            "wake14": wake14?.timeIntervalSince1970,
            "bedtime7": bedtime7?.timeIntervalSince1970,
            "wake7": wake7?.timeIntervalSince1970,
            "walkingHR14": walkingHR14,
            "respiratoryRate14": respiratoryRate14,
            "oxygenSaturation14": oxygenSaturation14,
            "lastUpdated": Date().timeIntervalSince1970
        ]
        UserDefaults.standard.set(dict, forKey: baselineKey)
        
        // Debug: Print the bedtime values being stored
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        print("💾 DEBUG: Baseline data being persisted:")
        print("   Bedtime 14-day: \(bedtime14.map { formatter.string(from: $0) } ?? "nil")")
        print("   Bedtime 7-day: \(bedtime7.map { formatter.string(from: $0) } ?? "nil")")
        print("   Wake 14-day: \(wake14.map { formatter.string(from: $0) } ?? "nil")")
        print("   Wake 7-day: \(wake7.map { formatter.string(from: $0) } ?? "nil")")
    }
    
    func resetBaselines() {
        // print("🔄 Resetting baseline data...")
        UserDefaults.standard.removeObject(forKey: baselineKey)
        hrv60 = nil
        hrv14 = nil
        rhr60 = nil
        rhr14 = nil
        sleepDuration14 = nil
        bedtime14 = nil
        wake14 = nil
        bedtime7 = nil
        wake7 = nil
        walkingHR14 = nil
        respiratoryRate14 = nil
        oxygenSaturation14 = nil
    }
    
    func forceRecalculateBaselines(completion: @escaping () -> Void = {}) {
        print("🔄 Force recalculating baselines with new circular averaging...")
        resetBaselines()
        updateAndStoreBaselines(completion: completion)
    }
    
    // MARK: - Historical Baselining for Single Source of Truth
    
    /// Calculates baseline metrics for a specific historical date using data from the specified number of days
    /// before that date. This ensures historically accurate, non-changing baseline values for score calculations.
    /// 
    /// - Parameters:
    ///   - date: The reference date for which to calculate the baseline
    ///   - days: Number of days to look back from the reference date (e.g., 60 for HRV/RHR baseline)
    /// - Returns: BaselineMetrics object containing all calculated baseline values
    func calculateBaseline(for date: Date, days: Int) async -> BaselineMetrics {
        // Comment out all print statements
        // print("📊 Calculating \(days)-day baseline for date: \(date)")
        
        let calendar = Calendar.current
        // Calculate the range ending the day BEFORE the reference date
        let endDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) ?? date
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        // print("   Baseline period: \(startDate) to \(endDate)")
        
        // Use a dispatch group to fetch all metrics in parallel
        return await withTaskGroup(of: Void.self, returning: BaselineMetrics.self) { group in
            var hrv: Double?
            var rhr: Double?
            var sleepDuration: Double?
            var bedtime: Date?
            var wakeTime: Date?
            var walkingHR: Double?
            var respiratoryRate: Double?
            var oxygenSaturation: Double?
            
            // Fetch HRV baseline
            group.addTask {
                hrv = await withCheckedContinuation { continuation in
                    self.fetchRollingAverageForPeriod(.heartRateVariabilitySDNN, unit: HKUnit(from: "ms"), startDate: startDate, endDate: endDate) { value in
                        continuation.resume(returning: value)
                    }
                }
            }
            
            // Fetch RHR baseline
            group.addTask {
                rhr = await withCheckedContinuation { continuation in
                    self.fetchRollingAverageForPeriod(.restingHeartRate, unit: HKUnit(from: "count/min"), startDate: startDate, endDate: endDate) { value in
                        continuation.resume(returning: value)
                    }
                }
            }
            
            // Fetch Sleep baseline
            group.addTask {
                let sleepBaseline = await withCheckedContinuation { continuation in
                    self.fetchSleepAveragesForPeriod(startDate: startDate, endDate: endDate) { duration, bedtimeAvg, wakeTimeAvg in
                        continuation.resume(returning: (duration, bedtimeAvg, wakeTimeAvg))
                    }
                }
                sleepDuration = sleepBaseline.0
                bedtime = sleepBaseline.1
                wakeTime = sleepBaseline.2
            }
            
            // Fetch Walking HR baseline
            group.addTask {
                walkingHR = await withCheckedContinuation { continuation in
                    self.fetchRollingAverageForPeriod(.walkingHeartRateAverage, unit: HKUnit(from: "count/min"), startDate: startDate, endDate: endDate) { value in
                        continuation.resume(returning: value)
                    }
                }
            }
            
            // Fetch Respiratory Rate baseline
            group.addTask {
                respiratoryRate = await withCheckedContinuation { continuation in
                    self.fetchRollingAverageForPeriod(.respiratoryRate, unit: HKUnit(from: "count/min"), startDate: startDate, endDate: endDate) { value in
                        continuation.resume(returning: value)
                    }
                }
            }
            
            // Fetch Oxygen Saturation baseline
            group.addTask {
                oxygenSaturation = await withCheckedContinuation { continuation in
                    self.fetchRollingAverageForPeriod(.oxygenSaturation, unit: HKUnit.percent(), startDate: startDate, endDate: endDate) { value in
                        continuation.resume(returning: value)
                    }
                }
            }
            
            // Wait for all tasks to complete
            for await _ in group { }
            
            let baseline = BaselineMetrics(
                hrv: hrv,
                rhr: rhr,
                sleepDuration: sleepDuration,
                bedtime: bedtime,
                wakeTime: wakeTime,
                walkingHeartRate: walkingHR,
                respiratoryRate: respiratoryRate,
                oxygenSaturation: oxygenSaturation,
                period: days
            )
            
            // print("✅ Baseline calculation completed for \(date):")
            // print("   HRV: \(hrv?.description ?? "nil") ms")
            // print("   RHR: \(rhr?.description ?? "nil") bpm")
            // print("   Sleep Duration: \((sleepDuration ?? 0) / 3600) hours")
            // print("   Walking HR: \(walkingHR?.description ?? "nil") bpm")
            // print("   Respiratory Rate: \(respiratoryRate?.description ?? "nil") rpm")
            // print("   Oxygen Saturation: \(oxygenSaturation?.description ?? "nil")%")
            
            return baseline
        }
    }
    
    // MARK: - Supporting Methods for Historical Baselines
    
    /// Fetches rolling average for a specific date range (used by calculateBaseline)
    private func fetchRollingAverageForPeriod(_ id: HKQuantityTypeIdentifier, unit: HKUnit, startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { 
            completion(nil)
            return 
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let values = (samples as? [HKQuantitySample])?.map { $0.quantity.doubleValue(for: unit) } ?? []
            let avg = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
            completion(avg)
        }
        healthStore.execute(query)
    }
    
    /// Fetches sleep averages for a specific date range (used by calculateBaseline)
    private func fetchSleepAveragesForPeriod(startDate: Date, endDate: Date, completion: @escaping (Double?, Date?, Date?) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { 
            completion(nil, nil, nil)
            return 
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let sleeps = (samples as? [HKCategorySample]) ?? []
            let grouped = Dictionary(grouping: sleeps) { Calendar.current.startOfDay(for: $0.startDate) }
            
            let durations = grouped.values.map { daySamples in
                daySamples.filter { sample in
                    let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                    return value == .asleepUnspecified || value == .asleepDeep || value == .asleepREM || value == .asleepCore
                }.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            }
            let avgDuration = durations.isEmpty ? nil : durations.reduce(0, +) / Double(durations.count)
            
            // Calculate average time of day for bedtime and wake time
            let bedtimes = grouped.values.compactMap { $0.min(by: { $0.startDate < $1.startDate })?.startDate }
            let wakes = grouped.values.compactMap { $0.max(by: { $0.endDate < $1.endDate })?.endDate }
            
            let calendar = Calendar.current
            let referenceDate = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            
            // Calculate average bedtime (time of day)
            let avgBedtime: Date?
            if !bedtimes.isEmpty {
                // Use circular averaging for bedtime (handles midnight wrap-around)
                let avgBedtimeComponents = self.calculateCircularTimeAverage(bedtimes)
                
                var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
                components.hour = avgBedtimeComponents.hour
                components.minute = avgBedtimeComponents.minute
                avgBedtime = calendar.date(from: components)
            } else {
                avgBedtime = nil
            }
            
            // Calculate average wake time (time of day)
            let avgWakeTime: Date?
            if !wakes.isEmpty {
                let wakeMinutes = wakes.map { date in
                    let components = calendar.dateComponents([.hour, .minute], from: date)
                    return (components.hour ?? 0) * 60 + (components.minute ?? 0)
                }
                let avgWakeMinutes = wakeMinutes.reduce(0, +) / wakeMinutes.count
                let avgWakeHour = avgWakeMinutes / 60
                let avgWakeMinute = avgWakeMinutes % 60
                
                var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
                components.hour = avgWakeHour
                components.minute = avgWakeMinute
                avgWakeTime = calendar.date(from: components)
            } else {
                avgWakeTime = nil
            }
            
            completion(avgDuration, avgBedtime, avgWakeTime)
        }
        healthStore.execute(query)
    }
} 
