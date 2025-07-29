import XCTest
@testable import work

@MainActor
final class FoodSearchViewModelTests: XCTestCase {
    
    var viewModel: FoodSearchViewModel!
    var mockRepository: MockFuelLogRepository!
    var mockNetworkManager: MockFoodNetworkManager!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockFuelLogRepository()
        mockNetworkManager = MockFoodNetworkManager()
        viewModel = FoodSearchViewModel(
            networkManager: mockNetworkManager,
            repository: mockRepository
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockRepository = nil
        mockNetworkManager = nil
        super.tearDown()
    }
    
    // MARK: - Search Tests
    
    func testSearchWithEmptyQuery() async {
        // Given
        let emptyQuery = ""
        
        // When
        await viewModel.search(query: emptyQuery)
        
        // Then
        XCTAssertTrue(viewModel.searchResults.isEmpty)
        XCTAssertFalse(viewModel.isSearching)
    }
    
    func testSearchWithValidQuery() async {
        // Given
        let query = "chicken"
        let mockCustomFood = CustomFood(
            name: "Custom Chicken Breast",
            caloriesPerServing: 165,
            proteinPerServing: 31,
            carbohydratesPerServing: 0,
            fatPerServing: 3.6,
            servingSize: 100,
            servingUnit: "g"
        )
        mockRepository.mockCustomFoods = [mockCustomFood]
        
        let mockApiResult = FoodSearchResult(
            id: "api-1",
            name: "API Chicken Breast",
            brand: "Test Brand",
            calories: 170,
            protein: 32,
            carbohydrates: 0,
            fat: 4,
            servingSize: 100,
            servingUnit: "g",
            imageUrl: nil,
            source: .openFoodFacts
        )
        mockNetworkManager.mockSearchResults = [mockApiResult]
        
        // When
        await viewModel.search(query: query)
        
        // Then
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertEqual(viewModel.searchResults.count, 2)
        
        // Verify local results come first
        XCTAssertEqual(viewModel.searchResults[0].source, .custom)
        XCTAssertEqual(viewModel.searchResults[1].source, .openFoodFacts)
    }
    
    func testSearchWithNetworkError() async {
        // Given
        let query = "chicken"
        let mockCustomFood = CustomFood(
            name: "Custom Chicken Breast",
            caloriesPerServing: 165,
            proteinPerServing: 31,
            carbohydratesPerServing: 0,
            fatPerServing: 3.6,
            servingSize: 100,
            servingUnit: "g"
        )
        mockRepository.mockCustomFoods = [mockCustomFood]
        mockNetworkManager.shouldThrowError = true
        mockNetworkManager.errorToThrow = FoodNetworkError.noInternetConnection
        
        // When
        await viewModel.search(query: query)
        
        // Then
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertEqual(viewModel.searchResults.count, 1) // Only local results
        XCTAssertEqual(viewModel.searchResults[0].source, .custom)
    }
    
    func testSearchCaching() async {
        // Given
        let query = "chicken"
        let mockApiResult = FoodSearchResult(
            id: "api-1",
            name: "API Chicken Breast",
            brand: "Test Brand",
            calories: 170,
            protein: 32,
            carbohydrates: 0,
            fat: 4,
            servingSize: 100,
            servingUnit: "g",
            imageUrl: nil,
            source: .openFoodFacts
        )
        mockNetworkManager.mockSearchResults = [mockApiResult]
        
        // When - First search
        await viewModel.search(query: query)
        let firstCallCount = mockNetworkManager.searchCallCount
        
        // When - Second search with same query
        await viewModel.search(query: query)
        let secondCallCount = mockNetworkManager.searchCallCount
        
        // Then - Network should only be called once due to caching
        XCTAssertEqual(firstCallCount, 1)
        XCTAssertEqual(secondCallCount, 1) // Should not increase
        XCTAssertEqual(viewModel.searchResults.count, 1)
    }
    
    func testCreateCustomFood() async {
        // Given
        let customFood = CustomFood(
            name: "Test Food",
            caloriesPerServing: 100,
            proteinPerServing: 10,
            carbohydratesPerServing: 5,
            fatPerServing: 2,
            servingSize: 1,
            servingUnit: "serving"
        )
        
        // When
        let success = await viewModel.createCustomFood(customFood)
        
        // Then
        XCTAssertTrue(success)
        XCTAssertEqual(mockRepository.mockCustomFoods.count, 1)
        XCTAssertEqual(mockRepository.mockCustomFoods[0].name, "Test Food")
    }
    
    func testBarcodeSearch() async {
        // Given
        let barcode = "1234567890"
        let mockResult = FoodSearchResult(
            id: "barcode-1",
            name: "Barcode Product",
            brand: "Test Brand",
            calories: 200,
            protein: 15,
            carbohydrates: 20,
            fat: 8,
            servingSize: 100,
            servingUnit: "g",
            imageUrl: nil,
            source: .openFoodFacts
        )
        mockNetworkManager.mockBarcodeResult = mockResult
        
        // When
        await viewModel.searchByBarcode(barcode)
        
        // Then
        XCTAssertFalse(viewModel.isLoadingBarcode)
        XCTAssertNotNil(viewModel.barcodeResult)
        XCTAssertTrue(viewModel.showBarcodeResult)
        XCTAssertEqual(viewModel.barcodeResult?.name, "Barcode Product")
    }
    
    func testClearSearch() {
        // Given
        viewModel.searchText = "test"
        viewModel.searchResults = [
            FoodSearchResult(
                id: "1",
                name: "Test",
                brand: nil,
                calories: 100,
                protein: 10,
                carbohydrates: 5,
                fat: 2,
                servingSize: 1,
                servingUnit: "serving",
                imageUrl: nil,
                source: .custom
            )
        ]
        viewModel.errorMessage = "Test error"
        viewModel.showErrorAlert = true
        
        // When
        viewModel.clearSearch()
        
        // Then
        XCTAssertTrue(viewModel.searchText.isEmpty)
        XCTAssertTrue(viewModel.searchResults.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showErrorAlert)
    }
}

// MARK: - Mock Network Manager

class MockFoodNetworkManager: FoodNetworkManager {
    var shouldThrowError = false
    var errorToThrow: Error = FoodNetworkError.networkError(NSError(domain: "test", code: 1))
    var mockSearchResults: [FoodSearchResult] = []
    var mockBarcodeResult: FoodSearchResult?
    var searchCallCount = 0
    var barcodeCallCount = 0
    
    override func searchFoodByName(_ query: String, page: Int = 1) async throws -> [FoodSearchResult] {
        searchCallCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
        return mockSearchResults
    }
    
    override func searchFoodByBarcode(_ barcode: String) async throws -> FoodSearchResult {
        barcodeCallCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
        guard let result = mockBarcodeResult else {
            throw FoodNetworkError.productNotFound
        }
        return result
    }
}