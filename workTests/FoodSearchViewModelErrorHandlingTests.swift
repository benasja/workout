import XCTest
@testable import work

@MainActor
final class FoodSearchViewModelErrorHandlingTests: XCTestCase {
    
    var viewModel: FoodSearchViewModel!
    var mockNetworkManager: MockFoodNetworkManager!
    var mockRepository: MockFuelLogRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        mockNetworkManager = MockFoodNetworkManager()
        mockRepository = MockFuelLogRepository()
        viewModel = FoodSearchViewModel(
            networkManager: mockNetworkManager,
            repository: mockRepository
        )
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockNetworkManager = nil
        mockRepository = nil
        try await super.tearDown()
    }
    
    // MARK: - Barcode Search Error Handling Tests
    
    func testBarcodeSearchHandlesNetworkError() async {
        // Given
        let barcode = "1234567890"
        let networkError = FoodNetworkError.noInternetConnection
        mockNetworkManager.shouldFailBarcodeSearch = true
        mockNetworkManager.errorToThrow = networkError
        
        // When
        await viewModel.searchByBarcode(barcode)
        
        // Then
        XCTAssertNil(viewModel.barcodeResult)
        XCTAssertFalse(viewModel.showBarcodeResult)
        XCTAssertEqual(viewModel.errorHandler.currentError, FuelLogError.networkError(networkError))
        XCTAssertTrue(viewModel.errorHandler.showErrorAlert)
        XCTAssertFalse(viewModel.isLoadingBarcode)
    }
    
    func testBarcodeSearchHandlesProductNotFound() async {
        // Given
        let barcode = "0000000000"
        mockNetworkManager.shouldFailBarcodeSearch = true
        mockNetworkManager.errorToThrow = FoodNetworkError.productNotFound
        
        // When
        await viewModel.searchByBarcode(barcode)
        
        // Then
        XCTAssertNil(viewModel.barcodeResult)
        XCTAssertFalse(viewModel.showBarcodeResult)
        XCTAssertEqual(viewModel.errorHandler.currentError, FuelLogError.foodNotFound)
        XCTAssertTrue(viewModel.errorHandler.showErrorAlert)
    }
    
    func testBarcodeSearchHandlesRateLimitError() async {
        // Given
        let barcode = "1234567890"
        mockNetworkManager.shouldFailBarcodeSearch = true
        mockNetworkManager.errorToThrow = FoodNetworkError.rateLimitExceeded
        
        // When
        await viewModel.searchByBarcode(barcode)
        
        // Then
        XCTAssertEqual(viewModel.errorHandler.currentError, FuelLogError.rateLimitExceeded)
        XCTAssertTrue(viewModel.errorHandler.currentError?.isRetryable ?? false)
        XCTAssertGreaterThan(viewModel.errorHandler.currentError?.retryDelay ?? 0, 0)
    }
    
    func testBarcodeSearchLoadingStates() async {
        // Given
        let barcode = "1234567890"
        mockNetworkManager.shouldDelayOperations = true
        
        // When
        let searchTask = Task {
            await viewModel.searchByBarcode(barcode)
        }
        
        // Then - check loading states
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        XCTAssertTrue(viewModel.isLoadingBarcode)
        XCTAssertTrue(viewModel.loadingManager.isTaskLoading("barcode-search"))
        
        await searchTask.value
        XCTAssertFalse(viewModel.isLoadingBarcode)
        XCTAssertFalse(viewModel.loadingManager.isTaskLoading("barcode-search"))
    }
    
    // MARK: - Text Search Error Handling Tests
    
    func testTextSearchHandlesNetworkErrorWithLocalFallback() async {
        // Given
        let query = "apple"
        let customFood = createTestCustomFood(name: "Apple")
        mockRepository.mockCustomFoods = [customFood]
        mockNetworkManager.shouldFailNameSearch = true
        mockNetworkManager.errorToThrow = FoodNetworkError.noInternetConnection
        
        // When
        await viewModel.search(query: query)
        
        // Then
        XCTAssertEqual(viewModel.searchResults.count, 1) // Local result shown
        XCTAssertEqual(viewModel.searchResults.first?.name, "Apple")
        XCTAssertFalse(viewModel.errorHandler.showErrorAlert) // No error if local results available
    }
    
    func testTextSearchHandlesNetworkErrorWithoutLocalResults() async {
        // Given
        let query = "nonexistent"
        mockRepository.mockCustomFoods = []
        mockNetworkManager.shouldFailNameSearch = true
        mockNetworkManager.errorToThrow = FoodNetworkError.noInternetConnection
        
        // When
        await viewModel.search(query: query)
        
        // Then
        XCTAssertTrue(viewModel.searchResults.isEmpty)
        XCTAssertEqual(viewModel.errorHandler.currentError, FuelLogError.networkError(FoodNetworkError.noInternetConnection))
        XCTAssertTrue(viewModel.errorHandler.showErrorAlert)
    }
    
    func testTextSearchHandlesOfflineMode() async {
        // Given
        let query = "apple"
        let customFood = createTestCustomFood(name: "Apple")
        mockRepository.mockCustomFoods = [customFood]
        viewModel.networkManager.isConnected = false
        
        // When
        await viewModel.search(query: query)
        
        // Then
        XCTAssertEqual(viewModel.searchResults.count, 1) // Only local results
        XCTAssertEqual(viewModel.searchResults.first?.source, .custom)
        XCTAssertFalse(mockNetworkManager.searchFoodByNameCalled) // Network not called when offline
    }
    
    func testTextSearchLoadingStates() async {
        // Given
        let query = "apple"
        mockNetworkManager.shouldDelayOperations = true
        
        // When
        let searchTask = Task {
            await viewModel.search(query: query)
        }
        
        // Then - check loading states
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        XCTAssertTrue(viewModel.isSearching)
        XCTAssertTrue(viewModel.loadingManager.isTaskLoading("food-search"))
        
        await searchTask.value
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertFalse(viewModel.loadingManager.isTaskLoading("food-search"))
    }
    
    // MARK: - Custom Food Operations Error Handling Tests
    
    func testCreateCustomFoodHandlesError() async {
        // Given
        let customFood = createTestCustomFood()
        let saveError = FuelLogError.persistenceError(NSError(domain: "test", code: 1))
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = saveError
        
        // When
        let result = await viewModel.createCustomFood(customFood)
        
        // Then
        XCTAssertFalse(result)
        XCTAssertEqual(viewModel.errorHandler.currentError, saveError)
        XCTAssertTrue(viewModel.errorHandler.showErrorAlert)
    }
    
    func testDeleteCustomFoodHandlesError() async {
        // Given
        let customFood = createTestCustomFood()
        let deleteError = FuelLogError.persistenceError(NSError(domain: "test", code: 1))
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = deleteError
        
        // When
        await viewModel.deleteCustomFood(customFood)
        
        // Then
        XCTAssertEqual(viewModel.errorHandler.currentError, deleteError)
        XCTAssertTrue(viewModel.errorHandler.showErrorAlert)
    }
    
    func testLoadCustomFoodsHandlesError() async {
        // Given
        let loadError = FuelLogError.persistenceError(NSError(domain: "test", code: 1))
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = loadError
        
        // When
        // Trigger loadCustomFoods by creating a new viewModel
        let newViewModel = FoodSearchViewModel(
            networkManager: mockNetworkManager,
            repository: mockRepository
        )
        
        // Wait for initialization to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertEqual(newViewModel.errorHandler.currentError, loadError)
        XCTAssertTrue(newViewModel.errorHandler.showErrorAlert)
    }
    
    // MARK: - Cache and Retry Tests
    
    func testSearchUsesCache() async {
        // Given
        let query = "apple"
        let apiResult = createTestFoodSearchResult(name: "Apple API")
        mockNetworkManager.resultsToReturn = [apiResult]
        
        // First search
        await viewModel.search(query: query)
        let firstCallCount = mockNetworkManager.searchFoodByNameCallCount
        
        // Second search with same query
        await viewModel.search(query: query)
        let secondCallCount = mockNetworkManager.searchFoodByNameCallCount
        
        // Then
        XCTAssertEqual(firstCallCount, 1)
        XCTAssertEqual(secondCallCount, 1) // Should not increase due to caching
        XCTAssertFalse(viewModel.searchResults.isEmpty)
    }
    
    func testRetryMechanismForRetryableErrors() async {
        // Given
        let barcode = "1234567890"
        let retryableError = FoodNetworkError.serverError
        mockNetworkManager.shouldFailBarcodeSearch = true
        mockNetworkManager.errorToThrow = retryableError
        
        // When
        await viewModel.searchByBarcode(barcode)
        
        // Then
        let fuelLogError = FuelLogError.networkError(retryableError)
        XCTAssertTrue(fuelLogError.isRetryable)
        XCTAssertGreaterThan(fuelLogError.retryDelay, 0)
    }
    
    // MARK: - Search Debouncing Tests
    
    func testSearchTextDebouncing() async {
        // Given
        mockNetworkManager.shouldDelayOperations = false
        
        // When - rapid text changes
        viewModel.searchText = "a"
        viewModel.searchText = "ap"
        viewModel.searchText = "app"
        viewModel.searchText = "appl"
        viewModel.searchText = "apple"
        
        // Wait for debounce delay
        try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        // Then - should only search once for final text
        XCTAssertLessThanOrEqual(mockNetworkManager.searchFoodByNameCallCount, 1)
    }
    
    // MARK: - Helper Methods
    
    private func createTestCustomFood(name: String = "Test Food") -> CustomFood {
        return CustomFood(
            name: name,
            caloriesPerServing: 100,
            proteinPerServing: 10,
            carbohydratesPerServing: 15,
            fatPerServing: 5,
            servingSize: 1,
            servingUnit: "serving"
        )
    }
    
    private func createTestFoodSearchResult(name: String = "Test Food") -> FoodSearchResult {
        return FoodSearchResult(
            id: UUID().uuidString,
            name: name,
            brand: "Test Brand",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            servingSize: 1,
            servingUnit: "serving",
            imageUrl: nil,
            source: .api
        )
    }
}

// MARK: - Mock Network Manager

class MockFoodNetworkManager: FoodNetworkManager {
    var shouldFailBarcodeSearch = false
    var shouldFailNameSearch = false
    var shouldDelayOperations = false
    var errorToThrow: Error = FoodNetworkError.serverError
    var resultsToReturn: [FoodSearchResult] = []
    
    var searchFoodByBarcodeCalled = false
    var searchFoodByNameCalled = false
    var searchFoodByNameCallCount = 0
    
    override func searchFoodByBarcode(_ barcode: String) async throws -> FoodSearchResult {
        searchFoodByBarcodeCalled = true
        
        if shouldDelayOperations {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        if shouldFailBarcodeSearch {
            throw errorToThrow
        }
        
        return FoodSearchResult(
            id: barcode,
            name: "Test Product",
            brand: "Test Brand",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            servingSize: 1,
            servingUnit: "serving",
            imageUrl: nil,
            source: .api
        )
    }
    
    override func searchFoodByName(_ query: String, page: Int = 1) async throws -> [FoodSearchResult] {
        searchFoodByNameCalled = true
        searchFoodByNameCallCount += 1
        
        if shouldDelayOperations {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        if shouldFailNameSearch {
            throw errorToThrow
        }
        
        return resultsToReturn
    }
}

// Note: MockFuelLogRepository is defined in FuelLogViewModelTests.swift