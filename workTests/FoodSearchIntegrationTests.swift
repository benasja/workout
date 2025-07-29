import XCTest
@testable import work

@MainActor
final class FoodSearchIntegrationTests: XCTestCase {
    
    var repository: MockFuelLogRepository!
    var networkManager: MockFoodNetworkManager!
    var searchViewModel: FoodSearchViewModel!
    
    override func setUp() {
        super.setUp()
        repository = MockFuelLogRepository()
        networkManager = MockFoodNetworkManager()
        searchViewModel = FoodSearchViewModel(
            networkManager: networkManager,
            repository: repository
        )
    }
    
    override func tearDown() {
        searchViewModel = nil
        networkManager = nil
        repository = nil
        super.tearDown()
    }
    
    // MARK: - Integration Tests
    
    func testCompleteSearchFlow() async {
        // Given - Setup mock data
        let customFood = CustomFood(
            name: "My Custom Chicken",
            caloriesPerServing: 150,
            proteinPerServing: 30,
            carbohydratesPerServing: 0,
            fatPerServing: 3,
            servingSize: 100,
            servingUnit: "g"
        )
        repository.mockCustomFoods = [customFood]
        
        let apiResult = FoodSearchResult(
            id: "api-chicken",
            name: "API Chicken Breast",
            brand: "Fresh Market",
            calories: 165,
            protein: 31,
            carbohydrates: 0,
            fat: 3.6,
            servingSize: 100,
            servingUnit: "g",
            imageUrl: nil,
            source: .openFoodFacts
        )
        networkManager.mockSearchResults = [apiResult]
        
        // When - Perform search
        await searchViewModel.search(query: "chicken")
        
        // Then - Verify results
        XCTAssertFalse(searchViewModel.isSearching)
        XCTAssertEqual(searchViewModel.searchResults.count, 2)
        
        // Verify local results come first
        let localResult = searchViewModel.searchResults[0]
        XCTAssertEqual(localResult.source, .custom)
        XCTAssertEqual(localResult.name, "My Custom Chicken")
        
        let networkResult = searchViewModel.searchResults[1]
        XCTAssertEqual(networkResult.source, .openFoodFacts)
        XCTAssertEqual(networkResult.name, "API Chicken Breast")
    }
    
    func testSearchWithNetworkFailureShowsLocalResults() async {
        // Given - Setup local data and network failure
        let customFood = CustomFood(
            name: "Local Chicken",
            caloriesPerServing: 150,
            proteinPerServing: 30,
            carbohydratesPerServing: 0,
            fatPerServing: 3,
            servingSize: 100,
            servingUnit: "g"
        )
        repository.mockCustomFoods = [customFood]
        networkManager.shouldThrowError = true
        networkManager.errorToThrow = FoodNetworkError.noInternetConnection
        
        // When - Perform search
        await searchViewModel.search(query: "chicken")
        
        // Then - Should show local results only
        XCTAssertFalse(searchViewModel.isSearching)
        XCTAssertEqual(searchViewModel.searchResults.count, 1)
        XCTAssertEqual(searchViewModel.searchResults[0].source, .custom)
        XCTAssertEqual(searchViewModel.searchResults[0].name, "Local Chicken")
    }
    
    func testBarcodeSearchFlow() async {
        // Given - Setup barcode result
        let barcodeResult = FoodSearchResult(
            id: "barcode-123",
            name: "Scanned Product",
            brand: "Test Brand",
            calories: 200,
            protein: 15,
            carbohydrates: 25,
            fat: 8,
            servingSize: 100,
            servingUnit: "g",
            imageUrl: nil,
            source: .openFoodFacts
        )
        networkManager.mockBarcodeResult = barcodeResult
        
        // When - Search by barcode
        await searchViewModel.searchByBarcode("1234567890")
        
        // Then - Verify barcode result
        XCTAssertFalse(searchViewModel.isLoadingBarcode)
        XCTAssertNotNil(searchViewModel.barcodeResult)
        XCTAssertTrue(searchViewModel.showBarcodeResult)
        XCTAssertEqual(searchViewModel.barcodeResult?.name, "Scanned Product")
    }
    
    func testCreateCustomFoodFlow() async {
        // Given - New custom food
        let newFood = CustomFood(
            name: "My Recipe",
            caloriesPerServing: 300,
            proteinPerServing: 20,
            carbohydratesPerServing: 30,
            fatPerServing: 10,
            servingSize: 1,
            servingUnit: "serving"
        )
        
        // When - Create custom food
        let success = await searchViewModel.createCustomFood(newFood)
        
        // Then - Verify creation
        XCTAssertTrue(success)
        XCTAssertEqual(repository.mockCustomFoods.count, 1)
        XCTAssertEqual(repository.mockCustomFoods[0].name, "My Recipe")
        
        // When - Search for the new food
        await searchViewModel.search(query: "recipe")
        
        // Then - Should find the custom food
        XCTAssertEqual(searchViewModel.searchResults.count, 1)
        XCTAssertEqual(searchViewModel.searchResults[0].source, .custom)
        XCTAssertEqual(searchViewModel.searchResults[0].name, "My Recipe")
    }
    
    func testSearchResultCaching() async {
        // Given - API result
        let apiResult = FoodSearchResult(
            id: "cached-item",
            name: "Cached Food",
            brand: nil,
            calories: 100,
            protein: 10,
            carbohydrates: 5,
            fat: 2,
            servingSize: 100,
            servingUnit: "g",
            imageUrl: nil,
            source: .openFoodFacts
        )
        networkManager.mockSearchResults = [apiResult]
        
        // When - First search
        await searchViewModel.search(query: "cached")
        let firstCallCount = networkManager.searchCallCount
        
        // When - Second search with same query
        await searchViewModel.search(query: "cached")
        let secondCallCount = networkManager.searchCallCount
        
        // Then - Network should only be called once
        XCTAssertEqual(firstCallCount, 1)
        XCTAssertEqual(secondCallCount, 1) // Should not increase due to caching
        XCTAssertEqual(searchViewModel.searchResults.count, 1)
        XCTAssertEqual(searchViewModel.searchResults[0].name, "Cached Food")
    }
    
    func testFoodLogCreationFromSearchResult() {
        // Given - Search result
        let searchResult = FoodSearchResult(
            id: "test-food",
            name: "Test Food",
            brand: "Test Brand",
            calories: 200,
            protein: 20,
            carbohydrates: 15,
            fat: 8,
            servingSize: 100,
            servingUnit: "g",
            imageUrl: nil,
            source: .openFoodFacts
        )
        
        // When - Create food log with custom serving
        let foodLog = searchResult.createFoodLog(
            mealType: .lunch,
            servingMultiplier: 1.5
        )
        
        // Then - Verify food log properties
        XCTAssertEqual(foodLog.name, "Test Food")
        XCTAssertEqual(foodLog.mealType, .lunch)
        XCTAssertEqual(foodLog.calories, 300, accuracy: 0.1) // 200 * 1.5
        XCTAssertEqual(foodLog.protein, 30, accuracy: 0.1) // 20 * 1.5
        XCTAssertEqual(foodLog.carbohydrates, 22.5, accuracy: 0.1) // 15 * 1.5
        XCTAssertEqual(foodLog.fat, 12, accuracy: 0.1) // 8 * 1.5
        XCTAssertEqual(foodLog.servingSize, 150, accuracy: 0.1) // 100 * 1.5
        XCTAssertEqual(foodLog.servingUnit, "g")
    }
    
    func testErrorHandling() async {
        // Given - Repository error
        repository.shouldThrowError = true
        repository.errorToThrow = FuelLogError.persistenceError(NSError(domain: "test", code: 1))
        
        // When - Try to create custom food
        let customFood = CustomFood(
            name: "Error Food",
            caloriesPerServing: 100,
            proteinPerServing: 10,
            carbohydratesPerServing: 5,
            fatPerServing: 2,
            servingSize: 1,
            servingUnit: "serving"
        )
        let success = await searchViewModel.createCustomFood(customFood)
        
        // Then - Should handle error gracefully
        XCTAssertFalse(success)
        XCTAssertNotNil(searchViewModel.errorMessage)
        XCTAssertTrue(searchViewModel.showErrorAlert)
    }
}

// MARK: - Mock Network Manager for Integration Tests

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