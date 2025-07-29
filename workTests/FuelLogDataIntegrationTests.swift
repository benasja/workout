import XCTest
import SwiftData
@testable import work

/// Integration tests for Fuel Log data persistence and offline functionality
@MainActor
final class FuelLogDataIntegrationTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var repository: FuelLogRepository!
    var viewModel: FuelLogViewModel!
    var cacheManager: FuelLogCacheManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model container for testing
        let schema = Schema([
            FoodLog.self,
            CustomFood.self,
            NutritionGoals.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
        
        // Initialize components
        repository = FuelLogRepository(modelContext: modelContext)
        cacheManager = FuelLogCacheManager.shared
        
        // Create data sync manager
        let dataSyncManager = FuelLogDataSyncManager(repository: repository)
        
        // Initialize view model with all dependencies
        viewModel = FuelLogViewModel(
            repository: repository,
            healthKitManager: nil,
            dataSyncManager: dataSyncManager
        )
        
        // Clear any existing cache
        await cacheManager.clearAllCache()
    }
    
    override func tearDown() async throws {
        await cacheManager.clearAllCache()
        try await super.tearDown()
    }
    
    // MARK: - Integration Tests
    
    func testCompleteDataFlow() async throws {
        // Given - Create nutrition goals
        let goals = NutritionGoals(
            dailyCalories: 2000,
            dailyProtein: 150,
            dailyCarbohydrates: 250,
            dailyFat: 67,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            bmr: 1600,
            tdee: 2000
        )
        
        // When - Update goals through view model
        await viewModel.updateNutritionGoals(goals)
        
        // Then - Goals should be persisted and loaded
        XCTAssertNotNil(viewModel.nutritionGoals)
        XCTAssertEqual(viewModel.nutritionGoals?.dailyCalories, 2000)
        
        // Given - Create a food log
        let foodLog = FoodLog(
            name: "Integration Test Food",
            calories: 300,
            protein: 20,
            carbohydrates: 30,
            fat: 12,
            mealType: .breakfast
        )
        
        // When - Log food through view model
        await viewModel.logFood(foodLog)
        
        // Then - Food should be logged and totals updated
        XCTAssertEqual(viewModel.todaysFoodLogs.count, 1)
        XCTAssertEqual(viewModel.dailyTotals.totalCalories, 300)
        XCTAssertEqual(viewModel.dailyTotals.totalProtein, 20)
        
        // When - Create custom food
        let customFood = CustomFood(
            name: "Integration Custom Food",
            caloriesPerServing: 150,
            proteinPerServing: 10,
            carbohydratesPerServing: 20,
            fatPerServing: 6
        )
        
        try await repository.saveCustomFood(customFood)
        
        // Then - Custom food should be persisted
        let savedFoods = try await repository.fetchCustomFoods()
        XCTAssertEqual(savedFoods.count, 1)
        XCTAssertEqual(savedFoods.first?.name, "Integration Custom Food")
    }
    
    func testOfflineDataPersistence() async throws {
        // Given - Create test data
        let customFood = CustomFood(
            name: "Offline Test Food",
            caloriesPerServing: 200,
            proteinPerServing: 15,
            carbohydratesPerServing: 25,
            fatPerServing: 8
        )
        
        let foodLog = FoodLog(
            name: "Offline Test Log",
            calories: 250,
            protein: 18,
            carbohydrates: 28,
            fat: 10,
            mealType: .lunch
        )
        
        // When - Save data offline
        try await repository.saveCustomFood(customFood)
        await viewModel.logFood(foodLog)
        
        // Then - Data should persist across app restarts (simulated by creating new instances)
        let newRepository = FuelLogRepository(modelContext: modelContext)
        let savedFoods = try await newRepository.fetchCustomFoods()
        let savedLogs = try await newRepository.fetchFoodLogs(for: Date())
        
        XCTAssertEqual(savedFoods.count, 1)
        XCTAssertEqual(savedLogs.count, 1)
        XCTAssertEqual(savedFoods.first?.name, "Offline Test Food")
        XCTAssertEqual(savedLogs.first?.name, "Offline Test Log")
    }
    
    func testCacheIntegration() async throws {
        // Given - Create a search result
        let searchResult = FoodSearchResult(
            id: "cache-integration-test",
            name: "Cache Integration Food",
            calories: 180,
            protein: 12,
            carbohydrates: 22,
            fat: 7,
            servingSize: 100,
            servingUnit: "g",
            source: .openFoodFacts
        )
        
        // When - Cache the result
        cacheManager.cacheFoodSearchResult(searchResult, for: "integration-test-key")
        
        // Then - Should be retrievable from cache
        let cachedResult = cacheManager.getCachedFoodSearchResult(for: "integration-test-key")
        XCTAssertNotNil(cachedResult)
        XCTAssertEqual(cachedResult?.name, "Cache Integration Food")
        XCTAssertEqual(cachedResult?.calories, 180)
        
        // When - Clear cache
        await cacheManager.clearAllCache()
        
        // Then - Should no longer be in cache
        let clearedResult = cacheManager.getCachedFoodSearchResult(for: "integration-test-key")
        XCTAssertNil(clearedResult)
    }
    
    func testDataExportImportIntegration() async throws {
        // Given - Create comprehensive test data
        let goals = NutritionGoals(
            dailyCalories: 2200,
            dailyProtein: 160,
            dailyCarbohydrates: 275,
            dailyFat: 73,
            activityLevel: .veryActive,
            goal: .bulk,
            bmr: 1700,
            tdee: 2200
        )
        
        let customFood = CustomFood(
            name: "Export Import Test Food",
            caloriesPerServing: 220,
            proteinPerServing: 16,
            carbohydratesPerServing: 28,
            fatPerServing: 9
        )
        
        let foodLog = FoodLog(
            name: "Export Import Test Log",
            calories: 180,
            protein: 14,
            carbohydrates: 24,
            fat: 7,
            mealType: .dinner
        )
        
        // Save initial data
        await viewModel.updateNutritionGoals(goals)
        try await repository.saveCustomFood(customFood)
        await viewModel.logFood(foodLog)
        
        // When - Export data
        let exportData = try await viewModel.exportNutritionData()
        XCTAssertGreaterThan(exportData.count, 0)
        
        // Clear existing data
        try await repository.deleteCustomFood(customFood)
        await viewModel.deleteFood(foodLog)
        
        // When - Import data
        try await viewModel.importNutritionData(exportData, mergeStrategy: .overwrite)
        
        // Then - Data should be restored
        let importedFoods = try await repository.fetchCustomFoods()
        XCTAssertEqual(importedFoods.count, 1)
        XCTAssertEqual(importedFoods.first?.name, "Export Import Test Food")
        
        // Note: Food logs and goals would also be imported, but we need to reload the view model
        // to see them in the published properties
    }
    
    func testStorageManagement() async throws {
        // Given - Create test data
        let customFood = CustomFood(
            name: "Storage Test Food",
            caloriesPerServing: 160,
            proteinPerServing: 11,
            carbohydratesPerServing: 21,
            fatPerServing: 6
        )
        
        let foodLog = FoodLog(
            name: "Storage Test Log",
            calories: 140,
            protein: 10,
            carbohydrates: 18,
            fat: 5,
            mealType: .snacks
        )
        
        try await repository.saveCustomFood(customFood)
        await viewModel.logFood(foodLog)
        
        // Cache some data
        let searchResult = FoodSearchResult(
            id: "storage-test-cached",
            name: "Storage Test Cached Food",
            calories: 120,
            protein: 8,
            carbohydrates: 16,
            fat: 4,
            servingSize: 100,
            servingUnit: "g",
            source: .openFoodFacts
        )
        cacheManager.cacheFoodSearchResult(searchResult, for: "storage-test-key")
        
        // When - Get storage statistics
        let stats = await viewModel.getStorageStatistics()
        
        // Then - Should have meaningful statistics
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.customFoodsCount, 1)
        XCTAssertEqual(stats?.foodLogsCount, 1)
        XCTAssertGreaterThan(stats?.cacheItemsCount ?? 0, 0)
        XCTAssertGreaterThan(stats?.totalDataSize ?? 0, 0)
    }
    
    func testErrorHandling() async throws {
        // Given - Invalid data
        let invalidFood = CustomFood(
            name: "", // Invalid empty name
            caloriesPerServing: -100, // Invalid negative calories
            proteinPerServing: 10,
            carbohydratesPerServing: 15,
            fatPerServing: 5
        )
        
        // When/Then - Should handle errors gracefully
        do {
            try await repository.saveCustomFood(invalidFood)
            XCTFail("Should have thrown an error for invalid food")
        } catch {
            XCTAssertTrue(error is FuelLogError)
            if let fuelLogError = error as? FuelLogError {
                XCTAssertEqual(fuelLogError, .invalidNutritionData)
            }
        }
    }
    
    func testViewModelDataSyncIntegration() async throws {
        // Given - View model with data sync manager
        XCTAssertNotNil(viewModel.dataSyncManager)
        
        // When - Check sync availability
        let isSyncEnabled = viewModel.isHealthKitSyncEnabled
        
        // Then - Should have sync capabilities
        XCTAssertFalse(isSyncEnabled) // Default is false
        
        // When - Enable sync
        viewModel.setHealthKitSyncEnabled(true)
        
        // Then - Should be enabled
        XCTAssertTrue(viewModel.isHealthKitSyncEnabled)
        
        // When - Try to perform full sync (will fail without HealthKit, but should not crash)
        do {
            try await viewModel.performFullSync()
        } catch {
            // Expected to fail in test environment without HealthKit
            XCTAssertTrue(error is SyncError)
        }
    }
}