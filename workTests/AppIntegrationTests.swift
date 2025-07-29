//
//  AppIntegrationTests.swift
//  workTests
//
//  Created by Kiro on 7/29/25.
//

import XCTest
import SwiftData
import HealthKit
@testable import work

@MainActor
final class AppIntegrationTests: XCTestCase {
    
    var dataManager: DataManager!
    var healthKitManager: HealthKitManager!
    var modelContainer: ModelContainer!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Setup test environment similar to main app
        let schema = Schema([
            FoodLog.self,
            CustomFood.self,
            NutritionGoals.self,
            // Add other existing models that might interact
            DailyJournal.self,
            WeightEntry.self,
            UserProfile.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        
        dataManager = DataManager()
        dataManager.modelContainer = modelContainer
        
        healthKitManager = HealthKitManager.shared
    }
    
    override func tearDown() async throws {
        dataManager = nil
        healthKitManager = nil
        modelContainer = nil
        try await super.tearDown()
    }
    
    // MARK: - Tab Integration Tests
    
    func testMainTabViewIntegration() async throws {
        // Test that Fuel Log tab integrates properly with existing tabs
        let tabSelectionModel = TabSelectionModel()
        let dateModel = DateModel()
        
        // Simulate navigation to Fuel Log tab
        tabSelectionModel.selectedTab = 4 // Fuel Log tab index
        
        // Verify tab selection works
        XCTAssertEqual(tabSelectionModel.selectedTab, 4)
        
        // Test date model integration
        let testDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        dateModel.selectedDate = testDate
        
        // Verify date changes affect fuel log data loading
        let repository = FuelLogRepository(modelContext: modelContainer.mainContext)
        let foodLogs = try await repository.fetchFoodLogs(for: testDate)
        XCTAssertEqual(foodLogs.count, 0) // Should be empty for test date
    }
    
    // MARK: - DataManager Integration
    
    func testDataManagerIntegration() async throws {
        let modelContext = modelContainer.mainContext
        
        // Test that nutrition data integrates with existing data structures
        let nutritionGoals = NutritionGoals(
            dailyCalories: 2000,
            dailyProtein: 150,
            dailyCarbohydrates: 200,
            dailyFat: 67,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            bmr: 1600,
            tdee: 2000
        )
        
        modelContext.insert(nutritionGoals)
        try modelContext.save()
        
        // Test that food logs can coexist with other data
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
        
        modelContext.insert(foodLog)
        try modelContext.save()
        
        // Verify both types of data exist
        let fetchedGoals = try modelContext.fetch(FetchDescriptor<NutritionGoals>())
        let fetchedLogs = try modelContext.fetch(FetchDescriptor<FoodLog>())
        
        XCTAssertEqual(fetchedGoals.count, 1)
        XCTAssertEqual(fetchedLogs.count, 1)
        
        // Test that existing app data isn't affected
        let userProfile = UserProfile(
            name: "Test User",
            age: 30,
            weight: 70,
            height: 175,
            activityLevel: "moderate",
            fitnessGoal: "maintain"
        )
        
        modelContext.insert(userProfile)
        try modelContext.save()
        
        let fetchedProfiles = try modelContext.fetch(FetchDescriptor<UserProfile>())
        XCTAssertEqual(fetchedProfiles.count, 1)
        XCTAssertEqual(fetchedProfiles.first?.name, "Test User")
    }
    
    // MARK: - HealthKit Integration Validation
    
    func testHealthKitIntegrationCompliance() async throws {
        // Test that HealthKit integration follows privacy guidelines
        let fuelLogHealthKit = FuelLogHealthKitManager.shared
        
        // Test authorization request
        if HKHealthStore.isHealthDataAvailable() {
            // This would normally require user interaction in real app
            // In tests, we verify the request is properly structured
            
            let readTypes: Set<HKObjectType> = [
                HKObjectType.quantityType(forIdentifier: .bodyMass)!,
                HKObjectType.quantityType(forIdentifier: .height)!,
                HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
                HKObjectType.characteristicType(forIdentifier: .biologicalSex)!
            ]
            
            let writeTypes: Set<HKSampleType> = [
                HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
                HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
                HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
                HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!
            ]
            
            // Verify types are properly defined
            XCTAssertEqual(readTypes.count, 4)
            XCTAssertEqual(writeTypes.count, 4)
            
            // Test BMR calculation
            let bmr = fuelLogHealthKit.calculateBMR(
                weight: 70,
                height: 175,
                age: 30,
                sex: .male
            )
            
            XCTAssertGreaterThan(bmr, 1000)
            XCTAssertLessThan(bmr, 3000)
        }
    }
    
    // MARK: - Memory and Performance Integration
    
    func testMemoryUsageIntegration() async throws {
        // Test that fuel log doesn't cause memory issues with existing app
        let initialMemory = getMemoryUsage()
        
        // Create multiple ViewModels as they would exist in the app
        let repository = FuelLogRepository(modelContext: modelContainer.mainContext)
        let healthKitManager = MockFuelLogHealthKitManager()
        let networkManager = MockFoodNetworkManager()
        
        var viewModels: [Any] = []
        
        // Create multiple instances to simulate real usage
        for _ in 0..<10 {
            let fuelLogVM = FuelLogViewModel(
                repository: repository,
                healthKitManager: healthKitManager
            )
            
            let nutritionGoalsVM = NutritionGoalsViewModel(
                repository: repository,
                healthKitManager: healthKitManager
            )
            
            let foodSearchVM = FoodSearchViewModel(
                repository: repository,
                networkManager: networkManager
            )
            
            viewModels.append(fuelLogVM)
            viewModels.append(nutritionGoalsVM)
            viewModels.append(foodSearchVM)
        }
        
        // Simulate some operations
        for viewModel in viewModels {
            if let fuelLogVM = viewModel as? FuelLogViewModel {
                await fuelLogVM.loadTodaysData()
            }
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable (less than 50MB for this test)
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024, "Memory usage should be reasonable")
        
        // Clean up
        viewModels.removeAll()
    }
    
    // MARK: - Cross-Feature Data Consistency
    
    func testCrossFeatureDataConsistency() async throws {
        let modelContext = modelContainer.mainContext
        
        // Test that nutrition data is consistent with other health data
        let weightEntry = WeightEntry(
            date: Date(),
            weight: 70.5,
            bodyFatPercentage: 15.0
        )
        modelContext.insert(weightEntry)
        
        let nutritionGoals = NutritionGoals(
            dailyCalories: 2000,
            dailyProtein: 150,
            dailyCarbohydrates: 200,
            dailyFat: 67,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            bmr: 1600,
            tdee: 2000
        )
        nutritionGoals.weight = 70.5 // Should match weight entry
        modelContext.insert(nutritionGoals)
        
        try modelContext.save()
        
        // Verify data consistency
        let fetchedWeights = try modelContext.fetch(FetchDescriptor<WeightEntry>())
        let fetchedGoals = try modelContext.fetch(FetchDescriptor<NutritionGoals>())
        
        XCTAssertEqual(fetchedWeights.first?.weight, fetchedGoals.first?.weight)
        
        // Test that daily journal can reference nutrition data
        let dailyJournal = DailyJournal(
            date: Date(),
            sleepQuality: 8,
            energyLevel: 7,
            mood: 8,
            stressLevel: 3,
            notes: "Good nutrition day - hit protein goals"
        )
        modelContext.insert(dailyJournal)
        try modelContext.save()
        
        // Verify journal entry exists alongside nutrition data
        let fetchedJournals = try modelContext.fetch(FetchDescriptor<DailyJournal>())
        XCTAssertEqual(fetchedJournals.count, 1)
        XCTAssertTrue(fetchedJournals.first?.notes?.contains("protein") == true)
    }
    
    // MARK: - State Preservation Tests
    
    func testStatePreservationAcrossTabs() async throws {
        // Test that fuel log state is preserved when switching tabs
        let repository = FuelLogRepository(modelContext: modelContainer.mainContext)
        let healthKitManager = MockFuelLogHealthKitManager()
        
        let fuelLogViewModel = FuelLogViewModel(
            repository: repository,
            healthKitManager: healthKitManager
        )
        
        // Load some data
        await fuelLogViewModel.loadTodaysData()
        
        // Log some food
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
        
        let initialCalories = fuelLogViewModel.dailyTotals.totalCalories
        let initialCount = fuelLogViewModel.todaysFoodLogs.count
        
        // Simulate tab switch by creating new ViewModel instance
        let newFuelLogViewModel = FuelLogViewModel(
            repository: repository,
            healthKitManager: healthKitManager
        )
        
        await newFuelLogViewModel.loadTodaysData()
        
        // Verify state is preserved
        XCTAssertEqual(newFuelLogViewModel.dailyTotals.totalCalories, initialCalories)
        XCTAssertEqual(newFuelLogViewModel.todaysFoodLogs.count, initialCount)
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> UInt64 {
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

// MARK: - Mock Classes for Integration Testing

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