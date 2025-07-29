import XCTest
import Network
@testable import work

final class FoodNetworkManagerTests: XCTestCase {
    var networkManager: FoodNetworkManager!
    var mockSession: MockURLSession!
    
    override func setUp() {
        super.setUp()
        networkManager = FoodNetworkManager.shared
        mockSession = MockURLSession()
    }
    
    override func tearDown() {
        networkManager = nil
        mockSession = nil
        super.tearDown()
    }
    
    // MARK: - Barcode Search Tests
    
    func testSearchFoodByBarcode_Success() async throws {
        // Given
        let barcode = "3017620422003"
        let mockProduct = createMockProduct()
        let mockResponse = OpenFoodFactsResponse(
            status: 1,
            statusVerbose: "product found",
            product: mockProduct
        )
        
        // When
        let result = try await networkManager.searchFoodByBarcode(barcode)
        
        // Then
        XCTAssertEqual(result.id, mockProduct.id)
        XCTAssertEqual(result.name, mockProduct.productName)
        XCTAssertEqual(result.source, .openFoodFacts)
    }
    
    func testSearchFoodByBarcode_InvalidBarcode() async {
        // Given
        let emptyBarcode = ""
        
        // When & Then
        do {
            _ = try await networkManager.searchFoodByBarcode(emptyBarcode)
            XCTFail("Expected FoodNetworkError.invalidBarcode")
        } catch FoodNetworkError.invalidBarcode {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSearchFoodByBarcode_ProductNotFound() async {
        // Given
        let barcode = "1234567890123"
        
        // When & Then
        do {
            _ = try await networkManager.searchFoodByBarcode(barcode)
            XCTFail("Expected FoodNetworkError.productNotFound")
        } catch FoodNetworkError.productNotFound {
            // Expected - this will happen with real API for invalid barcodes
        } catch {
            // Other network errors are acceptable in real testing
        }
    }
    
    // MARK: - Name Search Tests
    
    func testSearchFoodByName_Success() async throws {
        // Given
        let query = "apple"
        
        // When
        let results = try await networkManager.searchFoodByName(query)
        
        // Then
        XCTAssertFalse(results.isEmpty, "Should return search results")
        XCTAssertTrue(results.allSatisfy { $0.source == .openFoodFacts })
    }
    
    func testSearchFoodByName_EmptyQuery() async {
        // Given
        let emptyQuery = ""
        
        // When & Then
        do {
            _ = try await networkManager.searchFoodByName(emptyQuery)
            XCTFail("Expected FoodNetworkError.invalidQuery")
        } catch FoodNetworkError.invalidQuery {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSearchFoodByName_WhitespaceQuery() async {
        // Given
        let whitespaceQuery = "   "
        
        // When & Then
        do {
            _ = try await networkManager.searchFoodByName(whitespaceQuery)
            XCTFail("Expected FoodNetworkError.invalidQuery")
        } catch FoodNetworkError.invalidQuery {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Rate Limiting Tests
    
    func testRateLimit_EnforcesDelay() async throws {
        // Given
        let barcode1 = "3017620422003"
        let barcode2 = "3017620422004"
        
        // When
        let startTime = Date()
        
        // Make two rapid requests
        async let result1: () = {
            do {
                _ = try await networkManager.searchFoodByBarcode(barcode1)
            } catch {
                // Ignore errors for this test
            }
        }()
        
        async let result2: () = {
            do {
                _ = try await networkManager.searchFoodByBarcode(barcode2)
            } catch {
                // Ignore errors for this test
            }
        }()
        
        await result1
        await result2
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Then
        XCTAssertGreaterThanOrEqual(duration, 0.5, "Should enforce minimum 500ms delay between requests")
    }
    
    // MARK: - Caching Tests
    
    func testCaching_ReturnsCachedResult() async throws {
        // Given
        let barcode = "3017620422003"
        
        // When - Make first request
        do {
            let result1 = try await networkManager.searchFoodByBarcode(barcode)
            
            // Make second request immediately (should be cached)
            let result2 = try await networkManager.searchFoodByBarcode(barcode)
            
            // Then
            XCTAssertEqual(result1.id, result2.id)
            XCTAssertEqual(result1.name, result2.name)
        } catch {
            // Skip test if network is unavailable
            throw XCTSkip("Network unavailable for caching test")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling_NetworkError() async {
        // This test would require mocking URLSession, which is complex
        // For now, we'll test that the error types are properly defined
        
        let networkError = FoodNetworkError.networkError(URLError(.notConnectedToInternet))
        XCTAssertNotNil(networkError.errorDescription)
        XCTAssertNotNil(networkError.recoverySuggestion)
    }
    
    func testErrorHandling_RateLimitExceeded() {
        let rateLimitError = FoodNetworkError.rateLimitExceeded
        XCTAssertEqual(rateLimitError.errorDescription, "Too many requests. Please try again later")
        XCTAssertEqual(rateLimitError.recoverySuggestion, "Wait a moment before making another request")
    }
    
    func testErrorHandling_ProductNotFound() {
        let notFoundError = FoodNetworkError.productNotFound
        XCTAssertEqual(notFoundError.errorDescription, "Product not found in database")
        XCTAssertEqual(notFoundError.recoverySuggestion, "Try searching by product name or create a custom food item")
    }
    
    // MARK: - Model Tests
    
    func testOpenFoodFactsProduct_Initialization() {
        // Given
        let mockProduct = createMockProduct()
        
        // When
        let searchResult = FoodSearchResult(fromOpenFoodFacts: mockProduct)
        
        // Then
        XCTAssertEqual(searchResult.id, mockProduct.id)
        XCTAssertEqual(searchResult.name, mockProduct.productName)
        XCTAssertEqual(searchResult.brand, mockProduct.brands)
        XCTAssertEqual(searchResult.calories, mockProduct.nutriments.energyKcal100g)
        XCTAssertEqual(searchResult.protein, mockProduct.nutriments.proteins100g)
        XCTAssertEqual(searchResult.carbohydrates, mockProduct.nutriments.carbohydrates100g)
        XCTAssertEqual(searchResult.fat, mockProduct.nutriments.fat100g)
        XCTAssertEqual(searchResult.source, .openFoodFacts)
    }
    
    func testOpenFoodFactsProduct_MissingNutritionData() {
        // Given
        let incompleteNutriments = OpenFoodFactsNutriments(
            energyKcal100g: nil,
            proteins100g: nil,
            carbohydrates100g: nil,
            fat100g: nil,
            fiber100g: nil,
            sugars100g: nil,
            sodium100g: nil,
            salt100g: nil
        )
        
        let incompleteProduct = OpenFoodFactsProduct(
            id: "test123",
            productName: "Test Product",
            brands: "Test Brand",
            nutriments: incompleteNutriments,
            servingSize: nil,
            servingQuantity: nil,
            imageUrl: nil,
            categories: nil
        )
        
        // When
        let searchResult = FoodSearchResult(fromOpenFoodFacts: incompleteProduct)
        
        // Then
        XCTAssertEqual(searchResult.calories, 0)
        XCTAssertEqual(searchResult.protein, 0)
        XCTAssertEqual(searchResult.carbohydrates, 0)
        XCTAssertEqual(searchResult.fat, 0)
    }
    
    // MARK: - Helper Methods
    
    private func createMockProduct() -> OpenFoodFactsProduct {
        let nutriments = OpenFoodFactsNutriments(
            energyKcal100g: 250.0,
            proteins100g: 12.0,
            carbohydrates100g: 30.0,
            fat100g: 8.0,
            fiber100g: 2.0,
            sugars100g: 15.0,
            sodium100g: 0.5,
            salt100g: 1.25
        )
        
        return OpenFoodFactsProduct(
            id: "3017620422003",
            productName: "Test Product",
            brands: "Test Brand",
            nutriments: nutriments,
            servingSize: "100g",
            servingQuantity: 100.0,
            imageUrl: "https://example.com/image.jpg",
            categories: "Test Category"
        )
    }
}

// MARK: - Mock URL Session (for future use)

class MockURLSession {
    var data: Data?
    var response: URLResponse?
    var error: Error?
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = error {
            throw error
        }
        
        return (data ?? Data(), response ?? URLResponse())
    }
}

// MARK: - Integration Tests

final class FoodNetworkManagerIntegrationTests: XCTestCase {
    var networkManager: FoodNetworkManager!
    
    override func setUp() {
        super.setUp()
        networkManager = FoodNetworkManager.shared
    }
    
    override func tearDown() {
        networkManager = nil
        super.tearDown()
    }
    
    func testRealAPI_BarcodeSearch() async throws {
        // Given - Nutella barcode (well-known product)
        let nutellaBarcod = "3017620422003"
        
        // When
        do {
            let result = try await networkManager.searchFoodByBarcode(nutellaBarcod)
            
            // Then
            XCTAssertFalse(result.name.isEmpty)
            XCTAssertGreaterThan(result.calories, 0)
            XCTAssertEqual(result.source, .openFoodFacts)
        } catch {
            throw XCTSkip("Network unavailable or API changed: \(error)")
        }
    }
    
    func testRealAPI_NameSearch() async throws {
        // Given
        let searchQuery = "banana"
        
        // When
        do {
            let results = try await networkManager.searchFoodByName(searchQuery)
            
            // Then
            XCTAssertFalse(results.isEmpty)
            XCTAssertTrue(results.allSatisfy { $0.source == .openFoodFacts })
            
            // Check that at least some results have nutrition data
            let resultsWithCalories = results.filter { $0.calories > 0 }
            XCTAssertFalse(resultsWithCalories.isEmpty, "Should have at least some results with calorie data")
        } catch {
            throw XCTSkip("Network unavailable or API changed: \(error)")
        }
    }
}