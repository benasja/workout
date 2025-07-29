import Foundation
import Network

// MARK: - Food Network Manager

@MainActor
final class FoodNetworkManager: ObservableObject, FoodNetworkManagerProtocol {
    static let shared = FoodNetworkManager()
    
    private let session: URLSession
    private let baseURL = "https://world.openfoodfacts.org/api/v0"
    private let cacheManager = FuelLogCacheManager.shared
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = true
    
    // Rate limiting and request debouncing
    private var lastRequestTime: Date = Date.distantPast
    private let minimumRequestInterval: TimeInterval = 0.3 // 300ms between requests
    private var pendingRequests: [String: Any] = [:]
    private let requestQueue = DispatchQueue(label: "com.fuellog.network.requests", qos: .userInitiated)
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 30.0
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.session = URLSession(configuration: config)
        
        // Start network monitoring
        startNetworkMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Public API Methods
    
    func searchFoodByBarcode(_ barcode: String) async throws -> FoodSearchResult {
        guard !barcode.isEmpty else {
            throw FoodNetworkError.invalidBarcode
        }
        
        // Check cache first
        if let cachedResult = cacheManager.getCachedBarcodeResult(for: barcode) {
            return cachedResult
        }
        
        // If offline, throw appropriate error
        guard isConnected else {
            throw FoodNetworkError.noInternetConnection
        }
        
        // Check for pending request
        let requestKey = "barcode_\(barcode)"
        if let pendingTask = pendingRequests[requestKey] as? Task<FoodSearchResult, Error> {
            return try await pendingTask.value
        }
        
        // Create new request task
        let requestTask = Task<FoodSearchResult, Error> {
            defer {
                pendingRequests.removeValue(forKey: requestKey)
            }
            
            // Rate limiting
            try await enforceRateLimit()
            
            guard let url = buildBarcodeURL(barcode: barcode) else {
                throw FoodNetworkError.invalidURL
            }
            
            do {
                let response = try await performRequest(url) as OpenFoodFactsResponse
                
                guard response.status == 1, let product = response.product else {
                    throw FoodNetworkError.productNotFound
                }
                
                let result = FoodSearchResult(fromOpenFoodFacts: product)
                
                // Cache the result
                cacheManager.cacheBarcodeResult(result, for: barcode)
                
                return result
            } catch {
                if error is FoodNetworkError {
                    throw error
                } else {
                    throw FoodNetworkError.networkError(error)
                }
            }
        }
        
        pendingRequests[requestKey] = requestTask
        return try await requestTask.value
    }
    
    func searchFoodByName(_ query: String, page: Int = 1) async throws -> [FoodSearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FoodNetworkError.invalidQuery
        }
        
        // Check cache first
        if let cachedResults = cacheManager.getCachedSearchResults(for: query, page: page) {
            return cachedResults
        }
        
        // If offline, return empty results (local search should be handled elsewhere)
        guard isConnected else {
            throw FoodNetworkError.noInternetConnection
        }
        
        // Check for pending request
        let requestKey = "search_\(query)_\(page)"
        if let pendingTask = pendingRequests[requestKey] as? Task<[FoodSearchResult], Error> {
            return try await pendingTask.value
        }
        
        // Create new request task
        let requestTask = Task<[FoodSearchResult], Error> {
            defer {
                pendingRequests.removeValue(forKey: requestKey)
            }
            
            // Rate limiting
            try await enforceRateLimit()
            
            guard let url = buildSearchURL(query: query, page: page) else {
                throw FoodNetworkError.invalidURL
            }
            
            do {
                let response = try await performRequest(url) as OpenFoodFactsSearchResponse
                
                let results: [FoodSearchResult] = response.products.compactMap { product in
                    // Filter out products with insufficient nutrition data
                    guard product.nutriments.energyKcal100g != nil else { return nil }
                    return FoodSearchResult(fromOpenFoodFacts: product)
                }
                
                // Cache the results
                cacheManager.cacheSearchResults(results, for: query, page: page)
                
                return results
            } catch {
                if error is FoodNetworkError {
                    throw error
                } else {
                    throw FoodNetworkError.networkError(error)
                }
            }
        }
        
        pendingRequests[requestKey] = requestTask
        return try await requestTask.value
    }
    
    // MARK: - Private Helper Methods
    
    private func buildBarcodeURL(barcode: String) -> URL? {
        return URL(string: "\(baseURL)/product/\(barcode).json")
    }
    
    private func buildSearchURL(query: String, page: Int) -> URL? {
        guard var components = URLComponents(string: "\(baseURL)/search") else {
            return nil
        }
        
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: "20"),
            URLQueryItem(name: "json", value: "true"),
            URLQueryItem(name: "fields", value: "product_name,brands,nutriments,serving_size,serving_quantity,image_url,categories,_id")
        ]
        
        return components.url
    }
    
    private func performRequest<T: Codable>(_ url: URL) async throws -> T {
        guard isConnected else {
            throw FoodNetworkError.noInternetConnection
        }
        
        var request = URLRequest(url: url)
        request.setValue("FuelLog-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodNetworkError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            break
        case 404:
            throw FoodNetworkError.productNotFound
        case 429:
            throw FoodNetworkError.rateLimitExceeded
        case 500...599:
            throw FoodNetworkError.serverError
        default:
            throw FoodNetworkError.httpError(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw FoodNetworkError.decodingError(error)
        }
    }
    
    private func enforceRateLimit() async throws {
        let timeSinceLastRequest = Date().timeIntervalSince(lastRequestTime)
        if timeSinceLastRequest < minimumRequestInterval {
            let delay = minimumRequestInterval - timeSinceLastRequest
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        lastRequestTime = Date()
    }
    
    // MARK: - Offline Support Methods
    
    /// Returns whether the network manager can perform online operations
    var canPerformOnlineOperations: Bool {
        return isConnected
    }
    
    /// Clears all cached network data
    func clearNetworkCache() async {
        await cacheManager.clearAllCache()
    }
    
    /// Cancels all pending requests
    func cancelPendingRequests() {
        for (_, task) in pendingRequests {
            if let task = task as? Task<Any, Error> {
                task.cancel()
            }
        }
        pendingRequests.removeAll()
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: monitorQueue)
    }
}



// MARK: - Food Network Errors

enum FoodNetworkError: LocalizedError {
    case invalidBarcode
    case invalidQuery
    case invalidURL
    case invalidResponse
    case productNotFound
    case networkError(Error)
    case decodingError(Error)
    case noInternetConnection
    case rateLimitExceeded
    case serverError
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidBarcode:
            return "Invalid barcode format"
        case .invalidQuery:
            return "Search query cannot be empty"
        case .invalidURL:
            return "Invalid request URL"
        case .invalidResponse:
            return "Invalid server response"
        case .productNotFound:
            return "Product not found in database"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        case .noInternetConnection:
            return "No internet connection available"
        case .rateLimitExceeded:
            return "Too many requests. Please try again later"
        case .serverError:
            return "Server error. Please try again later"
        case .httpError(let code):
            return "HTTP error: \(code)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidBarcode:
            return "Please scan a valid product barcode"
        case .invalidQuery:
            return "Please enter a search term"
        case .productNotFound:
            return "Try searching by product name or create a custom food item"
        case .noInternetConnection:
            return "Check your internet connection and try again"
        case .rateLimitExceeded:
            return "Wait a moment before making another request"
        case .serverError:
            return "The service is temporarily unavailable"
        default:
            return "Please try again"
        }
    }
}