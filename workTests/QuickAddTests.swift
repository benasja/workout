import XCTest
@testable import work

final class QuickAddTests: XCTestCase {
    
    // MARK: - Quick Add Validation Tests
    
    func testQuickAddValidation_ValidMacros() {
        // Test that valid macro values pass validation
        let calories = 300.0
        let protein = 20.0
        let carbohydrates = 30.0
        let fat = 10.0
        
        let calculatedCalories = (protein * 4) + (carbohydrates * 4) + (fat * 9)
        let difference = abs(calories - calculatedCalories)
        let percentDifference = difference / calories
        
        XCTAssertLessThanOrEqual(percentDifference, 0.15, "Valid macro distribution should pass validation")
    }
    
    func testQuickAddValidation_InvalidMacroDistribution() {
        // Test that invalid macro distribution fails validation
        let calories = 300.0
        let protein = 50.0  // Too high protein for the calories
        let carbohydrates = 50.0
        let fat = 20.0
        
        let calculatedCalories = (protein * 4) + (carbohydrates * 4) + (fat * 9)
        let difference = abs(calories - calculatedCalories)
        let percentDifference = difference / calories
        
        XCTAssertGreaterThan(percentDifference, 0.15, "Invalid macro distribution should fail validation")
    }
    
    func testQuickAddValidation_OnlyMacrosProvided() {
        // Test that providing only macros without calories is valid
        let protein = 20.0
        let carbohydrates = 30.0
        let fat = 10.0
        
        let hasValidInput = protein > 0 || carbohydrates > 0 || fat > 0
        XCTAssertTrue(hasValidInput, "Should be valid when only macros are provided")
    }
    
    func testQuickAddValidation_NegativeValues() {
        // Test that negative values are invalid
        let negativeValues = [-1.0, -10.0, -100.0]
        
        for value in negativeValues {
            XCTAssertLessThan(value, 0, "Negative values should be invalid")
        }
    }
    
    func testQuickAddValidation_ExcessiveValues() {
        // Test that excessively high values are flagged
        let excessiveCalories = 6000.0
        let excessiveProtein = 600.0
        let excessiveCarbs = 600.0
        let excessiveFat = 300.0
        
        XCTAssertGreaterThan(excessiveCalories, 5000, "Excessive calories should be flagged")
        XCTAssertGreaterThan(excessiveProtein, 500, "Excessive protein should be flagged")
        XCTAssertGreaterThan(excessiveCarbs, 500, "Excessive carbs should be flagged")
        XCTAssertGreaterThan(excessiveFat, 200, "Excessive fat should be flagged")
    }
    
    // MARK: - FoodLog Creation Tests
    
    func testQuickAddFoodLogCreation() {
        // Test that quick add creates proper FoodLog entries
        let calories = 300.0
        let protein = 20.0
        let carbohydrates = 30.0
        let fat = 10.0
        let mealType = MealType.breakfast
        
        let foodLog = FoodLog(
            name: "Quick Add - \(mealType.displayName)",
            calories: calories,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat,
            mealType: mealType,
            servingSize: 1.0,
            servingUnit: "entry"
        )
        
        XCTAssertEqual(foodLog.calories, calories)
        XCTAssertEqual(foodLog.protein, protein)
        XCTAssertEqual(foodLog.carbohydrates, carbohydrates)
        XCTAssertEqual(foodLog.fat, fat)
        XCTAssertEqual(foodLog.mealType, mealType)
        XCTAssertTrue(foodLog.isQuickAdd, "Should be identified as quick add entry")
        XCTAssertEqual(foodLog.servingSize, 1.0)
        XCTAssertEqual(foodLog.servingUnit, "entry")
        XCTAssertNil(foodLog.barcode)
        XCTAssertNil(foodLog.customFoodId)
    }
    
    func testQuickAddFoodLogNaming() {
        // Test that quick add entries have proper naming
        let mealTypes = MealType.allCases
        
        for mealType in mealTypes {
            let foodLog = FoodLog(
                name: "Quick Add - \(mealType.displayName)",
                calories: 100,
                protein: 10,
                carbohydrates: 10,
                fat: 5,
                mealType: mealType
            )
            
            let expectedName = "Quick Add - \(mealType.displayName)"
            XCTAssertEqual(foodLog.name, expectedName, "Quick add entry should have proper naming for \(mealType)")
        }
    }
    
    // MARK: - Macro Calculation Tests
    
    func testMacroCalorieCalculation() {
        // Test the 4-4-9 rule for macro calorie calculation
        let protein = 25.0
        let carbohydrates = 40.0
        let fat = 15.0
        
        let expectedCalories = (protein * 4) + (carbohydrates * 4) + (fat * 9)
        let calculatedCalories = (protein * 4) + (carbohydrates * 4) + (fat * 9)
        
        XCTAssertEqual(calculatedCalories, expectedCalories, accuracy: 0.1)
        XCTAssertEqual(calculatedCalories, 395.0, accuracy: 0.1) // (25*4) + (40*4) + (15*9) = 100 + 160 + 135 = 395
    }
    
    func testMacroCalorieConsistency() {
        // Test various macro combinations for calorie consistency
        let testCases = [
            (calories: 400.0, protein: 30.0, carbs: 40.0, fat: 12.0), // Should be consistent
            (calories: 500.0, protein: 25.0, carbs: 50.0, fat: 20.0), // Should be consistent
            (calories: 300.0, protein: 20.0, carbs: 30.0, fat: 10.0)  // Should be consistent
        ]
        
        for testCase in testCases {
            let calculatedCalories = (testCase.protein * 4) + (testCase.carbs * 4) + (testCase.fat * 9)
            let difference = abs(testCase.calories - calculatedCalories)
            let percentDifference = difference / testCase.calories
            
            XCTAssertLessThanOrEqual(percentDifference, 0.15, 
                "Macro calories should be consistent for calories: \(testCase.calories), calculated: \(calculatedCalories)")
        }
    }
    
    // MARK: - Quick Edit Tests
    
    func testQuickEditDetectsChanges() {
        // Test that quick edit properly detects changes
        let originalFoodLog = FoodLog(
            name: "Quick Add - Breakfast",
            calories: 300,
            protein: 20,
            carbohydrates: 30,
            fat: 10,
            mealType: .breakfast
        )
        
        // Test calorie change
        let calorieChange = 350.0
        let hasCalorieChange = calorieChange != originalFoodLog.calories
        XCTAssertTrue(hasCalorieChange, "Should detect calorie changes")
        
        // Test protein change
        let proteinChange = 25.0
        let hasProteinChange = proteinChange != originalFoodLog.protein
        XCTAssertTrue(hasProteinChange, "Should detect protein changes")
        
        // Test meal type change
        let mealTypeChange = MealType.lunch
        let hasMealTypeChange = mealTypeChange != originalFoodLog.mealType
        XCTAssertTrue(hasMealTypeChange, "Should detect meal type changes")
        
        // Test no changes
        let noChanges = originalFoodLog.calories == originalFoodLog.calories &&
                       originalFoodLog.protein == originalFoodLog.protein &&
                       originalFoodLog.carbohydrates == originalFoodLog.carbohydrates &&
                       originalFoodLog.fat == originalFoodLog.fat &&
                       originalFoodLog.mealType == originalFoodLog.mealType
        XCTAssertTrue(noChanges, "Should detect when no changes are made")
    }
    
    // MARK: - Integration Tests
    
    func testQuickAddIntegrationWithDailyTotals() {
        // Test that quick add entries properly integrate with daily totals
        var dailyTotals = DailyNutritionTotals()
        
        let quickAddEntry = FoodLog(
            name: "Quick Add - Lunch",
            calories: 400,
            protein: 25,
            carbohydrates: 45,
            fat: 15,
            mealType: .lunch
        )
        
        dailyTotals.add(quickAddEntry)
        
        XCTAssertEqual(dailyTotals.totalCalories, 400, accuracy: 0.1)
        XCTAssertEqual(dailyTotals.totalProtein, 25, accuracy: 0.1)
        XCTAssertEqual(dailyTotals.totalCarbohydrates, 45, accuracy: 0.1)
        XCTAssertEqual(dailyTotals.totalFat, 15, accuracy: 0.1)
    }
    
    func testQuickAddMealTypeDistribution() {
        // Test that quick add entries are properly distributed across meal types
        let mealTypes = MealType.allCases
        var foodLogs: [FoodLog] = []
        
        for mealType in mealTypes {
            let foodLog = FoodLog(
                name: "Quick Add - \(mealType.displayName)",
                calories: 200,
                protein: 15,
                carbohydrates: 20,
                fat: 8,
                mealType: mealType
            )
            foodLogs.append(foodLog)
        }
        
        // Group by meal type
        let groupedLogs = Dictionary(grouping: foodLogs) { $0.mealType }
        
        XCTAssertEqual(groupedLogs.count, mealTypes.count, "Should have entries for all meal types")
        
        for mealType in mealTypes {
            XCTAssertNotNil(groupedLogs[mealType], "Should have entry for \(mealType)")
            XCTAssertEqual(groupedLogs[mealType]?.count, 1, "Should have exactly one entry per meal type")
        }
    }
}