import XCTest
@testable import work

@MainActor
final class ErrorHandlingTests: XCTestCase {
    
    var errorHandler: ErrorHandler!
    var loadingManager: LoadingStateManager!
    var networkManager: NetworkStatusManager!
    
    override func setUp() async throws {
        try await super.setUp()
        errorHandler = ErrorHandler()
        loadingManager = LoadingStateManager()
        networkManager = NetworkStatusManager()
    }
    
    override func tearDown() async throws {
        errorHandler = nil
        loadingManager = nil
        networkManager = nil
        try await super.tearDown()
    }
    
    // MARK: - ErrorHandler Tests
    
    func testErrorHandlerHandlesBasicError() async {
        // Given
        let testError = FuelLogError.foodNotFound
        
        // When
        errorHandler.handleError(testError)
        
        // Then
        XCTAssertEqual(errorHandler.currentError, testError)
        XCTAssertTrue(errorHandler.showErrorAlert)
        XCTAssertEqual(errorHandler.retryCount, 0)
    }
    
    func testErrorHandlerConvertsNetworkError() async {
        // Given
        let networkError = FoodNetworkError.rateLimitExceeded
        
        // When
        errorHandler.handleError(networkError)
        
        // Then
        XCTAssertEqual(errorHandler.currentError, FuelLogError.rateLimitExceeded)
        XCTAssertTrue(errorHandler.showErrorAlert)
    }
    
    func testErrorHandlerRetryMechanism() async {
        // Given
        let retryableError = FuelLogError.networkError(FoodNetworkError.serverError)
        var retryCallCount = 0
        let retryAction = {
            retryCallCount += 1
        }
        
        // When
        errorHandler.handleError(retryableError, retryAction: retryAction)
        
        // Wait for retry to execute
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertEqual(retryCallCount, 1)
        XCTAssertEqual(errorHandler.retryCount, 1)
        XCTAssertTrue(errorHandler.isRetryable)
    }
    
    func testErrorHandlerMaxRetryAttempts() async {
        // Given
        let retryableError = FuelLogError.networkError(FoodNetworkError.serverError)
        var retryCallCount = 0
        let retryAction = {
            retryCallCount += 1
            // Simulate continued failure
            throw retryableError
        }
        
        // When
        errorHandler.handleError(retryableError, retryAction: retryAction)
        
        // Wait for all retries to complete
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Then
        XCTAssertLessThanOrEqual(errorHandler.retryCount, 3) // Max retry attempts
    }
    
    func testErrorHandlerClearError() async {
        // Given
        let testError = FuelLogError.foodNotFound
        errorHandler.handleError(testError)
        
        // When
        errorHandler.clearError()
        
        // Then
        XCTAssertNil(errorHandler.currentError)
        XCTAssertFalse(errorHandler.showErrorAlert)
        XCTAssertEqual(errorHandler.retryCount, 0)
        XCTAssertFalse(errorHandler.isRetrying)
    }
    
    func testErrorHandlerNonRetryableError() async {
        // Given
        let nonRetryableError = FuelLogError.invalidNutritionData
        var retryCallCount = 0
        let retryAction = {
            retryCallCount += 1
        }
        
        // When
        errorHandler.handleError(nonRetryableError, retryAction: retryAction)
        
        // Wait briefly
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertEqual(retryCallCount, 0) // Should not retry
        XCTAssertEqual(errorHandler.retryCount, 0)
        XCTAssertFalse(nonRetryableError.isRetryable)
    }
    
    // MARK: - LoadingStateManager Tests
    
    func testLoadingStateManagerStartLoading() async {
        // Given
        let taskId = "test-task"
        let message = "Loading test data..."
        
        // When
        loadingManager.startLoading(taskId: taskId, message: message, showProgress: true)
        
        // Then
        XCTAssertTrue(loadingManager.isLoading)
        XCTAssertEqual(loadingManager.loadingMessage, message)
        XCTAssertTrue(loadingManager.showProgress)
        XCTAssertEqual(loadingManager.progress, 0.0)
        XCTAssertTrue(loadingManager.isTaskLoading(taskId))
    }
    
    func testLoadingStateManagerUpdateProgress() async {
        // Given
        loadingManager.startLoading(showProgress: true)
        let newProgress = 0.5
        let newMessage = "50% complete"
        
        // When
        loadingManager.updateProgress(newProgress, message: newMessage)
        
        // Then
        XCTAssertEqual(loadingManager.progress, newProgress)
        XCTAssertEqual(loadingManager.loadingMessage, newMessage)
    }
    
    func testLoadingStateManagerStopLoading() async {
        // Given
        let taskId = "test-task"
        loadingManager.startLoading(taskId: taskId)
        
        // When
        loadingManager.stopLoading(taskId: taskId)
        
        // Then
        XCTAssertFalse(loadingManager.isLoading)
        XCTAssertFalse(loadingManager.showProgress)
        XCTAssertEqual(loadingManager.progress, 0.0)
        XCTAssertFalse(loadingManager.isTaskLoading(taskId))
    }
    
    func testLoadingStateManagerMultipleTasks() async {
        // Given
        let taskId1 = "task-1"
        let taskId2 = "task-2"
        
        // When
        loadingManager.startLoading(taskId: taskId1)
        loadingManager.startLoading(taskId: taskId2)
        
        // Then
        XCTAssertTrue(loadingManager.isLoading)
        XCTAssertTrue(loadingManager.isTaskLoading(taskId1))
        XCTAssertTrue(loadingManager.isTaskLoading(taskId2))
        
        // When stopping one task
        loadingManager.stopLoading(taskId: taskId1)
        
        // Then
        XCTAssertTrue(loadingManager.isLoading) // Still loading task2
        XCTAssertFalse(loadingManager.isTaskLoading(taskId1))
        XCTAssertTrue(loadingManager.isTaskLoading(taskId2))
        
        // When stopping all tasks
        loadingManager.stopAllLoading()
        
        // Then
        XCTAssertFalse(loadingManager.isLoading)
        XCTAssertFalse(loadingManager.isTaskLoading(taskId1))
        XCTAssertFalse(loadingManager.isTaskLoading(taskId2))
    }
    
    // MARK: - FuelLogError Tests
    
    func testFuelLogErrorRetryableProperties() {
        // Test retryable errors
        let retryableErrors: [FuelLogError] = [
            .networkError(FoodNetworkError.serverError),
            .rateLimitExceeded,
            .serverUnavailable,
            .timeout,
            .persistenceError(NSError(domain: "test", code: 1))
        ]
        
        for error in retryableErrors {
            XCTAssertTrue(error.isRetryable, "Error \(error) should be retryable")
            XCTAssertGreaterThan(error.retryDelay, 0, "Error \(error) should have retry delay")
        }
        
        // Test non-retryable errors
        let nonRetryableErrors: [FuelLogError] = [
            .healthKitNotAvailable,
            .healthKitAuthorizationDenied,
            .invalidBarcode,
            .foodNotFound,
            .invalidNutritionData,
            .invalidUserData,
            .calculationError,
            .dataCorruption,
            .insufficientStorage,
            .operationCancelled
        ]
        
        for error in nonRetryableErrors {
            XCTAssertFalse(error.isRetryable, "Error \(error) should not be retryable")
            XCTAssertEqual(error.retryDelay, 0, "Error \(error) should have no retry delay")
        }
    }
    
    func testFuelLogErrorEquality() {
        // Test equality for simple cases
        XCTAssertEqual(FuelLogError.foodNotFound, FuelLogError.foodNotFound)
        XCTAssertEqual(FuelLogError.invalidBarcode, FuelLogError.invalidBarcode)
        XCTAssertNotEqual(FuelLogError.foodNotFound, FuelLogError.invalidBarcode)
        
        // Test equality for errors with associated values
        let error1 = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let error2 = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let error3 = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Different error"])
        
        XCTAssertEqual(
            FuelLogError.networkError(error1),
            FuelLogError.networkError(error2)
        )
        XCTAssertNotEqual(
            FuelLogError.networkError(error1),
            FuelLogError.networkError(error3)
        )
    }
    
    func testFuelLogErrorLocalizedDescriptions() {
        let errors: [FuelLogError] = [
            .healthKitNotAvailable,
            .healthKitAuthorizationDenied,
            .networkError(FoodNetworkError.serverError),
            .invalidBarcode,
            .foodNotFound,
            .invalidNutritionData,
            .persistenceError(NSError(domain: "test", code: 1)),
            .invalidUserData,
            .calculationError,
            .rateLimitExceeded,
            .serverUnavailable,
            .dataCorruption,
            .insufficientStorage,
            .operationCancelled,
            .timeout
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have error description")
            XCTAssertNotNil(error.failureReason, "Error \(error) should have failure reason")
            XCTAssertNotNil(error.recoverySuggestion, "Error \(error) should have recovery suggestion")
            
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
            XCTAssertFalse(error.failureReason!.isEmpty, "Failure reason should not be empty")
            XCTAssertFalse(error.recoverySuggestion!.isEmpty, "Recovery suggestion should not be empty")
        }
    }
    
    // MARK: - Integration Tests
    
    func testErrorHandlerWithLoadingManager() async {
        // Given
        let testError = FuelLogError.networkError(FoodNetworkError.serverError)
        loadingManager.startLoading(taskId: "test-operation")
        
        // When
        errorHandler.handleError(testError)
        
        // Then
        XCTAssertTrue(loadingManager.isLoading) // Loading should continue independently
        XCTAssertEqual(errorHandler.currentError, testError)
        XCTAssertTrue(errorHandler.showErrorAlert)
        
        // When clearing error
        errorHandler.clearError()
        
        // Then
        XCTAssertNil(errorHandler.currentError)
        XCTAssertFalse(errorHandler.showErrorAlert)
        XCTAssertTrue(loadingManager.isLoading) // Loading state unaffected
    }
    
    func testGracefulDegradationScenario() async {
        // Given - simulate network failure with cached data available
        let networkError = FuelLogError.networkError(FoodNetworkError.noInternetConnection)
        var fallbackDataUsed = false
        
        let operationWithFallback = {
            // Simulate trying network operation
            throw networkError
        }
        
        let fallbackOperation = {
            fallbackDataUsed = true
        }
        
        // When
        do {
            try await operationWithFallback()
        } catch {
            // Graceful degradation - use cached/local data
            await fallbackOperation()
            errorHandler.handleError(error, context: "Network operation with fallback")
        }
        
        // Then
        XCTAssertTrue(fallbackDataUsed, "Should use fallback data when network fails")
        XCTAssertEqual(errorHandler.currentError, networkError)
        XCTAssertTrue(errorHandler.showErrorAlert)
    }
}

// MARK: - Mock Classes for Testing

class MockRetryableOperation {
    var callCount = 0
    var shouldSucceed = false
    
    func execute() async throws {
        callCount += 1
        
        if !shouldSucceed {
            throw FuelLogError.networkError(FoodNetworkError.serverError)
        }
    }
}

// MARK: - Performance Tests

extension ErrorHandlingTests {
    
    func testErrorHandlerPerformance() {
        measure {
            let errorHandler = ErrorHandler()
            
            for _ in 0..<1000 {
                errorHandler.handleError(FuelLogError.foodNotFound)
                errorHandler.clearError()
            }
        }
    }
    
    func testLoadingManagerPerformance() {
        measure {
            let loadingManager = LoadingStateManager()
            
            for i in 0..<1000 {
                loadingManager.startLoading(taskId: "task-\(i)")
                loadingManager.updateProgress(Double(i % 100) / 100.0)
                loadingManager.stopLoading(taskId: "task-\(i)")
            }
        }
    }
}