import XCTest
import SwiftData
@testable import work

/// Performance tests specifically for dashboard loading and search operations
final class FuelLogDashboardPerformanceTests: XCTestCase {
    
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
        
        // Pre-populate with test data
        await populateTestData()
    }
    
    override func tearDown() async throws {
        repository = nil
        viewModel = nil
        searchViewModel = nil
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Dashboard Loading Performance Tests
    
    func testDashboardInitialLoadPerformance() throws {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = XCTestExpectation(description: "Dashboard load")
            
            Task {
                await viewModel.loadFoodLogs(for: Date())
                await viewModel.loadNutritionGoals()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testDashboardLoadWithLargeDataset() throws {
        // Create a large dataset
        let expectation = XCTestExpectation(description: "Large dataset creation")
        
        Task {
            await createLargeDataset(foodLogCount: 1000, customFoodCount: 200)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Measure dashboard load performance with large dataset
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(), XCTCPUMetric()]) {
            let loadExpectation = XCTestExpectation(description: "Dashboard load with large dataset")
            
            Task {
                await viewModel.loadFoodLogs(for: Date())
                expectation.fulfill()
            }
            
            wait(for: [loadExpectation], timeout: 10.0)
        }
    }
    
    func testDashboardDateNavigationPerformance() throws {
        let dates = generateDateRange(days: 30)
        
        measure(metrics: [XCTClockMetric()]) {
            let expectation = XCTestExpectation(description: "Date navigation")
            
            Task {
                for date in dates {
                    await viewModel.loadFoodLogs(for: date)
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 15.0)
        }
    }
    
    func testDashboardCalculationPerformance() throws {
        // Load a day with many food logs
        let expectation = XCTestExpectation(description: "Load food logs")
        
        Task {
            await viewModel.loadFoodLogs(for: Date())
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Measure calculation performance
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            viewModel.calculateDailyTotals()
            viewModel.updateNutritionProgress()
            viewModel.groupFoodLogsByMealType()
        }
    }
    
    func testDashboardRealTimeUpdatesPerformance() throws {
        let foodLogs = MockDataGenerator.shared.createMockFoodLogs(count: 20)
        
        measure(metrics: [XCTClockMetric()]) {
            let expectation = XCTestExpectation(description: "Real-time updates")
            
            Task {
                for foodLog in foodLogs {
                    await viewModel.logFood(foodLog)
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Search Performance Tests
    
    func testFoodSearchPerformance() throws {
        let searchQueries = [
            "chicken", "rice", "broccoli", "salmon", "eggs",
            "oatmeal", "banana", "yogurt", "spinach", "quinoa"
        ]
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = XCTestExpectation(description: "Food search")
            
            Task {
                for query in searchQueries {
                    await searchViewModel.search(query: query)
                    // Small delay to simulate user typing
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 15.0)
        }
    }
    
    func testLocalSearchPerformance() throws {
        let searchQueries = [
            "custom", "meal", "recipe", "homemade", "protein",
            "shake", "salad", "soup", "smoothie", "bowl"
        ]
        
        measure(metrics: [XCTClockMetric()]) {
            let expectation = XCTestExpectation(description: "Local search")
            
            Task {
                for query in searchQueries {
                    await searchViewModel.searchLocal(query: query)
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testSearchWithTypingSimulation() throws {
        let fullQuery = "chicken breast"
        let partialQueries = (1...fullQuery.count).map { index in
            String(fullQuery.prefix(index))
        }
        
        measure(metrics: [XCTClockMetric()]) {
            let expectation = XCTestExpectation(description: "Typing simulation")
            
            Task {
                for query in partialQueries {
                    await searchViewModel.search(query: query)
                    // Simulate typing delay
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testSearchResultCachingPerformance() throws {
        let cacheManager = FuelLogCacheManager.shared
        let testResults = MockDataGenerator.shared.createMockFoodSearchResults(count: 50)
        
        // Test cache write performance
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for i in 0..<100 {
                cacheManager.cacheSearchResults(testResults, for: "query\(i)")
            }
        }
        
        // Test cache read performance
        measure(metrics: [XCTClockMetric()]) {
            for i in 0..<100 {
                _ = cacheManager.getCachedSearchResults(for: "query\(i)")
            }
        }
    }
    
    // MARK: - Memory Usage Tests
    
    func testMemoryUsageWithLargeDataset() throws {
        measure(metrics: [XCTMemoryMetric()]) {
            let expectation = XCTestExpectation(description: "Memory usage test")
            
            Task {
                // Create and load large dataset
                await createLargeDataset(foodLogCount: 2000, customFoodCount: 500)
                
                // Load multiple days
                let dates = generateDateRange(days: 7)
                for date in dates {
                    await viewModel.loadFoodLogs(for: date)
                }
                
                // Perform multiple searches
                let queries = ["test", "food", "custom", "meal", "protein"]
                for query in queries {
                    await searchViewModel.search(query: query)
                }
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    func testMemoryLeakPrevention() throws {
        weak var weakViewModel: FuelLogViewModel?
        weak var weakSearchViewModel: FoodSearchViewModel?
        
        autoreleasepool {
            let testViewModel = FuelLogViewModel(repository: repository)
            let testSearchViewModel = FoodSearchViewModel(repository: repository)
            
            weakViewModel = testViewModel
            weakSearchViewModel = testSearchViewModel
            
            // Perform operations
            let expectation = XCTestExpectation(description: "Operations")
            
            Task {
                await testViewModel.loadFoodLogs(for: Date())
                await testSearchViewModel.search(query: "test")
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
        
        // Force garbage collection
        for _ in 0..<10 {
            autoreleasepool {
                _ = Array(0..<1000).map { $0 }
            }
        }
        
        // Check for memory leaks
        XCTAssertNil(weakViewModel, "FuelLogViewModel should be deallocated")
        XCTAssertNil(weakSearchViewModel, "FoodSearchViewModel should be deallocated")
    }
    
    // MARK: - Concurrent Operations Performance
    
    func testConcurrentDashboardOperations() throws {
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            let expectation = XCTestExpectation(description: "Concurrent operations")
            
            Task {
                async let loadFoodLogs = viewModel.loadFoodLogs(for: Date())
                async let loadGoals = viewModel.loadNutritionGoals()
                async let search1 = searchViewModel.search(query: "chicken")
                async let search2 = searchViewModel.search(query: "rice")
                
                await loadFoodLogs
                await loadGoals
                await search1
                await search2
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testConcurrentFoodLogging() throws {
        let foodLogs = MockDataGenerator.shared.createMockFoodLogs(count: 10)
        
        measure(metrics: [XCTClockMetric()]) {
            let expectation = XCTestExpectation(description: "Concurrent food logging")
            
            Task {
                await withTaskGroup(of: Void.self) { group in
                    for foodLog in foodLogs {
                        group.addTask {
                            await self.viewModel.logFood(foodLog)
                        }
                    }
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 15.0)
        }
    }
    
    // MARK: - Database Query Performance
    
    func testComplexQueryPerformance() throws {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = XCTestExpectation(description: "Complex queries")
            
            Task {
                // Date range query
                let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
                let endDate = Date()
                _ = try await repository.fetchFoodLogsByDateRange(from: startDate, to: endDate)
                
                // Multiple single-day queries
                let dates = generateDateRange(days: 7)
                for date in dates {
                    _ = try await repository.fetchFoodLogs(for: date)
                }
                
                // Custom food searches
                let queries = ["protein", "chicken", "rice", "vegetable", "fruit"]
                for query in queries {
                    _ = try await repository.searchCustomFoods(query: query)
                }
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 15.0)
        }
    }
    
    func testPaginatedQueryPerformance() throws {
        measure(metrics: [XCTClockMetric()]) {
            let expectation = XCTestExpectation(description: "Paginated queries")
            
            Task {
                // Simulate pagination through large dataset
                let pageSize = 20
                let totalPages = 10
                
                for page in 0..<totalPages {
                    let offset = page * pageSize
                    _ = try await repository.fetchFoodLogs(
                        for: Date(),
                        limit: pageSize,
                        offset: offset
                    )
                }
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - UI Responsiveness Tests
    
    func testUIResponsivenessDuringHeavyOperations() throws {
        measure(metrics: [XCTClockMetric()]) {
            let expectation = XCTestExpectation(description: "UI responsiveness")
            
            Task { @MainActor in
                // Simulate heavy operations on main actor
                await viewModel.loadFoodLogs(for: Date())
                
                // Simulate UI updates
                viewModel.calculateDailyTotals()
                viewModel.updateNutritionProgress()
                viewModel.groupFoodLogsByMealType()
                
                // Simulate user interactions
                viewModel.navigateToPreviousDay()
                await viewModel.loadFoodLogs(for: viewModel.selectedDate)
                
                viewModel.navigateToNextDay()
                await viewModel.loadFoodLogs(for: viewModel.selectedDate)
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Network Simulation Performance
    
    func testNetworkLatencySimulation() throws {
        let networkManager = FoodNetworkManager.shared
        
        measure(metrics: [XCTClockMetric()]) {
            let expectation = XCTestExpectation(description: "Network simulation")
            
            Task {
                // Simulate multiple network requests with artificial delay
                let queries = ["chicken", "rice", "broccoli", "salmon", "eggs"]
                
                for query in queries {
                    do {
                        // Add artificial delay to simulate network latency
                        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                        _ = try await networkManager.searchFoodByName(query)
                    } catch {
                        // Expected to fail in test environment
                    }
                }
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 15.0)
        }
    }
    
    // MARK: - Stress Tests
    
    func testStressTestDashboardOperations() throws {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(), XCTCPUMetric()]) {
            let expectation = XCTestExpectation(description: "Stress test")
            
            Task {
                // Rapid-fire operations
                for _ in 0..<100 {
                    await viewModel.loadFoodLogs(for: Date())
                    viewModel.calculateDailyTotals()
                    
                    // Simulate rapid date navigation
                    viewModel.navigateToPreviousDay()
                    viewModel.navigateToNextDay()
                }
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    func testStressTestSearchOperations() throws {
        let searchQueries = (0..<100).map { "query\($0)" }
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = XCTestExpectation(description: "Search stress test")
            
            Task {
                for query in searchQueries {
                    await searchViewModel.search(query: query)
                    await searchViewModel.searchLocal(query: query)
                }
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    // MARK: - Helper Methods
    
    private func populateTestData() async {
        // Create nutrition goals
        let goals = MockDataGenerator.shared.createMockNutritionGoals()
        try? await repository.saveNutritionGoals(goals)
        
        // Create food logs for today
        let todayLogs = MockDataGenerator.shared.createMockFoodLogsForDate(Date(), count: 8)
        for log in todayLogs {
            try? await repository.saveFoodLog(log)
        }
        
        // Create custom foods
        let customFoods = MockDataGenerator.shared.createMockCustomFoods(count: 20)
        for food in customFoods {
            try? await repository.saveCustomFood(food)
        }
    }
    
    private func createLargeDataset(foodLogCount: Int, customFoodCount: Int) async {
        // Create food logs across multiple dates
        let dates = generateDateRange(days: 30)
        let logsPerDay = foodLogCount / dates.count
        
        for date in dates {
            let logs = MockDataGenerator.shared.createMockFoodLogsForDate(date, count: logsPerDay)
            for log in logs {
                try? await repository.saveFoodLog(log)
            }
        }
        
        // Create custom foods
        let customFoods = MockDataGenerator.shared.createMockCustomFoods(count: customFoodCount)
        for food in customFoods {
            try? await repository.saveCustomFood(food)
        }
    }
    
    private func generateDateRange(days: Int) -> [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<days).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: -dayOffset, to: today)
        }
    }
}

// MARK: - Performance Comparison Tests

final class FuelLogPerformanceComparisonTests: XCTestCase {
    
    func testOptimizedVsUnoptimizedQueries() {
        let repository = createTestRepository()
        
        // Populate with test data
        let expectation = XCTestExpectation(description: "Data population")
        Task {
            let logs = MockDataGenerator.shared.createMockFoodLogs(count: 500)
            for log in logs {
                try? await repository.saveFoodLog(log)
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
        
        // Test unoptimized query
        measure(metrics: [XCTClockMetric()]) {
            let unoptimizedExpectation = XCTestExpectation(description: "Unoptimized query")
            
            Task {
                // Simulate unoptimized query (fetching all then filtering)
                let allLogs = try? await repository.fetchFoodLogsByDateRange(
                    from: Date.distantPast,
                    to: Date.distantFuture
                )
                let _ = allLogs?.filter { Calendar.current.isDateInToday($0.timestamp) }
                unoptimizedExpectation.fulfill()
            }
            
            wait(for: [unoptimizedExpectation], timeout: 5.0)
        }
        
        // Test optimized query
        measure(metrics: [XCTClockMetric()]) {
            let optimizedExpectation = XCTestExpectation(description: "Optimized query")
            
            Task {
                // Optimized query (direct date filtering)
                _ = try? await repository.fetchFoodLogs(for: Date())
                optimizedExpectation.fulfill()
            }
            
            wait(for: [optimizedExpectation], timeout: 5.0)
        }
    }
    
    func testCachedVsUncachedSearchResults() {
        let cacheManager = FuelLogCacheManager.shared
        let testResults = MockDataGenerator.shared.createMockFoodSearchResults(count: 20)
        
        // Cache the results
        cacheManager.cacheSearchResults(testResults, for: "performance-test")
        
        // Test uncached retrieval (simulation)
        measure(metrics: [XCTClockMetric()]) {
            // Simulate expensive search operation
            let _ = MockDataGenerator.shared.createMockFoodSearchResults(count: 20)
        }
        
        // Test cached retrieval
        measure(metrics: [XCTClockMetric()]) {
            _ = cacheManager.getCachedSearchResults(for: "performance-test")
        }
    }
    
    private func createTestRepository() -> FuelLogRepository {
        do {
            let schema = Schema([FoodLog.self, CustomFood.self, NutritionGoals.self])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return FuelLogRepository(modelContext: ModelContext(modelContainer))
        } catch {
            fatalError("Failed to create test repository: \(error)")
        }
    }
}

// MARK: - Repository Extensions for Performance Testing

extension FuelLogRepository {
    func fetchFoodLogs(for date: Date, limit: Int, offset: Int) async throws -> [FoodLog] {
        // This would be implemented in the actual repository
        // For testing purposes, we'll simulate pagination
        let allLogs = try await fetchFoodLogs(for: date)
        let startIndex = min(offset, allLogs.count)
        let endIndex = min(offset + limit, allLogs.count)
        
        guard startIndex < endIndex else { return [] }
        return Array(allLogs[startIndex..<endIndex])
    }
}