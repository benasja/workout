import Foundation
import SwiftData

// MARK: - FuelLogRepository Protocol

/// Protocol defining data access operations for Fuel Log functionality
protocol FuelLogRepositoryProtocol {
    // MARK: - FoodLog Operations
    nonisolated func fetchFoodLogs(for date: Date) async throws -> [FoodLog]
    nonisolated func fetchFoodLogs(for date: Date, limit: Int, offset: Int) async throws -> [FoodLog]
    nonisolated func saveFoodLog(_ foodLog: FoodLog) async throws
    nonisolated func updateFoodLog(_ foodLog: FoodLog) async throws
    nonisolated func deleteFoodLog(_ foodLog: FoodLog) async throws
    nonisolated func fetchFoodLogsByDateRange(from startDate: Date, to endDate: Date) async throws -> [FoodLog]
    nonisolated func fetchFoodLogsByDateRange(from startDate: Date, to endDate: Date, limit: Int) async throws -> [FoodLog]
    
    // MARK: - CustomFood Operations
    nonisolated func fetchCustomFoods() async throws -> [CustomFood]
    nonisolated func fetchCustomFoods(limit: Int, offset: Int, searchQuery: String?) async throws -> [CustomFood]
    nonisolated func fetchCustomFood(by id: UUID) async throws -> CustomFood?
    nonisolated func saveCustomFood(_ customFood: CustomFood) async throws
    nonisolated func updateCustomFood(_ customFood: CustomFood) async throws
    nonisolated func deleteCustomFood(_ customFood: CustomFood) async throws
    nonisolated func searchCustomFoods(query: String) async throws -> [CustomFood]
    
    // MARK: - NutritionGoals Operations
    nonisolated func fetchNutritionGoals() async throws -> NutritionGoals?
    nonisolated func fetchNutritionGoals(for userId: String) async throws -> NutritionGoals?
    nonisolated func saveNutritionGoals(_ goals: NutritionGoals) async throws
    nonisolated func updateNutritionGoals(_ goals: NutritionGoals) async throws
    nonisolated func deleteNutritionGoals(_ goals: NutritionGoals) async throws
}

// MARK: - FuelLogRepository Implementation

/// Concrete implementation of FuelLogRepository using SwiftData
final class FuelLogRepository: FuelLogRepositoryProtocol {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - FoodLog Operations
    
    /// Fetches all food logs for a specific date, sorted by meal type and timestamp
    nonisolated func fetchFoodLogs(for date: Date) async throws -> [FoodLog] {
        // CRITICAL FIX: Use consistent date range queries with proper predicate syntax
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<FoodLog> { foodLog in
            foodLog.timestamp >= startOfDay && foodLog.timestamp < endOfDay
        }
        
        let descriptor = FetchDescriptor<FoodLog>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.mealTypeRawValue),
                SortDescriptor(\.timestamp)
            ]
        )
        
        return try await MainActor.run {
            do {
                let foodLogs = try modelContext.fetch(descriptor)
                
                // print("📊 FuelLogRepository: Fetched \(foodLogs.count) food logs for \(DateFormatter.shortDate.string(from: date))")
                // print("📊 FuelLogRepository: Query range - Start: \(DateFormatter.debugDateTime.string(from: startOfDay)), End: \(DateFormatter.debugDateTime.string(from: endOfDay))")
                
                // Debug: Verify each food log belongs to the correct calendar day using the new utility
                // for (index, foodLog) in foodLogs.enumerated() {
                //     let belongsToDay = foodLog.timestamp.belongsToCalendarDay(date)
                //     print("📊 FuelLogRepository: Food \(index + 1): '\(foodLog.name)' - timestamp: \(DateFormatter.debugDateTime.string(from: foodLog.timestamp)), belongs to day: \(belongsToDay ? "✅" : "❌")")
                //     
                //     // Additional validation to catch any data inconsistencies
                //     if !belongsToDay {
                //         print("⚠️ FuelLogRepository: WARNING - Food log timestamp doesn't belong to query date!")
                //         print("⚠️ FuelLogRepository: Query date: \(DateFormatter.shortDate.string(from: date))")
                //         print("⚠️ FuelLogRepository: Food timestamp: \(DateFormatter.debugDateTime.string(from: foodLog.timestamp))")
                //     }
                // }
                
                return foodLogs
            } catch {
                print("❌ FuelLogRepository: Error fetching food logs for \(DateFormatter.shortDate.string(from: date)): \(error)")
                throw FuelLogError.persistenceError(error)
            }
        }
    }
    
    /// Fetches food logs with pagination for lazy loading
    nonisolated func fetchFoodLogs(
        for date: Date,
        limit: Int,
        offset: Int = 0
    ) async throws -> [FoodLog] {
        let descriptor = await PerformanceOptimizer.shared.createOptimizedFoodLogDescriptor(
            for: date,
            limit: limit,
            offset: offset
        )
        
        return try await MainActor.run {
            do {
                let foodLogs = try modelContext.fetch(descriptor)
                return foodLogs
            } catch {
                throw FuelLogError.persistenceError(error)
            }
        }
    }
    
    /// Saves a new food log entry
    nonisolated func saveFoodLog(_ foodLog: FoodLog) async throws {
        // Validate food log before saving
        try validateFoodLog(foodLog)
        
        // print("💾 FuelLogRepository: Saving food log '\(foodLog.name)' with timestamp \(foodLog.timestamp)")
        // print("💾 FuelLogRepository: Food will be saved to date: \(DateFormatter.shortDate.string(from: foodLog.timestamp))")
        
        try await MainActor.run {
            do {
                modelContext.insert(foodLog)
                try modelContext.save()
                // print("✅ FuelLogRepository: Successfully saved food log '\(foodLog.name)' to \(DateFormatter.shortDate.string(from: foodLog.timestamp))")
            } catch {
                print("❌ FuelLogRepository: Failed to save food log '\(foodLog.name)': \(error)")
                throw FuelLogError.persistenceError(error)
            }
        }
    }
    
    /// Updates an existing food log entry
    nonisolated func updateFoodLog(_ foodLog: FoodLog) async throws {
        // Validate food log before updating
        try validateFoodLog(foodLog)
        
        try await MainActor.run {
            do {
                try modelContext.save()
            } catch {
                throw FuelLogError.persistenceError(error)
            }
        }
    }
    
    /// Deletes a food log entry
    nonisolated func deleteFoodLog(_ foodLog: FoodLog) async throws {
        // print("🗑️ FuelLogRepository: Deleting food log '\(foodLog.name)' from date \(DateFormatter.shortDate.string(from: foodLog.timestamp))")
        
        try await MainActor.run {
            do {
                modelContext.delete(foodLog)
                try modelContext.save()
                // print("✅ FuelLogRepository: Successfully deleted food log '\(foodLog.name)' from database")
            } catch {
                print("❌ FuelLogRepository: Failed to delete food log '\(foodLog.name)': \(error)")
                throw FuelLogError.persistenceError(error)
            }
        }
    }
    
    /// Fetches food logs within a date range
    nonisolated func fetchFoodLogsByDateRange(from startDate: Date, to endDate: Date) async throws -> [FoodLog] {
        let descriptor = await PerformanceOptimizer.shared.createDateRangeFoodLogDescriptor(
            from: startDate,
            to: endDate
        )
        
        return try await MainActor.run {
            do {
                return try modelContext.fetch(descriptor)
            } catch {
                throw FuelLogError.persistenceError(error)
            }
        }
    }
    
    /// Fetches food logs within a date range with limit for performance
    nonisolated func fetchFoodLogsByDateRange(
        from startDate: Date,
        to endDate: Date,
        limit: Int
    ) async throws -> [FoodLog] {
        let descriptor = await PerformanceOptimizer.shared.createDateRangeFoodLogDescriptor(
            from: startDate,
            to: endDate,
            limit: limit
        )
        
        return try await MainActor.run {
            do {
                return try modelContext.fetch(descriptor)
            } catch {
                throw FuelLogError.persistenceError(error)
            }
        }
    }
    
    // MARK: - CustomFood Operations
    
    /// Fetches all custom foods, sorted by name and creation date
    nonisolated func fetchCustomFoods() async throws -> [CustomFood] {
        let descriptor = await PerformanceOptimizer.shared.createOptimizedCustomFoodDescriptor()
        
        return try await MainActor.run {
            do {
                return try modelContext.fetch(descriptor)
            } catch {
                throw FuelLogError.persistenceError(error)
            }
        }
    }
    
    /// Fetches custom foods with pagination for lazy loading
    nonisolated func fetchCustomFoods(
        limit: Int,
        offset: Int = 0,
        searchQuery: String? = nil
    ) async throws -> [CustomFood] {
        let descriptor = await PerformanceOptimizer.shared.createOptimizedCustomFoodDescriptor(
            searchQuery: searchQuery,
            limit: limit,
            offset: offset
        )
        
        return try await MainActor.run {
            do {
                return try modelContext.fetch(descriptor)
            } catch {
                throw FuelLogError.persistenceError(error)
            }
        }
    }
    
    /// Fetches a specific custom food by ID
    nonisolated func fetchCustomFood(by id: UUID) async throws -> CustomFood? {
        let predicate = #Predicate<CustomFood> { food in
            food.id == id
        }
        
        let descriptor = FetchDescriptor<CustomFood>(predicate: predicate)
        
        return try await MainActor.run {
            do {
                let foods = try modelContext.fetch(descriptor)
                return foods.first
            } catch {
                throw FuelLogError.persistenceError(error)
            }
        }
    }
    
    /// Saves a new custom food
    nonisolated func saveCustomFood(_ customFood: CustomFood) async throws {
        // Validate custom food before saving
        try validateCustomFood(customFood)
        
        try await MainActor.run {
            do {
                modelContext.insert(customFood)
                try modelContext.save()
            } catch {
                throw FuelLogError.persistenceError(error)
            }
        }
    }
    
    /// Updates an existing custom food
    nonisolated func updateCustomFood(_ customFood: CustomFood) async throws {
        // Validate custom food before updating
        try validateCustomFood(customFood)
        
        try await MainActor.run {
            do {
                try modelContext.save()
            } catch {
                throw FuelLogError.persistenceError(error)
            }
        }
    }
    
    /// Deletes a custom food
    nonisolated func deleteCustomFood(_ customFood: CustomFood) async throws {
        try await MainActor.run {
            do {
                modelContext.delete(customFood)
                try modelContext.save()
            } catch {
                throw FuelLogError.persistenceError(error)
            }
        }
    }
    
    /// Searches custom foods by name (case-insensitive)
    nonisolated func searchCustomFoods(query: String) async throws -> [CustomFood] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !trimmedQuery.isEmpty else {
            return try await fetchCustomFoods()
        }
        
        let predicate = #Predicate<CustomFood> { food in
            food.name.localizedStandardContains(trimmedQuery)
        }
        
        let descriptor = FetchDescriptor<CustomFood>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.name),
                SortDescriptor(\.createdDate, order: .reverse)
            ]
        )
        
        return try await MainActor.run {
            do {
                return try modelContext.fetch(descriptor)
            } catch {
                throw FuelLogError.persistenceError(error)
            }
        }
    }
    
    // MARK: - NutritionGoals Operations
    
    /// Fetches the most recent nutrition goals
    nonisolated func fetchNutritionGoals() async throws -> NutritionGoals? {
        let descriptor = FetchDescriptor<NutritionGoals>(
            sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
        )
        
        return try await MainActor.run {
            do {
                let goals = try modelContext.fetch(descriptor)
                return goals.first
            } catch {
                print("❌ FuelLogRepository: Error fetching nutrition goals: \(error)")
                throw FuelLogError.persistenceError(error)
            }
        }
    }
    
    /// Fetches nutrition goals for a specific user
    nonisolated func fetchNutritionGoals(for userId: String) async throws -> NutritionGoals? {
        let predicate = #Predicate<NutritionGoals> { goals in
            goals.userId == userId
        }
        
        let descriptor = FetchDescriptor<NutritionGoals>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
        )
        
        return try await MainActor.run {
            do {
                let goals = try modelContext.fetch(descriptor)
                return goals.first
            } catch {
                throw FuelLogError.persistenceError(error)
            }
        }
    }
    
    /// Saves new nutrition goals
    nonisolated func saveNutritionGoals(_ goals: NutritionGoals) async throws {
        // Validate nutrition goals before saving
        try validateNutritionGoals(goals)
        
        try await MainActor.run {
            do {
                modelContext.insert(goals)
                try modelContext.save()
            } catch {
                throw FuelLogError.persistenceError(error)
            }
        }
    }
    
    /// Updates existing nutrition goals
    nonisolated func updateNutritionGoals(_ goals: NutritionGoals) async throws {
        // Validate nutrition goals before updating
        try validateNutritionGoals(goals)
        
        try await MainActor.run {
            // Update the lastUpdated timestamp
            goals.lastUpdated = Date()
            
            do {
                try modelContext.save()
            } catch {
                throw FuelLogError.persistenceError(error)
            }
        }
    }
    
    /// Deletes nutrition goals
    nonisolated func deleteNutritionGoals(_ goals: NutritionGoals) async throws {
        try await MainActor.run {
            do {
                modelContext.delete(goals)
                try modelContext.save()
            } catch {
                throw FuelLogError.persistenceError(error)
            }
        }
    }
    
    // MARK: - Private Validation Methods
    
    /// Validates a FoodLog before persistence operations
    private func validateFoodLog(_ foodLog: FoodLog) throws {
        // Check for valid name
        guard !foodLog.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FuelLogError.invalidNutritionData
        }
        
        // Check for non-negative nutritional values
        guard foodLog.calories >= 0,
              foodLog.protein >= 0,
              foodLog.carbohydrates >= 0,
              foodLog.fat >= 0,
              foodLog.servingSize > 0 else {
            throw FuelLogError.invalidNutritionData
        }
        
        // Check for reasonable nutritional values (not excessively high)
        guard foodLog.calories <= 10000,
              foodLog.protein <= 1000,
              foodLog.carbohydrates <= 1000,
              foodLog.fat <= 1000 else {
            throw FuelLogError.invalidNutritionData
        }
        
        // Validate macro consistency if calories are significant
        if foodLog.calories > 10 && !foodLog.hasValidMacros {
            throw FuelLogError.invalidNutritionData
        }
    }
    
    /// Validates a CustomFood before persistence operations
    private func validateCustomFood(_ customFood: CustomFood) throws {
        // Use the model's built-in validation
        guard customFood.isValid else {
            throw FuelLogError.invalidNutritionData
        }
        
        // Additional validation for reasonable limits
        guard customFood.caloriesPerServing <= 10000,
              customFood.proteinPerServing <= 1000,
              customFood.carbohydratesPerServing <= 1000,
              customFood.fatPerServing <= 1000 else {
            throw FuelLogError.invalidNutritionData
        }
    }
    
    /// Validates NutritionGoals before persistence operations
    private func validateNutritionGoals(_ goals: NutritionGoals) throws {
        // Check for positive values
        guard goals.dailyCalories > 0,
              goals.dailyProtein >= 0,
              goals.dailyCarbohydrates >= 0,
              goals.dailyFat >= 0,
              goals.bmr > 0,
              goals.tdee > 0 else {
            throw FuelLogError.invalidNutritionData
        }
        
        // Check for reasonable ranges
        guard goals.dailyCalories >= 800 && goals.dailyCalories <= 8000,
              goals.bmr >= 800 && goals.bmr <= 5000,
              goals.tdee >= 1000 && goals.tdee <= 8000 else {
            throw FuelLogError.invalidNutritionData
        }
        
        // Validate macro consistency
        guard goals.hasValidMacros else {
            throw FuelLogError.invalidNutritionData
        }
        
        // Validate user ID
        guard !goals.userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FuelLogError.invalidUserData
        }
    }
}

