import XCTest
import SwiftData
@testable import work

// MARK: - Fuel Log Performance Benchmarks

final class FuelLogPerformanceBenchmarks: XCTestCase {
    
    var repository: FuelLogRepository!
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
    }
    
    override func tearDown() async throws {
        repository = nil
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Database Query Benchmarks
    
    func testFoodLogQueryPerformance() async throws {
        // Create test data
        await createTestFoodLogs(count: 1000)
        
        // Benchmark optimized query
        measure {
            let expectation = XCTestExpectation(description: "Query completion")
            
            Task {
                do {
                    _ = try await repository.fetchFoodLogs(for: Date())
                    expectation.fulfill()
                } catch {
                    XCTFail("Query failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testPaginatedQueryPerformance() async throws {
        // Create large dataset
        await createTestFoodLogs(count: 500)
        
        // Benchmark paginated queries
        measure {
            let expectation = XCTestExpectation(description: "Paginated query completion")
            
            Task {
                do {
                    // Test multiple pages
                    for page in 0..<5 {
                        _ = try await repository.fetchFoodLogs(
                            for: Date(),
                            limit: 20,
                            offset: page * 20
                        )
                    }
                    expectation.fulfill()
                } catch {
                    XCTFail("Paginated query failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testCustomFoodSearchPerformance() async throws {
        // Create test custom foods
        await createTestCustomFoods(count: 200)
        
        // Benchmark search queries
        measure {
            let expectation = XCTestExpectation(description: "Search completion")
            
            Task {
                do {
                    _ = try await repository.searchCustomFoods(query: "test")
                    expectation.fulfill()
                } catch {
                    XCTFail("Search failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 3.0)
        }
    }
    
    // MARK: - Calculation Benchmarks
    
    func testNutritionCalculationPerformance() {
        let foodLogs = createLargeFoodLogArray(count: 1000)
        
        measure {
            var totals = DailyNutritionTotals()
            for foodLog in foodLogs {
                totals.add(foodLog)
            }
        }
    }
    
    func testBackgroundCalculationPerformance() {
        let foodLogs = createLargeFoodLogArray(count: 500)
        
        measure {
            let expectation = XCTestExpectation(description: "Background calculation")
            
            Task {
                _ = await PerformanceOptimizer.shared.calculateNutritionTotals(from: foodLogs)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testMacroValidationPerformance() {
        let foodLogs = createLargeFoodLogArray(count: 200)
        
        measure {
            let expectation = XCTestExpectation(description: "Macro validation")
            
            Task {
                _ = await PerformanceOptimizer.shared.validateMacros(for: foodLogs)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 3.0)
        }
    }
    
    // MARK: - Cache Performance Benchmarks
    
    func testSearchCachePerformance() {
        let cacheManager = FuelLogCacheManager.shared
        let testResults = createTestSearchResults(count: 50)
        
        // Benchmark cache write operations
        measure {
            for i in 0..<100 {
                cacheManager.cacheSearchResults(testResults, for: "query\(i)")
            }
        }
    }
    
    func testSearchCacheRetrievalPerformance() {
        let cacheManager = FuelLogCacheManager.shared
        let testResults = createTestSearchResults(count: 20)
        
        // Pre-populate cache
        for i in 0..<100 {
            cacheManager.cacheSearchResults(testResults, for: "query\(i)")
        }
        
        // Benchmark cache read operations
        measure {
            for i in 0..<100 {
                _ = cacheManager.getCachedSearchResults(for: "query\(i)")
            }
        }
    }
    
    func testImageCachePerformance() {
        let imageCache = ImageCacheManager.shared
        let testUrls = (0..<50).map { "https://example.com/image\($0).jpg" }
        
        measure {
            let expectation = XCTestExpectation(description: "Image cache operations")
            
            Task {
                // Simulate cache operations
                for url in testUrls {
                    _ = await imageCache.loadImage(from: url)
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Memory Usage Benchmarks
    
    func testMemoryOptimizationPerformance() {
        var largeArray = createLargeFoodLogArray(count: 1000)
        
        measure {
            PerformanceOptimizer.shared.optimizeMemoryUsage(items: &largeArray, maxItems: 100)
        }
    }
    
    func testLazyLoadingPerformance() {
        let container = LazyLoadingContainer<FoodLog>(pageSize: 20) { limit, offset in
            // Simulate data loading
            return (0..<limit).map { index in
                self.createTestFoodLog(name: "Lazy Food \(offset + index)")
            }
        }
        
        measure {
            let expectation = XCTestExpectation(description: "Lazy loading")
            
            Task {
                await container.loadInitialItems()
                
                // Load several pages
                for _ in 0..<5 {
                    await container.loadMoreItems()
                }
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - Network Performance Benchmarks
    
    func testNetworkRequestDebouncingPerformance() {
        let networkManager = FoodNetworkManager.shared
        
        measure {
            let expectation = XCTestExpectation(description: "Request debouncing")
            
            Task {
                // Simulate rapid requests (should be debounced)
                let tasks = (0..<10).map { index in
                    Task {
                        do {
                            _ = try await networkManager.searchFoodByName("test\(index)")
                        } catch {
                            // Expected to fail in test environment
                        }
                    }
                }
                
                // Wait for all tasks
                for task in tasks {
                    await task.value
                }
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - UI Performance Benchmarks
    
    func testViewModelLoadingPerformance() async throws {
        let viewModel = FuelLogViewModel(repository: repository)
        
        // Create test data
        await createTestFoodLogs(count: 100)
        
        measure {
            let expectation = XCTestExpectation(description: "ViewModel loading")
            
            Task {
                await viewModel.loadFoodLogs(for: Date())
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 3.0)
        }
    }
    
    func testSearchViewModelPerformance() async throws {
        let searchViewModel = FoodSearchViewModel(repository: repository)
        
        // Create test custom foods
        await createTestCustomFoods(count: 50)
        
        measure {
            let expectation = XCTestExpectation(description: "Search ViewModel")
            
            Task {
                await searchViewModel.search(query: "test")
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - Stress Tests
    
    func testHighVolumeDataHandling() async throws {
        // Test with very large dataset
        await createTestFoodLogs(count: 5000)
        
        let viewModel = FuelLogViewModel(repository: repository)
        
        measure {
            let expectation = XCTestExpectation(description: "High volume data")
            
            Task {
                await viewModel.loadFoodLogs(for: Date())
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testConcurrentOperationsPerformance() async throws {
        let viewModel = FuelLogViewModel(repository: repository)
        
        measure {
            let expectation = XCTestExpectation(description: "Concurrent operations")
            
            Task {
                // Simulate concurrent operations
                async let loadTask = viewModel.loadFoodLogs(for: Date())
                async let goalsTask = viewModel.loadNutritionGoals()
                
                await loadTask
                await goalsTask
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestFoodLogs(count: Int) async {
        let today = Date()
        
        for i in 0..<count {
            let foodLog = createTestFoodLog(name: "Test Food \(i)")
            foodLog.timestamp = today
            try? await repository.saveFoodLog(foodLog)
        }
    }
    
    private func createTestCustomFoods(count: Int) async {
        for i in 0..<count {
            let customFood = CustomFood(
                name: "Test Custom Food \(i)",
                caloriesPerServing: Double.random(in: 100...500),
                proteinPerServing: Double.random(in: 10...50),
                carbohydratesPerServing: Double.random(in: 20...100),
                fatPerServing: Double.random(in: 5...30),
                servingSize: 100,
                servingUnit: "g"
            )
            try? await repository.saveCustomFood(customFood)
        }
    }
    
    private func createLargeFoodLogArray(count: Int) -> [FoodLog] {
        return (0..<count).map { index in
            createTestFoodLog(name: "Array Food \(index)")
        }
    }
    
    private func createTestFoodLog(name: String) -> FoodLog {
        return FoodLog(
            name: name,
            calories: Double.random(in: 100...500),
            protein: Double.random(in: 10...50),
            carbohydrates: Double.random(in: 20...100),
            fat: Double.random(in: 5...30),
            mealType: MealType.allCases.randomElement()!
        )
    }
    
    private func createTestSearchResults(count: Int) -> [FoodSearchResult] {
        return (0..<count).map { index in
            FoodSearchResult(
                id: "test-\(index)",
                name: "Test Result \(index)",
                calories: Double.random(in: 100...400),
                protein: Double.random(in: 10...40),
                carbohydrates: Double.random(in: 20...80),
                fat: Double.random(in: 5...25),
                servingSize: 100,
                servingUnit: "g",
                source: .openFoodFacts
            )
        }
    }
}

// MARK: - Performance Comparison Tests

final class PerformanceComparisonTests: XCTestCase {
    
    func testOptimizedVsUnoptimizedQueries() {
        // This would compare optimized queries with basic queries
        // to demonstrate performance improvements
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            // Optimized query simulation
            let _ = PerformanceOptimizer.shared.createOptimizedFoodLogDescriptor(for: Date())
        }
    }
    
    func testCachedVsUncachedOperations() {
        let cacheManager = FuelLogCacheManager.shared
        let testResults = [
            FoodSearchResult(
                id: "test",
                name: "Test Food",
                calories: 200,
                protein: 20,
                carbohydrates: 30,
                fat: 10,
                servingSize: 100,
                servingUnit: "g",
                source: .openFoodFacts
            )
        ]
        
        // Cache the results first
        cacheManager.cacheSearchResults(testResults, for: "test-query")
        
        measure(metrics: [XCTClockMetric()]) {
            // Cached retrieval should be very fast
            _ = cacheManager.getCachedSearchResults(for: "test-query")
        }
    }
    
    func testBackgroundVsForegroundCalculations() {
        let foodLogs = (0..<100).map { index in
            FoodLog(
                name: "Test Food \(index)",
                calories: 200,
                protein: 20,
                carbohydrates: 30,
                fat: 10,
                mealType: .lunch
            )
        }
        
        // Test foreground calculation
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            var totals = DailyNutritionTotals()
            for foodLog in foodLogs {
                totals.add(foodLog)
            }
        }
    }
}