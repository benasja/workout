import Foundation
import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

// MARK: - FuelLogHealthKitManager Protocol

/// Protocol for HealthKit integration in Fuel Log functionality
protocol FuelLogHealthKitManager {
    func writeNutritionData(_ foodLog: FoodLog) async throws
}

/// Main ViewModel for Fuel Log functionality, managing daily food logs and nutrition tracking
@MainActor
final class FuelLogViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current day's food log entries, grouped by meal type
    @Published var todaysFoodLogs: [FoodLog] = []
    
    /// User's current nutrition goals
    @Published var nutritionGoals: NutritionGoals?
    
    /// Calculated daily nutrition totals
    @Published var dailyTotals: DailyNutritionTotals = DailyNutritionTotals()
    
    /// Currently selected date for viewing food logs (using HydrationLog pattern)
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date()) {
        didSet {
            // Use the same pattern as HydrationLog - compare startOfDay dates
            let calendar = Calendar.current
            let normalizedOldDate = calendar.startOfDay(for: oldValue)
            let normalizedNewDate = calendar.startOfDay(for: selectedDate)
            
            if normalizedOldDate != normalizedNewDate {
                // print("📅 FuelLogViewModel: Selected date changed (HydrationLog pattern)")
                // print("📅 FuelLogViewModel: From: \(DateFormatter.shortDate.string(from: normalizedOldDate))")
                // print("📅 FuelLogViewModel: To: \(DateFormatter.shortDate.string(from: normalizedNewDate))")
                
                Task {
                    await loadFoodLogs(for: normalizedNewDate)
                }
            }
        }
    }
    
    /// Loading state for UI feedback
    @Published var isLoading: Bool = false
    
    /// Error message for user feedback
    @Published var errorMessage: String?
    
    /// Loading state for specific operations
    @Published var isLoadingGoals: Bool = false
    @Published var isSavingFood: Bool = false
    @Published var isDeletingFood: Bool = false
    
    /// Enhanced error handling
    @Published var errorHandler = ErrorHandler()
    @Published var loadingManager = LoadingStateManager()
    @Published var networkManager = NetworkStatusManager()
    
    /// Operation-specific loading states
    @Published var isLoadingInitialData: Bool = false
    @Published var isRefreshing: Bool = false
    
    /// Nutrition progress calculations
    @Published var nutritionProgress: NutritionProgress = NutritionProgress(
        caloriesProgress: 0,
        proteinProgress: 0,
        carbohydratesProgress: 0,
        fatProgress: 0
    )
    
    /// Food logs grouped by meal type for UI display
    @Published var foodLogsByMealType: [MealType: [FoodLog]] = [:]
    
    /// Computed property to force UI reactivity when food logs change
    var foodLogsSummary: String {
        let total = todaysFoodLogs.count
        let breakdown = MealType.allCases.map { mealType in
            let count = foodLogsByMealType[mealType]?.count ?? 0
            return "\(mealType.displayName): \(count)"
        }.joined(separator: ", ")
        return "Total: \(total) (\(breakdown))"
    }
    
    /// Detailed food content for debugging UI caching issues
    var foodLogsDetailedSummary: String {
        let details = MealType.allCases.compactMap { mealType -> String? in
            let logs = foodLogsByMealType[mealType] ?? []
            guard !logs.isEmpty else { return nil }
            let items = logs.map { "\($0.name)(\($0.id.uuidString.prefix(8)))" }.joined(separator: ",")
            return "\(mealType.displayName): \(items)"
        }.joined(separator: " | ")
        return details.isEmpty ? "No food" : details
    }
    
    /// Global refresh trigger to force complete UI recreation
    @Published var uiRefreshTrigger: UUID = UUID()
    
    // MARK: - Private Properties
    
    private let _repository: FuelLogRepositoryProtocol
    private let healthKitManager: FuelLogHealthKitManager?
    private let dataSyncManager: FuelLogDataSyncManager?
    
    // MARK: - Public Properties
    
    var repository: FuelLogRepositoryProtocol {
        return _repository
    }
    
    // MARK: - Computed Properties
    
    /// Remaining nutrition values to reach daily goals
    var remainingNutrition: DailyNutritionTotals {
        guard let goals = nutritionGoals else {
            return DailyNutritionTotals()
        }
        return dailyTotals.remaining(against: goals)
    }
    
    /// Whether the selected date is today (using HydrationLog pattern)
    var isSelectedDateToday: Bool {
        let calendar = Calendar.current
        let todayStartOfDay = calendar.startOfDay(for: Date())
        let selectedStartOfDay = calendar.startOfDay(for: selectedDate)
        return todayStartOfDay == selectedStartOfDay
    }
    
    /// Whether nutrition goals are available
    var hasNutritionGoals: Bool {
        return nutritionGoals != nil
    }
    
    /// Whether any food has been logged for the selected date
    var hasFoodLogs: Bool {
        !todaysFoodLogs.isEmpty
    }
    
    // MARK: - Initialization
    
    init(repository: FuelLogRepositoryProtocol, healthKitManager: FuelLogHealthKitManager? = nil, dataSyncManager: FuelLogDataSyncManager? = nil) {
        self._repository = repository
        self.healthKitManager = healthKitManager
        self.dataSyncManager = dataSyncManager
        
        // Load initial data
        Task {
            await loadInitialData()
        }
    }
    
    // MARK: - Public Methods
    
    /// Loads initial data including nutrition goals and today's food logs
    func loadInitialData() async {
        isLoadingInitialData = true
        loadingManager.startLoading(
            taskId: "initial-load",
            message: "Loading nutrition data...",
            showProgress: true
        )
        errorHandler.resetRetryCount()
        
        do {
            // Load nutrition goals first (30% progress)
            loadingManager.updateProgress(0.3, message: "Loading nutrition goals...")
            await loadNutritionGoals()
            
            // Load today's food logs (100% progress)
            loadingManager.updateProgress(0.7, message: "Loading food logs...")
            await loadFoodLogs(for: selectedDate)
            
            loadingManager.updateProgress(1.0, message: "Complete!")
            
            // Small delay to show completion
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            

            
        } catch {
            print("❌ FuelLogViewModel: Error in loadInitialData: \(error)")
            errorHandler.handleError(
                error,
                context: "Loading initial data"
            ) { [weak self] in
                await self?.loadInitialData()
            }
        }
        
        isLoadingInitialData = false
        loadingManager.stopLoading(taskId: "initial-load")
    }
    
    /// Loads nutrition goals from repository
    func loadNutritionGoals() async {
        isLoadingGoals = true
        
        do {
            let goals = try await _repository.fetchNutritionGoals()
            await MainActor.run {
                self.nutritionGoals = goals
                if goals != nil {
                    // print("✅ FuelLogViewModel: Loaded nutrition goals successfully")
                } else {
                    // print("ℹ️ FuelLogViewModel: No nutrition goals found - user needs to set them up")
                }
            }
        } catch {
            print("❌ FuelLogViewModel: Error loading nutrition goals: \(error)")
            errorHandler.handleError(
                error,
                context: "Loading nutrition goals"
            ) { [weak self] in
                await self?.loadNutritionGoals()
            }
        }
        
        isLoadingGoals = false
    }
    
    /// Loads food logs for a specific date with performance monitoring
    func loadFoodLogs(for date: Date) async {
        isLoading = true
        
        // CRITICAL FIX: Normalize the date to start of day for consistent querying
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        // print("🔄 FuelLogViewModel: Loading food logs for \(DateFormatter.shortDate.string(from: normalizedDate))")
        
        // Ensure nutrition goals are loaded if not already present
        if nutritionGoals == nil {
            await loadNutritionGoals()
        }
        
        let foodLogs = await PerformanceOptimizer.shared.measureExecutionTime(
            operation: PerformanceMetrics.loadFoodLogs
        ) {
            do {
                return try await _repository.fetchFoodLogs(for: normalizedDate)
            } catch {
                print("❌ FuelLogViewModel: Error loading food logs for \(DateFormatter.shortDate.string(from: normalizedDate)): \(error)")
                errorHandler.handleError(
                    error,
                    context: "Loading food logs for \(DateFormatter.shortDate.string(from: normalizedDate))"
                ) { [weak self] in
                    await self?.loadFoodLogs(for: normalizedDate)
                }
                return []
            }
        }
        
        // print("✅ FuelLogViewModel: Loaded \(foodLogs.count) food logs for \(DateFormatter.shortDate.string(from: normalizedDate))")
        
        // CRITICAL FIX: Update all UI state on main thread in correct order
        await MainActor.run {
            // print("🔄 FuelLogViewModel: Updating UI state with \(foodLogs.count) food logs from repository")
            
            // Force UI update notification
            objectWillChange.send()
            
            // 1. Update the primary data source
            todaysFoodLogs = foodLogs
            // print("🔄 FuelLogViewModel: Set todaysFoodLogs to \(todaysFoodLogs.count) items")
            
            // 2. Group food logs by meal type for UI display
            groupFoodLogsByMealType()
            
            // 3. Calculate daily totals
            calculateDailyTotals()
            
            // 4. Update nutrition progress
            updateNutritionProgress()
            
            // print("🔄 FuelLogViewModel: UI state updated - \(todaysFoodLogs.count) food logs, \(foodLogsByMealType.values.flatMap { $0 }.count) grouped items")
            
            // CRITICAL FIX: Force complete UI recreation by updating refresh trigger
            uiRefreshTrigger = UUID()
            // print("🔄 FuelLogViewModel: Triggered UI refresh with new UUID: \(uiRefreshTrigger)")
            
            // Force another UI update after all changes
            objectWillChange.send()
        }
        
        isLoading = false
    }
    

    
    /// Logs a new food entry with proper date handling
    func logFood(_ foodLog: FoodLog) async {
        isSavingFood = true
        loadingManager.startLoading(
            taskId: "save-food",
            message: "Saving \(foodLog.name)..."
        )
        
        // Create a new food log with the correct timestamp for the selected date
        let correctedFoodLog = createFoodLogForSelectedDate(from: foodLog)
        
        // print("🍎 FuelLogViewModel: Logging food '\(correctedFoodLog.name)' for selected date \(DateFormatter.shortDate.string(from: selectedDate))")
        // print("🍎 FuelLogViewModel: Food will be saved with timestamp: \(correctedFoodLog.timestamp)")
        
        do {
            // Save to repository
            try await _repository.saveFoodLog(correctedFoodLog)
            
            // Write to HealthKit if available and authorized
            if let healthKitManager = healthKitManager {
                do {
                    try await healthKitManager.writeNutritionData(correctedFoodLog)
                } catch {
                    // HealthKit write failure shouldn't prevent food logging
                    print("⚠️ HealthKit write failed: \(error.localizedDescription)")
                }
            }
            
            // Sync to HealthKit via data sync manager if available
            if let dataSyncManager = dataSyncManager {
                do {
                    try await dataSyncManager.syncFoodLogToHealthKit(correctedFoodLog)
                } catch {
                    // Sync failure shouldn't prevent food logging
                    print("⚠️ Data sync failed: \(error.localizedDescription)")
                }
            }
            
            // Reload data for the selected date to ensure consistency
            // print("🔄 FuelLogViewModel: Reloading food logs for selected date \(DateFormatter.shortDate.string(from: selectedDate))")
            await loadFoodLogs(for: selectedDate)
            
            // Provide haptic feedback for successful logging
            await provideFeedbackForGoalCompletion()
            
            // print("✅ FuelLogViewModel: Successfully logged food '\(correctedFoodLog.name)' to \(DateFormatter.shortDate.string(from: selectedDate))")
            
        } catch {
            print("❌ FuelLogViewModel: Failed to log food '\(correctedFoodLog.name)': \(error)")
            errorHandler.handleError(
                error,
                context: "Logging food: \(correctedFoodLog.name)"
            ) { [weak self] in
                await self?.logFood(foodLog)
            }
        }
        
        isSavingFood = false
        loadingManager.stopLoading(taskId: "save-food")
    }
    
    /// Updates an existing food log entry
    func updateFood(_ foodLog: FoodLog) async {
        isSavingFood = true
        loadingManager.startLoading(
            taskId: "update-food",
            message: "Updating \(foodLog.name)..."
        )
        
        do {
            try await _repository.updateFoodLog(foodLog)
            
            // Reload data to reflect changes
            await loadFoodLogs(for: selectedDate)
            
        } catch {
            errorHandler.handleError(
                error,
                context: "Updating food: \(foodLog.name)"
            ) { [weak self] in
                await self?.updateFood(foodLog)
            }
        }
        
        isSavingFood = false
        loadingManager.stopLoading(taskId: "update-food")
    }
    
    /// Deletes a food log entry and updates UI properly
    func deleteFood(_ foodLog: FoodLog) async {
        isDeletingFood = true
        loadingManager.startLoading(
            taskId: "delete-food",
            message: "Deleting \(foodLog.name)..."
        )
        
        // let calendar = Calendar.current
       // let foodDate = calendar.startOfDay(for: foodLog.timestamp)
       // let selectedDateNormalized = calendar.startOfDay(for: selectedDate)
        
        // print("🗑️ FuelLogViewModel: Deleting food '\(foodLog.name)' with ID \(foodLog.id)")
        // print("🗑️ FuelLogViewModel: Food original date: \(DateFormatter.shortDate.string(from: foodDate))")
        // print("🗑️ FuelLogViewModel: Currently viewing date: \(DateFormatter.shortDate.string(from: selectedDateNormalized))")
        
        do {
            // Delete from repository first
            try await _repository.deleteFoodLog(foodLog)
            
            // print("🔄 FuelLogViewModel: Food deleted from repository, reloading data...")
            
            // CRITICAL FIX: Just reload the data from repository instead of manual UI updates
            // This ensures the UI state matches the database state exactly
            await loadFoodLogs(for: selectedDate)
            
            // print("✅ FuelLogViewModel: Successfully deleted food '\(foodLog.name)' and updated UI")
            
        } catch {
            print("❌ FuelLogViewModel: Failed to delete food '\(foodLog.name)': \(error)")
            errorHandler.handleError(
                error,
                context: "Deleting food: \(foodLog.name)"
            ) { [weak self] in
                await self?.deleteFood(foodLog)
            }
        }
        
        isDeletingFood = false
        loadingManager.stopLoading(taskId: "delete-food")
    }
    
    /// Updates an existing food log entry with optimistic UI updates
    func updateFoodLog(_ originalFoodLog: FoodLog, with updatedFoodLog: FoodLog) async {
        isSavingFood = true
        errorMessage = nil
        
        // Optimistic update - replace in UI immediately
        let originalFoodLogs = todaysFoodLogs
        let originalDailyTotals = dailyTotals
        let originalProgress = nutritionProgress
        let originalGroupedLogs = foodLogsByMealType
        
        // Apply optimistic update by updating the original food log's properties
        if let index = todaysFoodLogs.firstIndex(where: { $0.id == originalFoodLog.id }) {
            let foodLogToUpdate = todaysFoodLogs[index]
            
            // Update the properties of the existing food log
            foodLogToUpdate.name = updatedFoodLog.name
            foodLogToUpdate.calories = updatedFoodLog.calories
            foodLogToUpdate.protein = updatedFoodLog.protein
            foodLogToUpdate.carbohydrates = updatedFoodLog.carbohydrates
            foodLogToUpdate.fat = updatedFoodLog.fat
            foodLogToUpdate.mealType = updatedFoodLog.mealType
            foodLogToUpdate.servingSize = updatedFoodLog.servingSize
            foodLogToUpdate.servingUnit = updatedFoodLog.servingUnit
            
            groupFoodLogsByMealType()
            calculateDailyTotals()
            updateNutritionProgress()
        }
        
        do {
            // Update the food log in the repository
            try await _repository.updateFoodLog(originalFoodLog)
            
            // Write to HealthKit if available and authorized
            if let healthKitManager = healthKitManager {
                try? await healthKitManager.writeNutritionData(originalFoodLog)
            }
            
            // Provide haptic feedback for successful update
            await provideFeedbackForGoalCompletion()
            
        } catch {
            // Revert optimistic update on failure
            todaysFoodLogs = originalFoodLogs
            dailyTotals = originalDailyTotals
            nutritionProgress = originalProgress
            foodLogsByMealType = originalGroupedLogs
            
            await handleError(error, message: "Failed to update food entry")
        }
        
        isSavingFood = false
    }
    
    /// Updates nutrition goals
    func updateNutritionGoals(_ goals: NutritionGoals) async {
        isLoadingGoals = true
        loadingManager.startLoading(
            taskId: "update-goals",
            message: "Updating nutrition goals..."
        )
        
        do {
            if nutritionGoals != nil {
                try await _repository.updateNutritionGoals(goals)
            } else {
                try await _repository.saveNutritionGoals(goals)
            }
            
            nutritionGoals = goals
            updateNutritionProgress()
            
        } catch {
            errorHandler.handleError(
                error,
                context: "Updating nutrition goals"
            ) { [weak self] in
                await self?.updateNutritionGoals(goals)
            }
        }
        
        isLoadingGoals = false
        loadingManager.stopLoading(taskId: "update-goals")
    }
    
    /// Navigates to the previous day
    func navigateToPreviousDay() {
        let calendar = Calendar.current
        selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }
    
    /// Navigates to the next day
    func navigateToNextDay() {
        let calendar = Calendar.current
        selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }
    
    /// Navigates to today
    func navigateToToday() {
        let today = Date()
        print("🏠 FuelLogViewModel: Navigating to today: \(DateFormatter.shortDate.string(from: today))")
        selectedDate = today
    }
    
    /// Debug method to validate current state
    func debugCurrentState() {
        let calendar = Calendar.current
        let normalizedSelectedDate = calendar.startOfDay(for: selectedDate)
        
        print("🔍 FuelLogViewModel Debug State:")
        print("🔍 Selected date: \(DateFormatter.shortDate.string(from: selectedDate))")
        print("🔍 Normalized selected date: \(DateFormatter.shortDate.string(from: normalizedSelectedDate))")
        print("🔍 Is today: \(calendar.isDateInToday(selectedDate))")
        print("🔍 Food logs count: \(todaysFoodLogs.count)")
        
        for (index, foodLog) in todaysFoodLogs.enumerated() {
            let foodDate = calendar.startOfDay(for: foodLog.timestamp)
            let isCorrectDate = foodDate == normalizedSelectedDate
            print("🔍 Food \(index + 1): '\(foodLog.name)' - Date: \(DateFormatter.shortDate.string(from: foodDate)) - Correct: \(isCorrectDate)")
        }
    }
    
    /// Force refresh the UI state by recalculating everything
    func forceRefreshUI() {
        print("🔄 FuelLogViewModel: Force refreshing UI state")
        groupFoodLogsByMealType()
        calculateDailyTotals()
        updateNutritionProgress()
        print("🔄 FuelLogViewModel: UI state refreshed - \(todaysFoodLogs.count) food logs")
    }
    
    /// Clears the current error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Refreshes all data
    func refresh() async {
        isRefreshing = true
        loadingManager.startLoading(
            taskId: "refresh",
            message: "Refreshing data..."
        )
        
        errorHandler.resetRetryCount()
        await loadInitialData()
        
        isRefreshing = false
        loadingManager.stopLoading(taskId: "refresh")
    }
    
    /// Retry the last failed operation
    func retryLastOperation() async {
        await errorHandler.retry { [weak self] in
            await self?.loadInitialData()
        }
    }
    
    // MARK: - Data Management Methods
    
    /// Exports all nutrition data
    func exportNutritionData() async throws -> Data {
        guard let dataSyncManager = dataSyncManager else {
            throw FuelLogError.syncUnavailable
        }
        
        loadingManager.startLoading(
            taskId: "export-data",
            message: "Exporting nutrition data..."
        )
        
        do {
            let exportData = try await dataSyncManager.exportNutritionData()
            loadingManager.stopLoading(taskId: "export-data")
            return exportData
        } catch {
            loadingManager.stopLoading(taskId: "export-data")
            throw error
        }
    }
    
    /// Imports nutrition data
    func importNutritionData(_ data: Data, mergeStrategy: ImportMergeStrategy = .skipExisting) async throws {
        guard let dataSyncManager = dataSyncManager else {
            throw FuelLogError.syncUnavailable
        }
        
        loadingManager.startLoading(
            taskId: "import-data",
            message: "Importing nutrition data..."
        )
        
        do {
            try await dataSyncManager.importNutritionData(data, mergeStrategy: mergeStrategy)
            
            // Reload data after import
            await loadInitialData()
            
            loadingManager.stopLoading(taskId: "import-data")
        } catch {
            loadingManager.stopLoading(taskId: "import-data")
            throw error
        }
    }
    
    /// Performs data cleanup
    func performDataCleanup() async throws {
        guard let dataSyncManager = dataSyncManager else {
            throw FuelLogError.syncUnavailable
        }
        
        loadingManager.startLoading(
            taskId: "cleanup-data",
            message: "Cleaning up old data..."
        )
        
        do {
            try await dataSyncManager.performDataCleanup()
            
            // Reload data after cleanup
            await loadFoodLogs(for: selectedDate)
            
            loadingManager.stopLoading(taskId: "cleanup-data")
        } catch {
            loadingManager.stopLoading(taskId: "cleanup-data")
            throw error
        }
    }
    
    /// Gets storage statistics
    func getStorageStatistics() async -> StorageStatistics? {
        return await dataSyncManager?.getStorageStatistics()
    }
    
    /// Performs full HealthKit sync
    func performFullSync() async throws {
        guard let dataSyncManager = dataSyncManager else {
            throw FuelLogError.syncUnavailable
        }
        
        loadingManager.startLoading(
            taskId: "full-sync",
            message: "Syncing with HealthKit..."
        )
        
        do {
            try await dataSyncManager.performFullSync()
            loadingManager.stopLoading(taskId: "full-sync")
        } catch {
            loadingManager.stopLoading(taskId: "full-sync")
            throw error
        }
    }
    
    /// Enables or disables HealthKit sync
    func setHealthKitSyncEnabled(_ enabled: Bool) {
        dataSyncManager?.setHealthKitSyncEnabled(enabled)
    }
    
    /// Returns whether HealthKit sync is enabled
    var isHealthKitSyncEnabled: Bool {
        return dataSyncManager?.isHealthKitSyncEnabled ?? false
    }
    
    // MARK: - Private Methods
    
    /// Calculates daily nutrition totals from current food logs with performance monitoring
    func calculateDailyTotals() {
        let totals = PerformanceOptimizer.shared.measureSyncExecutionTime(
            operation: PerformanceMetrics.calculateTotals
        ) {
            var totals = DailyNutritionTotals()
            for foodLog in todaysFoodLogs {
                totals.add(foodLog)
            }
            return totals
        }
        
        dailyTotals = totals
    }
    
    /// Updates nutrition progress based on current totals and goals
    private func updateNutritionProgress() {
        guard let goals = nutritionGoals else {
            nutritionProgress = NutritionProgress(
                caloriesProgress: 0,
                proteinProgress: 0,
                carbohydratesProgress: 0,
                fatProgress: 0
            )
            return
        }
        
        nutritionProgress = dailyTotals.progress(against: goals)
    }
    
    /// Groups food logs by meal type for organized display
    private func groupFoodLogsByMealType() {
        // print("🍽️ FuelLogViewModel: Grouping \(todaysFoodLogs.count) food logs by meal type")
        
        foodLogsByMealType = Dictionary(grouping: todaysFoodLogs) { $0.mealType }
        
        // Ensure all meal types have entries (even if empty)
        for mealType in MealType.allCases {
            if foodLogsByMealType[mealType] == nil {
                foodLogsByMealType[mealType] = []
            }
        }
        
        // Debug logging to track UI state
        // print("🍽️ FuelLogViewModel: Grouped \(todaysFoodLogs.count) food logs by meal type:")
        // for mealType in MealType.allCases {
        //     let count = foodLogsByMealType[mealType]?.count ?? 0
        //     let items = foodLogsByMealType[mealType]?.map { $0.name }.joined(separator: ", ") ?? "none"
        //     print("🍽️ FuelLogViewModel: \(mealType.displayName): \(count) items (\(items))")
        // }
    }
    
    /// Provides haptic feedback when nutrition goals are completed
    private func provideFeedbackForGoalCompletion() async {
        guard nutritionProgress.hasCompletedGoals else { return }
        
        // Check which goals were just completed and provide feedback
        if isGoalCompleted(for: .calories) {
            AccessibilityUtils.announceGoalCompletion(for: "Calorie")
        }
        if isGoalCompleted(for: .protein) {
            AccessibilityUtils.announceGoalCompletion(for: "Protein")
        }
        if isGoalCompleted(for: .carbohydrates) {
            AccessibilityUtils.announceGoalCompletion(for: "Carbohydrate")
        }
        if isGoalCompleted(for: .fat) {
            AccessibilityUtils.announceGoalCompletion(for: "Fat")
        }
    }
    
    /// Handles errors with user-friendly messaging (deprecated - use errorHandler instead)
    private func handleError(_ error: Error, message: String) async {
        print("FuelLogViewModel Error: \(message) - \(error.localizedDescription)")
        
        if let fuelLogError = error as? FuelLogError {
            errorMessage = fuelLogError.localizedDescription
        } else {
            errorMessage = "\(message): \(error.localizedDescription)"
        }
    }
}



// MARK: - Extensions

extension FuelLogViewModel {
    
    /// Gets food logs for a specific meal type
    func foodLogs(for mealType: MealType) -> [FoodLog] {
        return foodLogsByMealType[mealType] ?? []
    }
    
    /// Gets nutrition totals for a specific meal type
    func nutritionTotals(for mealType: MealType) -> DailyNutritionTotals {
        let mealFoodLogs = foodLogs(for: mealType)
        var totals = DailyNutritionTotals()
        
        for foodLog in mealFoodLogs {
            totals.add(foodLog)
        }
        
        return totals
    }
    
    /// Checks if a specific nutrition goal has been completed
    func isGoalCompleted(for nutrient: NutrientType) -> Bool {
        switch nutrient {
        case .calories:
            return nutritionProgress.caloriesProgress >= 1.0
        case .protein:
            return nutritionProgress.proteinProgress >= 1.0
        case .carbohydrates:
            return nutritionProgress.carbohydratesProgress >= 1.0
        case .fat:
            return nutritionProgress.fatProgress >= 1.0
        }
    }
    
    /// Gets the progress percentage for a specific nutrient
    func progress(for nutrient: NutrientType) -> Double {
        switch nutrient {
        case .calories:
            return nutritionProgress.caloriesProgress
        case .protein:
            return nutritionProgress.proteinProgress
        case .carbohydrates:
            return nutritionProgress.carbohydratesProgress
        case .fat:
            return nutritionProgress.fatProgress
        }
    }
    
    /// Creates a new food log with the correct date for the selected calendar day
    private func createFoodLogForSelectedDate(from originalFoodLog: FoodLog) -> FoodLog {
        // CRITICAL FIX: Use the new date utility for consistent timestamp creation
        let targetTimestamp = Date.timestampForCalendarDay(selectedDate, withCurrentTime: true)
        
        // Create a completely new FoodLog with the corrected timestamp
        let correctedFoodLog = FoodLog(
            timestamp: targetTimestamp,
            name: originalFoodLog.name,
            calories: originalFoodLog.calories,
            protein: originalFoodLog.protein,
            carbohydrates: originalFoodLog.carbohydrates,
            fat: originalFoodLog.fat,
            mealType: originalFoodLog.mealType,
            servingSize: originalFoodLog.servingSize,
            servingUnit: originalFoodLog.servingUnit,
            barcode: originalFoodLog.barcode,
            customFoodId: originalFoodLog.customFoodId
        )
        
        // Validate the timestamp is correct
        assert(targetTimestamp.belongsToCalendarDay(selectedDate), "Food log timestamp must belong to selected calendar day")
        
        // print("🕐 FuelLogViewModel: Created food log with proper date handling")
        // print("🕐 FuelLogViewModel: Selected date: \(DateFormatter.shortDate.string(from: selectedDate))")
        // print("🕐 FuelLogViewModel: Target timestamp: \(DateFormatter.debugDateTime.string(from: targetTimestamp))")
        // print("🕐 FuelLogViewModel: Timestamp validation: \(targetTimestamp.belongsToCalendarDay(selectedDate) ? "✅ CORRECT" : "❌ INCORRECT")")
        
        // Debug logging commented out - issue was in UI meal type selection
        // print("🍽️ MEAL TYPE DEBUG: Original meal type: \(originalFoodLog.mealType.displayName) (\(originalFoodLog.mealType.rawValue))")
        // print("🍽️ MEAL TYPE DEBUG: Original raw value: \(originalFoodLog.mealTypeRawValue)")
        // print("🍽️ MEAL TYPE DEBUG: Corrected meal type: \(correctedFoodLog.mealType.displayName) (\(correctedFoodLog.mealType.rawValue))")
        // print("🍽️ MEAL TYPE DEBUG: Corrected raw value: \(correctedFoodLog.mealTypeRawValue)")
        
        return correctedFoodLog
    }
}


