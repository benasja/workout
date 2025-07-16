import Foundation
import HealthKit

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
    
    // New baselines for Recovery Score algorithm
    private(set) var walkingHR14: Double?
    private(set) var respiratoryRate14: Double?
    private(set) var oxygenSaturation14: Double?
    
    // Calibration status
    var calibrating: Bool {
        return hrv60 == nil || rhr60 == nil || hrv14 == nil || rhr14 == nil || bedtime14 == nil || wake14 == nil
    }
    
    private init() {}
    
    private let userFixedBaselines: [String: Any] = [
        "hrv60": 62.1,
        "hrv14": 62.1,
        "rhr60": 60.4,
        "rhr14": 60.4,
        "sleepDuration14": 7.05 * 3600, // hours to seconds
        "bedtime14": { let comps = DateComponents(hour: 13, minute: 53); return Calendar.current.date(from: comps)?.timeIntervalSince1970 ?? 0 }(),
        "wake14": { let comps = DateComponents(hour: 21, minute: 31); return Calendar.current.date(from: comps)?.timeIntervalSince1970 ?? 0 }(),
        "walkingHR14": 95.0, // user-provided average walking HR
        "respiratoryRate14": 15.0, // user-provided average respiratory rate
        "oxygenSaturation14": 99.0, // user-provided average oxygen saturation
    ]
    
    func loadBaselines() {
        // Always use user-provided fixed baselines
        hrv60 = userFixedBaselines["hrv60"] as? Double
        hrv14 = userFixedBaselines["hrv14"] as? Double
        rhr60 = userFixedBaselines["rhr60"] as? Double
        rhr14 = userFixedBaselines["rhr14"] as? Double
        sleepDuration14 = userFixedBaselines["sleepDuration14"] as? Double
        if let bed = userFixedBaselines["bedtime14"] as? Double { bedtime14 = Date(timeIntervalSince1970: bed) }
        if let wake = userFixedBaselines["wake14"] as? Double { wake14 = Date(timeIntervalSince1970: wake) }
        walkingHR14 = userFixedBaselines["walkingHR14"] as? Double
        respiratoryRate14 = userFixedBaselines["respiratoryRate14"] as? Double
        oxygenSaturation14 = userFixedBaselines["oxygenSaturation14"] as? Double
    }
    
    func updateAndStoreBaselines(completion: @escaping () -> Void) {
        // Do nothing, always use fixed baselines
        completion()
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
            
            // Calculate average bedtime (time of day)
            let avgBedtime: Date?
            if !bedtimes.isEmpty {
                let bedtimeMinutes = bedtimes.map { date in
                    let components = calendar.dateComponents([.hour, .minute], from: date)
                    return (components.hour ?? 0) * 60 + (components.minute ?? 0)
                }
                let avgBedtimeMinutes = bedtimeMinutes.reduce(0, +) / bedtimeMinutes.count
                let avgBedtimeHour = avgBedtimeMinutes / 60
                let avgBedtimeMinute = avgBedtimeMinutes % 60
                
                // Use a reference date that's more appropriate (yesterday to avoid timezone issues)
                let referenceDate = calendar.date(byAdding: .day, value: -1, to: today) ?? today
                var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
                components.hour = avgBedtimeHour
                components.minute = avgBedtimeMinute
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
            
            print("📊 Sleep Baseline Calculation:")
            print("   Bedtimes found: \(bedtimes.count)")
            print("   Wake times found: \(wakes.count)")
            print("   Average bedtime: \(avgBedtime?.description ?? "nil")")
            print("   Average wake time: \(avgWakeTime?.description ?? "nil")")
            
            completion(avgDuration, avgBedtime, avgWakeTime)
        }
        healthStore.execute(query)
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
            "walkingHR14": walkingHR14,
            "respiratoryRate14": respiratoryRate14,
            "oxygenSaturation14": oxygenSaturation14
        ]
        UserDefaults.standard.set(dict, forKey: baselineKey)
        
        print("💾 Baseline data persisted:")
        print("   HRV 60-day: \(hrv60?.description ?? "nil")")
        print("   HRV 14-day: \(hrv14?.description ?? "nil")")
        print("   RHR 60-day: \(rhr60?.description ?? "nil")")
        print("   RHR 14-day: \(rhr14?.description ?? "nil")")
        print("   Walking HR 14-day: \(walkingHR14?.description ?? "nil")")
        print("   Respiratory Rate 14-day: \(respiratoryRate14?.description ?? "nil")")
        print("   Oxygen Saturation 14-day: \(oxygenSaturation14?.description ?? "nil")")
    }
    
    func resetBaselines() {
        print("🔄 Resetting baseline data...")
        UserDefaults.standard.removeObject(forKey: baselineKey)
        hrv60 = nil
        hrv14 = nil
        rhr60 = nil
        rhr14 = nil
        sleepDuration14 = nil
        bedtime14 = nil
        wake14 = nil
        walkingHR14 = nil
        respiratoryRate14 = nil
        oxygenSaturation14 = nil
    }
} 