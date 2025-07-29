import XCTest
import SwiftData
@testable import work

@MainActor
final class FuelLogRepositoryTests: XCTestCase {
    var repository: FuelLogRepository!
    var modelContext: ModelContext!
    var modelContainer: ModelContainer!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model container for testing
        let schema = Schema([
            FoodLog.self,
            CustomFood.self,
            NutritionGoals.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
        repository = FuelLogRepository(modelContext: modelContext)
    }
    
    override func tearDown() async throws {
        repository = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }
    
    // MARK: - FoodLog Tests
    
    func testSaveFoodLog() async throws {
        // Given
        let foodLog = FoodLog(
            name: "Test Food",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            mealType: .breakfast
        )
        
        // When
        try await repository.saveFoodLog(foodLog)
        
        // Then
        let fetchedLogs = try await repository.fetchFoodLogs(for: Date())
        XCTAssertEqual(fetchedLogs.count, 1)
        XCTAssertEqual(fetchedLogs.first?.name, "Test Food")
        XCTAssertEqual(fetchedLogs.first?.calories, 100)
    }
    
    func testSaveFoodLogWithInvalidData() async throws {
        // Given - food log with negative calories
        let invalidFoodLog = FoodLog(
            name: "Invalid Food",
            calories: -100,
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            mealType: .breakfast
        )
        
        // When & Then
        do {
            try await repository.saveFoodLog(invalidFoodLog)
            XCTFail("Expected FuelLogError.invalidNutritionData to be thrown")
        } catch FuelLogError.invalidNutritionData {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testFetchFoodLogsForDate() async throws {
        // Given
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        let todayLog = FoodLog(
            timestamp: today,
            name: "Today Food",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            mealType: .breakfast
        )
        
        let yesterdayLog = FoodLog(
            timestamp: yesterday,
            name: "Yesterday Food",
            calories: 200,
            protein: 20,
            carbohydrates: 25,
            fat: 10,
            mealType: .lunch
        )
        
        try await repository.saveFoodLog(todayLog)
        try await repository.saveFoodLog(yesterdayLog)
        
        // When
        let todayLogs = try await repository.fetchFoodLogs(for: today)
        let yesterdayLogs = try await repository.fetchFoodLogs(for: yesterday)
        
        // Then
        XCTAssertEqual(todayLogs.count, 1)
        XCTAssertEqual(todayLogs.first?.name, "Today Food")
        
        XCTAssertEqual(yesterdayLogs.count, 1)
        XCTAssertEqual(yesterdayLogs.first?.name, "Yesterday Food")
    }
    
    func testFetchFoodLogsSortedByMealTypeAndTime() async throws {
        // Given
        let baseDate = Date()
        let breakfast1 = FoodLog(
            timestamp: baseDate.addingTimeInterval(100),
            name: "Breakfast 1",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            mealType: .breakfast
        )
        
        let lunch1 = FoodLog(
            timestamp: baseDate.addingTimeInterval(200),
            name: "Lunch 1",
            calories: 200,
            protein: 20,
            carbohydrates: 25,
            fat: 10,
            mealType: .lunch
        )
        
        let breakfast2 = FoodLog(
            timestamp: baseDate.addingTimeInterval(50),
            name: "Breakfast 2",
            calories: 150,
            protein: 15,
            carbohydrates: 20,
            fat: 7,
            mealType: .breakfast
        )
        
        try await repository.saveFoodLog(lunch1)
        try await repository.saveFoodLog(breakfast1)
        try await repository.saveFoodLog(breakfast2)
        
        // When
        let logs = try await repository.fetchFoodLogs(for: baseDate)
        
        // Then
        XCTAssertEqual(logs.count, 3)
        // Should be sorted by meal type first (breakfast before lunch), then by timestamp
        XCTAssertEqual(logs[0].name, "Breakfast 2") // Earlier timestamp
        XCTAssertEqual(logs[1].name, "Breakfast 1") // Later timestamp
        XCTAssertEqual(logs[2].name, "Lunch 1")
    }
    
    func testUpdateFoodLog() async throws {
        // Given
        let foodLog = FoodLog(
            name: "Original Food",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            mealType: .breakfast
        )
        
        try await repository.saveFoodLog(foodLog)
        
        // When
        foodLog.name = "Updated Food"
        foodLog.calories = 200
        try await repository.updateFoodLog(foodLog)
        
        // Then
        let fetchedLogs = try await repository.fetchFoodLogs(for: Date())
        XCTAssertEqual(fetchedLogs.count, 1)
        XCTAssertEqual(fetchedLogs.first?.name, "Updated Food")
        XCTAssertEqual(fetchedLogs.first?.calories, 200)
    }
    
    func testDeleteFoodLog() async throws {
        // Given
        let foodLog = FoodLog(
            name: "Food to Delete",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            mealType: .breakfast
        )
        
        try await repository.saveFoodLog(foodLog)
        
        // Verify it was saved
        var fetchedLogs = try await repository.fetchFoodLogs(for: Date())
        XCTAssertEqual(fetchedLogs.count, 1)
        
        // When
        try await repository.deleteFoodLog(foodLog)
        
        // Then
        fetchedLogs = try await repository.fetchFoodLogs(for: Date())
        XCTAssertEqual(fetchedLogs.count, 0)
    }
    
    func testFetchFoodLogsByDateRange() async throws {
        // Given
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: today)!
        
        let logs = [
            FoodLog(timestamp: threeDaysAgo, name: "Three Days Ago", calories: 100, protein: 10, carbohydrates: 15, fat: 5, mealType: .breakfast),
            FoodLog(timestamp: twoDaysAgo, name: "Two Days Ago", calories: 200, protein: 20, carbohydrates: 25, fat: 10, mealType: .lunch),
            FoodLog(timestamp: yesterday, name: "Yesterday", calories: 300, protein: 30, carbohydrates: 35, fat: 15, mealType: .dinner),
            FoodLog(timestamp: today, name: "Today", calories: 400, protein: 40, carbohydrates: 45, fat: 20, mealType: .snacks)
        ]
        
        for log in logs {
            try await repository.saveFoodLog(log)
        }
        
        // When - fetch logs from two days ago to today
        let rangeResults = try await repository.fetchFoodLogsByDateRange(from: twoDaysAgo, to: today)
        
        // Then
        XCTAssertEqual(rangeResults.count, 3) // Should include twoDaysAgo, yesterday, and today
        XCTAssertEqual(rangeResults[0].name, "Two Days Ago")
        XCTAssertEqual(rangeResults[1].name, "Yesterday")
        XCTAssertEqual(rangeResults[2].name, "Today")
    }
    
    // MARK: - CustomFood Tests
    
    func testSaveCustomFood() async throws {
        // Given
        let customFood = CustomFood(
            name: "Test Custom Food",
            caloriesPerServing: 150,
            proteinPerServing: 15,
            carbohydratesPerServing: 20,
            fatPerServing: 8
        )
        
        // When
        try await repository.saveCustomFood(customFood)
        
        // Then
        let fetchedFoods = try await repository.fetchCustomFoods()
        XCTAssertEqual(fetchedFoods.count, 1)
        XCTAssertEqual(fetchedFoods.first?.name, "Test Custom Food")
        XCTAssertEqual(fetchedFoods.first?.caloriesPerServing, 150)
    }
    
    func testSaveCustomFoodWithInvalidData() async throws {
        // Given - custom food with empty name
        let invalidCustomFood = CustomFood(
            name: "",
            caloriesPerServing: 150,
            proteinPerServing: 15,
            carbohydratesPerServing: 20,
            fatPerServing: 8
        )
        
        // When & Then
        do {
            try await repository.saveCustomFood(invalidCustomFood)
            XCTFail("Expected FuelLogError.invalidNutritionData to be thrown")
        } catch FuelLogError.invalidNutritionData {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testFetchCustomFoodById() async throws {
        // Given
        let customFood = CustomFood(
            name: "Findable Food",
            caloriesPerServing: 150,
            proteinPerServing: 15,
            carbohydratesPerServing: 20,
            fatPerServing: 8
        )
        
        try await repository.saveCustomFood(customFood)
        
        // When
        let foundFood = try await repository.fetchCustomFood(by: customFood.id)
        let notFoundFood = try await repository.fetchCustomFood(by: UUID())
        
        // Then
        XCTAssertNotNil(foundFood)
        XCTAssertEqual(foundFood?.name, "Findable Food")
        XCTAssertNil(notFoundFood)
    }
    
    func testSearchCustomFoods() async throws {
        // Given
        let foods = [
            CustomFood(name: "Apple Pie", caloriesPerServing: 300, proteinPerServing: 5, carbohydratesPerServing: 50, fatPerServing: 12),
            CustomFood(name: "Apple Juice", caloriesPerServing: 100, proteinPerServing: 0, carbohydratesPerServing: 25, fatPerServing: 0),
            CustomFood(name: "Banana Bread", caloriesPerServing: 250, proteinPerServing: 8, carbohydratesPerServing: 40, fatPerServing: 10),
            CustomFood(name: "Orange Juice", caloriesPerServing: 110, proteinPerServing: 2, carbohydratesPerServing: 26, fatPerServing: 0)
        ]
        
        for food in foods {
            try await repository.saveCustomFood(food)
        }
        
        // When
        let appleResults = try await repository.searchCustomFoods(query: "apple")
        let juiceResults = try await repository.searchCustomFoods(query: "juice")
        let emptyResults = try await repository.searchCustomFoods(query: "")
        
        // Then
        XCTAssertEqual(appleResults.count, 2)
        XCTAssertTrue(appleResults.contains { $0.name == "Apple Pie" })
        XCTAssertTrue(appleResults.contains { $0.name == "Apple Juice" })
        
        XCTAssertEqual(juiceResults.count, 2)
        XCTAssertTrue(juiceResults.contains { $0.name == "Apple Juice" })
        XCTAssertTrue(juiceResults.contains { $0.name == "Orange Juice" })
        
        XCTAssertEqual(emptyResults.count, 4) // Empty query should return all
    }
    
    func testUpdateCustomFood() async throws {
        // Given
        let customFood = CustomFood(
            name: "Original Custom Food",
            caloriesPerServing: 150,
            proteinPerServing: 15,
            carbohydratesPerServing: 20,
            fatPerServing: 8
        )
        
        try await repository.saveCustomFood(customFood)
        
        // When
        customFood.name = "Updated Custom Food"
        customFood.caloriesPerServing = 200
        try await repository.updateCustomFood(customFood)
        
        // Then
        let fetchedFoods = try await repository.fetchCustomFoods()
        XCTAssertEqual(fetchedFoods.count, 1)
        XCTAssertEqual(fetchedFoods.first?.name, "Updated Custom Food")
        XCTAssertEqual(fetchedFoods.first?.caloriesPerServing, 200)
    }
    
    func testDeleteCustomFood() async throws {
        // Given
        let customFood = CustomFood(
            name: "Food to Delete",
            caloriesPerServing: 150,
            proteinPerServing: 15,
            carbohydratesPerServing: 20,
            fatPerServing: 8
        )
        
        try await repository.saveCustomFood(customFood)
        
        // Verify it was saved
        var fetchedFoods = try await repository.fetchCustomFoods()
        XCTAssertEqual(fetchedFoods.count, 1)
        
        // When
        try await repository.deleteCustomFood(customFood)
        
        // Then
        fetchedFoods = try await repository.fetchCustomFoods()
        XCTAssertEqual(fetchedFoods.count, 0)
    }
    
    // MARK: - NutritionGoals Tests
    
    func testSaveNutritionGoals() async throws {
        // Given
        let goals = NutritionGoals(
            dailyCalories: 2000,
            dailyProtein: 150,
            dailyCarbohydrates: 200,
            dailyFat: 67,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            bmr: 1600,
            tdee: 2000
        )
        
        // When
        try await repository.saveNutritionGoals(goals)
        
        // Then
        let fetchedGoals = try await repository.fetchNutritionGoals()
        XCTAssertNotNil(fetchedGoals)
        XCTAssertEqual(fetchedGoals?.dailyCalories, 2000)
        XCTAssertEqual(fetchedGoals?.dailyProtein, 150)
        XCTAssertEqual(fetchedGoals?.activityLevel, .moderatelyActive)
        XCTAssertEqual(fetchedGoals?.goal, .maintain)
    }
    
    func testSaveNutritionGoalsWithInvalidData() async throws {
        // Given - goals with negative calories
        let invalidGoals = NutritionGoals(
            dailyCalories: -2000,
            dailyProtein: 150,
            dailyCarbohydrates: 200,
            dailyFat: 67,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            bmr: 1600,
            tdee: 2000
        )
        
        // When & Then
        do {
            try await repository.saveNutritionGoals(invalidGoals)
            XCTFail("Expected FuelLogError.invalidNutritionData to be thrown")
        } catch FuelLogError.invalidNutritionData {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testFetchNutritionGoalsForUser() async throws {
        // Given
        let user1Goals = NutritionGoals(
            userId: "user1",
            dailyCalories: 2000,
            dailyProtein: 150,
            dailyCarbohydrates: 200,
            dailyFat: 67,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            bmr: 1600,
            tdee: 2000
        )
        
        let user2Goals = NutritionGoals(
            userId: "user2",
            dailyCalories: 2500,
            dailyProtein: 200,
            dailyCarbohydrates: 250,
            dailyFat: 83,
            activityLevel: .veryActive,
            goal: .bulk,
            bmr: 1800,
            tdee: 2500
        )
        
        try await repository.saveNutritionGoals(user1Goals)
        try await repository.saveNutritionGoals(user2Goals)
        
        // When
        let fetchedUser1Goals = try await repository.fetchNutritionGoals(for: "user1")
        let fetchedUser2Goals = try await repository.fetchNutritionGoals(for: "user2")
        let nonExistentUserGoals = try await repository.fetchNutritionGoals(for: "user3")
        
        // Then
        XCTAssertNotNil(fetchedUser1Goals)
        XCTAssertEqual(fetchedUser1Goals?.dailyCalories, 2000)
        XCTAssertEqual(fetchedUser1Goals?.userId, "user1")
        
        XCTAssertNotNil(fetchedUser2Goals)
        XCTAssertEqual(fetchedUser2Goals?.dailyCalories, 2500)
        XCTAssertEqual(fetchedUser2Goals?.userId, "user2")
        
        XCTAssertNil(nonExistentUserGoals)
    }
    
    func testUpdateNutritionGoals() async throws {
        // Given
        let goals = NutritionGoals(
            dailyCalories: 2000,
            dailyProtein: 150,
            dailyCarbohydrates: 200,
            dailyFat: 67,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            bmr: 1600,
            tdee: 2000
        )
        
        try await repository.saveNutritionGoals(goals)
        let originalLastUpdated = goals.lastUpdated
        
        // Wait a moment to ensure timestamp difference
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        
        // When
        goals.dailyCalories = 2200
        goals.goal = .bulk
        try await repository.updateNutritionGoals(goals)
        
        // Then
        let fetchedGoals = try await repository.fetchNutritionGoals()
        XCTAssertNotNil(fetchedGoals)
        XCTAssertEqual(fetchedGoals?.dailyCalories, 2200)
        XCTAssertEqual(fetchedGoals?.goal, .bulk)
        XCTAssertGreaterThan(fetchedGoals?.lastUpdated ?? Date.distantPast, originalLastUpdated)
    }
    
    func testDeleteNutritionGoals() async throws {
        // Given
        let goals = NutritionGoals(
            dailyCalories: 2000,
            dailyProtein: 150,
            dailyCarbohydrates: 200,
            dailyFat: 67,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            bmr: 1600,
            tdee: 2000
        )
        
        try await repository.saveNutritionGoals(goals)
        
        // Verify it was saved
        var fetchedGoals = try await repository.fetchNutritionGoals()
        XCTAssertNotNil(fetchedGoals)
        
        // When
        try await repository.deleteNutritionGoals(goals)
        
        // Then
        fetchedGoals = try await repository.fetchNutritionGoals()
        XCTAssertNil(fetchedGoals)
    }
    
    // MARK: - Validation Tests
    
    func testFoodLogValidationWithExcessiveValues() async throws {
        // Given - food log with excessively high values
        let excessiveFoodLog = FoodLog(
            name: "Excessive Food",
            calories: 15000, // Over the 10000 limit
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            mealType: .breakfast
        )
        
        // When & Then
        do {
            try await repository.saveFoodLog(excessiveFoodLog)
            XCTFail("Expected FuelLogError.invalidNutritionData to be thrown")
        } catch FuelLogError.invalidNutritionData {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testNutritionGoalsValidationWithUnreasonableValues() async throws {
        // Given - goals with unreasonably low BMR
        let invalidGoals = NutritionGoals(
            dailyCalories: 2000,
            dailyProtein: 150,
            dailyCarbohydrates: 200,
            dailyFat: 67,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            bmr: 500, // Below the 800 minimum
            tdee: 2000
        )
        
        // When & Then
        do {
            try await repository.saveNutritionGoals(invalidGoals)
            XCTFail("Expected FuelLogError.invalidNutritionData to be thrown")
        } catch FuelLogError.invalidNutritionData {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}