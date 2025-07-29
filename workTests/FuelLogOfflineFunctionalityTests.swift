import XCTest
import SwiftData
@testable import work

/// Integration tests for offline functionality in Fuel Log
@MainActor
final class FuelLogOfflineFunctionalityTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var repository: FuelLogRepository!
    var cacheManager: FuelLogCacheManager!
    var dataSyncManager: FuelLogDataSyncManager!
    
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
        dataSyncManager = FuelLogDataSyncManager(repository: repository)
        
        // Clear any existing cache
        await cacheManager.clearAllCache()
    }
    
    override func tearDown() async throws {
        await cacheManager.clearAllCache()
        try await super.tearDown()
    }
    
    // MARK: - Cache Functionality Tests
    
    func testCacheFoodSearchResult() async throws {
        // Given
        let searchResult = FoodSearchResult(
            id: "test-food-1",
            name: "Test Food",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            servingSize: 100,
            servingUnit: "g",
            source: .openFoodFacts
        )
        
        // When
        cacheManager.cacheFoodSearchResult(searchResult, for: "test-key")
        
        // Then
        let cachedResult = cacheManager.getCachedFoodSearchResult(for: "test-key")
        XCTAssertNotNil(cachedResult)
        XCTAssertEqual(cachedResult?.id, searchResult.id)
        XCTAssertEqual(cachedResult?.name, searchResult.name)
        XCTAssertEqual(cachedResult?.calories, searchResult.calories)
    }
    
    func testCacheBarcodeResult() async throws {
        // Given
        let barcode = "1234567890123"
        let searchResult = FoodSearchResult(
            id: "barcode-food-1",
            name: "Barcode Food",
            calories: 200,
            protein: 20,
            carbohydrates: 25,
            fat: 8,
            servingSize: 100,
            servingUnit: "g",
            source: .openFoodFacts
        )
        
        // When
        cacheManager.cacheBarcodeResult(searchResult, for: barcode)
        
        // Then
        let cachedResult = cacheManager.getCachedBarcodeResult(for: barcode)
        XCTAssertNotNil(cachedResult)
        XCTAssertEqual(cachedResult?.id, searchResult.id)
        XCTAssertEqual(cachedResult?.name, searchResult.name)
    }
    
    func testCacheSearchResults() async throws {
        // Given
        let query = "apple"
        let searchResults = [
            FoodSearchResult(
                id: "apple-1",
                name: "Red Apple",
                calories: 80,
                protein: 0.5,
                carbohydrates: 20,
                fat: 0.2,
                servingSize: 150,
                servingUnit: "g",
                source: .openFoodFacts
            ),
            FoodSearchResult(
                id: "apple-2",
                name: "Green Apple",
                calories: 75,
                protein: 0.4,
                carbohydrates: 19,
                fat: 0.1,
                servingSize: 140,
                servingUnit: "g",
                source: .openFoodFacts
            )
        ]
        
        // When
        cacheManager.cacheSearchResults(searchResults, for: query)
        
        // Then
        let cachedResults = cacheManager.getCachedSearchResults(for: query)
        XCTAssertNotNil(cachedResults)
        XCTAssertEqual(cachedResults?.count, 2)
        XCTAssertEqual(cachedResults?.first?.name, "Red Apple")
        XCTAssertEqual(cachedResults?.last?.name, "Green Apple")
    }
    
    func testCacheExpiration() async throws {
        // Given
        let searchResult = FoodSearchResult(
            id: "expiring-food",
            name: "Expiring Food",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            servingSize: 100,
            servingUnit: "g",
            source: .openFoodFacts
        )
        
        // When - Cache the result
        cacheManager.cacheFoodSearchResult(searchResult, for: "expiring-key")
        
        // Then - Should be available immediately
        let cachedResult = cacheManager.getCachedFoodSearchResult(for: "expiring-key")
        XCTAssertNotNil(cachedResult)
        
        // When - Clear expired cache (this will remove items older than 7 days)
        await cacheManager.clearExpiredCache()
        
        // Then - Should still be available (not expired yet)
        let stillCachedResult = cacheManager.getCachedFoodSearchResult(for: "expiring-key")
        XCTAssertNotNil(stillCachedResult)
    }
    
    func testCacheStatistics() async throws {
        // Given
        let searchResults = [
            FoodSearchResult(
                id: "stats-food-1",
                name: "Stats Food 1",
                calories: 100,
                protein: 10,
                carbohydrates: 15,
                fat: 5,
                servingSize: 100,
                servingUnit: "g",
                source: .openFoodFacts
            ),
            FoodSearchResult(
                id: "stats-food-2",
                name: "Stats Food 2",
                calories: 150,
                protein: 15,
                carbohydrates: 20,
                fat: 7,
                servingSize: 120,
                servingUnit: "g",
                source: .openFoodFacts
            )
        ]
        
        // When
        for (index, result) in searchResults.enumerated() {
            cacheManager.cacheFoodSearchResult(result, for: "stats-key-\(index)")
        }
        
        // Then
        let stats = cacheManager.getCacheStatistics()
        XCTAssertGreaterThan(stats.itemCount, 0)
        XCTAssertGreaterThan(stats.totalSize, 0)
        XCTAssertGreaterThan(stats.maxSize, 0)
    }
    
    // MARK: - Data Persistence Tests
    
    func testPersistCustomFood() async throws {
        // Given
        let customFood = CustomFood(
            name: "Test Custom Food",
            caloriesPerServing: 250,
            proteinPerServing: 20,
            carbohydratesPerServing: 30,
            fatPerServing: 10,
            servingSize: 1.0,
            servingUnit: "serving"
        )
        
        // When
        try await repository.saveCustomFood(customFood)
        
        // Then
        let savedFoods = try await repository.fetchCustomFoods()
        XCTAssertEqual(savedFoods.count, 1)
        XCTAssertEqual(savedFoods.first?.name, "Test Custom Food")
        XCTAssertEqual(savedFoods.first?.caloriesPerServing, 250)
    }
    
    func testPersistNutritionGoals() async throws {
        // Given
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
        
        // When
        try await repository.saveNutritionGoals(goals)
        
        // Then
        let savedGoals = try await repository.fetchNutritionGoals()
        XCTAssertNotNil(savedGoals)
        XCTAssertEqual(savedGoals?.dailyCalories, 2000)
        XCTAssertEqual(savedGoals?.dailyProtein, 150)
        XCTAssertEqual(savedGoals?.activityLevel, .moderatelyActive)
    }
    
    func testPersistFoodLogs() async throws {
        // Given
        let today = Date()
        let foodLog1 = FoodLog(
            timestamp: today,
            name: "Breakfast Food",
            calories: 300,
            protein: 15,
            carbohydrates: 40,
            fat: 12,
            mealType: .breakfast
        )
        
        let foodLog2 = FoodLog(
            timestamp: today,
            name: "Lunch Food",
            calories: 500,
            protein: 25,
            carbohydrates: 60,
            fat: 20,
            mealType: .lunch
        )
        
        // When
        try await repository.saveFoodLog(foodLog1)
        try await repository.saveFoodLog(foodLog2)
        
        // Then
        let savedLogs = try await repository.fetchFoodLogs(for: today)
        XCTAssertEqual(savedLogs.count, 2)
        
        let breakfastLogs = savedLogs.filter { $0.mealType == .breakfast }
        let lunchLogs = savedLogs.filter { $0.mealType == .lunch }
        
        XCTAssertEqual(breakfastLogs.count, 1)
        XCTAssertEqual(lunchLogs.count, 1)
        XCTAssertEqual(breakfastLogs.first?.name, "Breakfast Food")
        XCTAssertEqual(lunchLogs.first?.name, "Lunch Food")
    }
    
    // MARK: - Data Export/Import Tests
    
    func testDataExport() async throws {
        // Given - Create test data
        let customFood = CustomFood(
            name: "Export Test Food",
            caloriesPerServing: 200,
            proteinPerServing: 15,
            carbohydratesPerServing: 25,
            fatPerServing: 8
        )
        
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
        
        let foodLog = FoodLog(
            name: "Export Test Log",
            calories: 150,
            protein: 12,
            carbohydrates: 20,
            fat: 6,
            mealType: .snacks
        )
        
        try await repository.saveCustomFood(customFood)
        try await repository.saveNutritionGoals(goals)
        try await repository.saveFoodLog(foodLog)
        
        // When
        let exportData = try await dataSyncManager.exportNutritionData()
        
        // Then
        XCTAssertGreaterThan(exportData.count, 0)
        
        // Verify the exported data can be decoded
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        XCTAssertNoThrow(try decoder.decode([String: Any].self, from: exportData))
    }
    
    func testDataImport() async throws {
        // Given - Create export data
        let customFood = CustomFood(
            name: "Import Test Food",
            caloriesPerServing: 180,
            proteinPerServing: 12,
            carbohydratesPerServing: 22,
            fatPerServing: 7
        )
        
        try await repository.saveCustomFood(customFood)
        let exportData = try await dataSyncManager.exportNutritionData()
        
        // Clear existing data
        try await repository.deleteCustomFood(customFood)
        
        // When
        try await dataSyncManager.importNutritionData(exportData, mergeStrategy: .overwrite)
        
        // Then
        let importedFoods = try await repository.fetchCustomFoods()
        XCTAssertEqual(importedFoods.count, 1)
        XCTAssertEqual(importedFoods.first?.name, "Import Test Food")
    }
    
    // MARK: - Data Cleanup Tests
    
    func testDataCleanup() async throws {
        // Given - Create old data
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        let oldFoodLog = FoodLog(
            timestamp: twoYearsAgo,
            name: "Old Food Log",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            mealType: .breakfast
        )
        
        let recentFoodLog = FoodLog(
            name: "Recent Food Log",
            calories: 200,
            protein: 20,
            carbohydrates: 25,
            fat: 8,
            mealType: .lunch
        )
        
        try await repository.saveFoodLog(oldFoodLog)
        try await repository.saveFoodLog(recentFoodLog)
        
        // When
        try await dataSyncManager.performDataCleanup()
        
        // Then
        let remainingLogs = try await repository.fetchFoodLogsByDateRange(
            from: Date.distantPast,
            to: Date()
        )
        
        // Should only have recent logs (old ones cleaned up)
        XCTAssertEqual(remainingLogs.count, 1)
        XCTAssertEqual(remainingLogs.first?.name, "Recent Food Log")
    }
    
    func testStorageStatistics() async throws {
        // Given - Create test data
        let customFood = CustomFood(
            name: "Stats Test Food",
            caloriesPerServing: 150,
            proteinPerServing: 10,
            carbohydratesPerServing: 20,
            fatPerServing: 6
        )
        
        let foodLog = FoodLog(
            name: "Stats Test Log",
            calories: 100,
            protein: 8,
            carbohydrates: 15,
            fat: 4,
            mealType: .breakfast
        )
        
        try await repository.saveCustomFood(customFood)
        try await repository.saveFoodLog(foodLog)
        
        // Cache some data
        let searchResult = FoodSearchResult(
            id: "stats-cached-food",
            name: "Cached Food",
            calories: 120,
            protein: 9,
            carbohydrates: 18,
            fat: 5,
            servingSize: 100,
            servingUnit: "g",
            source: .openFoodFacts
        )
        cacheManager.cacheFoodSearchResult(searchResult, for: "stats-cache-key")
        
        // When
        let stats = await dataSyncManager.getStorageStatistics()
        
        // Then
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.customFoodsCount, 1)
        XCTAssertEqual(stats?.foodLogsCount, 1)
        XCTAssertGreaterThan(stats?.cacheItemsCount ?? 0, 0)
        XCTAssertGreaterThan(stats?.totalDataSize ?? 0, 0)
    }
    
    // MARK: - Offline Search Tests
    
    func testOfflineCustomFoodSearch() async throws {
        // Given
        let customFoods = [
            CustomFood(
                name: "Apple Pie",
                caloriesPerServing: 300,
                proteinPerServing: 5,
                carbohydratesPerServing: 50,
                fatPerServing: 12
            ),
            CustomFood(
                name: "Apple Juice",
                caloriesPerServing: 120,
                proteinPerServing: 0.5,
                carbohydratesPerServing: 30,
                fatPerServing: 0.2
            ),
            CustomFood(
                name: "Banana Bread",
                caloriesPerServing: 250,
                proteinPerServing: 4,
                carbohydratesPerServing: 45,
                fatPerServing: 8
            )
        ]
        
        for food in customFoods {
            try await repository.saveCustomFood(food)
        }
        
        // When
        let appleResults = try await repository.searchCustomFoods(query: "apple")
        let allResults = try await repository.searchCustomFoods(query: "")
        
        // Then
        XCTAssertEqual(appleResults.count, 2)
        XCTAssertEqual(allResults.count, 3)
        
        let appleNames = appleResults.map { $0.name }.sorted()
        XCTAssertEqual(appleNames, ["Apple Juice", "Apple Pie"])
    }
    
    // MARK: - Error Handling Tests
    
    func testPersistenceErrorHandling() async throws {
        // Given - Invalid custom food (empty name)
        let invalidFood = CustomFood(
            name: "",
            caloriesPerServing: -100, // Invalid negative calories
            proteinPerServing: 10,
            carbohydratesPerServing: 15,
            fatPerServing: 5
        )
        
        // When/Then
        do {
            try await repository.saveCustomFood(invalidFood)
            XCTFail("Should have thrown an error for invalid food")
        } catch {
            XCTAssertTrue(error is FuelLogError)
        }
    }
    
    func testCacheMemoryManagement() async throws {
        // Given - Create many cache entries to test memory management
        for i in 0..<300 { // Exceed the cache limit
            let searchResult = FoodSearchResult(
                id: "memory-test-\(i)",
                name: "Memory Test Food \(i)",
                calories: Double(100 + i),
                protein: Double(10 + i),
                carbohydrates: Double(15 + i),
                fat: Double(5 + i),
                servingSize: 100,
                servingUnit: "g",
                source: .openFoodFacts
            )
            
            cacheManager.cacheFoodSearchResult(searchResult, for: "memory-key-\(i)")
        }
        
        // When - Get cache statistics
        let stats = cacheManager.getCacheStatistics()
        
        // Then - Should not exceed memory limits
        XCTAssertLessThanOrEqual(stats.itemCount, 250) // Some items may be evicted
        XCTAssertLessThanOrEqual(stats.totalSize, stats.maxSize)
    }
}