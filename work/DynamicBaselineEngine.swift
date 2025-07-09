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
    
    // Calibration status
    var calibrating: Bool {
        return hrv60 == nil || rhr60 == nil || hrv14 == nil || rhr14 == nil || bedtime14 == nil || wake14 == nil
    }
    
    private init() {}
    
    // MARK: - Update and Store Baselines
    func updateAndStoreBaselines(completion: @escaping () -> Void) {
        let group = DispatchGroup()
        
        group.enter()
        fetchRollingAverage(.heartRateVariabilitySDNN, unit: HKUnit(from: "ms"), days: 60) { avg in
            self.hrv60 = avg
            group.leave()
        }
        group.enter()
        fetchRollingAverage(.heartRateVariabilitySDNN, unit: HKUnit(from: "ms"), days: 14) { avg in
            self.hrv14 = avg
            group.leave()
        }
        group.enter()
        fetchRollingAverage(.restingHeartRate, unit: HKUnit(from: "count/min"), days: 60) { avg in
            self.rhr60 = avg
            group.leave()
        }
        group.enter()
        fetchRollingAverage(.restingHeartRate, unit: HKUnit(from: "count/min"), days: 14) { avg in
            self.rhr14 = avg
            group.leave()
        }
        group.enter()
        fetchSleepAverages(days: 14) { avgDuration, avgBed, avgWake in
            self.sleepDuration14 = avgDuration
            self.bedtime14 = avgBed
            self.wake14 = avgWake
            group.leave()
        }
        group.notify(queue: .main) {
            self.persistBaselines()
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
            let bedtimes = grouped.values.compactMap { $0.min(by: { $0.startDate < $1.startDate })?.startDate }
            let wakes = grouped.values.compactMap { $0.max(by: { $0.endDate < $1.endDate })?.endDate }
            let avgBed = bedtimes.isEmpty ? nil : Date(timeIntervalSince1970: bedtimes.map { $0.timeIntervalSince1970 }.reduce(0, +) / Double(bedtimes.count))
            let avgWake = wakes.isEmpty ? nil : Date(timeIntervalSince1970: wakes.map { $0.timeIntervalSince1970 }.reduce(0, +) / Double(wakes.count))
            completion(avgDuration, avgBed, avgWake)
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
            "wake14": wake14?.timeIntervalSince1970
        ]
        UserDefaults.standard.set(dict, forKey: baselineKey)
    }
    
    func loadBaselines() {
        guard let dict = UserDefaults.standard.dictionary(forKey: baselineKey) else { return }
        hrv60 = dict["hrv60"] as? Double
        hrv14 = dict["hrv14"] as? Double
        rhr60 = dict["rhr60"] as? Double
        rhr14 = dict["rhr14"] as? Double
        sleepDuration14 = dict["sleepDuration14"] as? Double
        if let bed = dict["bedtime14"] as? Double { bedtime14 = Date(timeIntervalSince1970: bed) }
        if let wake = dict["wake14"] as? Double { wake14 = Date(timeIntervalSince1970: wake) }
    }
} 