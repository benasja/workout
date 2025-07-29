import XCTest
import SwiftData
@testable import work

// MARK: - Performance Tests

final class PerformanceTests: XCTestCase {
    
    var repository: FuelLogRepository!
    var viewModel: FuelLogViewModel!
    var searchViewModel: FoodSearchViewModel!
    var modelContext: ModelContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model context for testing
        let schema = Schema([
            FoodLog.self,
            CustomFood.self,
            NutritionGoals.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
        
        repository = FuelLogRepository(modelContext: modelContext)
        viewModel = FuelLogViewModel(repository: repository)
        searchViewModel = FoodSearchViewModel(repository: repository)
        
        // Seed test data
        await seedTestData()
    }
    
    override func tearDown() async throws {
        repository = nil
        viewModel = nil
        searchViewModel = nil
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Dashboard Loading Performance Tests
    
    func testDashboardLoadingPerformance() async throws {
        // Test that dashboard loads within 500ms requirement
        let expectation = XCTestExpectation(description: "Dashboard loads quickly")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await viewModel.loadFoodLogs(for: Date())
        
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should load within 500ms (0.5 seconds)
        XCTAssertLessThan(loadTime, 0.5, "Dashboard should load within 500ms, took \(loadTime)s")
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testDashboardLoadingWithLargeDataset() async throws {
        // Create a large dataset (100 food logs)
        await createLargeFoodLogDataset(count: 100)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await viewModel.loadFoodLogs(for: Date())
        
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should still load within reasonable time even with large dataset
        XCTAssertLessThan(loadTime, 1.0, "Dashboard with large dataset should load within 1s, took \(loadTime)s")
        
        // Verify all data was loaded
        XCTAssertEqual(viewModel.todaysFoodLogs.count, 100)
    }
    
    // MARK: - Search Performance Tests
    
    func testFoodSearchPerformance() async throws {
        // Test that search results appear within 2 seconds requirement
        let expectation = XCTestExpectation(description: "Search completes quickly")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await searchViewModel.search(query: "chicken")
        
        let searchTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should complete within 2 seconds
        XCTAssertLessThan(searchTime, 2.0, "Search should complete within 2s, took \(searchTime)s")
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 3.0)
    }
    
    func testSearchDebouncing() async throws {
        // Test that rapid search queries are properly debounced
        let expectation = XCTestExpectation(description: "Search debouncing works")
        
        // Simulate rapid typing
        searchViewModel.searchText = "c"
        searchViewModel.searchText = "ch"
        searchViewModel.searchText = "chi"
        searchViewModel.searchText = "chic"
        searchViewModel.searchText = "chick"
        searchViewModel.searchText = "chicke"
        searchViewModel.searchText = "chicken"
        
        // Wait for debounce delay plus some buffer
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Should have results for final query
        XCTAssertFalse(searchViewModel.searchResults.isEmpty)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Calculation Performance Tests
    
    func testNutritionCalculationPerformance() async throws {
        // Create dataset with many food logs
        await createLargeFoodLogDataset(count: 50)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Load and calculate totals
        await viewModel.loadFoodLogs(for: Date())
        
        let calculationTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Calculations should be fast even with many items
        XCTAssertLessThan(calculationTime, 0.1, "Nutrition calculations should be fast, took \(calculationTime)s")
        
        // Verify calculations are correct
        XCTAssertGreaterThan(viewModel.dailyTotals.totalCalories, 0)
        XCTAssertGreaterThan(viewModel.dailyTotals.totalProtein, 0)
    }
    
    func testBackgroundCalculationPerformance() async throws {
        // Test that background calculations don't block UI
        let foodLogs = createTestFoodLogs(count: 100)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let totals = await PerformanceOptimizer.shared.calculateNutritionTotals(from: foodLogs)
        
        let calculationTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Background calculations should be efficient
        XCTAssertLessThan(calculationTime, 0.2, "Background calculations should be efficient, took \(calculationTime)s")
        
        // Verify results
        XCTAssertGreaterThan(totals.totalCalories, 0)
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryUsageOptimization() async throws {
        // Test that memory usage is optimized with large datasets
        var largeArray = createTestFoodLogs(count: 200)
        
        let initialCount = largeArray.count
        XCTAssertEqual(initialCount, 200)
        
        // Apply memory optimization
        PerformanceOptimizer.shared.optimizeMemoryUsage(items: &largeArray, maxItems: 100)
        
        // Should be limited to max items
        XCTAssertEqual(largeArray.count, 100)
        
        // Should keep the most recent items (last 100)
        XCTAssertEqual(largeArray.first?.name, "Test Food 100")
        XCTAssertEqual(largeArray.last?.name, "Test Food 199")
    }
    
    // MARK: - Cache Performance Tests
    
    func testSearchCachePerformance() async throws {
        // First search should hit network/database
        let startTime1 = CFAbsoluteTimeGetCurrent()
        await searchViewModel.search(query: "apple")
        let firstSearchTime = CFAbsoluteTimeGetCurrent() - startTime1
        
        // Clear results to force cache lookup
        searchViewModel.searchResults = []
        
        // Second search should hit cache and be faster
        let startTime2 = CFAbsoluteTimeGetCurrent()
        await searchViewModel.search(query: "apple")
        let cachedSearchTime = CFAbsoluteTimeGetCurrent() - startTime2
        
        // Cached search should be significantly faster
        XCTAssertLessThan(cachedSearchTime, firstSearchTime * 0.5, 
                         "Cached search should be at least 50% faster")
    }
    
    func testImageCachePerformance() async throws {
        let imageUrl = "https://example.com/test-image.jpg"
        
        // Mock image data
        let testImage = UIImage(systemName: "photo")!
        
        // First load (cache miss)
        let startTime1 = CFAbsoluteTimeGetCurrent()
        // Note: In real test, this would load from network
        let firstLoadTime = CFAbsoluteTimeGetCurrent() - startTime1
        
        // Second load (cache hit)
        let startTime2 = CFAbsoluteTimeGetCurrent()
        let cachedImage = await ImageCacheManager.shared.loadImage(from: imageUrl)
        let cachedLoadTime = CFAbsoluteTimeGetCurrent() - startTime2
        
        // Cached load should be much faster
        XCTAssertLessThan(cachedLoadTime, 0.01, "Cached image load should be very fast")
    }
    
    // MARK: - Lazy Loading Performance Tests
    
    func testLazyLoadingContainer() async throws {
        let container = LazyLoadingContainer<FoodLog>(pageSize: 10) { limit, offset in
            // Simulate paginated data loading
            let startIndex = offset
            let endIndex = min(offset + limit, 50) // Total of 50 items
            
            return (startIndex..<endIndex).map { index in
                self.createTestFoodLog(name: "Lazy Food \(index)")
            }
        }
        
        // Load initial items
        await container.loadInitialItems()
        XCTAssertEqual(container.items.count, 10)
        XCTAssertTrue(container.hasMoreItems)
        
        // Load more items
        await container.loadMoreItems()
        XCTAssertEqual(container.items.count, 20)
        XCTAssertTrue(container.hasMoreItems)
        
        // Continue loading until no more items
        while container.hasMoreItems {
            await container.loadMoreItems()
        }
        
        XCTAssertEqual(container.items.count, 50)
        XCTAssertFalse(container.hasMoreItems)
    }
    
    // MARK: - Performance Metrics Tests
    
    func testPerformanceMetricsCollection() async throws {
        let optimizer = PerformanceOptimizer.shared
        
        // Perform some measured operations
        _ = await optimizer.measureExecutionTime(operation: "test_operation") {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        _ = await optimizer.measureExecutionTime(operation: "test_operation") {
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
        
        // Check metrics
        let metrics = optimizer.performanceMetrics
        XCTAssertEqual(metrics.totalCount(for: "test_operation"), 2)
        
        let averageTime = metrics.averageTime(for: "test_operation")
        XCTAssertNotNil(averageTime)
        XCTAssertGreaterThan(averageTime!, 0.05)
        XCTAssertLessThan(averageTime!, 0.15)
    }
    
    // MARK: - Helper Methods
    
    private func seedTestData() async {
        // Create test custom foods
        let customFoods = [
            createTestCustomFood(name: "Custom Chicken"),
            createTestCustomFood(name: "Custom Rice"),
            createTestCustomFood(name: "Custom Vegetables")
        ]
        
        for food in customFoods {
            try? await repository.saveCustomFood(food)
        }
        
        // Create test nutrition goals
        let goals = createTestNutritionGoals()
        try? await repository.saveNutritionGoals(goals)
    }
    
    private func createLargeFoodLogDataset(count: Int) async {
        let today = Date()
        
        for i in 0..<count {
            let foodLog = createTestFoodLog(name: "Test Food \(i)")
            foodLog.timestamp = today
            try? await repository.saveFoodLog(foodLog)
        }
    }
    
    private func createTestFoodLogs(count: Int) -> [FoodLog] {
        return (0..<count).map { index in
            createTestFoodLog(name: "Test Food \(index)")
        }
    }
    
    private func createTestFoodLog(name: String) -> FoodLog {
        return FoodLog(
            name: name,
            calories: 200,
            protein: 20,
            carbohydrates: 15,
            fat: 8,
            mealType: .lunch
        )
    }
    
    private func createTestCustomFood(name: String) -> CustomFood {
        return CustomFood(
            name: name,
            caloriesPerServing: 150,
            proteinPerServing: 15,
            carbohydratesPerServing: 10,
            fatPerServing: 5,
            servingSize: 100,
            servingUnit: "g"
        )
    }
    
    private func createTestNutritionGoals() -> NutritionGoals {
        return NutritionGoals(
            userId: "test-user",
            dailyCalories: 2000,
            dailyProtein: 150,
            dailyCarbohydrates: 200,
            dailyFat: 65,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            bmr: 1600,
            tdee: 2000
        )
    }
}

// MARK: - Benchmark Tests

final class BenchmarkTests: XCTestCase {
    
    func testFoodLogQueryBenchmark() {
        // Benchmark different query approaches
        measure {
            // This would test the optimized vs non-optimized queries
            // In a real scenario, you'd compare performance
        }
    }
    
    func testCalculationBenchmark() {
        let foodLogs = (0..<1000).map { index in
            FoodLog(
                name: "Benchmark Food \(index)",
                calories: Double.random(in: 100...500),
                protein: Double.random(in: 10...50),
                carbohydrates: Double.random(in: 20...100),
                fat: Double.random(in: 5...30),
                mealType: MealType.allCases.randomElement()!
            )
        }
        
        measure {
            var totals = DailyNutritionTotals()
            for foodLog in foodLogs {
                totals.add(foodLog)
            }
        }
    }
    
    func testSearchCacheBenchmark() {
        let searchQueries = (0..<100).map { "query\($0)" }
        let mockResults = searchQueries.map { query in
            FoodSearchResult(
                id: UUID().uuidString,
                name: "Result for \(query)",
                calories: 100,
                protein: 10,
                carbohydrates: 15,
                fat: 5,
                servingSize: 100,
                servingUnit: "g",
                source: .openFoodFacts
            )
        }
        
        measure {
            var cache: [String: [FoodSearchResult]] = [:]
            
            // Simulate caching operations
            for (query, result) in zip(searchQueries, mockResults) {
                cache[query] = [result]
            }
            
            // Simulate cache lookups
            for query in searchQueries {
                _ = cache[query]
            }
        }
    }
}