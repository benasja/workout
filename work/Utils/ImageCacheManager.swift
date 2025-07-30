import Foundation
import SwiftUI
import UIKit

// MARK: - Image Cache Manager

@MainActor
final class ImageCacheManager: ObservableObject {
    static let shared = ImageCacheManager()
    
    // MARK: - Cache Configuration
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCache: DiskImageCache
    private let downloadQueue = DispatchQueue(label: "com.fuellog.image.download", qos: .utility, attributes: .concurrent)
    
    // Cache limits
    private let maxMemoryCacheSize = 50 * 1024 * 1024 // 50MB
    private let maxDiskCacheSize = 200 * 1024 * 1024 // 200MB
    private let maxCacheAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days
    
    @Published var cacheStatistics = ImageCacheStatistics()
    
    // MARK: - Active Downloads
    
    private var activeDownloads: [String: Task<UIImage?, Error>] = [:]
    
    private init() {
        diskCache = DiskImageCache()
        configureMemoryCache()
        setupCacheCleanup()
    }
    
    // MARK: - Public API
    
    /// Loads an image from URL with caching
    func loadImage(from url: String) async -> UIImage? {
        // Check memory cache first
        if let cachedImage = memoryCache.object(forKey: NSString(string: url)) {
            await updateStatistics(hit: true, source: .memory)
            return cachedImage
        }
        
        // Check if download is already in progress
        if let existingTask = activeDownloads[url] {
            do {
                return try await existingTask.value
            } catch {
                print("❌ Image download task failed: \(error)")
                return nil
            }
        }
        
        // Create new download task
        let downloadTask = Task<UIImage?, Error> {
            // Check disk cache
            if let diskImage = await diskCache.image(for: url) {
                // Store in memory cache for faster access
                memoryCache.setObject(diskImage, forKey: NSString(string: url))
                await updateStatistics(hit: true, source: .disk)
                return diskImage
            }
            
            // Download from network
            guard let imageUrl = URL(string: url) else {
                throw ImageCacheError.invalidURL
            }
            
            let (data, response) = try await URLSession.shared.data(from: imageUrl)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw ImageCacheError.networkError
            }
            
            guard let image = UIImage(data: data) else {
                throw ImageCacheError.invalidImageData
            }
            
            // Cache the image
            memoryCache.setObject(image, forKey: NSString(string: url))
            await diskCache.store(image: image, for: url)
            await updateStatistics(hit: false, source: .network)
            
            return image
        }
        
        activeDownloads[url] = downloadTask
        
        do {
            let image = try await downloadTask.value
            activeDownloads.removeValue(forKey: url)
            return image
        } catch {
            activeDownloads.removeValue(forKey: url)
            print("❌ Failed to load image from \(url): \(error)")
            return nil
        }
    }
    
    /// Preloads images for better performance
    func preloadImages(urls: [String]) {
        for url in urls {
            Task {
                _ = await loadImage(from: url)
            }
        }
    }
    
    /// Clears all cached images
    func clearAllCache() async {
        memoryCache.removeAllObjects()
        await diskCache.clearAll()
        await updateCacheStatistics()
    }
    
    /// Clears expired images from cache
    func clearExpiredCache() async {
        await diskCache.clearExpired(maxAge: maxCacheAge)
        await updateCacheStatistics()
    }
    
    /// Gets current cache statistics
    func getCacheStatistics() async -> ImageCacheStatistics {
        await updateCacheStatistics()
        return cacheStatistics
    }
    
    // MARK: - Private Methods
    
    private func configureMemoryCache() {
        memoryCache.totalCostLimit = maxMemoryCacheSize
        memoryCache.countLimit = 200 // Maximum number of images
        
        // Clear memory cache on memory warning
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.memoryCache.removeAllObjects()
            }
        }
    }
    
    private func setupCacheCleanup() {
        // Setup timer to clean expired cache every 6 hours
        Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { _ in
            Task {
                await self.clearExpiredCache()
            }
        }
    }
    
    private func updateStatistics(hit: Bool, source: CacheSource) async {
        await MainActor.run {
            if hit {
                cacheStatistics.hits += 1
                switch source {
                case .memory:
                    cacheStatistics.memoryHits += 1
                case .disk:
                    cacheStatistics.diskHits += 1
                case .network:
                    break
                }
            } else {
                cacheStatistics.misses += 1
                cacheStatistics.networkLoads += 1
            }
        }
    }
    
    private func updateCacheStatistics() async {
        let diskStats = await diskCache.getStatistics()
        
        await MainActor.run {
            cacheStatistics.diskCacheSize = diskStats.totalSize
            cacheStatistics.diskCacheCount = diskStats.itemCount
        }
    }
}

// MARK: - Disk Image Cache

private actor DiskImageCache {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("ImageCache")
        Task {
            await createCacheDirectoryIfNeeded()
        }
    }
    
    func image(for url: String) -> UIImage? {
        let fileName = cacheFileName(for: url)
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        // Update access time
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
        
        return image
    }
    
    func store(image: UIImage, for url: String) {
        let fileName = cacheFileName(for: url)
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return
        }
        
        do {
            try data.write(to: fileURL)
        } catch {
            print("❌ Failed to store image to disk: \(error)")
        }
    }
    
    func clearAll() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
        } catch {
            print("❌ Failed to clear disk cache: \(error)")
        }
    }
    
    func clearExpired(maxAge: TimeInterval) {
        do {
            let files = try fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey]
            )
            
            let now = Date()
            for file in files {
                let resourceValues = try file.resourceValues(forKeys: [.contentModificationDateKey])
                if let modificationDate = resourceValues.contentModificationDate,
                   now.timeIntervalSince(modificationDate) > maxAge {
                    try fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("❌ Failed to clear expired cache: \(error)")
        }
    }
    
    func getStatistics() -> (totalSize: Int, itemCount: Int) {
        do {
            let files = try fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.fileSizeKey]
            )
            
            var totalSize = 0
            var itemCount = 0
            
            for file in files {
                let resourceValues = try file.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = resourceValues.fileSize {
                    totalSize += fileSize
                    itemCount += 1
                }
            }
            
            return (totalSize, itemCount)
        } catch {
            print("❌ Failed to get cache statistics: \(error)")
            return (0, 0)
        }
    }
    
    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            do {
                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            } catch {
                print("❌ Failed to create image cache directory: \(error)")
            }
        }
    }
    
    private func cacheFileName(for url: String) -> String {
        return url.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-") ?? UUID().uuidString
    }
}

// MARK: - Supporting Types

enum ImageCacheError: LocalizedError {
    case invalidURL
    case networkError
    case invalidImageData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid image URL"
        case .networkError:
            return "Network error while downloading image"
        case .invalidImageData:
            return "Invalid image data received"
        }
    }
}

enum CacheSource {
    case memory
    case disk
    case network
}

struct ImageCacheStatistics {
    var hits: Int = 0
    var misses: Int = 0
    var memoryHits: Int = 0
    var diskHits: Int = 0
    var networkLoads: Int = 0
    var diskCacheSize: Int = 0
    var diskCacheCount: Int = 0
    
    var hitRate: Double {
        let total = hits + misses
        return total > 0 ? Double(hits) / Double(total) : 0
    }
    
    var diskCacheSizeMB: Double {
        Double(diskCacheSize) / (1024 * 1024)
    }
}

// MARK: - SwiftUI Integration

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: String
    private let content: (UIImage) -> Content
    private let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = true
    
    init(
        url: String,
        @ViewBuilder content: @escaping (UIImage) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(image)
            } else {
                placeholder()
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        isLoading = true
        image = await ImageCacheManager.shared.loadImage(from: url)
        isLoading = false
    }
}

// Convenience initializer for simple image display
extension CachedAsyncImage where Content == Image, Placeholder == ProgressView<EmptyView, EmptyView> {
    init(url: String) {
        self.init(
            url: url,
            content: { uiImage in
                Image(uiImage: uiImage)
                    .resizable()
            },
            placeholder: {
                ProgressView()
            }
        )
    }
}