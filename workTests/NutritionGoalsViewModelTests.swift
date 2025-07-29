import XCTest
import HealthKit
@testable import work

@MainActor
final class NutritionGoalsViewModelTests: XCTestCase {
    var viewModel: NutritionGoalsViewModel!
    var mockRepository: MockFuelLogRepository!
    var mockHealthKitManager: MockHealthKitManager!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockFuelLogRepository()
        mockHealthKitManager = MockHealthKitManager()
        viewModel = NutritionGoalsViewModel(repository: mockRepository, healthKitManager: mockHealthKitManager)
    }
    
    override func tearDown() {
        viewModel = nil
        mockRepository = nil
        mockHealthKitManager = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showingOnboarding)
        XCTAssertFalse(viewModel.hasHealthKitAuthorization)
        XCTAssertNil(viewModel.userPhysicalData)
        XCTAssertEqual(viewModel.selectedActivityLevel, .sedentary)
        XCTAssertEqual(viewModel.selectedGoal, .maintain)
        XCTAssertFalse(viewModel.isOnboardingComplete)
        XCTAssertFalse(viewModel.isManualOverride)
    }
    
    // MARK: - Goal Loading Tests
    
    func testLoadExistingGoals_WithExistingGoals() async {
        // Given
        let existingGoals = createTestNutritionGoals()
        mockRepository.nutritionGoalsToReturn = existingGoals
        
        // When
        await viewModel.loadExistingGoals()
        
        // Then
        XCTAssertEqual(viewModel.nutritionGoals?.id, existingGoals.id)
        XCTAssertTrue(viewModel.isOnboardingComplete)
        XCTAssertFalse(viewModel.showingOnboarding)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testLoadExistingGoals_WithoutExistingGoals() async {
        // Given
        mockRepository.nutritionGoalsToReturn = nil
        
        // When
        await viewModel.loadExistingGoals()
        
        // Then
        XCTAssertNil(viewModel.nutritionGoals)
        XCTAssertFalse(viewModel.isOnboardingComplete)
        XCTAssertTrue(viewModel.showingOnboarding)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testLoadExistingGoals_WithError() async {
        // Given
        mockRepository.shouldThrowError = true
        
        // When
        await viewModel.loadExistingGoals()
        
        // Then
        XCTAssertNil(viewModel.nutritionGoals)
        XCTAssertFalse(viewModel.isOnboardingComplete)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("Failed to load nutrition goals"))
    }
    
    // MARK: - HealthKit Authorization Tests
    
    func testRequestHealthKitAuthorization_Success() async {
        // Given
        mockHealthKitManager.authorizationResult = true
        mockHealthKitManager.mockPhysicalData = createTestPhysicalData()
        
        // When
        await viewModel.requestHealthKitAuthorization()
        
        // Then
        XCTAssertTrue(viewModel.hasHealthKitAuthorization)
        XCTAssertNotNil(viewModel.userPhysicalData)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testRequestHealthKitAuthorization_Failure() async {
        // Given
        mockHealthKitManager.authorizationResult = false
        
        // When
        await viewModel.requestHealthKitAuthorization()
        
        // Then
        XCTAssertFalse(viewModel.hasHealthKitAuthorization)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Activity Level Tests
    
    func testUpdateActivityLevel() {
        // Given
        let initialLevel = ActivityLevel.sedentary
        let newLevel = ActivityLevel.veryActive
        viewModel.selectedActivityLevel = initialLevel
        viewModel.userPhysicalData = createTestPhysicalData()
        
        // When
        viewModel.updateActivityLevel(newLevel)
        
        // Then
        XCTAssertEqual(viewModel.selectedActivityLevel, newLevel)
        XCTAssertNotNil(viewModel.userPhysicalData?.tdee)
        
        // Verify TDEE was recalculated
        let expectedTDEE = NutritionGoals.calculateTDEE(bmr: 1500, activityLevel: newLevel)
        XCTAssertEqual(viewModel.userPhysicalData?.tdee, expectedTDEE, accuracy: 0.1)
    }
    
    func testUpdateGoal() {
        // Given
        let initialGoal = NutritionGoal.maintain
        let newGoal = NutritionGoal.cut
        viewModel.selectedGoal = initialGoal
        
        // When
        viewModel.updateGoal(newGoal)
        
        // Then
        XCTAssertEqual(viewModel.selectedGoal, newGoal)
    }
    
    // MARK: - Manual Override Tests
    
    func testToggleManualOverride() {
        // Given
        viewModel.nutritionGoals = createTestNutritionGoals()
        XCTAssertFalse(viewModel.isManualOverride)
        
        // When
        viewModel.toggleManualOverride()
        
        // Then
        XCTAssertTrue(viewModel.isManualOverride)
        XCTAssertFalse(viewModel.manualCalories.isEmpty)
        XCTAssertFalse(viewModel.manualProtein.isEmpty)
        XCTAssertFalse(viewModel.manualCarbs.isEmpty)
        XCTAssertFalse(viewModel.manualFat.isEmpty)
        
        // When toggled back
        viewModel.toggleManualOverride()
        
        // Then
        XCTAssertFalse(viewModel.isManualOverride)
    }
    
    func testValidateManualInputs_ValidInputs() {
        // Given
        viewModel.manualCalories = "2000"
        viewModel.manualProtein = "150"  // 600 cal
        viewModel.manualCarbs = "200"    // 800 cal
        viewModel.manualFat = "67"       // 603 cal (total: 2003 cal, within 20% of 2000)
        
        // When
        let isValid = viewModel.validateManualInputs()
        
        // Then
        XCTAssertTrue(isValid)
    }
    
    func testValidateManualInputs_InvalidInputs() {
        // Given - macro calories way off from total calories
        viewModel.manualCalories = "2000"
        viewModel.manualProtein = "300"  // 1200 cal
        viewModel.manualCarbs = "300"    // 1200 cal
        viewModel.manualFat = "100"      // 900 cal (total: 3300 cal, way over 20% variance)
        
        // When
        let isValid = viewModel.validateManualInputs()
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    func testValidateManualInputs_NonNumericInputs() {
        // Given
        viewModel.manualCalories = "abc"
        viewModel.manualProtein = "150"
        viewModel.manualCarbs = "200"
        viewModel.manualFat = "67"
        
        // When
        let isValid = viewModel.validateManualInputs()
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    func testValidateManualInputs_NegativeValues() {
        // Given
        viewModel.manualCalories = "2000"
        viewModel.manualProtein = "-50"
        viewModel.manualCarbs = "200"
        viewModel.manualFat = "67"
        
        // When
        let isValid = viewModel.validateManualInputs()
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    // MARK: - Goal Completion Tests
    
    func testCompleteOnboarding_Success() async {
        // Given
        viewModel.userPhysicalData = createTestPhysicalData()
        viewModel.selectedActivityLevel = .moderatelyActive
        viewModel.selectedGoal = .cut
        mockRepository.shouldThrowError = false
        
        // When
        await viewModel.completeOnboarding()
        
        // Then
        XCTAssertNotNil(viewModel.nutritionGoals)
        XCTAssertTrue(viewModel.isOnboardingComplete)
        XCTAssertFalse(viewModel.showingOnboarding)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(mockRepository.saveNutritionGoalsCalled)
    }
    
    func testCompleteOnboarding_WithManualOverride() async {
        // Given
        viewModel.userPhysicalData = createTestPhysicalData()
        viewModel.isManualOverride = true
        viewModel.manualCalories = "1800"
        viewModel.manualProtein = "140"
        viewModel.manualCarbs = "180"
        viewModel.manualFat = "60"
        mockRepository.shouldThrowError = false
        
        // When
        await viewModel.completeOnboarding()
        
        // Then
        XCTAssertNotNil(viewModel.nutritionGoals)
        XCTAssertEqual(viewModel.nutritionGoals?.dailyCalories, 1800, accuracy: 0.1)
        XCTAssertEqual(viewModel.nutritionGoals?.dailyProtein, 140, accuracy: 0.1)
        XCTAssertEqual(viewModel.nutritionGoals?.dailyCarbohydrates, 180, accuracy: 0.1)
        XCTAssertEqual(viewModel.nutritionGoals?.dailyFat, 60, accuracy: 0.1)
    }
    
    func testCompleteOnboarding_Error() async {
        // Given
        viewModel.userPhysicalData = createTestPhysicalData()
        mockRepository.shouldThrowError = true
        
        // When
        await viewModel.completeOnboarding()
        
        // Then
        XCTAssertFalse(viewModel.isOnboardingComplete)
        XCTAssertTrue(viewModel.showingOnboarding)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("Failed to save nutrition goals"))
    }
    
    // MARK: - BMR and TDEE Calculation Tests
    
    func testCalculateBMR_Male() {
        // Given
        let weight: Double = 80 // kg
        let height: Double = 180 // cm
        let age = 30
        let biologicalSex = HKBiologicalSex.male
        
        // When
        let bmr = viewModel.calculateBMR(weight: weight, height: height, age: age, biologicalSex: biologicalSex)
        
        // Then
        let expectedBMR = (10 * weight) + (6.25 * height) - (5 * Double(age)) + 5
        XCTAssertEqual(bmr, expectedBMR, accuracy: 0.1)
    }
    
    func testCalculateBMR_Female() {
        // Given
        let weight: Double = 65 // kg
        let height: Double = 165 // cm
        let age = 25
        let biologicalSex = HKBiologicalSex.female
        
        // When
        let bmr = viewModel.calculateBMR(weight: weight, height: height, age: age, biologicalSex: biologicalSex)
        
        // Then
        let expectedBMR = (10 * weight) + (6.25 * height) - (5 * Double(age)) - 161
        XCTAssertEqual(bmr, expectedBMR, accuracy: 0.1)
    }
    
    func testCalculateBMR_MissingData() {
        // When
        let bmr = viewModel.calculateBMR(weight: nil, height: 180, age: 30, biologicalSex: .male)
        
        // Then
        XCTAssertNil(bmr)
    }
    
    func testCalculateTDEE() {
        // Given
        let bmr: Double = 1800
        let activityLevel = ActivityLevel.moderatelyActive
        
        // When
        let tdee = viewModel.calculateTDEE(bmr: bmr, activityLevel: activityLevel)
        
        // Then
        let expectedTDEE = bmr * activityLevel.multiplier
        XCTAssertEqual(tdee, expectedTDEE, accuracy: 0.1)
    }
    
    func testCalculateTDEE_NilBMR() {
        // When
        let tdee = viewModel.calculateTDEE(bmr: nil, activityLevel: .moderatelyActive)
        
        // Then
        XCTAssertNil(tdee)
    }
    
    // MARK: - Helper Methods
    
    private func createTestNutritionGoals() -> NutritionGoals {
        return NutritionGoals(
            dailyCalories: 2000,
            dailyProtein: 150,
            dailyCarbohydrates: 200,
            dailyFat: 67,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            bmr: 1600,
            tdee: 2000,
            weight: 75,
            height: 175,
            age: 30,
            biologicalSex: "male"
        )
    }
    
    private func createTestPhysicalData() -> UserPhysicalData {
        return UserPhysicalData(
            weight: 75,
            height: 175,
            age: 30,
            biologicalSex: .male,
            bmr: 1500,
            tdee: 2000
        )
    }
}

// MARK: - Mock Classes

class MockFuelLogRepository: FuelLogRepositoryProtocol {
    var nutritionGoalsToReturn: NutritionGoals?
    var shouldThrowError = false
    var saveNutritionGoalsCalled = false
    
    nonisolated func fetchNutritionGoals() async throws -> NutritionGoals? {
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        return nutritionGoalsToReturn
    }
    
    nonisolated func saveNutritionGoals(_ goals: NutritionGoals) async throws {
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save error"])
        }
        saveNutritionGoalsCalled = true
        nutritionGoalsToReturn = goals
    }
    
    // Other required methods (not used in these tests)
    nonisolated func fetchFoodLogs(for date: Date) async throws -> [FoodLog] { return [] }
    nonisolated func saveFoodLog(_ foodLog: FoodLog) async throws {}
    nonisolated func updateFoodLog(_ foodLog: FoodLog) async throws {}
    nonisolated func deleteFoodLog(_ foodLog: FoodLog) async throws {}
    nonisolated func fetchFoodLogsByDateRange(from startDate: Date, to endDate: Date) async throws -> [FoodLog] { return [] }
    nonisolated func fetchCustomFoods() async throws -> [CustomFood] { return [] }
    nonisolated func fetchCustomFood(by id: UUID) async throws -> CustomFood? { return nil }
    nonisolated func saveCustomFood(_ customFood: CustomFood) async throws {}
    nonisolated func updateCustomFood(_ customFood: CustomFood) async throws {}
    nonisolated func deleteCustomFood(_ customFood: CustomFood) async throws {}
    nonisolated func searchCustomFoods(query: String) async throws -> [CustomFood] { return [] }
    nonisolated func fetchNutritionGoals(for userId: String) async throws -> NutritionGoals? { return nutritionGoalsToReturn }
    nonisolated func updateNutritionGoals(_ goals: NutritionGoals) async throws {}
    nonisolated func deleteNutritionGoals(_ goals: NutritionGoals) async throws {}
}

class MockHealthKitManager {
    var authorizationResult = false
    var mockPhysicalData: UserPhysicalData?
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion(self.authorizationResult)
        }
    }
    
    func fetchLatestWeight(completion: @escaping (Double?) -> Void) {
        completion(mockPhysicalData?.weight)
    }
    
    let healthStore = HKHealthStore()
}