//
//  MemoryLeakDetectionTests.swift
//  workTests
//
//  Created by Kiro on 7/29/25.
//

import XCTest
import SwiftData
@testable import work

@MainActor
final class MemoryLeakDetectionTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var initialMemoryUsage: UInt64 = 0
    
    override func setUp() async throws {
        try await super.setUp()
        
        let schema = Schema([
            FoodLog.self,
            CustomFood.self,
            NutritionGoals.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        
        // Record initial memory usage
        initialMemoryUsage = getCurrentMemoryUsage()
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        
        // Force garbage collection
        autoreleasepool {
            // Empty pool to force cleanup
        }
        
        // Check for memory leaks
        let finalMemoryUsage = getCurrentMemoryUsage()
        let memoryDifference = finalMemoryUsage - initialMemoryUsage
        
        // Allow for some memory growth but flag significant leaks
        let maxAllowedIncrease: UInt64 = 10 * 1024 * 1024 // 10MB
        if memoryDifference > maxAllowedIncrease {
            print("⚠️ Potential memory leak detected: \(memoryDifference / 1024 / 1024)MB increase")
        }
        
        try await super.tearDown()
    }
    
    // MARK: - ViewModel Memory Leak Tests
    
    func testFuelLogViewModelMemoryLeak() async throws {
        weak var weakViewModel: FuelLogViewModel?
        
        autoreleasepool {
            let repository = FuelLogRepository(modelContext: modelContainer.mainContext)
            let healthKitManager = MockFuelLogHealthKitManager()
            
            let viewModel = FuelLogViewModel(
                repository: repository,
                healthKitManager: healthKitManager
            )
            
            weakViewModel = viewModel
            
            // Perform operations that might cause retain cycles
            Task {
                await viewModel.loadTodaysData()
                
                let foodLog = FoodLog(
                    name: "Test Food",
                    calories: 300,
                    protein: 20,
                    carbohydrates: 30,
                    fat: 10,
                    mealType: .breakfast,
                    servingSize: 1,
                    servingUnit: "serving"
                )
                
                await viewModel.logFood(foodLog)
                await viewModel.deleteFood(foodLog)
            }
        }
        
        // Wait for async operations to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // ViewModel should be deallocated
        XCTAssertNil(weakViewModel, "FuelLogViewModel should be deallocated")
    }
    
    func testNutritionGoalsViewModelMemoryLeak() async throws {
        weak var weakViewModel: NutritionGoalsViewModel?
        
        autoreleasepool {
            let repository = FuelLogRepository(modelContext: modelContainer.mainContext)
            let healthKitManager = MockFuelLogHealthKitManager()
            
            let viewModel = NutritionGoalsViewModel(
                repository: repository,
                healthKitManager: healthKitManager
            )
            
            weakViewModel = viewModel
            
            // Perform operations
            Task {
                await viewModel.loadPhysicalData()
                viewModel.selectedActivityLevel = .moderatelyActive
                viewModel.selectedGoal = .maintain
                viewModel.calculateNutritionGoals()
                await viewModel.saveGoals()
            }
        }
        
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNil(weakViewModel, "NutritionGoalsViewModel should be deallocated")
    }
    
    func testFoodSearchViewModelMemoryLeak() async throws {
        weak var weakViewModel: FoodSearchViewModel?
        
        autoreleasepool {
            let repository = FuelLogRepository(modelContext: modelContainer.mainContext)
            let networkManager = MockFoodNetworkManager()
            
            let viewModel = FoodSearchViewModel(
                repository: repository,
                networkManager: networkManager
            )
            
            weakViewModel = viewModel
            
            // Perform search operations
            Task {
                await viewModel.search(query: "test")
                await viewModel.searchLocal(query: "local")
                
                let customFood = CustomFood(
                    name: "Test Food",
                    caloriesPerServing: 100,
                    proteinPerServing: 10,
                    carbohydratesPerServing: 15,
                    fatPerServing: 3,
                    servingSize: 1,
                    servingUnit: "serving"
                )
                
                await viewModel.createCustomFood(customFood)
            }
        }
        
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNil(weakViewModel, "FoodSearchViewModel should be deallocated")
    }
    
    // MARK: - Repository Memory Leak Tests
    
    func testRepositoryMemoryLeak() async throws {
        weak var weakRepository: FuelLogRepository?
        
        autoreleasepool {
            let repository = FuelLogRepository(modelContext: modelContainer.mainContext)
            weakRepository = repository
            
            // Perform repository operations
            Task {
                let foodLog = FoodLog(
                    name: "Test Food",
                    calories: 300,
                    protein: 20,
                    carbohydrates: 30,
                    fat: 10,
                    mealType: .breakfast,
                    servingSize: 1,
                    servingUnit: "serving"
                )
                
                try await repository.saveFoodLog(foodLog)
                let _ = try await repository.fetchFoodLogs(for: Date())
                try await repository.deleteFoodLog(foodLog)
            }
        }
        
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNil(weakRepository, "FuelLogRepository should be deallocated")
    }
    
    // MARK: - Network Manager Memory Leak Tests
    
    func testNetworkManagerMemoryLeak() async throws {
        weak var weakNetworkManager: FoodNetworkManager?
        
        autoreleasepool {
            let networkManager = FoodNetworkManager.shared
            weakNetworkManager = networkManager
            
            // Note: Singleton pattern means this won't be deallocated
            // This test verifies the singleton doesn't accumulate memory
            let initialMemory = getCurrentMemoryUsage()
            
            // Perform multiple network operations
            for i in 0..<10 {
                do {
                    let _ = try await networkManager.searchFoodByName("test\(i)")
                } catch {
                    // Expected to fail in test environment
                }
            }
            
            let finalMemory = getCurrentMemoryUsage()
            let memoryIncrease = finalMemory - initialMemory
            
            // Should not accumulate significant memory
            XCTAssertLessThan(memoryIncrease, 5 * 1024 * 1024, "Network manager should not accumulate memory")
        }
    }
    
    // MARK: - SwiftData Memory Leak Tests
    
    func testSwiftDataMemoryLeak() async throws {
        let initialMemory = getCurrentMemoryUsage()
        
        // Create and delete many objects
        for i in 0..<100 {
            autoreleasepool {
                let foodLog = FoodLog(
                    name: "Test Food \(i)",
                    calories: Double(100 + i),
                    protein: Double(10 + i),
                    carbohydrates: Double(15 + i),
                    fat: Double(3 + i),
                    mealType: .breakfast,
                    servingSize: 1,
                    servingUnit: "serving"
                )
                
                modelContainer.mainContext.insert(foodLog)
                
                if i % 10 == 0 {
                    try? modelContainer.mainContext.save()
                }
            }
        }
        
        // Clear all data
        let descriptor = FetchDescriptor<FoodLog>()
        let allLogs = try modelContainer.mainContext.fetch(descriptor)
        
        for log in allLogs {
            modelContainer.mainContext.delete(log)
        }
        
        try modelContainer.mainContext.save()
        
        // Force cleanup
        autoreleasepool {}
        
        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Should not have significant memory increase after cleanup
        XCTAssertLessThan(memoryIncrease, 5 * 1024 * 1024, "SwiftData should properly clean up memory")
    }
    
    // MARK: - Concurrent Operations Memory Test
    
    func testConcurrentOperationsMemoryUsage() async throws {
        let initialMemory = getCurrentMemoryUsage()
        
        // Run multiple concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    
                    autoreleasepool {
                        let repository = FuelLogRepository(modelContext: self.modelContainer.mainContext)
                        let healthKitManager = MockFuelLogHealthKitManager()
                        
                        let viewModel = FuelLogViewModel(
                            repository: repository,
                            healthKitManager: healthKitManager
                        )
                        
                        Task {
                            await viewModel.loadTodaysData()
                            
                            let foodLog = FoodLog(
                                name: "Concurrent Food \(i)",
                                calories: Double(100 + i),
                                protein: Double(10 + i),
                                carbohydrates: Double(15 + i),
                                fat: Double(3 + i),
                                mealType: .breakfast,
                                servingSize: 1,
                                servingUnit: "serving"
                            )
                            
                            await viewModel.logFood(foodLog)
                        }
                    }
                }
            }
        }
        
        // Wait for cleanup
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Should not have excessive memory increase from concurrent operations
        XCTAssertLessThan(memoryIncrease, 20 * 1024 * 1024, "Concurrent operations should not cause memory issues")
    }
    
    // MARK: - Performance Profiling Tests
    
    func testDashboardLoadPerformance() async throws {
        let repository = FuelLogRepository(modelContext: modelContainer.mainContext)
        let healthKitManager = MockFuelLogHealthKitManager()
        
        // Add some test data
        for i in 0..<50 {
            let foodLog = FoodLog(
                name: "Food \(i)",
                calories: Double(100 + i),
                protein: Double(10 + i),
                carbohydrates: Double(15 + i),
                fat: Double(3 + i),
                mealType: MealType.allCases.randomElement()!,
                servingSize: 1,
                servingUnit: "serving"
            )
            try await repository.saveFoodLog(foodLog)
        }
        
        // Measure dashboard load performance
        let viewModel = FuelLogViewModel(
            repository: repository,
            healthKitManager: healthKitManager
        )
        
        measure {
            Task {
                await viewModel.loadTodaysData()
            }
        }
        
        // Verify performance requirement (should load within 500ms)
        let startTime = CFAbsoluteTimeGetCurrent()
        await viewModel.loadTodaysData()
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(loadTime, 0.5, "Dashboard should load within 500ms")
    }
    
    func testSearchPerformance() async throws {
        let repository = FuelLogRepository(modelContext: modelContainer.mainContext)
        let networkManager = MockFoodNetworkManager()
        
        // Add many custom foods for search testing
        for i in 0..<100 {
            let customFood = CustomFood(
                name: "Custom Food \(i)",
                caloriesPerServing: Double(100 + i),
                proteinPerServing: Double(10 + i),
                carbohydratesPerServing: Double(15 + i),
                fatPerServing: Double(3 + i),
                servingSize: 1,
                servingUnit: "serving"
            )
            try await repository.saveCustomFood(customFood)
        }
        
        let viewModel = FoodSearchViewModel(
            repository: repository,
            networkManager: networkManager
        )
        
        // Measure search performance
        measure {
            Task {
                await viewModel.searchLocal(query: "Custom")
            }
        }
        
        // Verify search performance requirement
        let startTime = CFAbsoluteTimeGetCurrent()
        await viewModel.searchLocal(query: "Food")
        let searchTime = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(searchTime, 0.1, "Local search should be very fast")
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
}

// MARK: - Mock Classes

class MockFuelLogHealthKitManager: FuelLogHealthKitManagerProtocol {
    var shouldAuthorize = true
    var mockPhysicalData: UserPhysicalData?
    var didWriteNutritionData = false
    var lastWrittenFoodLog: FoodLog?
    
    func requestAuthorization() async throws -> Bool {
        return shouldAuthorize
    }
    
    func fetchUserPhysicalData() async throws -> UserPhysicalData {
        return mockPhysicalData ?? UserPhysicalData(
            weight: 70.0,
            height: 175.0,
            age: 30,
            biologicalSex: .male,
            bmr: 1650.0,
            tdee: 2200.0
        )
    }
    
    func writeNutritionData(_ foodLog: FoodLog) async throws {
        didWriteNutritionData = true
        lastWrittenFoodLog = foodLog
    }
    
    func calculateBMR(weight: Double, height: Double, age: Int, sex: HKBiologicalSex) -> Double {
        let baseRate: Double
        if sex == .male {
            baseRate = (10 * weight) + (6.25 * height) - (5 * Double(age)) + 5
        } else {
            baseRate = (10 * weight) + (6.25 * height) - (5 * Double(age)) - 161
        }
        return baseRate
    }
}

class MockFoodNetworkManager: FoodNetworkManagerProtocol {
    var shouldFailRequests = false
    var mockSearchResults: [FoodSearchResult] = []
    var mockBarcodeResult: FoodSearchResult?
    
    func searchFoodByBarcode(_ barcode: String) async throws -> FoodSearchResult {
        if shouldFailRequests {
            throw FuelLogError.networkError(URLError(.notConnectedToInternet))
        }
        
        return mockBarcodeResult ?? FoodSearchResult(
            id: barcode,
            name: "Mock Product",
            brand: "Mock Brand",
            calories: 250,
            protein: 20,
            carbohydrates: 30,
            fat: 8,
            fiber: 5,
            sugar: 10,
            sodium: 0.5,
            servingSize: "100g",
            servingQuantity: 100,
            barcode: barcode
        )
    }
    
    func searchFoodByName(_ query: String, page: Int = 1) async throws -> [FoodSearchResult] {
        if shouldFailRequests {
            throw FuelLogError.networkError(URLError(.notConnectedToInternet))
        }
        
        return mockSearchResults
    }
}