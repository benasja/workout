import Foundation
import HealthKit

final class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    
    // MARK: - Permissions
    let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
    ]
    
    private init() {}
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            completion(success)
        }
    }
    
    // MARK: - Async Fetchers
    func fetchLatestHRV(completion: @escaping (Double?) -> Void) {
        fetchLatestQuantity(.heartRateVariabilitySDNN, unit: HKUnit(from: "ms"), completion: completion)
    }
    
    func fetchLatestRHR(completion: @escaping (Double?) -> Void) {
        fetchLatestQuantity(.restingHeartRate, unit: HKUnit(from: "count/min"), completion: completion)
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
            print("Error syncing journal with health data: \(error)")
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
        print("Syncing journal entries with health data:")
        print("Recovery scores: \(recoveryScores.count) entries")
        print("Sleep scores: \(sleepScores.count) entries")
        print("HRV data: \(hrvData.count) entries")
        print("RHR data: \(rhrData.count) entries")
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
            print("Error fetching health data for date: \(error)")
            return (nil, nil, nil, nil)
        }
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
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [:] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard let samples = samples as? [HKCategorySample], error == nil else { cont.resume(returning: [:]); return }
                let grouped = Dictionary(grouping: samples) { Calendar.current.startOfDay(for: $0.startDate) }
                var result: [Date: Int] = [:]
                for (date, daySamples) in grouped {
                    let total = daySamples.filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue || $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue || $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue || $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue }.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                    let hours = total / 3600
                    // Simple sleep score: 100 for 8h, 80 for 7h, 60 for 6h, 40 for 5h, 20 for <5h
                    let score: Int
                    if hours >= 8 { score = 100 }
                    else if hours >= 7 { score = 80 }
                    else if hours >= 6 { score = 60 }
                    else if hours >= 5 { score = 40 }
                    else { score = 20 }
                    result[date] = score
                }
                cont.resume(returning: result)
            }
            self.healthStore.execute(query)
        }
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
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let values = (samples as? [HKQuantitySample])?.map { $0.quantity.doubleValue(for: HKUnit(from: "ms")) } ?? []
            let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
            completion(average)
        }
        healthStore.execute(query)
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
}

// MARK: - Extensions
extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
} 