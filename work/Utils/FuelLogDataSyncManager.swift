import Foundation
import HealthKit
import SwiftData

// MARK: - Data Synchronization Manager

@MainActor
final class FuelLogDataSyncManager: ObservableObject {
    static let shared = FuelLogDataSyncManager(repository: FuelLogRepository(modelContext: ModelContext(try! ModelContainer(for: FoodLog.self, CustomFood.self, NutritionGoals.self))))
    
    private let healthStore = HKHealthStore()
    private let repository: FuelLogRepositoryProtocol
    private let userDefaults = UserDefaults.standard
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncErrors: [SyncError] = []
    
    // Sync configuration
    private let syncInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private let maxSyncDays: Int = 30 // Sync last 30 days
    
    // UserDefaults keys
    private let lastSyncDateKey = "FuelLogLastSyncDate"
    private let healthKitSyncEnabledKey = "FuelLogHealthKitSyncEnabled"
    
    init(repository: FuelLogRepositoryProtocol) {
        self.repository = repository
        
        // Load last sync date
        if let lastSync = userDefaults.object(forKey: lastSyncDateKey) as? Date {
            self.lastSyncDate = lastSync
        }
        
        // Setup background sync if enabled
        setupBackgroundSync()
    }
    
    // MARK: - Public Sync Methods
    
    /// Enables or disables HealthKit synchronization
    func setHealthKitSyncEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: healthKitSyncEnabledKey)
        
        if enabled {
            setupBackgroundSync()
        }
    }
    
    /// Returns whether HealthKit sync is enabled
    var isHealthKitSyncEnabled: Bool {
        return userDefaults.bool(forKey: healthKitSyncEnabledKey)
    }
    
    /// Performs a full synchronization with HealthKit
    func performFullSync() async throws {
        guard isHealthKitSyncEnabled else {
            throw SyncError.syncDisabled
        }
        
        guard HKHealthStore.isHealthDataAvailable() else {
            throw SyncError.healthKitUnavailable
        }
        
        isSyncing = true
        syncErrors.removeAll()
        
        do {
            // Sync nutrition data to HealthKit
            try await syncNutritionDataToHealthKit()
            
            // Update last sync date
            lastSyncDate = Date()
            userDefaults.set(lastSyncDate, forKey: lastSyncDateKey)
            
        } catch {
            let syncError = SyncError.syncFailed(error)
            syncErrors.append(syncError)
            throw syncError
        }
        
        isSyncing = false
    }
    
    /// Performs incremental sync since last sync date
    func performIncrementalSync() async throws {
        guard isHealthKitSyncEnabled else { return }
        
        let startDate = lastSyncDate ?? Calendar.current.date(byAdding: .day, value: -maxSyncDays, to: Date()) ?? Date()
        
        try await syncNutritionDataToHealthKit(since: startDate)
        
        lastSyncDate = Date()
        userDefaults.set(lastSyncDate, forKey: lastSyncDateKey)
    }
    
    /// Syncs a specific food log entry to HealthKit
    func syncFoodLogToHealthKit(_ foodLog: FoodLog) async throws {
        guard isHealthKitSyncEnabled else { return }
        
        guard HKHealthStore.isHealthDataAvailable() else {
            throw SyncError.healthKitUnavailable
        }
        
        // Request write authorization if needed
        let writeTypes: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
            HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
            HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
            HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!
        ]
        
        try await healthStore.requestAuthorization(toShare: writeTypes, read: [])
        
        // Create HealthKit samples
        let samples = createHealthKitSamples(from: foodLog)
        
        // Save to HealthKit
        try await healthStore.save(samples)
    }
    
    /// Removes a food log entry from HealthKit
    func removeFoodLogFromHealthKit(_ foodLog: FoodLog) async throws {
        guard isHealthKitSyncEnabled else { return }
        
        // Query for existing samples with matching metadata
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: foodLog.timestamp),
            end: Calendar.current.date(byAdding: .day, value: 1, to: foodLog.timestamp)
        )
        
        let metadataPredicate = HKQuery.predicateForObjects(withMetadataKey: "FuelLogID", allowedValues: [foodLog.id.uuidString])
        let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, metadataPredicate])
        
        // Delete samples for each nutrition type
        let nutritionTypes: [HKQuantityTypeIdentifier] = [
            .dietaryEnergyConsumed,
            .dietaryProtein,
            .dietaryCarbohydrates,
            .dietaryFatTotal
        ]
        
        for typeIdentifier in nutritionTypes {
            guard let quantityType = HKObjectType.quantityType(forIdentifier: typeIdentifier) else { continue }
            
            let samples = try await querySamples(for: quantityType, predicate: combinedPredicate)
            if !samples.isEmpty {
                try await healthStore.delete(samples)
            }
        }
    }
    
    // MARK: - Data Export and Backup
    
    /// Exports all nutrition data to JSON format
    func exportNutritionData() async throws -> Data {
        var exportData = NutritionExportData()
        
        // Export nutrition goals
        if let goals = try await repository.fetchNutritionGoals() {
            exportData.nutritionGoals = ExportableNutritionGoals(from: goals)
        }
        
        // Export custom foods
        let customFoods = try await repository.fetchCustomFoods()
        exportData.customFoods = customFoods.map { ExportableCustomFood(from: $0) }
        
        // Export food logs for the last year
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let foodLogs = try await repository.fetchFoodLogsByDateRange(from: oneYearAgo, to: Date())
        exportData.foodLogs = foodLogs.map { ExportableFoodLog(from: $0) }
        
        // Add metadata
        exportData.exportDate = Date()
        exportData.version = "1.0"
        exportData.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try encoder.encode(exportData)
    }
    
    /// Imports nutrition data from JSON format
    func importNutritionData(_ data: Data, mergeStrategy: ImportMergeStrategy = .skipExisting) async throws {
        // Import functionality temporarily disabled due to SwiftData model complexity
        // TODO: Implement proper conversion from exportable types back to SwiftData models
        throw SyncError.dataCorrupted
    }
    
    // MARK: - Data Cleanup and Storage Management
    
    /// Cleans up old data based on retention policies
    func performDataCleanup() async throws {
        // Clean up old food logs (older than 2 years)
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
        let oldFoodLogs = try await repository.fetchFoodLogsByDateRange(from: Date.distantPast, to: twoYearsAgo)
        
        for foodLog in oldFoodLogs {
            try await repository.deleteFoodLog(foodLog)
        }
        
        // Clean up unused custom foods (not used in last 6 months and not recently created)
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        let customFoods = try await repository.fetchCustomFoods()
        
        for customFood in customFoods {
            // Skip recently created foods
            if customFood.createdDate > sixMonthsAgo {
                continue
            }
            
            // Check if used in recent food logs
            let recentLogs = try await repository.fetchFoodLogsByDateRange(from: sixMonthsAgo, to: Date())
            let isUsed = recentLogs.contains { $0.customFoodId == customFood.id }
            
            if !isUsed {
                try await repository.deleteCustomFood(customFood)
            }
        }
        
        // Clear old cache data
        await FuelLogCacheManager.shared.clearExpiredCache()
    }
    
    /// Gets storage usage statistics
    func getStorageStatistics() async -> StorageStatistics {
        let customFoods = (try? await repository.fetchCustomFoods()) ?? []
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let recentFoodLogs = (try? await repository.fetchFoodLogsByDateRange(from: oneYearAgo, to: Date())) ?? []
        let cacheStats = FuelLogCacheManager.shared.getCacheStatistics()
        
        return StorageStatistics(
            customFoodsCount: customFoods.count,
            foodLogsCount: recentFoodLogs.count,
            cacheSize: cacheStats.totalSize,
            cacheItemsCount: cacheStats.itemCount
        )
    }
    
    // MARK: - Private Methods
    
    private func setupBackgroundSync() {
        guard isHealthKitSyncEnabled else { return }
        
        // Setup periodic sync
        Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { _ in
            Task {
                try? await self.performIncrementalSync()
            }
        }
    }
    
    private func syncNutritionDataToHealthKit(since startDate: Date? = nil) async throws {
        let syncStartDate = startDate ?? Calendar.current.date(byAdding: .day, value: -maxSyncDays, to: Date()) ?? Date()
        
        // Get food logs to sync
        let foodLogs = try await repository.fetchFoodLogsByDateRange(from: syncStartDate, to: Date())
        
        // Group by date for batch processing
        let logsByDate = Dictionary(grouping: foodLogs) { log in
            Calendar.current.startOfDay(for: log.timestamp)
        }
        
        // Sync each day's data
        for (date, logs) in logsByDate {
            try await syncDailyNutritionToHealthKit(logs, for: date)
        }
    }
    
    private func syncDailyNutritionToHealthKit(_ foodLogs: [FoodLog], for date: Date) async throws {
        // Calculate daily totals
        let totalCalories = foodLogs.reduce(0) { $0 + $1.calories }
        let totalProtein = foodLogs.reduce(0) { $0 + $1.protein }
        let totalCarbs = foodLogs.reduce(0) { $0 + $1.carbohydrates }
        let totalFat = foodLogs.reduce(0) { $0 + $1.fat }
        
        // Create HealthKit samples for daily totals
        let samples: [HKQuantitySample] = [
            createQuantitySample(
                type: .dietaryEnergyConsumed,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: totalCalories),
                date: date
            ),
            createQuantitySample(
                type: .dietaryProtein,
                quantity: HKQuantity(unit: .gram(), doubleValue: totalProtein),
                date: date
            ),
            createQuantitySample(
                type: .dietaryCarbohydrates,
                quantity: HKQuantity(unit: .gram(), doubleValue: totalCarbs),
                date: date
            ),
            createQuantitySample(
                type: .dietaryFatTotal,
                quantity: HKQuantity(unit: .gram(), doubleValue: totalFat),
                date: date
            )
        ]
        
        // Save to HealthKit
        try await healthStore.save(samples)
    }
    
    private func createHealthKitSamples(from foodLog: FoodLog) -> [HKQuantitySample] {
        return [
            createQuantitySample(
                type: .dietaryEnergyConsumed,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: foodLog.calories),
                date: foodLog.timestamp,
                metadata: ["FuelLogID": foodLog.id.uuidString, "FoodName": foodLog.name]
            ),
            createQuantitySample(
                type: .dietaryProtein,
                quantity: HKQuantity(unit: .gram(), doubleValue: foodLog.protein),
                date: foodLog.timestamp,
                metadata: ["FuelLogID": foodLog.id.uuidString, "FoodName": foodLog.name]
            ),
            createQuantitySample(
                type: .dietaryCarbohydrates,
                quantity: HKQuantity(unit: .gram(), doubleValue: foodLog.carbohydrates),
                date: foodLog.timestamp,
                metadata: ["FuelLogID": foodLog.id.uuidString, "FoodName": foodLog.name]
            ),
            createQuantitySample(
                type: .dietaryFatTotal,
                quantity: HKQuantity(unit: .gram(), doubleValue: foodLog.fat),
                date: foodLog.timestamp,
                metadata: ["FuelLogID": foodLog.id.uuidString, "FoodName": foodLog.name]
            )
        ]
    }
    
    private func createQuantitySample(
        type: HKQuantityTypeIdentifier,
        quantity: HKQuantity,
        date: Date,
        metadata: [String: Any]? = nil
    ) -> HKQuantitySample {
        let quantityType = HKObjectType.quantityType(forIdentifier: type)!
        return HKQuantitySample(
            type: quantityType,
            quantity: quantity,
            start: date,
            end: date,
            metadata: metadata
        )
    }
    
    private func querySamples(for type: HKQuantityType, predicate: NSPredicate) async throws -> [HKSample] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            
            healthStore.execute(query)
        }
    }
}

// MARK: - Supporting Types

enum SyncError: LocalizedError {
    case syncDisabled
    case healthKitUnavailable
    case syncFailed(Error)
    case authorizationDenied
    case dataCorrupted
    
    var errorDescription: String? {
        switch self {
        case .syncDisabled:
            return "HealthKit synchronization is disabled"
        case .healthKitUnavailable:
            return "HealthKit is not available on this device"
        case .syncFailed(let error):
            return "Synchronization failed: \(error.localizedDescription)"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        case .dataCorrupted:
            return "Data corruption detected during sync"
        }
    }
}

enum ImportMergeStrategy {
    case skipExisting  // Skip items that already exist
    case overwrite     // Overwrite existing items
    case merge         // Merge based on timestamps/versions
}

struct StorageStatistics {
    let customFoodsCount: Int
    let foodLogsCount: Int
    let cacheSize: Int
    let cacheItemsCount: Int
    
    var totalDataSize: Int {
        // Rough estimation of data size
        return (customFoodsCount * 1024) + (foodLogsCount * 512) + cacheSize
    }
    
    var totalDataSizeInMB: Double {
        Double(totalDataSize) / (1024 * 1024)
    }
}

// MARK: - Export Data Model

private struct NutritionExportData: Codable {
    var nutritionGoals: ExportableNutritionGoals?
    var customFoods: [ExportableCustomFood] = []
    var foodLogs: [ExportableFoodLog] = []
    var exportDate: Date = Date()
    var version: String = "1.0"
    var appVersion: String = "Unknown"
}

// Simplified exportable versions of SwiftData models
private struct ExportableNutritionGoals: Codable {
    let userId: String
    let dailyCalories: Double
    let dailyProtein: Double
    let dailyCarbohydrates: Double
    let dailyFat: Double
    let bmr: Double
    let tdee: Double
    let activityLevel: String
    let goal: String
    let lastUpdated: Date
    
    init(from goals: NutritionGoals) {
        self.userId = goals.userId
        self.dailyCalories = goals.dailyCalories
        self.dailyProtein = goals.dailyProtein
        self.dailyCarbohydrates = goals.dailyCarbohydrates
        self.dailyFat = goals.dailyFat
        self.bmr = goals.bmr
        self.tdee = goals.tdee
        self.activityLevel = goals.activityLevel.rawValue
        self.goal = goals.goal.rawValue
        self.lastUpdated = goals.lastUpdated
    }
}

private struct ExportableCustomFood: Codable {
    let id: UUID
    let name: String
    let caloriesPerServing: Double
    let proteinPerServing: Double
    let carbohydratesPerServing: Double
    let fatPerServing: Double
    let servingSize: Double
    let servingUnit: String
    let createdDate: Date
    let isComposite: Bool
    
    init(from customFood: CustomFood) {
        self.id = customFood.id
        self.name = customFood.name
        self.caloriesPerServing = customFood.caloriesPerServing
        self.proteinPerServing = customFood.proteinPerServing
        self.carbohydratesPerServing = customFood.carbohydratesPerServing
        self.fatPerServing = customFood.fatPerServing
        self.servingSize = customFood.servingSize
        self.servingUnit = customFood.servingUnit
        self.createdDate = customFood.createdDate
        self.isComposite = customFood.isComposite
    }
}

private struct ExportableFoodLog: Codable {
    let id: UUID
    let name: String
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let servingSize: Double
    let servingUnit: String
    let timestamp: Date
    let mealType: String
    
    init(from foodLog: FoodLog) {
        self.id = foodLog.id
        self.name = foodLog.name
        self.calories = foodLog.calories
        self.protein = foodLog.protein
        self.carbohydrates = foodLog.carbohydrates
        self.fat = foodLog.fat
        self.servingSize = foodLog.servingSize
        self.servingUnit = foodLog.servingUnit
        self.timestamp = foodLog.timestamp
        self.mealType = foodLog.mealType.rawValue
    }
}