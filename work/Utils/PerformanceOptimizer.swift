import Foundation
import SwiftData
import SwiftUI

// MARK: - Performance Optimizer

/// Utility class for performance optimizations across the Fuel Log feature
@MainActor
final class PerformanceOptimizer: ObservableObject {
    static let shared = PerformanceOptimizer()
    
    // MARK: - Lazy Loading Configuration
    
    /// Default page size for lazy loading
    nonisolated static let defaultPageSize = 20
    
    /// Maximum items to keep in memory for lazy loading
    nonisolated static let maxMemoryItems = 100
    
    // MARK: - Debouncing
    
    private var searchDebounceTask: Task<Void, Never>?
    private let searchDebounceDelay: TimeInterval = 0.3
    
    // MARK: - Background Processing Queue
    
    private let backgroundQueue = DispatchQueue(
        label: "com.fuellog.background",
        qos: .utility,
        attributes: .concurrent
    )
    
    private let calculationQueue = DispatchQueue(
        label: "com.fuellog.calculations",
        qos: .userInitiated
    )
    
    // MARK: - Performance Metrics
    
    @Published var performanceMetrics = PerformanceMetrics()
    
    private init() {}
    
    // MARK: - Lazy Loading Utilities
    
    /// Creates optimized fetch descriptor for food logs with pagination
    func createOptimizedFoodLogDescriptor(
        for date: Date,
        limit: Int = defaultPageSize,
        offset: Int = 0
    ) -> FetchDescriptor<FoodLog> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<FoodLog> { log in
            log.timestamp >= startOfDay && log.timestamp < endOfDay
        }
        
        var descriptor = FetchDescriptor<FoodLog>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.mealTypeRawValue),
                SortDescriptor(\.timestamp)
            ]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        return descriptor
    }
    
    /// Creates optimized fetch descriptor for custom foods with search
    func createOptimizedCustomFoodDescriptor(
        searchQuery: String? = nil,
        limit: Int = defaultPageSize,
        offset: Int = 0
    ) -> FetchDescriptor<CustomFood> {
        var predicate: Predicate<CustomFood>?
        
        if let query = searchQuery?.trimmingCharacters(in: .whitespacesAndNewlines),
           !query.isEmpty {
            let lowercaseQuery = query.lowercased()
            predicate = #Predicate<CustomFood> { food in
                food.name.localizedStandardContains(lowercaseQuery)
            }
        }
        
        var descriptor = FetchDescriptor<CustomFood>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.name),
                SortDescriptor(\.createdDate, order: .reverse)
            ]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        return descriptor
    }
    
    /// Creates optimized fetch descriptor for date range queries
    func createDateRangeFoodLogDescriptor(
        from startDate: Date,
        to endDate: Date,
        limit: Int? = nil
    ) -> FetchDescriptor<FoodLog> {
        let calendar = Calendar.current
        let startOfStartDate = calendar.startOfDay(for: startDate)
        let endOfEndDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))!
        
        let predicate = #Predicate<FoodLog> { log in
            log.timestamp >= startOfStartDate && log.timestamp < endOfEndDate
        }
        
        var descriptor = FetchDescriptor<FoodLog>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.timestamp, order: .reverse),
                SortDescriptor(\.mealTypeRawValue)
            ]
        )
        
        if let limit = limit {
            descriptor.fetchLimit = limit
        }
        
        return descriptor
    }
    
    // MARK: - Debouncing Utilities
    
    /// Debounces search operations to reduce API calls
    func debounceSearch(
        delay: TimeInterval = 0.3,
        operation: @escaping () async -> Void
    ) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await operation()
        }
    }
    
    /// Cancels any pending debounced search
    func cancelDebouncedSearch() {
        searchDebounceTask?.cancel()
        searchDebounceTask = nil
    }
    
    // MARK: - Background Processing
    
    /// Performs nutrition calculations in background
    func calculateNutritionTotals(
        from foodLogs: [FoodLog]
    ) async -> DailyNutritionTotals {
        return await withTaskGroup(of: DailyNutritionTotals.self) { group in
            group.addTask {
                await self.performCalculationInBackground {
                    var totals = DailyNutritionTotals()
                    for foodLog in foodLogs {
                        totals.add(foodLog)
                    }
                    return totals
                }
            }
            
            // Return the first (and only) result
            for await result in group {
                return result
            }
            
            return DailyNutritionTotals()
        }
    }
    
    /// Performs macro validation in background
    func validateMacros(
        for foodLogs: [FoodLog]
    ) async -> [UUID: Bool] {
        return await performCalculationInBackground {
            var validationResults: [UUID: Bool] = [:]
            for foodLog in foodLogs {
                validationResults[foodLog.id] = foodLog.hasValidMacros
            }
            return validationResults
        }
    }
    
    /// Generic background calculation performer
    private func performCalculationInBackground<T>(
        operation: @escaping () -> T
    ) async -> T {
        return await withCheckedContinuation { continuation in
            calculationQueue.async {
                let result = operation()
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - Memory Management
    
    /// Optimizes memory usage by limiting cached items
    func optimizeMemoryUsage<T>(
        items: inout [T],
        maxItems: Int = maxMemoryItems
    ) {
        if items.count > maxItems {
            let itemsToRemove = items.count - maxItems
            items.removeFirst(itemsToRemove)
        }
    }
    
    /// Clears performance-related caches
    func clearPerformanceCaches() {
        cancelDebouncedSearch()
        performanceMetrics.reset()
    }
    
    // MARK: - Performance Monitoring
    
    /// Measures execution time of an operation
    func measureExecutionTime<T>(
        operation: String,
        block: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        await MainActor.run {
            performanceMetrics.recordOperation(operation, duration: executionTime)
        }
        
        return result
    }
    
    /// Measures execution time of a synchronous operation
    func measureSyncExecutionTime<T>(
        operation: String,
        block: () throws -> T
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        performanceMetrics.recordOperation(operation, duration: executionTime)
        
        return result
    }
}

// MARK: - Performance Metrics

struct PerformanceMetrics {
    private var operationTimes: [String: [TimeInterval]] = [:]
    private var operationCounts: [String: Int] = [:]
    
    mutating func recordOperation(_ operation: String, duration: TimeInterval) {
        operationTimes[operation, default: []].append(duration)
        operationCounts[operation, default: 0] += 1
        
        // Keep only last 100 measurements per operation
        if operationTimes[operation]!.count > 100 {
            operationTimes[operation]!.removeFirst()
        }
    }
    
    func averageTime(for operation: String) -> TimeInterval? {
        guard let times = operationTimes[operation], !times.isEmpty else {
            return nil
        }
        return times.reduce(0, +) / Double(times.count)
    }
    
    func totalCount(for operation: String) -> Int {
        return operationCounts[operation] ?? 0
    }
    
    func allOperations() -> [String] {
        return Array(operationCounts.keys).sorted()
    }
    
    mutating func reset() {
        operationTimes.removeAll()
        operationCounts.removeAll()
    }
    
    // Common operation names
    static let loadFoodLogs = "load_food_logs"
    static let searchFoods = "search_foods"
    static let calculateTotals = "calculate_totals"
    static let saveFoodLog = "save_food_log"
    static let loadCustomFoods = "load_custom_foods"
}

// MARK: - Lazy Loading Container

/// Generic container for lazy-loaded data
@MainActor
class LazyLoadingContainer<T>: ObservableObject {
    @Published var items: [T] = []
    @Published var isLoading = false
    @Published var hasMoreItems = true
    @Published var error: Error?
    
    private let pageSize: Int
    private var currentPage = 0
    private let loadMore: (Int, Int) async throws -> [T]
    
    init(pageSize: Int = PerformanceOptimizer.defaultPageSize, loadMore: @escaping (Int, Int) async throws -> [T]) {
        self.pageSize = pageSize
        self.loadMore = loadMore
    }
    
    func loadInitialItems() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        currentPage = 0
        
        do {
            let newItems = try await loadMore(pageSize, 0)
            items = newItems
            hasMoreItems = newItems.count == pageSize
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func loadMoreItems() async {
        guard !isLoading && hasMoreItems else { return }
        
        isLoading = true
        error = nil
        
        do {
            let offset = currentPage * pageSize
            let newItems = try await loadMore(pageSize, offset + pageSize)
            
            if newItems.isEmpty {
                hasMoreItems = false
            } else {
                items.append(contentsOf: newItems)
                currentPage += 1
                hasMoreItems = newItems.count == pageSize
            }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func refresh() async {
        await loadInitialItems()
    }
    
    func reset() {
        items.removeAll()
        currentPage = 0
        hasMoreItems = true
        error = nil
    }
}