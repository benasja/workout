import Foundation
import SwiftData

// MARK: - Cache Manager for Offline Functionality

@MainActor
final class FuelLogCacheManager: ObservableObject {
    static let shared = FuelLogCacheManager()
    
    private let cache = NSCache<NSString, CachedFoodData>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    // Cache configuration
    private let maxCacheSize: Int = 50 * 1024 * 1024 // 50MB
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    private let maxMemoryItems: Int = 200
    
    @Published var cacheSize: Int = 0
    @Published var cachedItemsCount: Int = 0
    
    private init() {
        // Setup cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("FuelLogCache")
        
        // Configure memory cache
        cache.countLimit = maxMemoryItems
        cache.totalCostLimit = maxCacheSize
        
        // Create cache directory if needed
        createCacheDirectoryIfNeeded()
        
        // Load cache statistics asynchronously
        Task { @MainActor in
            await updateCacheStatistics()
        }
        
        // Setup cleanup timer
        setupPeriodicCleanup()
    }
    
    // MARK: - Public Cache Methods
    
    /// Caches a food search result from API
    func cacheFoodSearchResult(_ result: FoodSearchResult, for key: String) {
        let cachedData = CachedFoodData(
            searchResult: result,
            timestamp: Date(),
            source: .api
        )
        
        // Store in memory cache
        cache.setObject(cachedData, forKey: NSString(string: key))
        
        // Store in persistent cache
        Task { @MainActor in
            await persistCachedData(cachedData, for: key)
            await updateCacheStatistics()
        }
    }
    
    /// Caches multiple food search results
    func cacheFoodSearchResults(_ results: [FoodSearchResult], for key: String) {
        let cachedData = CachedFoodData(
            searchResults: results,
            timestamp: Date(),
            source: .api
        )
        
        // Store in memory cache
        cache.setObject(cachedData, forKey: NSString(string: key))
        
        // Store in persistent cache
        Task { @MainActor in
            await persistCachedData(cachedData, for: key)
            await updateCacheStatistics()
        }
    }
    
    /// Retrieves a cached food search result
    func getCachedFoodSearchResult(for key: String) -> FoodSearchResult? {
        // Check memory cache first
        if let cachedData = cache.object(forKey: NSString(string: key)),
           !cachedData.isExpired,
           let result = cachedData.searchResult {
            return result
        }
        
        // Check persistent cache
        if let cachedData = loadCachedData(for: key),
           !cachedData.isExpired,
           let result = cachedData.searchResult {
            // Restore to memory cache
            cache.setObject(cachedData, forKey: NSString(string: key))
            return result
        }
        
        return nil
    }
    
    /// Retrieves cached food search results
    func getCachedFoodSearchResults(for key: String) -> [FoodSearchResult]? {
        // Check memory cache first
        if let cachedData = cache.object(forKey: NSString(string: key)),
           !cachedData.isExpired,
           let results = cachedData.searchResults {
            return results
        }
        
        // Check persistent cache
        if let cachedData = loadCachedData(for: key),
           !cachedData.isExpired,
           let results = cachedData.searchResults {
            // Restore to memory cache
            cache.setObject(cachedData, forKey: NSString(string: key))
            return results
        }
        
        return nil
    }
    
    /// Caches barcode lookup result
    func cacheBarcodeResult(_ result: FoodSearchResult, for barcode: String) {
        let key = "barcode_\(barcode)"
        cacheFoodSearchResult(result, for: key)
    }
    
    /// Retrieves cached barcode result
    func getCachedBarcodeResult(for barcode: String) -> FoodSearchResult? {
        let key = "barcode_\(barcode)"
        return getCachedFoodSearchResult(for: key)
    }
    
    /// Caches search query results
    func cacheSearchResults(_ results: [FoodSearchResult], for query: String, page: Int = 1) {
        let key = "search_\(query.lowercased())_\(page)"
        cacheFoodSearchResults(results, for: key)
    }
    
    /// Retrieves cached search results
    func getCachedSearchResults(for query: String, page: Int = 1) -> [FoodSearchResult]? {
        let key = "search_\(query.lowercased())_\(page)"
        return getCachedFoodSearchResults(for: key)
    }
    
    // MARK: - Cache Management
    
    /// Clears all cached data
    func clearAllCache() async {
        // Clear memory cache
        cache.removeAllObjects()
        
        // Clear persistent cache
        do {
            let cacheFiles = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in cacheFiles {
                try fileManager.removeItem(at: file)
            }
        } catch {
            print("❌ Failed to clear persistent cache: \(error)")
        }
        
        await updateCacheStatistics()
    }
    
    /// Clears expired cache entries
    func clearExpiredCache() async {
        // Clear expired items from memory cache
        // Note: NSCache doesn't provide enumeration, so we rely on periodic cleanup
        
        // Clear expired items from persistent cache
        do {
            let cacheFiles = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            let now = Date()
            
            for file in cacheFiles {
                let resourceValues = try file.resourceValues(forKeys: [.contentModificationDateKey])
                if let modificationDate = resourceValues.contentModificationDate,
                   now.timeIntervalSince(modificationDate) > maxCacheAge {
                    try fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("❌ Failed to clear expired cache: \(error)")
        }
        
        await updateCacheStatistics()
    }
    
    /// Gets cache statistics
    func getCacheStatistics() -> CacheStatistics {
        return CacheStatistics(
            totalSize: cacheSize,
            itemCount: cachedItemsCount,
            maxSize: maxCacheSize,
            maxAge: maxCacheAge
        )
    }
    
    // MARK: - Private Methods
    
    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            do {
                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            } catch {
                print("❌ Failed to create cache directory: \(error)")
            }
        }
    }
    
    private func persistCachedData(_ data: CachedFoodData, for key: String) async {
        let fileName = sanitizeFileName(key) + ".cache"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        do {
            let encodedData = try JSONEncoder().encode(data)
            try encodedData.write(to: fileURL)
        } catch {
            print("❌ Failed to persist cached data for key \(key): \(error)")
        }
    }
    
    private func loadCachedData(for key: String) -> CachedFoodData? {
        let fileName = sanitizeFileName(key) + ".cache"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(CachedFoodData.self, from: data)
        } catch {
            print("❌ Failed to load cached data for key \(key): \(error)")
            // Remove corrupted cache file
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
    }
    
    private func sanitizeFileName(_ fileName: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return fileName.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
    
    private func updateCacheStatistics() async {
        do {
            let cacheFiles = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            
            var totalSize = 0
            var itemCount = 0
            
            for file in cacheFiles {
                let resourceValues = try file.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = resourceValues.fileSize {
                    totalSize += fileSize
                    itemCount += 1
                }
            }
            
            await MainActor.run {
                self.cacheSize = totalSize
                self.cachedItemsCount = itemCount
            }
        } catch {
            print("❌ Failed to update cache statistics: \(error)")
        }
    }
    
    private func setupPeriodicCleanup() {
        // Setup timer to clean expired cache every hour
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task {
                await self.clearExpiredCache()
            }
        }
    }
}

// MARK: - Cached Food Data Model

private class CachedFoodData: NSObject, Codable {
    let searchResult: FoodSearchResult?
    let searchResults: [FoodSearchResult]?
    let timestamp: Date
    let source: CacheSource
    let expirationInterval: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    enum CacheSource: String, Codable {
        case api = "api"
        case user = "user"
    }
    
    init(searchResult: FoodSearchResult, timestamp: Date, source: CacheSource) {
        self.searchResult = searchResult
        self.searchResults = nil
        self.timestamp = timestamp
        self.source = source
        super.init()
    }
    
    init(searchResults: [FoodSearchResult], timestamp: Date, source: CacheSource) {
        self.searchResult = nil
        self.searchResults = searchResults
        self.timestamp = timestamp
        self.source = source
        super.init()
    }
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > expirationInterval
    }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case searchResult, searchResults, timestamp, source
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        searchResult = try container.decodeIfPresent(FoodSearchResult.self, forKey: .searchResult)
        searchResults = try container.decodeIfPresent([FoodSearchResult].self, forKey: .searchResults)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        source = try container.decode(CacheSource.self, forKey: .source)
        super.init()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(searchResult, forKey: .searchResult)
        try container.encodeIfPresent(searchResults, forKey: .searchResults)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(source, forKey: .source)
    }
}

// MARK: - Cache Statistics

struct CacheStatistics {
    let totalSize: Int
    let itemCount: Int
    let maxSize: Int
    let maxAge: TimeInterval
    
    var sizeInMB: Double {
        Double(totalSize) / (1024 * 1024)
    }
    
    var maxSizeInMB: Double {
        Double(maxSize) / (1024 * 1024)
    }
    
    var usagePercentage: Double {
        guard maxSize > 0 else { return 0 }
        return Double(totalSize) / Double(maxSize) * 100
    }
}

// MARK: - FoodSearchResult Codable Extension

extension FoodSearchResult: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, brand, calories, protein, carbohydrates, fat
        case servingSize, servingUnit, imageUrl, source, customFood
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        calories = try container.decode(Double.self, forKey: .calories)
        protein = try container.decode(Double.self, forKey: .protein)
        carbohydrates = try container.decode(Double.self, forKey: .carbohydrates)
        fat = try container.decode(Double.self, forKey: .fat)
        servingSize = try container.decode(Double.self, forKey: .servingSize)
        servingUnit = try container.decode(String.self, forKey: .servingUnit)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        source = try container.decode(FoodSource.self, forKey: .source)
        customFood = nil // CustomFood is not Codable, skip for caching
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(brand, forKey: .brand)
        try container.encode(calories, forKey: .calories)
        try container.encode(protein, forKey: .protein)
        try container.encode(carbohydrates, forKey: .carbohydrates)
        try container.encode(fat, forKey: .fat)
        try container.encode(servingSize, forKey: .servingSize)
        try container.encode(servingUnit, forKey: .servingUnit)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encode(source, forKey: .source)
        // Skip encoding customFood as it's not Codable (SwiftData model)
    }
}

