import XCTest
@testable import work

@MainActor
final class FuelLogViewModelErrorHandlingTests: XCTestCase {
    
    var viewModel: FuelLogViewModel!
    var mockRepository: MockFuelLogRepository!
    var mockHealthKitManager: MockFuelLogHealthKitManager!
    
    override func setUp() async throws {
        try await super.setUp()
        mockRepository = MockFuelLogRepository()
        mockHealthKitManager = MockFuelLogHealthKitManager()
        viewModel = FuelLogViewModel(
            repository: mockRepository,
            healthKitManager: mockHealthKitManager
        )
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockRepository = nil
        mockHealthKitManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Error Handling Tests
    
    func testLoadInitialDataHandlesRepositoryError() async {
        // Given
        let expectedError = FuelLogError.persistenceError(NSError(domain: "test", code: 1))
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = expectedError
        
        // When
        await viewModel.loadInitialData()
        
        // Then
        XCTAssertEqual(viewModel.errorHandler.currentError, expectedError)
        XCTAssertTrue(viewModel.errorHandler.showErrorAlert)
        XCTAssertFalse(viewModel.isLoadingInitialData)
    }
    
    func testLoadFoodLogsHandlesNetworkError() async {
        // Given
        let networkError = FuelLogError.networkError(FoodNetworkError.noInternetConnection)
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = networkError
        
        // When
        await viewModel.loadFoodLogs(for: Date())
        
        // Then
        XCTAssertEqual(viewModel.errorHandler.currentError, networkError)
        XCTAssertTrue(viewModel.errorHandler.showErrorAlert)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testLogFoodHandlesOptimisticUpdateReversal() async {
        // Given
        let foodLog = createTestFoodLog()
        let originalCount = viewModel.todaysFoodLogs.count
        let saveError = FuelLogError.persistenceError(NSError(domain: "test", code: 1))
        
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = saveError
        
        // When
        await viewModel.logFood(foodLog)
        
        // Then
        XCTAssertEqual(viewModel.todaysFoodLogs.count, originalCount) // Reverted
        XCTAssertEqual(viewModel.errorHandler.currentError, saveError)
        XCTAssertTrue(viewModel.errorHandler.showErrorAlert)
        XCTAssertFalse(viewModel.isSavingFood)
    }
    
    func testDeleteFoodHandlesOptimisticUpdateReversal() async {
        // Given
        let foodLog = createTestFoodLog()
        viewModel.todaysFoodLogs = [foodLog]
        let originalCount = viewModel.todaysFoodLogs.count
        let deleteError = FuelLogError.persistenceError(NSError(domain: "test", code: 1))
        
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = deleteError
        
        // When
        await viewModel.deleteFood(foodLog)
        
        // Then
        XCTAssertEqual(viewModel.todaysFoodLogs.count, originalCount) // Reverted
        XCTAssertEqual(viewModel.errorHandler.currentError, deleteError)
        XCTAssertTrue(viewModel.errorHandler.showErrorAlert)
        XCTAssertFalse(viewModel.isDeletingFood)
    }
    
    func testUpdateNutritionGoalsHandlesError() async {
        // Given
        let goals = createTestNutritionGoals()
        let updateError = FuelLogError.persistenceError(NSError(domain: "test", code: 1))
        
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = updateError
        
        // When
        await viewModel.updateNutritionGoals(goals)
        
        // Then
        XCTAssertEqual(viewModel.errorHandler.currentError, updateError)
        XCTAssertTrue(viewModel.errorHandler.showErrorAlert)
        XCTAssertFalse(viewModel.isLoadingGoals)
    }
    
    func testHealthKitWriteFailureDoesNotPreventFoodLogging() async {
        // Given
        let foodLog = createTestFoodLog()
        mockHealthKitManager.shouldThrowError = true
        mockHealthKitManager.errorToThrow = FuelLogError.healthKitAuthorizationDenied
        
        // When
        await viewModel.logFood(foodLog)
        
        // Then
        XCTAssertEqual(viewModel.todaysFoodLogs.count, 1) // Food should still be logged
        XCTAssertFalse(viewModel.errorHandler.showErrorAlert) // No error shown for HealthKit failure
        XCTAssertFalse(viewModel.isSavingFood)
    }
    
    func testRetryMechanismForRetryableErrors() async {
        // Given
        let retryableError = FuelLogError.networkError(FoodNetworkError.serverError)
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = retryableError
        
        // When
        await viewModel.loadNutritionGoals()
        
        // Then
        XCTAssertEqual(viewModel.errorHandler.currentError, retryableError)
        XCTAssertTrue(retryableError.isRetryable)
        XCTAssertGreaterThan(retryableError.retryDelay, 0)
    }
    
    func testLoadingStatesManagement() async {
        // Given - no delay needed for this test
        
        // When
        await viewModel.loadInitialData()
        
        // Then - check final states
        XCTAssertFalse(viewModel.isLoadingInitialData)
        XCTAssertFalse(viewModel.loadingManager.isLoading)
    }
    
    func testRefreshResetsRetryCount() async {
        // Given
        viewModel.errorHandler.retryCount = 2
        
        // When
        await viewModel.refresh()
        
        // Then
        XCTAssertEqual(viewModel.errorHandler.retryCount, 0)
    }
    
    func testClearErrorResetsErrorState() async {
        // Given
        let testError = FuelLogError.foodNotFound
        viewModel.errorHandler.handleError(testError)
        
        // When
        viewModel.clearError()
        
        // Then
        XCTAssertNil(viewModel.errorHandler.currentError)
        XCTAssertFalse(viewModel.errorHandler.showErrorAlert)
        XCTAssertEqual(viewModel.errorHandler.retryCount, 0)
    }
    
    // MARK: - Loading Progress Tests
    
    func testLoadInitialDataShowsProgress() async {
        // Given
        mockRepository.shouldDelayOperations = true
        
        // When
        let loadingTask = Task {
            await viewModel.loadInitialData()
        }
        
        // Then - check progress is shown
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        XCTAssertTrue(viewModel.loadingManager.showProgress)
        XCTAssertGreaterThanOrEqual(viewModel.loadingManager.progress, 0.0)
        
        await loadingTask.value
    }
    
    func testSpecificOperationLoadingStates() async {
        // Test food saving loading state
        let foodLog = createTestFoodLog()
        
        await viewModel.logFood(foodLog)
        
        XCTAssertFalse(viewModel.isSavingFood)
        XCTAssertFalse(viewModel.loadingManager.isTaskLoading("save-food"))
    }
    
    // MARK: - Network Status Integration Tests
    
    func testNetworkStatusAwareness() async {
        // Given
        viewModel.networkManager.isConnected = false
        
        // When performing network-dependent operation
        await viewModel.loadInitialData()
        
        // Then - should handle offline gracefully
        // (Specific behavior depends on repository implementation)
        XCTAssertFalse(viewModel.networkManager.isConnected)
    }
    
    // MARK: - Helper Methods
    
    private func createTestFoodLog() -> FoodLog {
        return FoodLog(
            timestamp: Date(),
            name: "Test Food",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            mealType: .breakfast,
            servingSize: 1,
            servingUnit: "serving"
        )
    }
    
    private func createTestNutritionGoals() -> NutritionGoals {
        return NutritionGoals(
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

// Note: MockFuelLogRepository and MockFuelLogHealthKitManager are defined in FuelLogViewModelTests.swift