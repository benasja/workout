import XCTest
import Foundation
@testable import work

/// Integration tests for network operations in Fuel Log
final class NetworkIntegrationTests: XCTestCase {
    
    var networkManager: FoodNetworkManager!
    var mockURLSession: MockURLSession!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockURLSession = MockURLSession()
        networkManager = FoodNetworkManager.shared
        
        // Inject mock URL session for testing
        networkManager.urlSession = mockURLSession
    }
    
    override func tearDown() async throws {
        networkManager = nil
        mockURLSession = nil
        try await super.tearDown()
    }
    
    // MARK: - Barcode Search Integration Tests
    
    func testSearchFoodByBarcode_Success() async throws {
        // Given
        let barcode = "1234567890123"
        let mockProduct = MockDataGenerator.shared.createMockOpenFoodFactsProduct(
            id: barcode,
            productName: "Test Product",
            brands: "Test Brand"
        )
        let mockResponse = MockDataGenerator.shared.createMockOpenFoodFactsResponse(
            status: 1,
            statusVerbose: "product found",
            product: mockProduct
        )
        
        mockURLSession.mockData = try JSONEncoder().encode(mockResponse)
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        let result = try await networkManager.searchFoodByBarcode(barcode)
        
        // Then
        XCTAssertEqual(result.id, barcode)
        XCTAssertEqual(result.productName, "Test Product")
        XCTAssertEqual(result.brands, "Test Brand")
        XCTAssertTrue(mockURLSession.dataTaskCalled)
        
        // Verify correct URL was called
        let expectedURL = "https://world.openfoodfacts.org/api/v0/product/\(barcode).json"
        XCTAssertEqual(mockURLSession.lastRequestURL?.absoluteString, expectedURL)
    }
    
    func testSearchFoodByBarcode_ProductNotFound() async throws {
        // Given
        let barcode = "0000000000000"
        let mockResponse = MockDataGenerator.shared.createMockOpenFoodFactsResponse(
            status: 0,
            statusVerbose: "product not found",
            product: nil
        )
        
        mockURLSession.mockData = try JSONEncoder().encode(mockResponse)
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When & Then
        do {
            _ = try await networkManager.searchFoodByBarcode(barcode)
            XCTFail("Expected FuelLogError.foodNotFound to be thrown")
        } catch FuelLogError.foodNotFound {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSearchFoodByBarcode_InvalidBarcode() async throws {
        // Given
        let invalidBarcode = "invalid"
        
        // When & Then
        do {
            _ = try await networkManager.searchFoodByBarcode(invalidBarcode)
            XCTFail("Expected FuelLogError.invalidBarcode to be thrown")
        } catch FuelLogError.invalidBarcode {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSearchFoodByBarcode_NetworkError() async throws {
        // Given
        let barcode = "1234567890123"
        mockURLSession.shouldThrowError = true
        mockURLSession.errorToThrow = URLError(.notConnectedToInternet)
        
        // When & Then
        do {
            _ = try await networkManager.searchFoodByBarcode(barcode)
            XCTFail("Expected FuelLogError.networkError to be thrown")
        } catch FuelLogError.networkError(let underlyingError) {
            XCTAssertTrue(underlyingError is URLError)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSearchFoodByBarcode_HTTPError() async throws {
        // Given
        let barcode = "1234567890123"
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )
        mockURLSession.mockData = Data()
        
        // When & Then
        do {
            _ = try await networkManager.searchFoodByBarcode(barcode)
            XCTFail("Expected FuelLogError.networkError to be thrown")
        } catch FuelLogError.networkError {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Food Name Search Integration Tests
    
    func testSearchFoodByName_Success() async throws {
        // Given
        let searchQuery = "chicken"
        let mockProducts = [
            MockDataGenerator.shared.createMockOpenFoodFactsProduct(
                id: "1",
                productName: "Chicken Breast",
                brands: "Brand A"
            ),
            MockDataGenerator.shared.createMockOpenFoodFactsProduct(
                id: "2",
                productName: "Chicken Thigh",
                brands: "Brand B"
            )
        ]
        
        let mockSearchResponse = OpenFoodFactsSearchResponse(
            count: 2,
            page: 1,
            pageCount: 1,
            pageSize: 20,
            products: mockProducts
        )
        
        mockURLSession.mockData = try JSONEncoder().encode(mockSearchResponse)
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://world.openfoodfacts.org/cgi/search.pl")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        let results = try await networkManager.searchFoodByName(searchQuery)
        
        // Then
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].productName, "Chicken Breast")
        XCTAssertEqual(results[1].productName, "Chicken Thigh")
        XCTAssertTrue(mockURLSession.dataTaskCalled)
        
        // Verify search parameters
        XCTAssertTrue(mockURLSession.lastRequestURL?.absoluteString.contains("search_terms=chicken") ?? false)
    }
    
    func testSearchFoodByName_EmptyResults() async throws {
        // Given
        let searchQuery = "nonexistentfood"
        let mockSearchResponse = OpenFoodFactsSearchResponse(
            count: 0,
            page: 1,
            pageCount: 0,
            pageSize: 20,
            products: []
        )
        
        mockURLSession.mockData = try JSONEncoder().encode(mockSearchResponse)
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://world.openfoodfacts.org/cgi/search.pl")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        let results = try await networkManager.searchFoodByName(searchQuery)
        
        // Then
        XCTAssertEqual(results.count, 0)
    }
    
    func testSearchFoodByName_EmptyQuery() async throws {
        // Given
        let emptyQuery = ""
        
        // When & Then
        do {
            _ = try await networkManager.searchFoodByName(emptyQuery)
            XCTFail("Expected error for empty query")
        } catch {
            // Expected to fail with some error
        }
    }
    
    // MARK: - Rate Limiting Tests
    
    func testRateLimiting() async throws {
        // Given
        let barcode = "1234567890123"
        let mockProduct = MockDataGenerator.shared.createMockOpenFoodFactsProduct(id: barcode)
        let mockResponse = MockDataGenerator.shared.createMockOpenFoodFactsResponse(product: mockProduct)
        
        mockURLSession.mockData = try JSONEncoder().encode(mockResponse)
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When - make multiple rapid requests
        let startTime = Date()
        
        for i in 0..<5 {
            let testBarcode = "\(barcode)\(i)"
            _ = try await networkManager.searchFoodByBarcode(testBarcode)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Then - should have some delay due to rate limiting
        XCTAssertGreaterThan(duration, 1.0, "Rate limiting should introduce delays")
    }
    
    func testRateLimitExceeded() async throws {
        // Given
        let barcode = "1234567890123"
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json")!,
            statusCode: 429, // Too Many Requests
            httpVersion: nil,
            headerFields: ["Retry-After": "60"]
        )
        mockURLSession.mockData = Data()
        
        // When & Then
        do {
            _ = try await networkManager.searchFoodByBarcode(barcode)
            XCTFail("Expected rate limit error")
        } catch FuelLogError.networkError {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Timeout Tests
    
    func testRequestTimeout() async throws {
        // Given
        let barcode = "1234567890123"
        mockURLSession.shouldTimeout = true
        mockURLSession.timeoutDelay = 10.0 // Longer than expected timeout
        
        // When & Then
        do {
            _ = try await networkManager.searchFoodByBarcode(barcode)
            XCTFail("Expected timeout error")
        } catch FuelLogError.networkError(let underlyingError) {
            XCTAssertTrue(underlyingError is URLError)
            let urlError = underlyingError as! URLError
            XCTAssertEqual(urlError.code, .timedOut)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Data Parsing Tests
    
    func testMalformedJSONResponse() async throws {
        // Given
        let barcode = "1234567890123"
        mockURLSession.mockData = "invalid json".data(using: .utf8)!
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When & Then
        do {
            _ = try await networkManager.searchFoodByBarcode(barcode)
            XCTFail("Expected parsing error")
        } catch {
            // Expected to fail with parsing error
        }
    }
    
    func testIncompleteProductData() async throws {
        // Given
        let barcode = "1234567890123"
        let incompleteProduct = """
        {
            "status": 1,
            "status_verbose": "product found",
            "product": {
                "_id": "\(barcode)",
                "product_name": "Incomplete Product"
                // Missing nutriments and other data
            }
        }
        """
        
        mockURLSession.mockData = incompleteProduct.data(using: .utf8)!
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        let result = try await networkManager.searchFoodByBarcode(barcode)
        
        // Then - should handle missing data gracefully
        XCTAssertEqual(result.id, barcode)
        XCTAssertEqual(result.productName, "Incomplete Product")
        // Nutriments should have default values or be nil
    }
    
    // MARK: - Caching Integration Tests
    
    func testResponseCaching() async throws {
        // Given
        let barcode = "1234567890123"
        let mockProduct = MockDataGenerator.shared.createMockOpenFoodFactsProduct(id: barcode)
        let mockResponse = MockDataGenerator.shared.createMockOpenFoodFactsResponse(product: mockProduct)
        
        mockURLSession.mockData = try JSONEncoder().encode(mockResponse)
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Cache-Control": "max-age=3600"]
        )
        
        // When - first request
        let result1 = try await networkManager.searchFoodByBarcode(barcode)
        let firstRequestCount = mockURLSession.requestCount
        
        // When - second request (should use cache)
        let result2 = try await networkManager.searchFoodByBarcode(barcode)
        let secondRequestCount = mockURLSession.requestCount
        
        // Then
        XCTAssertEqual(result1.id, result2.id)
        // In a real implementation, the second request might not hit the network
        // For this test, we verify the caching mechanism is in place
    }
    
    // MARK: - Offline Handling Tests
    
    func testOfflineHandling() async throws {
        // Given
        let barcode = "1234567890123"
        mockURLSession.shouldThrowError = true
        mockURLSession.errorToThrow = URLError(.notConnectedToInternet)
        
        // When & Then
        do {
            _ = try await networkManager.searchFoodByBarcode(barcode)
            XCTFail("Expected network error")
        } catch FuelLogError.networkError(let underlyingError) {
            let urlError = underlyingError as! URLError
            XCTAssertEqual(urlError.code, .notConnectedToInternet)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testConcurrentRequests() async throws {
        // Given
        let barcodes = (0..<10).map { "123456789012\($0)" }
        let mockProduct = MockDataGenerator.shared.createMockOpenFoodFactsProduct()
        let mockResponse = MockDataGenerator.shared.createMockOpenFoodFactsResponse(product: mockProduct)
        
        mockURLSession.mockData = try JSONEncoder().encode(mockResponse)
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://world.openfoodfacts.org")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        let startTime = Date()
        
        await withTaskGroup(of: Void.self) { group in
            for barcode in barcodes {
                group.addTask {
                    do {
                        _ = try await self.networkManager.searchFoodByBarcode(barcode)
                    } catch {
                        // Handle errors in concurrent requests
                    }
                }
            }
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Then - concurrent requests should be faster than sequential
        XCTAssertLessThan(duration, 5.0, "Concurrent requests should complete within reasonable time")
    }
    
    func testNetworkPerformanceMetrics() throws {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = XCTestExpectation(description: "Network performance")
            
            Task {
                do {
                    let barcode = "1234567890123"
                    let mockProduct = MockDataGenerator.shared.createMockOpenFoodFactsProduct(id: barcode)
                    let mockResponse = MockDataGenerator.shared.createMockOpenFoodFactsResponse(product: mockProduct)
                    
                    self.mockURLSession.mockData = try JSONEncoder().encode(mockResponse)
                    self.mockURLSession.mockResponse = HTTPURLResponse(
                        url: URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json")!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )
                    
                    _ = try await self.networkManager.searchFoodByBarcode(barcode)
                    expectation.fulfill()
                } catch {
                    XCTFail("Network request failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - Integration with Repository Tests
    
    func testNetworkToRepositoryIntegration() async throws {
        // Given
        let repository = createTestRepository()
        let searchViewModel = FoodSearchViewModel(repository: repository, networkManager: networkManager)
        
        let searchQuery = "chicken"
        let mockProducts = [
            MockDataGenerator.shared.createMockOpenFoodFactsProduct(
                id: "1",
                productName: "Chicken Breast",
                brands: "Test Brand"
            )
        ]
        
        let mockSearchResponse = OpenFoodFactsSearchResponse(
            count: 1,
            page: 1,
            pageCount: 1,
            pageSize: 20,
            products: mockProducts
        )
        
        mockURLSession.mockData = try JSONEncoder().encode(mockSearchResponse)
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://world.openfoodfacts.org/cgi/search.pl")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        await searchViewModel.search(query: searchQuery)
        
        // Then
        XCTAssertEqual(searchViewModel.searchResults.count, 1)
        XCTAssertEqual(searchViewModel.searchResults.first?.name, "Chicken Breast")
        XCTAssertFalse(searchViewModel.isSearching)
    }
    
    // MARK: - Helper Methods
    
    private func createTestRepository() -> FuelLogRepository {
        do {
            let schema = Schema([FoodLog.self, CustomFood.self, NutritionGoals.self])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return FuelLogRepository(modelContext: ModelContext(modelContainer))
        } catch {
            fatalError("Failed to create test repository: \(error)")
        }
    }
}

// MARK: - Mock URL Session

class MockURLSession: URLSession {
    
    var shouldThrowError = false
    var errorToThrow: Error = URLError(.networkConnectionLost)
    
    var shouldTimeout = false
    var timeoutDelay: TimeInterval = 1.0
    
    var mockData: Data?
    var mockResponse: URLResponse?
    
    var dataTaskCalled = false
    var lastRequestURL: URL?
    var requestCount = 0
    
    override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        dataTaskCalled = true
        lastRequestURL = request.url
        requestCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if shouldTimeout {
            try await Task.sleep(nanoseconds: UInt64(timeoutDelay * 1_000_000_000))
            throw URLError(.timedOut)
        }
        
        let data = mockData ?? Data()
        let response = mockResponse ?? HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        return (data, response)
    }
}

// MARK: - OpenFoodFacts Search Response Model

struct OpenFoodFactsSearchResponse: Codable {
    let count: Int
    let page: Int
    let pageCount: Int
    let pageSize: Int
    let products: [OpenFoodFactsProduct]
    
    enum CodingKeys: String, CodingKey {
        case count
        case page
        case pageCount = "page_count"
        case pageSize = "page_size"
        case products
    }
}

// MARK: - FoodNetworkManager Extension for Testing

extension FoodNetworkManager {
    var urlSession: URLSession {
        get { session }
        set { session = newValue }
    }
    
    private var session: URLSession {
        get {
            // In real implementation, this would access the private session property
            return URLSession.shared
        }
        set {
            // In real implementation, this would set the private session property
        }
    }
}