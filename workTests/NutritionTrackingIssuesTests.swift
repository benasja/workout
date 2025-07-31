import XCTest
import SwiftData
@testable import work

final class NutritionTrackingIssuesTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var repository: FuelLogRepository!
    var viewModel: FuelLogViewModel!
    
    override func setUpWithError() throws {
        modelContainer = try ModelContainer(for: FoodLog.self, CustomFood.self, NutritionGoals.self)
        modelContext = modelContainer.mainContext
        repository = FuelLogRepository(modelContext: modelContext)
        viewModel = FuelLogViewModel(repository: repository)
    }
    
    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
        repository = nil
        viewModel = nil
    }
    
    // MARK: - Date Issue Tests
    
    func testFoodLogDateAssignment() async throws {
        // Test that food logs are assigned to the correct date
        let today = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: today)
        
        // Create food logs for today
        let apple = FoodLog(
            timestamp: today,
            name: "Apple",
            calories: 95,
            protein: 0.5,
            carbohydrates: 25,
            fat: 0.3,
            mealType: .snacks
        )
        
        let blueberries = FoodLog(
            timestamp: today,
            name: "Blueberries",
            calories: 85,
            protein: 1.1,
            carbohydrates: 21,
            fat: 0.5,
            mealType: .snacks
        )
        
        try await repository.saveFoodLog(apple)
        try await repository.saveFoodLog(blueberries)
        
        // Fetch food logs for today
        let todaysLogs = try await repository.fetchFoodLogs(for: today)
        
        XCTAssertEqual(todaysLogs.count, 2, "Should have 2 food logs for today")
        
        // Verify all logs are from today
        for log in todaysLogs {
            let logDate = calendar.startOfDay(for: log.timestamp)
            XCTAssertEqual(logDate, startOfToday, "Food log should be from today")
        }
    }
    
    func testDateNavigationAndFoodLogs() async throws {
        // Test that food logs appear on the correct date when navigating
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        // Create food logs for yesterday
        let yesterdayApple = FoodLog(
            timestamp: yesterday,
            name: "Apple (Yesterday)",
            calories: 95,
            protein: 0.5,
            carbohydrates: 25,
            fat: 0.3,
            mealType: .snacks
        )
        
        // Create food logs for today
        let todayApple = FoodLog(
            timestamp: today,
            name: "Apple (Today)",
            calories: 95,
            protein: 0.5,
            carbohydrates: 25,
            fat: 0.3,
            mealType: .snacks
        )
        
        try await repository.saveFoodLog(yesterdayApple)
        try await repository.saveFoodLog(todayApple)
        
        // Test fetching for yesterday
        let yesterdayLogs = try await repository.fetchFoodLogs(for: yesterday)
        XCTAssertEqual(yesterdayLogs.count, 1, "Should have 1 food log for yesterday")
        XCTAssertEqual(yesterdayLogs.first?.name, "Apple (Yesterday)")
        
        // Test fetching for today
        let todayLogs = try await repository.fetchFoodLogs(for: today)
        XCTAssertEqual(todayLogs.count, 1, "Should have 1 food log for today")
        XCTAssertEqual(todayLogs.first?.name, "Apple (Today)")
    }
    
    // MARK: - Macronutrient Calculation Tests
    
    func testMacronutrientCalculations() async throws {
        // Test that macronutrient calculations are accurate
        let apple = FoodLog(
            timestamp: Date(),
            name: "Apple",
            calories: 95,
            protein: 0.5,
            carbohydrates: 25,
            fat: 0.3,
            mealType: .snacks
        )
        
        let blueberries = FoodLog(
            timestamp: Date(),
            name: "Blueberries",
            calories: 85,
            protein: 1.1,
            carbohydrates: 21,
            fat: 0.5,
            mealType: .snacks
        )
        
        // Calculate expected totals
        let expectedProtein = 0.5 + 1.1 // 1.6g
        let expectedCarbs = 25 + 21 // 46g
        let expectedFat = 0.3 + 0.5 // 0.8g
        let expectedCalories = 95 + 85 // 180 kcal
        
        // Create daily totals and add foods
        var dailyTotals = DailyNutritionTotals()
        dailyTotals.add(apple)
        dailyTotals.add(blueberries)
        
        // Verify calculations
        XCTAssertEqual(dailyTotals.totalProtein, expectedProtein, accuracy: 0.01, "Protein calculation should be accurate")
        XCTAssertEqual(dailyTotals.totalCarbohydrates, expectedCarbs, accuracy: 0.01, "Carbohydrates calculation should be accurate")
        XCTAssertEqual(dailyTotals.totalFat, expectedFat, accuracy: 0.01, "Fat calculation should be accurate")
        XCTAssertEqual(dailyTotals.totalCalories, expectedCalories, accuracy: 0.01, "Calories calculation should be accurate")
    }
    
    func testMacronutrientDisplayRounding() async throws {
        // Test that macronutrient display values are properly rounded
        let apple = FoodLog(
            timestamp: Date(),
            name: "Apple",
            calories: 95,
            protein: 0.5,
            carbohydrates: 25,
            fat: 0.3,
            mealType: .snacks
        )
        
        let blueberries = FoodLog(
            timestamp: Date(),
            name: "Blueberries",
            calories: 85,
            protein: 1.1,
            carbohydrates: 21,
            fat: 0.5,
            mealType: .snacks
        )
        
        // Test individual food log display values
        XCTAssertEqual(Int(apple.protein), 0, "Apple protein should display as 0g")
        XCTAssertEqual(Int(apple.carbohydrates), 25, "Apple carbs should display as 25g")
        XCTAssertEqual(Int(apple.fat), 0, "Apple fat should display as 0g")
        
        XCTAssertEqual(Int(blueberries.protein), 1, "Blueberries protein should display as 1g")
        XCTAssertEqual(Int(blueberries.carbohydrates), 21, "Blueberries carbs should display as 21g")
        XCTAssertEqual(Int(blueberries.fat), 0, "Blueberries fat should display as 0g")
        
        // Test total calculations
        var dailyTotals = DailyNutritionTotals()
        dailyTotals.add(apple)
        dailyTotals.add(blueberries)
        
        XCTAssertEqual(Int(dailyTotals.totalProtein), 1, "Total protein should display as 1g")
        XCTAssertEqual(Int(dailyTotals.totalCarbohydrates), 46, "Total carbs should display as 46g")
        XCTAssertEqual(Int(dailyTotals.totalFat), 0, "Total fat should display as 0g")
    }
    
    // MARK: - Nutrition Goals Visibility Tests
    
    func testNutritionGoalsVisibility() async throws {
        // Test that nutrition goals onboarding card disappears after goals are set
        
        // Initially, no goals should be set
        XCTAssertNil(viewModel.nutritionGoals, "Initially no nutrition goals should be set")
        XCTAssertFalse(viewModel.hasNutritionGoals, "hasNutritionGoals should be false initially")
        
        // Create and save nutrition goals
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
        
        // Load goals in view model
        await viewModel.loadNutritionGoals()
        
        // Now goals should be available
        XCTAssertNotNil(viewModel.nutritionGoals, "Nutrition goals should be loaded")
        XCTAssertTrue(viewModel.hasNutritionGoals, "hasNutritionGoals should be true after setting goals")
    }
    
    // MARK: - Food Log Persistence Tests
    
    func testFoodLogPersistence() async throws {
        // Test that food logs don't disappear after adding
        let today = Date()
        
        // Add first food
        let apple = FoodLog(
            timestamp: today,
            name: "Apple",
            calories: 95,
            protein: 0.5,
            carbohydrates: 25,
            fat: 0.3,
            mealType: .snacks
        )
        
        try await repository.saveFoodLog(apple)
        
        // Verify first food is saved
        var todaysLogs = try await repository.fetchFoodLogs(for: today)
        XCTAssertEqual(todaysLogs.count, 1, "Should have 1 food log after adding apple")
        
        // Add second food
        let blueberries = FoodLog(
            timestamp: today,
            name: "Blueberries",
            calories: 85,
            protein: 1.1,
            carbohydrates: 21,
            fat: 0.5,
            mealType: .snacks
        )
        
        try await repository.saveFoodLog(blueberries)
        
        // Verify both foods are still there
        todaysLogs = try await repository.fetchFoodLogs(for: today)
        XCTAssertEqual(todaysLogs.count, 2, "Should have 2 food logs after adding blueberries")
        
        // Verify specific foods are present
        let foodNames = todaysLogs.map { $0.name }.sorted()
        XCTAssertEqual(foodNames, ["Apple", "Blueberries"], "Should have both Apple and Blueberries")
    }
    
    // MARK: - Performance Tests
    
    func testFoodLogLoadingPerformance() async throws {
        // Test that food log loading is fast and responsive
        let today = Date()
        
        // Create multiple food logs
        for i in 1...10 {
            let food = FoodLog(
                timestamp: today,
                name: "Food \(i)",
                calories: Double(i * 10),
                protein: Double(i),
                carbohydrates: Double(i * 2),
                fat: Double(i * 0.5),
                mealType: .snacks
            )
            try await repository.saveFoodLog(food)
        }
        
        // Measure loading time
        let startTime = CFAbsoluteTimeGetCurrent()
        let logs = try await repository.fetchFoodLogs(for: today)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let loadingTime = endTime - startTime
        
        XCTAssertEqual(logs.count, 10, "Should load all 10 food logs")
        XCTAssertLessThan(loadingTime, 0.1, "Food log loading should be fast (< 100ms)")
    }
} 