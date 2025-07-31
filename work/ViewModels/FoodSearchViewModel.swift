import Foundation
import SwiftUI

// MARK: - Food Search ViewModel

@MainActor
final class FoodSearchViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current search results from API and local database
    @Published var searchResults: [FoodSearchResult] = []
    
    /// Local custom foods for search
    @Published var customFoods: [CustomFood] = []
    
    /// Current search text
    @Published var searchText: String = "" {
        didSet {
            if searchText != oldValue {
                searchTask?.cancel()
                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Use performance optimizer for debouncing
                    PerformanceOptimizer.shared.debounceSearch(delay: searchDebounceDelay) {
                        await self.performSearch()
                    }
                } else {
                    // Show all available foods when search is empty
                    Task {
                        await loadAllAvailableFoods()
                    }
                }
            }
        }
    }
    
    /// Loading state for search operations
    @Published var isSearching: Bool = false
    
    /// Loading state for barcode lookup
    @Published var isLoadingBarcode: Bool = false
    
    /// Error message for user feedback
    @Published var errorMessage: String?
    
    /// Show error alert
    @Published var showErrorAlert: Bool = false
    
    /// Enhanced error handling
    @Published var errorHandler = ErrorHandler()
    @Published var loadingManager = LoadingStateManager()
    @Published var networkStatusManager = NetworkStatusManager()
    
    /// Barcode search result
    @Published var barcodeResult: FoodSearchResult?
    
    /// Show barcode result view
    @Published var showBarcodeResult: Bool = false
    
    /// Custom food editing properties
    @Published var showingCustomFoodEdit: Bool = false
    @Published var selectedCustomFoodForEditing: CustomFood?
    @Published var showingDeleteConfirmation: Bool = false
    @Published var customFoodToDelete: CustomFood?
    
    // MARK: - Private Properties
    
    private let networkManager: FoodNetworkManager
    let repository: FuelLogRepositoryProtocol
    private var searchTask: Task<Void, Never>?
    private let searchDebounceDelay: TimeInterval = 0.3
    private let performanceOptimizer = PerformanceOptimizer.shared
    
    // Search result caching - enhanced with performance monitoring
    private var searchCache: [String: CachedSearchResult] = [:]
    private let maxCacheSize = 100
    private let cacheExpirationTime: TimeInterval = 600 // 10 minutes
    
    // Lazy loading for custom foods
    private let customFoodsContainer: LazyLoadingContainer<CustomFood>
    
    // MARK: - Initialization
    
    init(networkManager: FoodNetworkManager? = nil, repository: FuelLogRepositoryProtocol) {
        self.networkManager = networkManager ?? .shared
        self.repository = repository
        
        // Initialize lazy loading container for custom foods
        self.customFoodsContainer = LazyLoadingContainer { limit, offset in
            try await repository.fetchCustomFoods(limit: limit, offset: offset, searchQuery: nil)
        }
        
        // Load custom foods and all available foods on initialization
        Task {
            await customFoodsContainer.loadInitialItems()
            await loadCustomFoods()
            await loadAllAvailableFoods()
        }
    }
    
    deinit {
        searchTask?.cancel()
        let optimizer = performanceOptimizer
        Task { @MainActor in
            optimizer.cancelDebouncedSearch()
        }
    }
    
    // MARK: - Public Methods
    
    /// Searches for food by barcode
    func searchByBarcode(_ barcode: String) async {
        isLoadingBarcode = true
        loadingManager.startLoading(
            taskId: "barcode-search",
            message: "Looking up barcode..."
        )
        barcodeResult = nil
        errorHandler.resetRetryCount()
        
        do {
            let result = try await networkManager.searchFoodByBarcode(barcode)
            barcodeResult = result
            showBarcodeResult = true
            
        } catch {
            errorHandler.handleError(
                error,
                context: "Barcode search: \(barcode)"
            ) { [weak self] in
                await self?.searchByBarcode(barcode)
            }
        }
        
        isLoadingBarcode = false
        loadingManager.stopLoading(taskId: "barcode-search")
    }
    
    /// Performs text-based food search with performance monitoring
    func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        let searchResults = await performanceOptimizer.measureExecutionTime(
            operation: PerformanceMetrics.searchFoods
        ) {
            await performSearchInternal(query: query)
        }
        
        self.searchResults = searchResults
    }
    
    private func performSearchInternal(query: String) async -> [FoodSearchResult] {
        isSearching = true
        loadingManager.startLoading(
            taskId: "food-search",
            message: "Searching for \(query)..."
        )
        
        defer {
            isSearching = false
            loadingManager.stopLoading(taskId: "food-search")
        }
        
        let cacheKey = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check cache first
        if let cachedResult = getCachedResults(for: cacheKey), !cachedResult.isExpired {
            let localResults = await searchLocalFoods(query: query)
            return localResults + cachedResult.results.filter { $0.source != .custom }
        }
        
        do {
            // Search local custom foods first
            let localResults = await searchLocalFoods(query: query)
            
            // Search external API only if connected
            if networkStatusManager.isConnected {
                let apiResults = try await networkManager.searchFoodByName(query)
                
                // Cache API results
                cacheResults(apiResults, for: cacheKey)
                
                // Combine results with local foods prioritized
                return localResults + apiResults
            } else {
                // Offline mode - show only local results
                if localResults.isEmpty {
                    errorHandler.handleError(
                        FuelLogError.networkError(FoodNetworkError.noInternetConnection),
                        context: "Food search (offline)"
                    )
                }
                return localResults
            }
            
        } catch {
            // For network errors, still show local results and any cached results
            let localResults = await searchLocalFoods(query: query)
            let cachedResult = getCachedResults(for: cacheKey)
            let cachedResults = cachedResult?.results.filter { $0.source != .custom } ?? []
            
            let combinedResults = localResults + cachedResults
            
            if combinedResults.isEmpty {
                errorHandler.handleError(
                    error,
                    context: "Food search: \(query)"
                ) { [weak self] in
                    await self?.search(query: query)
                }
            }
            
            return combinedResults
        }
    }
    
    /// Creates a new custom food
    func createCustomFood(_ customFood: CustomFood) async -> Bool {
        loadingManager.startLoading(
            taskId: "create-custom-food",
            message: "Saving \(customFood.name)..."
        )
        
        do {
            try await repository.saveCustomFood(customFood)
            await loadCustomFoods() // Refresh the list
            loadingManager.stopLoading(taskId: "create-custom-food")
            return true
        } catch {
            errorHandler.handleError(
                error,
                context: "Creating custom food: \(customFood.name)"
            ) { [weak self] in
                _ = await self?.createCustomFood(customFood)
            }
            loadingManager.stopLoading(taskId: "create-custom-food")
            return false
        }
    }
    
    /// Clears current search results
    func clearSearch() {
        searchText = ""
        searchResults = []
        errorMessage = nil
        showErrorAlert = false
    }
    
    /// Clears the search cache
    func clearSearchCache() {
        clearCache()
    }
    
    /// Dismisses barcode result view
    func dismissBarcodeResult() {
        showBarcodeResult = false
        barcodeResult = nil
    }
    
    /// Deletes a custom food
    func deleteCustomFood(_ customFood: CustomFood) async {
        loadingManager.startLoading(
            taskId: "delete-custom-food",
            message: "Deleting \(customFood.name)..."
        )
        
        do {
            try await repository.deleteCustomFood(customFood)
            await loadCustomFoods() // Refresh the list
            
            // Clear search results and re-search if there's an active search
            if !searchText.isEmpty {
                await search(query: searchText)
            }
        } catch {
            errorHandler.handleError(
                error,
                context: "Deleting custom food: \(customFood.name)"
            ) { [weak self] in
                await self?.deleteCustomFood(customFood)
            }
        }
        
        loadingManager.stopLoading(taskId: "delete-custom-food")
    }
    
    // MARK: - Private Methods
    
    private func performSearch() async {
        // Check if task was cancelled
        guard !Task.isCancelled else { return }
        
        await search(query: searchText)
    }
    
    private func loadCustomFoods() async {
        let foods = await performanceOptimizer.measureExecutionTime(
            operation: PerformanceMetrics.loadCustomFoods
        ) {
            do {
                return try await repository.fetchCustomFoods()
            } catch {
                errorHandler.handleError(
                    error,
                    context: "Loading custom foods"
                ) { [weak self] in
                    await self?.loadCustomFoods()
                }
                return []
            }
        }
        
        customFoods = foods
        
        // Optimize memory usage
        performanceOptimizer.optimizeMemoryUsage(items: &customFoods)
    }
    
    /// Loads all available foods (custom foods + basic database) for initial display
    private func loadAllAvailableFoods() async {
        // Get all custom foods
        let customFoodResults = customFoods.map { customFood in
            FoodSearchResult(
                id: customFood.id.uuidString,
                name: customFood.name,
                brand: nil,
                calories: customFood.caloriesPerServing,
                protein: customFood.proteinPerServing,
                carbohydrates: customFood.carbohydratesPerServing,
                fat: customFood.fatPerServing,
                servingSize: customFood.servingSize,
                servingUnit: customFood.servingUnit,
                imageUrl: nil,
                source: .custom,
                customFood: customFood
            )
        }
        
        // Get all basic foods
        let basicFoods = BasicFoodDatabase.shared.foods
        let basicFoodResults = basicFoods.map { basicFood in
            BasicFoodDatabase.shared.convertToFoodSearchResult(basicFood)
        }
        
        // Combine and sort by usage (custom foods first, then basic foods)
        // TODO: Implement actual usage tracking for better sorting
        searchResults = customFoodResults + basicFoodResults
    }
    
    private func searchLocalFoods(query: String) async -> [FoodSearchResult] {
        let lowercaseQuery = query.lowercased()
        
        // Search custom foods
        let customFoodResults = customFoods
            .filter { food in
                food.name.lowercased().contains(lowercaseQuery)
            }
            .map { customFood in
                FoodSearchResult(
                    id: customFood.id.uuidString,
                    name: customFood.name,
                    brand: nil,
                    calories: customFood.caloriesPerServing,
                    protein: customFood.proteinPerServing,
                    carbohydrates: customFood.carbohydratesPerServing,
                    fat: customFood.fatPerServing,
                    servingSize: customFood.servingSize,
                    servingUnit: customFood.servingUnit,
                    imageUrl: nil,
                    source: .custom,
                    customFood: customFood
                )
            }
        
        // Search basic food database
        let basicFoods = BasicFoodDatabase.shared.searchFoods(query: query)
        let basicFoodResults = basicFoods.map { basicFood in
            BasicFoodDatabase.shared.convertToFoodSearchResult(basicFood)
        }
        
        // Combine results with custom foods first, then basic foods
        return customFoodResults + basicFoodResults
    }
    
    private func handleNetworkError(_ error: FoodNetworkError) async {
        let message: String
        
        switch error {
        case .productNotFound:
            message = "Product not found. Try searching by name or create a custom food item."
        case .invalidBarcode:
            message = "Invalid barcode format. Please try scanning again."
        case .noInternetConnection:
            message = "No internet connection. Showing local results only."
        case .rateLimitExceeded:
            message = "Too many requests. Please wait a moment and try again."
        case .serverError:
            message = "Server temporarily unavailable. Please try again later."
        default:
            message = error.localizedDescription
        }
        
        await handleError(error, message: message)
    }
    
    private func handleError(_ error: Error, message: String) async {
        errorMessage = message
        showErrorAlert = true
        print("FoodSearchViewModel error: \(error)")
    }
    
    // MARK: - Enhanced Caching Methods
    
    private func getCachedResults(for query: String) -> CachedSearchResult? {
        return searchCache[query]
    }
    
    private func cacheResults(_ results: [FoodSearchResult], for query: String) {
        // Limit cache size - remove oldest entries
        if searchCache.count >= maxCacheSize {
            let sortedKeys = searchCache.keys.sorted { key1, key2 in
                let time1 = searchCache[key1]?.timestamp ?? Date.distantPast
                let time2 = searchCache[key2]?.timestamp ?? Date.distantPast
                return time1 < time2
            }
            
            let keysToRemove = Array(sortedKeys.prefix(searchCache.count - maxCacheSize + 1))
            for key in keysToRemove {
                searchCache.removeValue(forKey: key)
            }
        }
        
        searchCache[query] = CachedSearchResult(
            results: results,
            timestamp: Date(),
            expirationTime: cacheExpirationTime
        )
    }
    
    private func clearCache() {
        searchCache.removeAll()
        performanceOptimizer.clearPerformanceCaches()
    }
    
    /// Clears expired cache entries
    private func clearExpiredCache() {
        searchCache = searchCache.filter { _, cachedResult in
            !cachedResult.isExpired
        }
    }
}

// MARK: - Cached Search Result

private struct CachedSearchResult {
    let results: [FoodSearchResult]
    let timestamp: Date
    let expirationTime: TimeInterval
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > expirationTime
    }
}

// MARK: - Food Search Result Extensions

extension FoodSearchResult {
    /// Creates a FoodLog from this search result
    func createFoodLog(
        mealType: MealType,
        servingMultiplier: Double = 1.0,
        barcode: String? = nil,
        timestamp: Date = Date()
    ) -> FoodLog {
        return FoodLog(
            timestamp: timestamp,
            name: name,
            calories: calories * servingMultiplier,
            protein: protein * servingMultiplier,
            carbohydrates: carbohydrates * servingMultiplier,
            fat: fat * servingMultiplier,
            mealType: mealType,
            servingSize: servingSize * servingMultiplier,
            servingUnit: servingUnit,
            barcode: barcode,
            customFoodId: source == .custom ? UUID(uuidString: id) : nil
        )
    }
    
    /// Formatted display name with brand
    var displayName: String {
        if let brand = brand, !brand.isEmpty {
            return "\(name) - \(brand)"
        }
        return name
    }
    
    /// Formatted nutrition summary
    var nutritionSummary: String {
        return String(format: "%.0f cal • %.1fg protein • %.1fg carbs • %.1fg fat", 
                     calories, protein, carbohydrates, fat)
    }
}