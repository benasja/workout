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
    
    /// Currently selected date for viewing food logs
    @Published var selectedDate: Date = Date() {
        didSet {
            if !Calendar.current.isDate(selectedDate, inSameDayAs: oldValue) {
                Task {
                    await loadFoodLogs(for: selectedDate)
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
    
    /// Whether the selected date is today
    var isSelectedDateToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    /// Whether nutrition goals are available
    var hasNutritionGoals: Bool {
        let hasGoals = nutritionGoals != nil
        print("🔍 FuelLogViewModel: hasNutritionGoals called - nutritionGoals is \(nutritionGoals != nil ? "not nil" : "nil"), returning \(hasGoals)")
        return hasGoals
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
            
            print("🔍 FuelLogViewModel: Initial data loaded successfully")
            
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
            nutritionGoals = try await _repository.fetchNutritionGoals()
            print("🔍 FuelLogViewModel: Loaded nutrition goals: \(nutritionGoals != nil ? "Found" : "Not found")")
            if let goals = nutritionGoals {
                print("🔍 FuelLogViewModel: Goals - Calories: \(goals.dailyCalories), Protein: \(goals.dailyProtein)")
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
        
        let foodLogs = await PerformanceOptimizer.shared.measureExecutionTime(
            operation: PerformanceMetrics.loadFoodLogs
        ) {
            do {
                return try await _repository.fetchFoodLogs(for: date)
            } catch {
                errorHandler.handleError(
                    error,
                    context: "Loading food logs for \(DateFormatter.shortDate.string(from: date))"
                ) { [weak self] in
                    await self?.loadFoodLogs(for: date)
                }
                return []
            }
        }
        
        // Update published properties
        todaysFoodLogs = foodLogs
        
        // Perform calculations in background
        await updateUIWithFoodLogs(foodLogs)
        
        isLoading = false
    }
    
    /// Updates UI with food logs using background processing
    private func updateUIWithFoodLogs(_ foodLogs: [FoodLog]) async {
        // Group food logs by meal type
        groupFoodLogsByMealType()
        
        // Calculate daily totals in background
        dailyTotals = await PerformanceOptimizer.shared.calculateNutritionTotals(from: foodLogs)
        
        // Update nutrition progress
        updateNutritionProgress()
    }
    
    /// Logs a new food entry with optimistic UI updates
    func logFood(_ foodLog: FoodLog) async {
        isSavingFood = true
        loadingManager.startLoading(
            taskId: "save-food",
            message: "Saving \(foodLog.name)..."
        )
        
        // Optimistic update - add to UI immediately
        let originalFoodLogs = todaysFoodLogs
        let originalDailyTotals = dailyTotals
        let originalProgress = nutritionProgress
        let originalGroupedLogs = foodLogsByMealType
        
        // Apply optimistic update
        todaysFoodLogs.append(foodLog)
        groupFoodLogsByMealType()
        calculateDailyTotals()
        updateNutritionProgress()
        
        do {
            // Save to repository
            try await _repository.saveFoodLog(foodLog)
            
            // Write to HealthKit if available and authorized
            if let healthKitManager = healthKitManager {
                do {
                    try await healthKitManager.writeNutritionData(foodLog)
                } catch {
                    // HealthKit write failure shouldn't prevent food logging
                    print("HealthKit write failed: \(error.localizedDescription)")
                }
            }
            
            // Sync to HealthKit via data sync manager if available
            if let dataSyncManager = dataSyncManager {
                do {
                    try await dataSyncManager.syncFoodLogToHealthKit(foodLog)
                } catch {
                    // Sync failure shouldn't prevent food logging
                    print("Data sync failed: \(error.localizedDescription)")
                }
            }
            
            // Provide haptic feedback for successful logging
            await provideFeedbackForGoalCompletion()
            
        } catch {
            // Revert optimistic update on failure
            todaysFoodLogs = originalFoodLogs
            dailyTotals = originalDailyTotals
            nutritionProgress = originalProgress
            foodLogsByMealType = originalGroupedLogs
            
            errorHandler.handleError(
                error,
                context: "Logging food: \(foodLog.name)"
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
    
    /// Deletes a food log entry with optimistic UI updates
    func deleteFood(_ foodLog: FoodLog) async {
        isDeletingFood = true
        loadingManager.startLoading(
            taskId: "delete-food",
            message: "Deleting \(foodLog.name)..."
        )
        
        // Optimistic update - remove from UI immediately
        let originalFoodLogs = todaysFoodLogs
        let originalDailyTotals = dailyTotals
        let originalProgress = nutritionProgress
        let originalGroupedLogs = foodLogsByMealType
        
        // Apply optimistic update
        todaysFoodLogs.removeAll { $0.id == foodLog.id }
        groupFoodLogsByMealType()
        calculateDailyTotals()
        updateNutritionProgress()
        
        do {
            try await _repository.deleteFoodLog(foodLog)
            
        } catch {
            // Revert optimistic update on failure
            todaysFoodLogs = originalFoodLogs
            dailyTotals = originalDailyTotals
            nutritionProgress = originalProgress
            foodLogsByMealType = originalGroupedLogs
            
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
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }
    
    /// Navigates to the next day
    func navigateToNextDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }
    
    /// Navigates to today
    func navigateToToday() {
        selectedDate = Date()
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
        foodLogsByMealType = Dictionary(grouping: todaysFoodLogs) { $0.mealType }
        
        // Ensure all meal types have entries (even if empty)
        for mealType in MealType.allCases {
            if foodLogsByMealType[mealType] == nil {
                foodLogsByMealType[mealType] = []
            }
        }
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

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
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
}

// MARK: - Supporting Types

/// Enum for different nutrient types
enum NutrientType: CaseIterable {
    case calories
    case protein
    case carbohydrates
    case fat
    
    var displayName: String {
        switch self {
        case .calories:
            return "Calories"
        case .protein:
            return "Protein"
        case .carbohydrates:
            return "Carbs"
        case .fat:
            return "Fat"
        }
    }
    
    var unit: String {
        switch self {
        case .calories:
            return "kcal"
        case .protein, .carbohydrates, .fat:
            return "g"
        }
    }
}
