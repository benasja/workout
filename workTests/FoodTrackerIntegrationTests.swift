import XCTest
import SwiftData
@testable import work

final class FoodTrackerIntegrationTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var repository: FuelLogRepository!
    
    override func setUpWithError() throws {
        modelContainer = try ModelContainer(for: FoodLog.self, CustomFood.self, NutritionGoals.self)
        modelContext = modelContainer.mainContext
        repository = FuelLogRepository(modelContext: modelContext)
    }
    
    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
        repository = nil
    }
    
    // MARK: - Goals Dashboard Tests
    
    func testNutritionGoalsDashboard() async throws {
        // Create nutrition goals
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
        
        // Verify goals are saved
        let savedGoals = try await repository.fetchNutritionGoals()
        XCTAssertNotNil(savedGoals)
        XCTAssertEqual(savedGoals?.dailyCalories, 2000)
        XCTAssertEqual(savedGoals?.dailyProtein, 150)
        XCTAssertEqual(savedGoals?.dailyCarbohydrates, 200)
        XCTAssertEqual(savedGoals?.dailyFat, 67)
    }
    
    // MARK: - Personal Food Library Tests
    
    func testCreateIndividualFood() async throws {
        // Create a simple food item
        let food = CustomFood(
            name: "Chicken Breast",
            caloriesPerServing: 165,
            proteinPerServing: 31,
            carbohydratesPerServing: 0,
            fatPerServing: 3.6,
            servingSize: 100,
            servingUnit: "g"
        )
        
        try await repository.saveCustomFood(food)
        
        // Verify food is saved
        let savedFoods = try await repository.fetchCustomFoods()
        XCTAssertEqual(savedFoods.count, 1)
        XCTAssertEqual(savedFoods.first?.name, "Chicken Breast")
        XCTAssertEqual(savedFoods.first?.caloriesPerServing, 165)
        XCTAssertFalse(savedFoods.first?.isComposite ?? true)
    }
    
    func testCreateCompositeMeal() async throws {
        // First create individual foods
        let chicken = CustomFood(
            name: "Chicken Breast",
            caloriesPerServing: 165,
            proteinPerServing: 31,
            carbohydratesPerServing: 0,
            fatPerServing: 3.6,
            servingSize: 100,
            servingUnit: "g"
        )
        
        let rice = CustomFood(
            name: "Basmati Rice",
            caloriesPerServing: 130,
            proteinPerServing: 2.7,
            carbohydratesPerServing: 28,
            fatPerServing: 0.3,
            servingSize: 100,
            servingUnit: "g"
        )
        
        try await repository.saveCustomFood(chicken)
        try await repository.saveCustomFood(rice)
        
        // Create ingredients for the meal
        let chickenIngredient = CustomFoodIngredient(
            name: "Chicken Breast",
            quantity: 200,
            unit: "g",
            calories: 330,
            protein: 62,
            carbohydrates: 0,
            fat: 7.2
        )
        
        let riceIngredient = CustomFoodIngredient(
            name: "Basmati Rice",
            quantity: 100,
            unit: "g",
            calories: 130,
            protein: 2.7,
            carbohydrates: 28,
            fat: 0.3
        )
        
        // Create composite meal
        let meal = CustomFood(
            name: "Chicken & Rice Bowl",
            caloriesPerServing: 460,
            proteinPerServing: 64.7,
            carbohydratesPerServing: 28,
            fatPerServing: 7.5,
            servingSize: 1,
            servingUnit: "bowl",
            isComposite: true,
            ingredients: [chickenIngredient, riceIngredient]
        )
        
        try await repository.saveCustomFood(meal)
        
        // Verify meal is saved correctly
        let savedFoods = try await repository.fetchCustomFoods()
        let savedMeal = savedFoods.first { $0.name == "Chicken & Rice Bowl" }
        
        XCTAssertNotNil(savedMeal)
        XCTAssertTrue(savedMeal?.isComposite ?? false)
        XCTAssertEqual(savedMeal?.caloriesPerServing, 460)
        XCTAssertEqual(savedMeal?.proteinPerServing, 64.7)
        XCTAssertEqual(savedMeal?.ingredients.count, 2)
    }
    
    // MARK: - Daily Logging Tests
    
    func testDailyFoodLogging() async throws {
        let today = Date()
        
        // Create a food item
        let food = CustomFood(
            name: "Apple",
            caloriesPerServing: 95,
            proteinPerServing: 0.5,
            carbohydratesPerServing: 25,
            fatPerServing: 0.3,
            servingSize: 1,
            servingUnit: "medium apple"
        )
        
        try await repository.saveCustomFood(food)
        
        // Log the food for today
        let foodLog = FoodLog(
            timestamp: today,
            name: "Apple",
            calories: 95,
            protein: 0.5,
            carbohydrates: 25,
            fat: 0.3,
            mealType: .snacks,
            servingSize: 1,
            servingUnit: "medium apple",
            customFoodId: food.id
        )
        
        try await repository.saveFoodLog(foodLog)
        
        // Verify food is logged for today
        let todaysLogs = try await repository.fetchFoodLogs(for: today)
        XCTAssertEqual(todaysLogs.count, 1)
        XCTAssertEqual(todaysLogs.first?.name, "Apple")
        XCTAssertEqual(todaysLogs.first?.calories, 95)
        XCTAssertEqual(todaysLogs.first?.mealType, .snacks)
    }
    
    func testMealLoggingWithQuantity() async throws {
        let today = Date()
        
        // Create a meal
        let meal = CustomFood(
            name: "Protein Shake",
            caloriesPerServing: 120,
            proteinPerServing: 25,
            carbohydratesPerServing: 3,
            fatPerServing: 1,
            servingSize: 1,
            servingUnit: "shake"
        )
        
        try await repository.saveCustomFood(meal)
        
        // Log 1.5 servings of the meal
        let foodLog = FoodLog(
            timestamp: today,
            name: "Protein Shake",
            calories: 180, // 120 * 1.5
            protein: 37.5, // 25 * 1.5
            carbohydrates: 4.5, // 3 * 1.5
            fat: 1.5, // 1 * 1.5
            mealType: .breakfast,
            servingSize: 1.5,
            servingUnit: "shake",
            customFoodId: meal.id
        )
        
        try await repository.saveFoodLog(foodLog)
        
        // Verify meal is logged with correct quantities
        let todaysLogs = try await repository.fetchFoodLogs(for: today)
        XCTAssertEqual(todaysLogs.count, 1)
        XCTAssertEqual(todaysLogs.first?.servingSize, 1.5)
        XCTAssertEqual(todaysLogs.first?.calories, 180)
        XCTAssertEqual(todaysLogs.first?.protein, 37.5)
    }
    
    // MARK: - Search and Filter Tests
    
    func testFoodLibrarySearch() async throws {
        // Create multiple foods
        let foods = [
            CustomFood(name: "Chicken Breast", caloriesPerServing: 165, proteinPerServing: 31, carbohydratesPerServing: 0, fatPerServing: 3.6),
            CustomFood(name: "Salmon", caloriesPerServing: 208, proteinPerServing: 25, carbohydratesPerServing: 0, fatPerServing: 12),
            CustomFood(name: "Broccoli", caloriesPerServing: 55, proteinPerServing: 3.7, carbohydratesPerServing: 11, fatPerServing: 0.6)
        ]
        
        for food in foods {
            try await repository.saveCustomFood(food)
        }
        
        // Test search functionality
        let searchResults = try await repository.searchCustomFoods(query: "chicken")
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.name, "Chicken Breast")
        
        let allFoods = try await repository.fetchCustomFoods()
        XCTAssertEqual(allFoods.count, 3)
    }
    
    // MARK: - Nutrition Calculation Tests
    
    func testDailyNutritionTotals() async throws {
        let today = Date()
        
        // Create and log multiple foods
        let foods = [
            FoodLog(timestamp: today, name: "Breakfast", calories: 400, protein: 25, carbohydrates: 45, fat: 15, mealType: .breakfast),
            FoodLog(timestamp: today, name: "Lunch", calories: 600, protein: 35, carbohydrates: 60, fat: 20, mealType: .lunch),
            FoodLog(timestamp: today, name: "Snack", calories: 200, protein: 10, carbohydrates: 25, fat: 8, mealType: .snacks)
        ]
        
        for foodLog in foods {
            try await repository.saveFoodLog(foodLog)
        }
        
        // Calculate daily totals
        let todaysLogs = try await repository.fetchFoodLogs(for: today)
        let totalCalories = todaysLogs.reduce(0) { $0 + $1.calories }
        let totalProtein = todaysLogs.reduce(0) { $0 + $1.protein }
        let totalCarbs = todaysLogs.reduce(0) { $0 + $1.carbohydrates }
        let totalFat = todaysLogs.reduce(0) { $0 + $1.fat }
        
        XCTAssertEqual(totalCalories, 1200)
        XCTAssertEqual(totalProtein, 70)
        XCTAssertEqual(totalCarbs, 130)
        XCTAssertEqual(totalFat, 43)
    }
    
    // MARK: - Goal Progress Tests
    
    func testGoalProgressCalculation() async throws {
        // Set up nutrition goals
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
        
        let today = Date()
        
        // Log food that represents 60% of daily calories
        let foodLog = FoodLog(
            timestamp: today,
            name: "Large Meal",
            calories: 1200, // 60% of 2000
            protein: 90, // 60% of 150
            carbohydrates: 120, // 60% of 200
            fat: 40, // ~60% of 67
            mealType: .lunch
        )
        
        try await repository.saveFoodLog(foodLog)
        
        // Calculate progress
        let todaysLogs = try await repository.fetchFoodLogs(for: today)
        let totalCalories = todaysLogs.reduce(0) { $0 + $1.calories }
        let totalProtein = todaysLogs.reduce(0) { $0 + $1.protein }
        
        let caloriesProgress = totalCalories / goals.dailyCalories
        let proteinProgress = totalProtein / goals.dailyProtein
        
        XCTAssertEqual(caloriesProgress, 0.6, accuracy: 0.01)
        XCTAssertEqual(proteinProgress, 0.6, accuracy: 0.01)
    }
    
    // MARK: - Data Persistence Tests
    
    func testDataPersistence() async throws {
        let today = Date()
        
        // Create and save data
        let food = CustomFood(
            name: "Test Food",
            caloriesPerServing: 100,
            proteinPerServing: 10,
            carbohydratesPerServing: 15,
            fatPerServing: 5
        )
        
        try await repository.saveCustomFood(food)
        
        let foodLog = FoodLog(
            timestamp: today,
            name: "Test Food",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            mealType: .breakfast,
            customFoodId: food.id
        )
        
        try await repository.saveFoodLog(foodLog)
        
        // Verify data persists
        let savedFoods = try await repository.fetchCustomFoods()
        let savedLogs = try await repository.fetchFoodLogs(for: today)
        
        XCTAssertEqual(savedFoods.count, 1)
        XCTAssertEqual(savedLogs.count, 1)
        XCTAssertEqual(savedFoods.first?.name, "Test Food")
        XCTAssertEqual(savedLogs.first?.name, "Test Food")
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidFoodData() async throws {
        // Test saving food with invalid data
        let invalidFood = CustomFood(
            name: "", // Empty name should be invalid
            caloriesPerServing: -100, // Negative calories should be invalid
            proteinPerServing: 10,
            carbohydratesPerServing: 15,
            fatPerServing: 5
        )
        
        // This should not throw but the food should be invalid
        try await repository.saveCustomFood(invalidFood)
        
        let savedFoods = try await repository.fetchCustomFoods()
        XCTAssertEqual(savedFoods.count, 1)
        
        // The food should be saved but marked as invalid
        let savedFood = savedFoods.first
        XCTAssertEqual(savedFood?.name, "")
        XCTAssertEqual(savedFood?.caloriesPerServing, -100)
    }
} 