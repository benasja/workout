import XCTest
@testable import work

/// Unit tests for FuelLogViewModel
@MainActor
final class FuelLogViewModelTests: XCTestCase {
    
    var viewModel: FuelLogViewModel!
    var mockRepository: MockFuelLogRepository!
    var mockHealthKitManager: MockFuelLogHealthKitManager!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockFuelLogRepository()
        mockHealthKitManager = MockFuelLogHealthKitManager()
        viewModel = FuelLogViewModel(
            repository: mockRepository,
            healthKitManager: mockHealthKitManager
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockRepository = nil
        mockHealthKitManager = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertEqual(viewModel.todaysFoodLogs.count, 0)
        XCTAssertNil(viewModel.nutritionGoals)
        XCTAssertEqual(viewModel.dailyTotals.totalCalories, 0)
        XCTAssertTrue(Calendar.current.isDateInToday(viewModel.selectedDate))
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Data Loading Tests
    
    func testLoadNutritionGoals_Success() async {
        // Given
        let mockGoals = createMockNutritionGoals()
        mockRepository.mockNutritionGoals = mockGoals
        
        // When
        await viewModel.loadNutritionGoals()
        
        // Then
        XCTAssertEqual(viewModel.nutritionGoals?.id, mockGoals.id)
        XCTAssertFalse(viewModel.isLoadingGoals)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testLoadNutritionGoals_Failure() async {
        // Given
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = FuelLogError.persistenceError(NSError(domain: "test", code: 1))
        
        // When
        await viewModel.loadNutritionGoals()
        
        // Then
        XCTAssertNil(viewModel.nutritionGoals)
        XCTAssertFalse(viewModel.isLoadingGoals)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    func testLoadFoodLogs_Success() async {
        // Given
        let mockFoodLogs = createMockFoodLogs()
        mockRepository.mockFoodLogs = mockFoodLogs
        
        // When
        await viewModel.loadFoodLogs(for: Date())
        
        // Then
        XCTAssertEqual(viewModel.todaysFoodLogs.count, mockFoodLogs.count)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        
        // Verify daily totals are calculated
        XCTAssertGreaterThan(viewModel.dailyTotals.totalCalories, 0)
        
        // Verify food logs are grouped by meal type
        XCTAssertTrue(viewModel.foodLogsByMealType.keys.contains(.breakfast))
    }
    
    func testLoadFoodLogs_Failure() async {
        // Given
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = FuelLogError.persistenceError(NSError(domain: "test", code: 1))
        
        // When
        await viewModel.loadFoodLogs(for: Date())
        
        // Then
        XCTAssertEqual(viewModel.todaysFoodLogs.count, 0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    // MARK: - Food Logging Tests
    
    func testLogFood_Success() async {
        // Given
        let foodLog = createMockFoodLog()
        mockRepository.shouldThrowError = false
        
        // When
        await viewModel.logFood(foodLog)
        
        // Then
        XCTAssertEqual(viewModel.todaysFoodLogs.count, 1)
        XCTAssertEqual(viewModel.todaysFoodLogs.first?.id, foodLog.id)
        XCTAssertFalse(viewModel.isSavingFood)
        XCTAssertNil(viewModel.errorMessage)
        
        // Verify repository was called
        XCTAssertTrue(mockRepository.saveFoodLogCalled)
        
        // Verify HealthKit was called
        XCTAssertTrue(mockHealthKitManager.writeNutritionDataCalled)
        
        // Verify daily totals updated
        XCTAssertEqual(viewModel.dailyTotals.totalCalories, foodLog.calories)
    }
    
    func testLogFood_Failure_RevertsOptimisticUpdate() async {
        // Given
        let foodLog = createMockFoodLog()
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = FuelLogError.persistenceError(NSError(domain: "test", code: 1))
        
        let originalCount = viewModel.todaysFoodLogs.count
        let originalTotals = viewModel.dailyTotals
        
        // When
        await viewModel.logFood(foodLog)
        
        // Then - optimistic update should be reverted
        XCTAssertEqual(viewModel.todaysFoodLogs.count, originalCount)
        XCTAssertEqual(viewModel.dailyTotals.totalCalories, originalTotals.totalCalories)
        XCTAssertFalse(viewModel.isSavingFood)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    func testUpdateFood_Success() async {
        // Given
        let foodLog = createMockFoodLog()
        viewModel.todaysFoodLogs = [foodLog]
        mockRepository.shouldThrowError = false
        
        // When
        await viewModel.updateFood(foodLog)
        
        // Then
        XCTAssertFalse(viewModel.isSavingFood)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(mockRepository.updateFoodLogCalled)
    }
    
    func testDeleteFood_Success() async {
        // Given
        let foodLog = createMockFoodLog()
        viewModel.todaysFoodLogs = [foodLog]
        viewModel.calculateDailyTotals()
        mockRepository.shouldThrowError = false
        
        // When
        await viewModel.deleteFood(foodLog)
        
        // Then
        XCTAssertEqual(viewModel.todaysFoodLogs.count, 0)
        XCTAssertFalse(viewModel.isDeletingFood)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(mockRepository.deleteFoodLogCalled)
        
        // Verify daily totals updated
        XCTAssertEqual(viewModel.dailyTotals.totalCalories, 0)
    }
    
    func testDeleteFood_Failure_RevertsOptimisticUpdate() async {
        // Given
        let foodLog = createMockFoodLog()
        viewModel.todaysFoodLogs = [foodLog]
        viewModel.calculateDailyTotals()
        
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = FuelLogError.persistenceError(NSError(domain: "test", code: 1))
        
        let originalCount = viewModel.todaysFoodLogs.count
        let originalTotals = viewModel.dailyTotals
        
        // When
        await viewModel.deleteFood(foodLog)
        
        // Then - optimistic update should be reverted
        XCTAssertEqual(viewModel.todaysFoodLogs.count, originalCount)
        XCTAssertEqual(viewModel.dailyTotals.totalCalories, originalTotals.totalCalories)
        XCTAssertFalse(viewModel.isDeletingFood)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    // MARK: - Nutrition Goals Tests
    
    func testUpdateNutritionGoals_NewGoals() async {
        // Given
        let goals = createMockNutritionGoals()
        mockRepository.shouldThrowError = false
        
        // When
        await viewModel.updateNutritionGoals(goals)
        
        // Then
        XCTAssertEqual(viewModel.nutritionGoals?.id, goals.id)
        XCTAssertFalse(viewModel.isLoadingGoals)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(mockRepository.saveNutritionGoalsCalled)
    }
    
    func testUpdateNutritionGoals_ExistingGoals() async {
        // Given
        let existingGoals = createMockNutritionGoals()
        viewModel.nutritionGoals = existingGoals
        
        let updatedGoals = createMockNutritionGoals()
        updatedGoals.dailyCalories = 2500
        mockRepository.shouldThrowError = false
        
        // When
        await viewModel.updateNutritionGoals(updatedGoals)
        
        // Then
        XCTAssertEqual(viewModel.nutritionGoals?.dailyCalories, 2500)
        XCTAssertFalse(viewModel.isLoadingGoals)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(mockRepository.updateNutritionGoalsCalled)
    }
    
    // MARK: - Date Navigation Tests
    
    func testNavigateToPreviousDay() {
        // Given
        let today = Date()
        viewModel.selectedDate = today
        
        // When
        viewModel.navigateToPreviousDay()
        
        // Then
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        XCTAssertTrue(Calendar.current.isDate(viewModel.selectedDate, inSameDayAs: yesterday))
    }
    
    func testNavigateToNextDay() {
        // Given
        let today = Date()
        viewModel.selectedDate = today
        
        // When
        viewModel.navigateToNextDay()
        
        // Then
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        XCTAssertTrue(Calendar.current.isDate(viewModel.selectedDate, inSameDayAs: tomorrow))
    }
    
    func testNavigateToToday() {
        // Given
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        viewModel.selectedDate = yesterday
        
        // When
        viewModel.navigateToToday()
        
        // Then
        XCTAssertTrue(Calendar.current.isDateInToday(viewModel.selectedDate))
    }
    
    // MARK: - Computed Properties Tests
    
    func testRemainingNutrition() {
        // Given
        let goals = createMockNutritionGoals()
        goals.dailyCalories = 2000
        goals.dailyProtein = 150
        viewModel.nutritionGoals = goals
        
        let foodLog = createMockFoodLog()
        foodLog.calories = 500
        foodLog.protein = 30
        viewModel.todaysFoodLogs = [foodLog]
        viewModel.calculateDailyTotals()
        
        // When
        let remaining = viewModel.remainingNutrition
        
        // Then
        XCTAssertEqual(remaining.totalCalories, 1500)
        XCTAssertEqual(remaining.totalProtein, 120)
    }
    
    func testIsSelectedDateToday() {
        // Given
        viewModel.selectedDate = Date()
        
        // Then
        XCTAssertTrue(viewModel.isSelectedDateToday)
        
        // Given
        viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        
        // Then
        XCTAssertFalse(viewModel.isSelectedDateToday)
    }
    
    func testHasNutritionGoals() {
        // Given
        viewModel.nutritionGoals = nil
        
        // Then
        XCTAssertFalse(viewModel.hasNutritionGoals)
        
        // Given
        viewModel.nutritionGoals = createMockNutritionGoals()
        
        // Then
        XCTAssertTrue(viewModel.hasNutritionGoals)
    }
    
    func testHasFoodLogs() {
        // Given
        viewModel.todaysFoodLogs = []
        
        // Then
        XCTAssertFalse(viewModel.hasFoodLogs)
        
        // Given
        viewModel.todaysFoodLogs = [createMockFoodLog()]
        
        // Then
        XCTAssertTrue(viewModel.hasFoodLogs)
    }
    
    // MARK: - Business Logic Tests
    
    func testCalculateDailyTotals() {
        // Given
        let foodLog1 = createMockFoodLog()
        foodLog1.calories = 300
        foodLog1.protein = 20
        
        let foodLog2 = createMockFoodLog()
        foodLog2.calories = 400
        foodLog2.protein = 25
        
        viewModel.todaysFoodLogs = [foodLog1, foodLog2]
        
        // When
        viewModel.calculateDailyTotals()
        
        // Then
        XCTAssertEqual(viewModel.dailyTotals.totalCalories, 700)
        XCTAssertEqual(viewModel.dailyTotals.totalProtein, 45)
    }
    
    func testUpdateNutritionProgress() {
        // Given
        let goals = createMockNutritionGoals()
        goals.dailyCalories = 2000
        goals.dailyProtein = 100
        viewModel.nutritionGoals = goals
        
        viewModel.dailyTotals.totalCalories = 1000
        viewModel.dailyTotals.totalProtein = 50
        
        // When
        viewModel.updateNutritionProgress()
        
        // Then
        XCTAssertEqual(viewModel.nutritionProgress.caloriesProgress, 0.5, accuracy: 0.01)
        XCTAssertEqual(viewModel.nutritionProgress.proteinProgress, 0.5, accuracy: 0.01)
    }
    
    func testGroupFoodLogsByMealType() {
        // Given
        let breakfastLog = createMockFoodLog()
        breakfastLog.mealType = .breakfast
        
        let lunchLog = createMockFoodLog()
        lunchLog.mealType = .lunch
        
        viewModel.todaysFoodLogs = [breakfastLog, lunchLog]
        
        // When
        viewModel.groupFoodLogsByMealType()
        
        // Then
        XCTAssertEqual(viewModel.foodLogsByMealType[.breakfast]?.count, 1)
        XCTAssertEqual(viewModel.foodLogsByMealType[.lunch]?.count, 1)
        XCTAssertEqual(viewModel.foodLogsByMealType[.dinner]?.count, 0)
        XCTAssertEqual(viewModel.foodLogsByMealType[.snacks]?.count, 0)
    }
    
    // MARK: - Extension Methods Tests
    
    func testFoodLogsForMealType() {
        // Given
        let breakfastLog = createMockFoodLog()
        breakfastLog.mealType = .breakfast
        
        let lunchLog = createMockFoodLog()
        lunchLog.mealType = .lunch
        
        viewModel.todaysFoodLogs = [breakfastLog, lunchLog]
        viewModel.groupFoodLogsByMealType()
        
        // When
        let breakfastLogs = viewModel.foodLogs(for: .breakfast)
        let dinnerLogs = viewModel.foodLogs(for: .dinner)
        
        // Then
        XCTAssertEqual(breakfastLogs.count, 1)
        XCTAssertEqual(dinnerLogs.count, 0)
    }
    
    func testNutritionTotalsForMealType() {
        // Given
        let breakfastLog = createMockFoodLog()
        breakfastLog.mealType = .breakfast
        breakfastLog.calories = 300
        breakfastLog.protein = 20
        
        viewModel.todaysFoodLogs = [breakfastLog]
        viewModel.groupFoodLogsByMealType()
        
        // When
        let breakfastTotals = viewModel.nutritionTotals(for: .breakfast)
        let lunchTotals = viewModel.nutritionTotals(for: .lunch)
        
        // Then
        XCTAssertEqual(breakfastTotals.totalCalories, 300)
        XCTAssertEqual(breakfastTotals.totalProtein, 20)
        XCTAssertEqual(lunchTotals.totalCalories, 0)
    }
    
    func testIsGoalCompleted() {
        // Given
        viewModel.nutritionProgress = NutritionProgress(
            caloriesProgress: 1.2,
            proteinProgress: 0.8,
            carbohydratesProgress: 1.0,
            fatProgress: 0.5
        )
        
        // Then
        XCTAssertTrue(viewModel.isGoalCompleted(for: .calories))
        XCTAssertFalse(viewModel.isGoalCompleted(for: .protein))
        XCTAssertTrue(viewModel.isGoalCompleted(for: .carbohydrates))
        XCTAssertFalse(viewModel.isGoalCompleted(for: .fat))
    }
    
    func testProgressForNutrient() {
        // Given
        viewModel.nutritionProgress = NutritionProgress(
            caloriesProgress: 0.75,
            proteinProgress: 0.9,
            carbohydratesProgress: 0.6,
            fatProgress: 1.1
        )
        
        // Then
        XCTAssertEqual(viewModel.progress(for: .calories), 0.75, accuracy: 0.01)
        XCTAssertEqual(viewModel.progress(for: .protein), 0.9, accuracy: 0.01)
        XCTAssertEqual(viewModel.progress(for: .carbohydrates), 0.6, accuracy: 0.01)
        XCTAssertEqual(viewModel.progress(for: .fat), 1.1, accuracy: 0.01)
    }
    
    // MARK: - Error Handling Tests
    
    func testClearError() {
        // Given
        viewModel.errorMessage = "Test error"
        
        // When
        viewModel.clearError()
        
        // Then
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Helper Methods
    
    private func createMockNutritionGoals() -> NutritionGoals {
        return NutritionGoals(
            userId: "test-user",
            dailyCalories: 2000,
            dailyProtein: 150,
            dailyCarbohydrates: 250,
            dailyFat: 67,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            bmr: 1800,
            tdee: 2000
        )
    }
    
    private func createMockFoodLog() -> FoodLog {
        return FoodLog(
            name: "Test Food",
            calories: 250,
            protein: 15,
            carbohydrates: 30,
            fat: 8,
            mealType: .breakfast,
            servingSize: 1,
            servingUnit: "serving"
        )
    }
    
    private func createMockFoodLogs() -> [FoodLog] {
        let breakfast = createMockFoodLog()
        breakfast.mealType = .breakfast
        
        let lunch = createMockFoodLog()
        lunch.mealType = .lunch
        lunch.calories = 400
        
        return [breakfast, lunch]
    }
}

// MARK: - Mock Classes

/// Mock repository for testing
class MockFuelLogRepository: FuelLogRepositoryProtocol {
    
    var shouldThrowError = false
    var errorToThrow: Error = FuelLogError.persistenceError(NSError(domain: "test", code: 1))
    
    var mockFoodLogs: [FoodLog] = []
    var mockCustomFoods: [CustomFood] = []
    var mockNutritionGoals: NutritionGoals?
    
    // Call tracking
    var fetchFoodLogsCalled = false
    var saveFoodLogCalled = false
    var updateFoodLogCalled = false
    var deleteFoodLogCalled = false
    var saveNutritionGoalsCalled = false
    var updateNutritionGoalsCalled = false
    
    nonisolated func fetchFoodLogs(for date: Date) async throws -> [FoodLog] {
        fetchFoodLogsCalled = true
        if shouldThrowError { throw errorToThrow }
        return mockFoodLogs
    }
    
    nonisolated func saveFoodLog(_ foodLog: FoodLog) async throws {
        saveFoodLogCalled = true
        if shouldThrowError { throw errorToThrow }
        mockFoodLogs.append(foodLog)
    }
    
    nonisolated func updateFoodLog(_ foodLog: FoodLog) async throws {
        updateFoodLogCalled = true
        if shouldThrowError { throw errorToThrow }
    }
    
    nonisolated func deleteFoodLog(_ foodLog: FoodLog) async throws {
        deleteFoodLogCalled = true
        if shouldThrowError { throw errorToThrow }
        mockFoodLogs.removeAll { $0.id == foodLog.id }
    }
    
    nonisolated func fetchFoodLogsByDateRange(from startDate: Date, to endDate: Date) async throws -> [FoodLog] {
        if shouldThrowError { throw errorToThrow }
        return mockFoodLogs
    }
    
    nonisolated func fetchCustomFoods() async throws -> [CustomFood] {
        if shouldThrowError { throw errorToThrow }
        return mockCustomFoods
    }
    
    nonisolated func fetchCustomFood(by id: UUID) async throws -> CustomFood? {
        if shouldThrowError { throw errorToThrow }
        return mockCustomFoods.first { $0.id == id }
    }
    
    nonisolated func saveCustomFood(_ customFood: CustomFood) async throws {
        if shouldThrowError { throw errorToThrow }
        mockCustomFoods.append(customFood)
    }
    
    nonisolated func updateCustomFood(_ customFood: CustomFood) async throws {
        if shouldThrowError { throw errorToThrow }
    }
    
    nonisolated func deleteCustomFood(_ customFood: CustomFood) async throws {
        if shouldThrowError { throw errorToThrow }
        mockCustomFoods.removeAll { $0.id == customFood.id }
    }
    
    nonisolated func searchCustomFoods(query: String) async throws -> [CustomFood] {
        if shouldThrowError { throw errorToThrow }
        return mockCustomFoods.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
    
    nonisolated func fetchNutritionGoals() async throws -> NutritionGoals? {
        if shouldThrowError { throw errorToThrow }
        return mockNutritionGoals
    }
    
    nonisolated func fetchNutritionGoals(for userId: String) async throws -> NutritionGoals? {
        if shouldThrowError { throw errorToThrow }
        return mockNutritionGoals
    }
    
    nonisolated func saveNutritionGoals(_ goals: NutritionGoals) async throws {
        saveNutritionGoalsCalled = true
        if shouldThrowError { throw errorToThrow }
        mockNutritionGoals = goals
    }
    
    nonisolated func updateNutritionGoals(_ goals: NutritionGoals) async throws {
        updateNutritionGoalsCalled = true
        if shouldThrowError { throw errorToThrow }
        mockNutritionGoals = goals
    }
    
    nonisolated func deleteNutritionGoals(_ goals: NutritionGoals) async throws {
        if shouldThrowError { throw errorToThrow }
        mockNutritionGoals = nil
    }
}

/// Mock HealthKit manager for testing
class MockFuelLogHealthKitManager: FuelLogHealthKitManager {
    
    var shouldThrowError = false
    var errorToThrow: Error = FuelLogError.healthKitAuthorizationDenied
    
    // Call tracking
    var writeNutritionDataCalled = false
    
    func writeNutritionData(_ foodLog: FoodLog) async throws {
        writeNutritionDataCalled = true
        if shouldThrowError { throw errorToThrow }
    }
}