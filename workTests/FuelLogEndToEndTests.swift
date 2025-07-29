//
//  FuelLogEndToEndTests.swift
//  workTests
//
//  Created by Kiro on 7/29/25.
//

import XCTest
import SwiftData
import HealthKit
@testable import work

@MainActor
final class FuelLogEndToEndTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var repository: FuelLogRepository!
    var mockHealthKitManager: MockFuelLogHealthKitManager!
    var mockNetworkManager: MockFoodNetworkManager!
    var fuelLogViewModel: FuelLogViewModel!
    var nutritionGoalsViewModel: NutritionGoalsViewModel!
    var foodSearchViewModel: FoodSearchViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Setup in-memory SwiftData container
        let schema = Schema([
            FoodLog.self,
            CustomFood.self,
            NutritionGoals.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
        
        // Setup dependencies
        repository = FuelLogRepository(modelContext: modelContext)
        mockHealthKitManager = MockFuelLogHealthKitManager()
        mockNetworkManager = MockFoodNetworkManager()
        
        // Setup ViewModels
        fuelLogViewModel = FuelLogViewModel(
            repository: repository,
            healthKitManager: mockHealthKitManager
        )
        
        nutritionGoalsViewModel = NutritionGoalsViewModel(
            repository: repository,
            healthKitManager: mockHealthKitManager
        )
        
        foodSearchViewModel = FoodSearchViewModel(
            repository: repository,
            networkManager: mockNetworkManager
        )
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        repository = nil
        mockHealthKitManager = nil
        mockNetworkManager = nil
        fuelLogViewModel = nil
        nutritionGoalsViewModel = nil
        foodSearchViewModel = nil
        try await super.tearDown()
    }
    
    // MARK: - Complete User Onboarding Flow
    
    func testCompleteOnboardingFlow() async throws {
        // Step 1: HealthKit Authorization
        mockHealthKitManager.shouldAuthorize = true
        mockHealthKitManager.mockPhysicalData = UserPhysicalData(
            weight: 70.0,
            height: 175.0,
            age: 30,
            biologicalSex: .male,
            bmr: 1650.0,
            tdee: 2200.0
        )
        
        let authResult = await nutritionGoalsViewModel.requestHealthKitAuthorization()
        XCTAssertTrue(authResult)
        XCTAssertTrue(nutritionGoalsViewModel.isHealthKitAuthorized)
        
        // Step 2: Physical Data Retrieval
        await nutritionGoalsViewModel.loadPhysicalData()
        XCTAssertEqual(nutritionGoalsViewModel.weight, 70.0)
        XCTAssertEqual(nutritionGoalsViewModel.height, 175.0)
        XCTAssertEqual(nutritionGoalsViewModel.age, 30)
        
        // Step 3: Activity Level Selection
        nutritionGoalsViewModel.selectedActivityLevel = .moderatelyActive
        XCTAssertEqual(nutritionGoalsViewModel.calculatedTDEE, 2557.5, accuracy: 0.1)
        
        // Step 4: Goal Selection
        nutritionGoalsViewModel.selectedGoal = .maintain
        nutritionGoalsViewModel.calculateNutritionGoals()
        
        XCTAssertEqual(nutritionGoalsViewModel.dailyCalories, 2557.5, accuracy: 0.1)
        XCTAssertGreaterThan(nutritionGoalsViewModel.dailyProtein, 0)
        XCTAssertGreaterThan(nutritionGoalsViewModel.dailyCarbohydrates, 0)
        XCTAssertGreaterThan(nutritionGoalsViewModel.dailyFat, 0)
        
        // Step 5: Save Goals
        await nutritionGoalsViewModel.saveGoals()
        XCTAssertFalse(nutritionGoalsViewModel.isLoading)
        XCTAssertNil(nutritionGoalsViewModel.errorMessage)
        
        // Verify goals are persisted
        let savedGoals = try await repository.fetchNutritionGoals()
        XCTAssertNotNil(savedGoals)
        XCTAssertEqual(savedGoals?.dailyCalories, 2557.5, accuracy: 0.1)
    }
    
    // MARK: - Complete Food Logging Flow
    
    func testCompleteFoodLoggingFlow() async throws {
        // Setup nutrition goals first
        let goals = NutritionGoals(
            dailyCalories: 2000,
            dailyProtein: 150,
            dailyCarbohydrates: 200,
            dailyFat: 67,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            bmr: 1600,
            tdee: 2000
        )
        try await repository.saveNutritionGoals(goals)
        
        // Load initial data
        await fuelLogViewModel.loadTodaysData()
        XCTAssertEqual(fuelLogViewModel.todaysFoodLogs.count, 0)
        XCTAssertEqual(fuelLogViewModel.dailyTotals.totalCalories, 0)
        
        // Step 1: Log food via barcode scan
        let barcodeFood = FoodLog(
            name: "Banana",
            calories: 105,
            protein: 1.3,
            carbohydrates: 27,
            fat: 0.3,
            mealType: .breakfast,
            servingSize: 1,
            servingUnit: "medium",
            barcode: "1234567890"
        )
        
        await fuelLogViewModel.logFood(barcodeFood)
        XCTAssertEqual(fuelLogViewModel.todaysFoodLogs.count, 1)
        XCTAssertEqual(fuelLogViewModel.dailyTotals.totalCalories, 105)
        
        // Step 2: Log food via search
        let searchFood = FoodLog(
            name: "Chicken Breast",
            calories: 231,
            protein: 43.5,
            carbohydrates: 0,
            fat: 5,
            mealType: .lunch,
            servingSize: 100,
            servingUnit: "g"
        )
        
        await fuelLogViewModel.logFood(searchFood)
        XCTAssertEqual(fuelLogViewModel.todaysFoodLogs.count, 2)
        XCTAssertEqual(fuelLogViewModel.dailyTotals.totalCalories, 336)
        XCTAssertEqual(fuelLogViewModel.dailyTotals.totalProtein, 44.8, accuracy: 0.1)
        
        // Step 3: Log custom food
        let customFood = CustomFood(
            name: "My Protein Shake",
            caloriesPerServing: 300,
            proteinPerServing: 50,
            carbohydratesPerServing: 10,
            fatPerServing: 5,
            servingSize: 1,
            servingUnit: "scoop"
        )
        try await repository.saveCustomFood(customFood)
        
        let customFoodLog = FoodLog(
            name: customFood.name,
            calories: customFood.caloriesPerServing,
            protein: customFood.proteinPerServing,
            carbohydrates: customFood.carbohydratesPerServing,
            fat: customFood.fatPerServing,
            mealType: .snacks,
            servingSize: customFood.servingSize,
            servingUnit: customFood.servingUnit,
            customFoodId: customFood.id
        )
        
        await fuelLogViewModel.logFood(customFoodLog)
        XCTAssertEqual(fuelLogViewModel.todaysFoodLogs.count, 3)
        XCTAssertEqual(fuelLogViewModel.dailyTotals.totalCalories, 636)
        
        // Step 4: Quick add macros
        let quickAdd = FoodLog(
            name: "Quick Add - Macros",
            calories: 400,
            protein: 20,
            carbohydrates: 50,
            fat: 10,
            mealType: .dinner,
            servingSize: 1,
            servingUnit: "entry"
        )
        
        await fuelLogViewModel.logFood(quickAdd)
        XCTAssertEqual(fuelLogViewModel.todaysFoodLogs.count, 4)
        XCTAssertEqual(fuelLogViewModel.dailyTotals.totalCalories, 1036)
        
        // Verify progress calculations
        let calorieProgress = fuelLogViewModel.dailyTotals.totalCalories / goals.dailyCalories
        XCTAssertEqual(calorieProgress, 0.518, accuracy: 0.01)
        
        // Step 5: Delete a food log
        await fuelLogViewModel.deleteFood(barcodeFood)
        XCTAssertEqual(fuelLogViewModel.todaysFoodLogs.count, 3)
        XCTAssertEqual(fuelLogViewModel.dailyTotals.totalCalories, 931)
    }
    
    // MARK: - Search and Custom Food Flow
    
    func testSearchAndCustomFoodFlow() async throws {
        // Step 1: Search for existing food
        mockNetworkManager.mockSearchResults = [
            FoodSearchResult(
                id: "123",
                name: "Test Product",
                brand: "Test Brand",
                calories: 250,
                protein: 20,
                carbohydrates: 30,
                fat: 8,
                fiber: 5,
                sugar: 10,
                sodium: 0.5,
                servingSize: "100g",
                servingQuantity: 100,
                barcode: nil
            )
        ]
        
        await foodSearchViewModel.search(query: "test")
        XCTAssertEqual(foodSearchViewModel.searchResults.count, 1)
        XCTAssertFalse(foodSearchViewModel.isSearching)
        
        // Step 2: Create custom food when not found
        let customFood = CustomFood(
            name: "My Custom Recipe",
            caloriesPerServing: 350,
            proteinPerServing: 25,
            carbohydratesPerServing: 40,
            fatPerServing: 12,
            servingSize: 1,
            servingUnit: "serving"
        )
        
        await foodSearchViewModel.createCustomFood(customFood)
        
        // Verify custom food is saved and searchable
        await foodSearchViewModel.searchLocal(query: "custom")
        XCTAssertEqual(foodSearchViewModel.customFoods.count, 1)
        XCTAssertEqual(foodSearchViewModel.customFoods.first?.name, "My Custom Recipe")
    }
    
    // MARK: - Offline Functionality Test
    
    func testOfflineFunctionality() async throws {
        // Setup some local data
        let customFood = CustomFood(
            name: "Offline Food",
            caloriesPerServing: 200,
            proteinPerServing: 15,
            carbohydratesPerServing: 20,
            fatPerServing: 8,
            servingSize: 1,
            servingUnit: "serving"
        )
        try await repository.saveCustomFood(customFood)
        
        let goals = NutritionGoals(
            dailyCalories: 2000,
            dailyProtein: 150,
            dailyCarbohydrates: 200,
            dailyFat: 67,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            bmr: 1600,
            tdee: 2000
        )
        try await repository.saveNutritionGoals(goals)
        
        // Simulate network failure
        mockNetworkManager.shouldFailRequests = true
        
        // Test that local functionality still works
        await foodSearchViewModel.searchLocal(query: "offline")
        XCTAssertEqual(foodSearchViewModel.customFoods.count, 1)
        
        // Test that food logging still works
        let foodLog = FoodLog(
            name: customFood.name,
            calories: customFood.caloriesPerServing,
            protein: customFood.proteinPerServing,
            carbohydrates: customFood.carbohydratesPerServing,
            fat: customFood.fatPerServing,
            mealType: .lunch,
            servingSize: customFood.servingSize,
            servingUnit: customFood.servingUnit,
            customFoodId: customFood.id
        )
        
        await fuelLogViewModel.logFood(foodLog)
        XCTAssertEqual(fuelLogViewModel.todaysFoodLogs.count, 1)
        XCTAssertEqual(fuelLogViewModel.dailyTotals.totalCalories, 200)
        
        // Test that goals are still accessible
        await fuelLogViewModel.loadTodaysData()
        XCTAssertNotNil(fuelLogViewModel.nutritionGoals)
        XCTAssertEqual(fuelLogViewModel.nutritionGoals?.dailyCalories, 2000)
    }
    
    // MARK: - Data Synchronization Test
    
    func testDataSynchronization() async throws {
        // Test HealthKit data sync
        mockHealthKitManager.shouldAuthorize = true
        mockHealthKitManager.mockPhysicalData = UserPhysicalData(
            weight: 75.0,
            height: 180.0,
            age: 25,
            biologicalSex: .female,
            bmr: 1500.0,
            tdee: 2100.0
        )
        
        await nutritionGoalsViewModel.loadPhysicalData()
        XCTAssertEqual(nutritionGoalsViewModel.weight, 75.0)
        XCTAssertEqual(nutritionGoalsViewModel.height, 180.0)
        
        // Test that changes sync properly
        nutritionGoalsViewModel.selectedActivityLevel = .veryActive
        nutritionGoalsViewModel.calculateNutritionGoals()
        await nutritionGoalsViewModel.saveGoals()
        
        // Verify persistence
        let savedGoals = try await repository.fetchNutritionGoals()
        XCTAssertNotNil(savedGoals)
        XCTAssertEqual(savedGoals?.activityLevel, .veryActive)
        
        // Test food log HealthKit sync
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
        
        await fuelLogViewModel.logFood(foodLog)
        
        // Verify HealthKit write was attempted
        XCTAssertTrue(mockHealthKitManager.didWriteNutritionData)
        XCTAssertEqual(mockHealthKitManager.lastWrittenFoodLog?.calories, 300)
    }
    
    // MARK: - Error Recovery Test
    
    func testErrorRecoveryScenarios() async throws {
        // Test network error recovery
        mockNetworkManager.shouldFailRequests = true
        
        await foodSearchViewModel.search(query: "test")
        XCTAssertNotNil(foodSearchViewModel.errorMessage)
        XCTAssertTrue(foodSearchViewModel.errorMessage?.contains("network") == true)
        
        // Test recovery after network comes back
        mockNetworkManager.shouldFailRequests = false
        mockNetworkManager.mockSearchResults = [
            FoodSearchResult(
                id: "123",
                name: "Recovery Test",
                brand: "Test",
                calories: 100,
                protein: 10,
                carbohydrates: 15,
                fat: 3,
                fiber: 2,
                sugar: 5,
                sodium: 0.1,
                servingSize: "100g",
                servingQuantity: 100,
                barcode: nil
            )
        ]
        
        await foodSearchViewModel.search(query: "recovery")
        XCTAssertNil(foodSearchViewModel.errorMessage)
        XCTAssertEqual(foodSearchViewModel.searchResults.count, 1)
        
        // Test HealthKit error recovery
        mockHealthKitManager.shouldAuthorize = false
        
        let authResult = await nutritionGoalsViewModel.requestHealthKitAuthorization()
        XCTAssertFalse(authResult)
        XCTAssertNotNil(nutritionGoalsViewModel.errorMessage)
        
        // Test manual data entry fallback
        nutritionGoalsViewModel.weight = 70
        nutritionGoalsViewModel.height = 175
        nutritionGoalsViewModel.age = 30
        nutritionGoalsViewModel.selectedSex = .male
        nutritionGoalsViewModel.calculateBMR()
        
        XCTAssertGreaterThan(nutritionGoalsViewModel.calculatedBMR, 0)
        XCTAssertNil(nutritionGoalsViewModel.errorMessage)
    }
    
    // MARK: - Performance Validation
    
    func testPerformanceRequirements() async throws {
        // Test dashboard load time (should be under 500ms)
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await fuelLogViewModel.loadTodaysData()
        
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertLessThan(loadTime, 0.5, "Dashboard should load within 500ms")
        
        // Test search response time (should be under 2 seconds)
        mockNetworkManager.mockSearchResults = Array(0..<50).map { index in
            FoodSearchResult(
                id: "\(index)",
                name: "Product \(index)",
                brand: "Brand \(index)",
                calories: Double(100 + index),
                protein: Double(10 + index),
                carbohydrates: Double(15 + index),
                fat: Double(3 + index),
                fiber: 2,
                sugar: 5,
                sodium: 0.1,
                servingSize: "100g",
                servingQuantity: 100,
                barcode: nil
            )
        }
        
        let searchStartTime = CFAbsoluteTimeGetCurrent()
        
        await foodSearchViewModel.search(query: "performance test")
        
        let searchTime = CFAbsoluteTimeGetCurrent() - searchStartTime
        XCTAssertLessThan(searchTime, 2.0, "Search should complete within 2 seconds")
        XCTAssertEqual(foodSearchViewModel.searchResults.count, 50)
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
        guard let data = mockPhysicalData else {
            throw FuelLogError.healthKitNotAvailable
        }
        return data
    }
    
    func writeNutritionData(_ foodLog: FoodLog) async throws {
        didWriteNutritionData = true
        lastWrittenFoodLog = foodLog
    }
    
    func calculateBMR(weight: Double, height: Double, age: Int, sex: HKBiologicalSex) -> Double {
        // Mifflin-St Jeor formula
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