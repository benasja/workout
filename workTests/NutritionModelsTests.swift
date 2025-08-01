import XCTest
import SwiftData
import HealthKit
@testable import work

final class NutritionModelsTests: XCTestCase {
    
    // MARK: - FoodLog Tests
    
    func testFoodLogInitialization() {
        let foodLog = FoodLog(
            name: "Apple",
            calories: 95,
            protein: 0.5,
            carbohydrates: 25,
            fat: 0.3,
            mealType: .breakfast,
            servingSize: 1.0,
            servingUnit: "medium apple"
        )
        
        XCTAssertEqual(foodLog.name, "Apple")
        XCTAssertEqual(foodLog.calories, 95)
        XCTAssertEqual(foodLog.protein, 0.5)
        XCTAssertEqual(foodLog.carbohydrates, 25)
        XCTAssertEqual(foodLog.fat, 0.3)
        XCTAssertEqual(foodLog.mealType, .breakfast)
        XCTAssertEqual(foodLog.servingSize, 1.0)
        XCTAssertEqual(foodLog.servingUnit, "medium apple")
        XCTAssertNil(foodLog.barcode)
        XCTAssertNil(foodLog.customFoodId)
    }
    
    func testFoodLogMacroCalculation() {
        let foodLog = FoodLog(
            name: "Test Food",
            calories: 400,
            protein: 25, // 100 calories
            carbohydrates: 50, // 200 calories
            fat: 11, // 99 calories (total: 399)
            mealType: .lunch
        )
        
        XCTAssertEqual(foodLog.totalMacroCalories, 399, accuracy: 0.1)
        XCTAssertTrue(foodLog.hasValidMacros) // Within 10% tolerance
    }
    
    func testFoodLogQuickAddIdentification() {
        let regularFood = FoodLog(
            name: "Apple",
            calories: 95,
            protein: 0.5,
            carbohydrates: 25,
            fat: 0.3,
            mealType: .breakfast,
            barcode: "123456789"
        )
        
        let customFood = FoodLog(
            name: "My Recipe",
            calories: 300,
            protein: 20,
            carbohydrates: 30,
            fat: 10,
            mealType: .dinner,
            customFoodId: UUID()
        )
        
        let quickAdd = FoodLog(
            name: "Quick Add - Snacks",
            calories: 200,
            protein: 10,
            carbohydrates: 20,
            fat: 8,
            mealType: .snacks
        )
        
        XCTAssertFalse(regularFood.isQuickAdd)
        XCTAssertFalse(customFood.isQuickAdd)
        XCTAssertTrue(quickAdd.isQuickAdd)
    }
    
    func testFoodLogFormattedServing() {
        let wholeServing = FoodLog(
            name: "Test",
            calories: 100,
            protein: 5,
            carbohydrates: 10,
            fat: 3,
            mealType: .breakfast,
            servingSize: 1.0,
            servingUnit: "cup"
        )
        
        let multipleServings = FoodLog(
            name: "Test",
            calories: 200,
            protein: 10,
            carbohydrates: 20,
            fat: 6,
            mealType: .breakfast,
            servingSize: 2.0,
            servingUnit: "cups"
        )
        
        let fractionalServing = FoodLog(
            name: "Test",
            calories: 150,
            protein: 7.5,
            carbohydrates: 15,
            fat: 4.5,
            mealType: .breakfast,
            servingSize: 1.5,
            servingUnit: "cups"
        )
        
        XCTAssertEqual(wholeServing.formattedServing, "1 cup")
        XCTAssertEqual(multipleServings.formattedServing, "2 cups")
        XCTAssertEqual(fractionalServing.formattedServing, "1.5 cups")
    }
    
    // MARK: - CustomFood Tests
    
    func testCustomFoodInitialization() {
        let customFood = CustomFood(
            name: "My Protein Shake",
            caloriesPerServing: 250,
            proteinPerServing: 30,
            carbohydratesPerServing: 15,
            fatPerServing: 8,
            servingSize: 1.0,
            servingUnit: "scoop"
        )
        
        XCTAssertEqual(customFood.name, "My Protein Shake")
        XCTAssertEqual(customFood.caloriesPerServing, 250)
        XCTAssertEqual(customFood.proteinPerServing, 30)
        XCTAssertEqual(customFood.carbohydratesPerServing, 15)
        XCTAssertEqual(customFood.fatPerServing, 8)
        XCTAssertEqual(customFood.servingSize, 1.0)
        XCTAssertEqual(customFood.servingUnit, "scoop")
        XCTAssertFalse(customFood.isComposite)
    }
    
    func testCustomFoodValidation() {
        let validFood = CustomFood(
            name: "Valid Food",
            caloriesPerServing: 200,
            proteinPerServing: 20,
            carbohydratesPerServing: 20,
            fatPerServing: 5
        )
        
        let invalidMacrosFood = CustomFood(
            name: "Invalid Macros",
            caloriesPerServing: 100, // Too low for macros
            proteinPerServing: 20, // 80 calories
            carbohydratesPerServing: 20, // 80 calories
            fatPerServing: 10 // 90 calories (total: 250)
        )
        
        let emptyNameFood = CustomFood(
            name: "",
            caloriesPerServing: 200,
            proteinPerServing: 20,
            carbohydratesPerServing: 20,
            fatPerServing: 5
        )
        
        XCTAssertTrue(validFood.isValid)
        XCTAssertTrue(validFood.hasValidName)
        XCTAssertTrue(validFood.hasValidNutrition)
        XCTAssertTrue(validFood.hasValidMacros)
        
        XCTAssertFalse(invalidMacrosFood.hasValidMacros)
        XCTAssertFalse(invalidMacrosFood.isValid)
        
        XCTAssertFalse(emptyNameFood.hasValidName)
        XCTAssertFalse(emptyNameFood.isValid)
    }
    
    func testCustomFoodIngredients() {
        let ingredient1 = CustomFoodIngredient(
            name: "Chicken Breast",
            quantity: 100,
            unit: "g",
            calories: 165,
            protein: 31,
            carbohydrates: 0,
            fat: 3.6
        )
        
        let ingredient2 = CustomFoodIngredient(
            name: "Rice",
            quantity: 50,
            unit: "g",
            calories: 65,
            protein: 1.3,
            carbohydrates: 14,
            fat: 0.2
        )
        
        let compositeFood = CustomFood(
            name: "Chicken and Rice",
            caloriesPerServing: 230,
            proteinPerServing: 32.3,
            carbohydratesPerServing: 14,
            fatPerServing: 3.8,
            isComposite: true,
            ingredients: [ingredient1, ingredient2]
        )
        
        XCTAssertTrue(compositeFood.isComposite)
        XCTAssertEqual(compositeFood.ingredients.count, 2)
        XCTAssertEqual(compositeFood.ingredients[0].name, "Chicken Breast")
        XCTAssertEqual(compositeFood.ingredients[1].name, "Rice")
    }
    
    // MARK: - NutritionGoals Tests
    
    func testNutritionGoalsInitialization() {
        let goals = NutritionGoals(
            dailyCalories: 2000,
            dailyProtein: 150,
            dailyCarbohydrates: 200,
            dailyFat: 67,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            bmr: 1600,
            tdee: 2000,
            weight: 70,
            height: 175,
            age: 30,
            biologicalSex: "male"
        )
        
        XCTAssertEqual(goals.dailyCalories, 2000)
        XCTAssertEqual(goals.dailyProtein, 150)
        XCTAssertEqual(goals.dailyCarbohydrates, 200)
        XCTAssertEqual(goals.dailyFat, 67)
        XCTAssertEqual(goals.activityLevel, .moderatelyActive)
        XCTAssertEqual(goals.goal, .maintain)
        XCTAssertEqual(goals.bmr, 1600)
        XCTAssertEqual(goals.tdee, 2000)
        XCTAssertEqual(goals.weight, 70)
        XCTAssertEqual(goals.height, 175)
        XCTAssertEqual(goals.age, 30)
        XCTAssertEqual(goals.biologicalSex, "male")
    }
    
    func testNutritionGoalsMacroCalculations() {
        let goals = NutritionGoals(
            dailyCalories: 2000,
            dailyProtein: 125, // 500 calories (25%)
            dailyCarbohydrates: 225, // 900 calories (45%)
            dailyFat: 67, // 603 calories (30%)
            activityLevel: .moderatelyActive,
            goal: .maintain,
            bmr: 1600,
            tdee: 2000
        )
        
        XCTAssertEqual(goals.totalMacroCalories, 2003, accuracy: 1.0)
        XCTAssertTrue(goals.hasValidMacros)
        XCTAssertEqual(goals.proteinPercentage, 25, accuracy: 1.0)
        XCTAssertEqual(goals.carbohydratesPercentage, 45, accuracy: 1.0)
        XCTAssertEqual(goals.fatPercentage, 30.15, accuracy: 1.0)
    }
    
    func testBMRCalculation() {
        // Test male BMR calculation
        let maleBMR = NutritionGoals.calculateBMR(
            weight: 80, // kg
            height: 180, // cm
            age: 30,
            biologicalSex: .male
        )
        
        // Expected: (10 * 80) + (6.25 * 180) - (5 * 30) + 5 = 800 + 1125 - 150 + 5 = 1780
        XCTAssertEqual(maleBMR, 1780, accuracy: 1.0)
        
        // Test female BMR calculation
        let femaleBMR = NutritionGoals.calculateBMR(
            weight: 65, // kg
            height: 165, // cm
            age: 25,
            biologicalSex: .female
        )
        
        // Expected: (10 * 65) + (6.25 * 165) - (5 * 25) - 161 = 650 + 1031.25 - 125 - 161 = 1395.25
        XCTAssertEqual(femaleBMR, 1395.25, accuracy: 1.0)
    }
    
    func testTDEECalculation() {
        let bmr = 1600.0
        
        let sedentaryTDEE = NutritionGoals.calculateTDEE(bmr: bmr, activityLevel: .sedentary)
        let moderateTDEE = NutritionGoals.calculateTDEE(bmr: bmr, activityLevel: .moderatelyActive)
        let veryActiveTDEE = NutritionGoals.calculateTDEE(bmr: bmr, activityLevel: .veryActive)
        
        XCTAssertEqual(sedentaryTDEE, 1920, accuracy: 1.0) // 1600 * 1.2
        XCTAssertEqual(moderateTDEE, 2480, accuracy: 1.0) // 1600 * 1.55
        XCTAssertEqual(veryActiveTDEE, 2760, accuracy: 1.0) // 1600 * 1.725
    }
    
    func testGoalUpdateFromTDEE() {
        let goals = NutritionGoals(
            dailyCalories: 2000,
            dailyProtein: 100,
            dailyCarbohydrates: 200,
            dailyFat: 67,
            activityLevel: .moderatelyActive,
            goal: .cut,
            bmr: 1600,
            tdee: 2000
        )
        
        goals.updateGoalsFromTDEE()
        
        // For cut: TDEE (2000) - 500 = 1500 calories
        XCTAssertEqual(goals.dailyCalories, 1500, accuracy: 1.0)
        
        // Cut macros: 35% protein, 25% fat, 40% carbs
        XCTAssertEqual(goals.dailyProtein, 131.25, accuracy: 1.0) // 1500 * 0.35 / 4
        XCTAssertEqual(goals.dailyFat, 41.67, accuracy: 1.0) // 1500 * 0.25 / 9
        XCTAssertEqual(goals.dailyCarbohydrates, 150, accuracy: 1.0) // 1500 * 0.40 / 4
    }
    
    // MARK: - Enum Tests
    
    func testMealTypeProperties() {
        XCTAssertEqual(MealType.breakfast.displayName, "Breakfast")
        XCTAssertEqual(MealType.lunch.displayName, "Lunch")
        XCTAssertEqual(MealType.dinner.displayName, "Dinner")
        XCTAssertEqual(MealType.snacks.displayName, "Snacks")
        
        XCTAssertEqual(MealType.breakfast.icon, "sunrise.fill")
        XCTAssertEqual(MealType.lunch.icon, "sun.max.fill")
        XCTAssertEqual(MealType.dinner.icon, "sunset.fill")
        XCTAssertEqual(MealType.snacks.icon, "star.fill")
        
        XCTAssertEqual(MealType.breakfast.sortOrder, 0)
        XCTAssertEqual(MealType.lunch.sortOrder, 1)
        XCTAssertEqual(MealType.dinner.sortOrder, 2)
        XCTAssertEqual(MealType.snacks.sortOrder, 3)
    }
    
    func testActivityLevelProperties() {
        XCTAssertEqual(ActivityLevel.sedentary.multiplier, 1.2)
        XCTAssertEqual(ActivityLevel.lightlyActive.multiplier, 1.375)
        XCTAssertEqual(ActivityLevel.moderatelyActive.multiplier, 1.55)
        XCTAssertEqual(ActivityLevel.veryActive.multiplier, 1.725)
        XCTAssertEqual(ActivityLevel.extremelyActive.multiplier, 1.9)
        
        XCTAssertEqual(ActivityLevel.sedentary.displayName, "Sedentary")
        XCTAssertEqual(ActivityLevel.lightlyActive.displayName, "Lightly Active")
        XCTAssertEqual(ActivityLevel.moderatelyActive.displayName, "Moderately Active")
        XCTAssertEqual(ActivityLevel.veryActive.displayName, "Very Active")
        XCTAssertEqual(ActivityLevel.extremelyActive.displayName, "Extremely Active")
    }
    
    func testNutritionGoalProperties() {
        XCTAssertEqual(NutritionGoal.cut.calorieAdjustment, -500)
        XCTAssertEqual(NutritionGoal.maintain.calorieAdjustment, 0)
        XCTAssertEqual(NutritionGoal.bulk.calorieAdjustment, 300)
        
        XCTAssertEqual(NutritionGoal.cut.displayName, "Cut (Lose Weight)")
        XCTAssertEqual(NutritionGoal.maintain.displayName, "Maintain Weight")
        XCTAssertEqual(NutritionGoal.bulk.displayName, "Bulk (Gain Weight)")
        
        XCTAssertEqual(NutritionGoal.cut.icon, "arrow.down.circle.fill")
        XCTAssertEqual(NutritionGoal.maintain.icon, "equal.circle.fill")
        XCTAssertEqual(NutritionGoal.bulk.icon, "arrow.up.circle.fill")
    }
    
    // MARK: - CustomFoodIngredient Tests
    
    func testCustomFoodIngredientFormatting() {
        let wholeQuantity = CustomFoodIngredient(
            name: "Chicken",
            quantity: 100,
            unit: "g",
            calories: 165,
            protein: 31,
            carbohydrates: 0,
            fat: 3.6
        )
        
        let fractionalQuantity = CustomFoodIngredient(
            name: "Oil",
            quantity: 1.5,
            unit: "tbsp",
            calories: 180,
            protein: 0,
            carbohydrates: 0,
            fat: 20
        )
        
        XCTAssertEqual(wholeQuantity.formattedQuantity, "100 g")
        XCTAssertEqual(fractionalQuantity.formattedQuantity, "1.5 tbsp")
    }
    
    // MARK: - DailyNutritionTotals Tests
    
    func testDailyNutritionTotalsInitialization() {
        let totals = DailyNutritionTotals()
        
        XCTAssertEqual(totals.totalCalories, 0)
        XCTAssertEqual(totals.totalProtein, 0)
        XCTAssertEqual(totals.totalCarbohydrates, 0)
        XCTAssertEqual(totals.totalFat, 0)
        XCTAssertEqual(totals.caloriesFromMacros, 0)
    }
    
    func testDailyNutritionTotalsAddition() {
        var totals = DailyNutritionTotals()
        
        let foodLog1 = FoodLog(
            name: "Apple",
            calories: 95,
            protein: 0.5,
            carbohydrates: 25,
            fat: 0.3,
            mealType: .breakfast
        )
        
        let foodLog2 = FoodLog(
            name: "Chicken",
            calories: 165,
            protein: 31,
            carbohydrates: 0,
            fat: 3.6,
            mealType: .lunch
        )
        
        totals.add(foodLog1)
        XCTAssertEqual(totals.totalCalories, 95)
        XCTAssertEqual(totals.totalProtein, 0.5)
        XCTAssertEqual(totals.totalCarbohydrates, 25)
        XCTAssertEqual(totals.totalFat, 0.3)
        
        totals.add(foodLog2)
        XCTAssertEqual(totals.totalCalories, 260)
        XCTAssertEqual(totals.totalProtein, 31.5)
        XCTAssertEqual(totals.totalCarbohydrates, 25)
        XCTAssertEqual(totals.totalFat, 3.9)
    }
    
    func testDailyNutritionTotalsSubtraction() {
        var totals = DailyNutritionTotals()
        totals.totalCalories = 200
        totals.totalProtein = 20
        totals.totalCarbohydrates = 30
        totals.totalFat = 5
        
        let foodLog = FoodLog(
            name: "Test Food",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 2,
            mealType: .snacks
        )
        
        totals.subtract(foodLog)
        XCTAssertEqual(totals.totalCalories, 100)
        XCTAssertEqual(totals.totalProtein, 10)
        XCTAssertEqual(totals.totalCarbohydrates, 15)
        XCTAssertEqual(totals.totalFat, 3)
    }
    
    func testDailyNutritionTotalsProgress() {
        let totals = DailyNutritionTotals(
            totalCalories: 1000,
            totalProtein: 75,
            totalCarbohydrates: 100,
            totalFat: 33
        )
        
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
        
        let progress = totals.progress(against: goals)
        
        XCTAssertEqual(progress.caloriesProgress, 0.5, accuracy: 0.01)
        XCTAssertEqual(progress.proteinProgress, 0.5, accuracy: 0.01)
        XCTAssertEqual(progress.carbohydratesProgress, 0.5, accuracy: 0.01)
        XCTAssertEqual(progress.fatProgress, 0.49, accuracy: 0.01)
        XCTAssertFalse(progress.hasCompletedGoals)
        XCTAssertEqual(progress.completedGoalsCount, 0)
    }
    
    func testDailyNutritionTotalsRemaining() {
        let totals = DailyNutritionTotals(
            totalCalories: 1500,
            totalProtein: 100,
            totalCarbohydrates: 150,
            totalFat: 50
        )
        
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
        
        let remaining = totals.remaining(against: goals)
        
        XCTAssertEqual(remaining.totalCalories, 500)
        XCTAssertEqual(remaining.totalProtein, 50)
        XCTAssertEqual(remaining.totalCarbohydrates, 50)
        XCTAssertEqual(remaining.totalFat, 17)
    }
    
    func testMealTypeTotalsCalculation() {
        let breakfastFood = FoodLog(
            name: "Oatmeal",
            calories: 150,
            protein: 5,
            carbohydrates: 30,
            fat: 3,
            mealType: .breakfast
        )
        
        let lunchFood = FoodLog(
            name: "Salad",
            calories: 200,
            protein: 15,
            carbohydrates: 20,
            fat: 8,
            mealType: .lunch
        )
        
        let anotherBreakfastFood = FoodLog(
            name: "Banana",
            calories: 105,
            protein: 1,
            carbohydrates: 27,
            fat: 0.5,
            mealType: .breakfast
        )
        
        let foodLogs = [breakfastFood, lunchFood, anotherBreakfastFood]
        let mealTotals = DailyNutritionTotals.calculateByMealType(foodLogs)
        
        XCTAssertEqual(mealTotals[.breakfast]?.totalCalories, 255)
        XCTAssertEqual(mealTotals[.breakfast]?.totalProtein, 6)
        XCTAssertEqual(mealTotals[.breakfast]?.totalCarbohydrates, 57)
        XCTAssertEqual(mealTotals[.breakfast]?.totalFat, 3.5)
        
        XCTAssertEqual(mealTotals[.lunch]?.totalCalories, 200)
        XCTAssertEqual(mealTotals[.lunch]?.totalProtein, 15)
        XCTAssertEqual(mealTotals[.lunch]?.totalCarbohydrates, 20)
        XCTAssertEqual(mealTotals[.lunch]?.totalFat, 8)
        
        XCTAssertEqual(mealTotals[.dinner]?.totalCalories, 0)
        XCTAssertEqual(mealTotals[.snacks]?.totalCalories, 0)
    }
}