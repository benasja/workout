import XCTest
import HealthKit
@testable import work

final class NutritionGoalCalculationTests: XCTestCase {
    
    // MARK: - BMR Calculation Tests
    
    func testBMRCalculation_MaleMifflinStJeor() {
        // Given - 30-year-old male, 80kg, 180cm
        let weight: Double = 80
        let height: Double = 180
        let age = 30
        let biologicalSex = HKBiologicalSex.male
        
        // When
        let bmr = NutritionGoals.calculateBMR(weight: weight, height: height, age: age, biologicalSex: biologicalSex)
        
        // Then - Expected: (10 * 80) + (6.25 * 180) - (5 * 30) + 5 = 800 + 1125 - 150 + 5 = 1780
        XCTAssertEqual(bmr, 1780, accuracy: 0.1)
    }
    
    func testBMRCalculation_FemaleMifflinStJeor() {
        // Given - 25-year-old female, 65kg, 165cm
        let weight: Double = 65
        let height: Double = 165
        let age = 25
        let biologicalSex = HKBiologicalSex.female
        
        // When
        let bmr = NutritionGoals.calculateBMR(weight: weight, height: height, age: age, biologicalSex: biologicalSex)
        
        // Then - Expected: (10 * 65) + (6.25 * 165) - (5 * 25) - 161 = 650 + 1031.25 - 125 - 161 = 1395.25
        XCTAssertEqual(bmr, 1395.25, accuracy: 0.1)
    }
    
    func testBMRCalculation_OtherSex() {
        // Given - 30-year-old other/unknown sex, 75kg, 170cm
        let weight: Double = 75
        let height: Double = 170
        let age = 30
        let biologicalSex = HKBiologicalSex.other
        
        // When
        let bmr = NutritionGoals.calculateBMR(weight: weight, height: height, age: age, biologicalSex: biologicalSex)
        
        // Then - Should be average of male and female formulas
        let maleFormula = (10 * weight) + (6.25 * height) - (5 * Double(age)) + 5
        let femaleFormula = (10 * weight) + (6.25 * height) - (5 * Double(age)) - 161
        let expectedBMR = (maleFormula + femaleFormula) / 2
        
        XCTAssertEqual(bmr, expectedBMR, accuracy: 0.1)
    }
    
    func testBMRCalculation_MinimumValue() {
        // Given - Very low values that would result in BMR < 1000
        let weight: Double = 30
        let height: Double = 120
        let age = 80
        let biologicalSex = HKBiologicalSex.female
        
        // When
        let bmr = NutritionGoals.calculateBMR(weight: weight, height: height, age: age, biologicalSex: biologicalSex)
        
        // Then - Should be at least 1000 (minimum BMR)
        XCTAssertGreaterThanOrEqual(bmr, 1000)
    }
    
    // MARK: - TDEE Calculation Tests
    
    func testTDEECalculation_AllActivityLevels() {
        let bmr: Double = 1800
        
        // Test all activity levels
        let testCases: [(ActivityLevel, Double)] = [
            (.sedentary, 1800 * 1.2),
            (.lightlyActive, 1800 * 1.375),
            (.moderatelyActive, 1800 * 1.55),
            (.veryActive, 1800 * 1.725),
            (.extremelyActive, 1800 * 1.9)
        ]
        
        for (activityLevel, expectedTDEE) in testCases {
            // When
            let tdee = NutritionGoals.calculateTDEE(bmr: bmr, activityLevel: activityLevel)
            
            // Then
            XCTAssertEqual(tdee, expectedTDEE, accuracy: 0.1, "TDEE calculation failed for \(activityLevel)")
        }
    }
    
    // MARK: - Goal Adjustment Tests
    
    func testGoalCalorieAdjustments() {
        let testCases: [(NutritionGoal, Double)] = [
            (.cut, -500),
            (.maintain, 0),
            (.bulk, 300)
        ]
        
        for (goal, expectedAdjustment) in testCases {
            XCTAssertEqual(goal.calorieAdjustment, expectedAdjustment, "Calorie adjustment incorrect for \(goal)")
        }
    }
    
    // MARK: - Macro Distribution Tests
    
    func testMacroDistribution_CutGoal() {
        // Given
        let goals = createNutritionGoals(goal: .cut, calories: 1500)
        
        // When
        goals.updateGoalsFromTDEE()
        
        // Then - Cut should be 35% protein, 40% carbs, 25% fat
        let expectedProtein = 1500 * 0.35 / 4  // 131.25g
        let expectedCarbs = 1500 * 0.40 / 4    // 150g
        let expectedFat = 1500 * 0.25 / 9      // 41.67g
        
        XCTAssertEqual(goals.dailyProtein, expectedProtein, accuracy: 0.1)
        XCTAssertEqual(goals.dailyCarbohydrates, expectedCarbs, accuracy: 0.1)
        XCTAssertEqual(goals.dailyFat, expectedFat, accuracy: 0.1)
    }
    
    func testMacroDistribution_MaintainGoal() {
        // Given
        let goals = createNutritionGoals(goal: .maintain, calories: 2000)
        
        // When
        goals.updateGoalsFromTDEE()
        
        // Then - Maintain should be 25% protein, 45% carbs, 30% fat
        let expectedProtein = 2000 * 0.25 / 4  // 125g
        let expectedCarbs = 2000 * 0.45 / 4    // 225g
        let expectedFat = 2000 * 0.30 / 9      // 66.67g
        
        XCTAssertEqual(goals.dailyProtein, expectedProtein, accuracy: 0.1)
        XCTAssertEqual(goals.dailyCarbohydrates, expectedCarbs, accuracy: 0.1)
        XCTAssertEqual(goals.dailyFat, expectedFat, accuracy: 0.1)
    }
    
    func testMacroDistribution_BulkGoal() {
        // Given
        let goals = createNutritionGoals(goal: .bulk, calories: 2300)
        
        // When
        goals.updateGoalsFromTDEE()
        
        // Then - Bulk should be 20% protein, 55% carbs, 25% fat
        let expectedProtein = 2300 * 0.20 / 4  // 115g
        let expectedCarbs = 2300 * 0.55 / 4    // 316.25g
        let expectedFat = 2300 * 0.25 / 9      // 63.89g
        
        XCTAssertEqual(goals.dailyProtein, expectedProtein, accuracy: 0.1)
        XCTAssertEqual(goals.dailyCarbohydrates, expectedCarbs, accuracy: 0.1)
        XCTAssertEqual(goals.dailyFat, expectedFat, accuracy: 0.1)
    }
    
    // MARK: - Macro Validation Tests
    
    func testMacroValidation_ValidMacros() {
        // Given - Macros that align with calories (within 5%)
        let goals = NutritionGoals(
            dailyCalories: 2000,
            dailyProtein: 125,    // 500 cal
            dailyCarbohydrates: 225, // 900 cal
            dailyFat: 67,         // 603 cal (total: 2003 cal, 0.15% difference)
            activityLevel: .maintain,
            goal: .maintain,
            bmr: 1600,
            tdee: 2000
        )
        
        // When/Then
        XCTAssertTrue(goals.hasValidMacros)
    }
    
    func testMacroValidation_InvalidMacros() {
        // Given - Macros that don't align with calories (>5% difference)
        let goals = NutritionGoals(
            dailyCalories: 2000,
            dailyProtein: 200,    // 800 cal
            dailyCarbohydrates: 300, // 1200 cal
            dailyFat: 100,        // 900 cal (total: 2900 cal, 45% difference)
            activityLevel: .maintain,
            goal: .maintain,
            bmr: 1600,
            tdee: 2000
        )
        
        // When/Then
        XCTAssertFalse(goals.hasValidMacros)
    }
    
    func testMacroValidation_ZeroCalories() {
        // Given
        let goals = NutritionGoals(
            dailyCalories: 0,
            dailyProtein: 100,
            dailyCarbohydrates: 100,
            dailyFat: 50,
            activityLevel: .maintain,
            goal: .maintain,
            bmr: 1600,
            tdee: 2000
        )
        
        // When/Then
        XCTAssertFalse(goals.hasValidMacros)
    }
    
    // MARK: - Percentage Calculations Tests
    
    func testMacroPercentages() {
        // Given
        let goals = NutritionGoals(
            dailyCalories: 2000,
            dailyProtein: 125,    // 500 cal = 25%
            dailyCarbohydrates: 225, // 900 cal = 45%
            dailyFat: 67,         // 603 cal = 30.15%
            activityLevel: .maintain,
            goal: .maintain,
            bmr: 1600,
            tdee: 2000
        )
        
        // When/Then
        XCTAssertEqual(goals.proteinPercentage, 25, accuracy: 0.1)
        XCTAssertEqual(goals.carbohydratesPercentage, 45, accuracy: 0.1)
        XCTAssertEqual(goals.fatPercentage, 30.15, accuracy: 0.1)
    }
    
    func testMacroPercentages_ZeroCalories() {
        // Given
        let goals = NutritionGoals(
            dailyCalories: 0,
            dailyProtein: 100,
            dailyCarbohydrates: 100,
            dailyFat: 50,
            activityLevel: .maintain,
            goal: .maintain,
            bmr: 1600,
            tdee: 2000
        )
        
        // When/Then
        XCTAssertEqual(goals.proteinPercentage, 0)
        XCTAssertEqual(goals.carbohydratesPercentage, 0)
        XCTAssertEqual(goals.fatPercentage, 0)
    }
    
    // MARK: - Update Detection Tests
    
    func testNeedsUpdate_RecentGoals() {
        // Given - Goals updated today
        let goals = createNutritionGoals(goal: .maintain, calories: 2000)
        goals.lastUpdated = Date()
        
        // When/Then
        XCTAssertFalse(goals.needsUpdate)
    }
    
    func testNeedsUpdate_OldGoals() {
        // Given - Goals updated 31 days ago
        let goals = createNutritionGoals(goal: .maintain, calories: 2000)
        goals.lastUpdated = Calendar.current.date(byAdding: .day, value: -31, to: Date()) ?? Date()
        
        // When/Then
        XCTAssertTrue(goals.needsUpdate)
    }
    
    // MARK: - Activity Level Tests
    
    func testActivityLevelMultipliers() {
        let testCases: [(ActivityLevel, Double)] = [
            (.sedentary, 1.2),
            (.lightlyActive, 1.375),
            (.moderatelyActive, 1.55),
            (.veryActive, 1.725),
            (.extremelyActive, 1.9)
        ]
        
        for (level, expectedMultiplier) in testCases {
            XCTAssertEqual(level.multiplier, expectedMultiplier, "Multiplier incorrect for \(level)")
        }
    }
    
    func testActivityLevelDisplayNames() {
        XCTAssertEqual(ActivityLevel.sedentary.displayName, "Sedentary")
        XCTAssertEqual(ActivityLevel.lightlyActive.displayName, "Lightly Active")
        XCTAssertEqual(ActivityLevel.moderatelyActive.displayName, "Moderately Active")
        XCTAssertEqual(ActivityLevel.veryActive.displayName, "Very Active")
        XCTAssertEqual(ActivityLevel.extremelyActive.displayName, "Extremely Active")
    }
    
    // MARK: - Nutrition Goal Tests
    
    func testNutritionGoalDisplayNames() {
        XCTAssertEqual(NutritionGoal.cut.displayName, "Cut (Lose Weight)")
        XCTAssertEqual(NutritionGoal.maintain.displayName, "Maintain Weight")
        XCTAssertEqual(NutritionGoal.bulk.displayName, "Bulk (Gain Weight)")
    }
    
    func testNutritionGoalIcons() {
        XCTAssertEqual(NutritionGoal.cut.icon, "arrow.down.circle.fill")
        XCTAssertEqual(NutritionGoal.maintain.icon, "equal.circle.fill")
        XCTAssertEqual(NutritionGoal.bulk.icon, "arrow.up.circle.fill")
    }
    
    // MARK: - Integration Tests
    
    func testCompleteGoalCalculationFlow() {
        // Given - Real-world scenario
        let weight: Double = 75 // kg
        let height: Double = 175 // cm
        let age = 30
        let biologicalSex = HKBiologicalSex.male
        let activityLevel = ActivityLevel.moderatelyActive
        let goal = NutritionGoal.cut
        
        // When - Calculate BMR
        let bmr = NutritionGoals.calculateBMR(weight: weight, height: height, age: age, biologicalSex: biologicalSex)
        
        // Then - BMR should be reasonable
        XCTAssertGreaterThan(bmr, 1500)
        XCTAssertLessThan(bmr, 2000)
        
        // When - Calculate TDEE
        let tdee = NutritionGoals.calculateTDEE(bmr: bmr, activityLevel: activityLevel)
        
        // Then - TDEE should be higher than BMR
        XCTAssertGreaterThan(tdee, bmr)
        
        // When - Apply goal adjustment
        let adjustedCalories = tdee + goal.calorieAdjustment
        
        // Then - Cut should reduce calories
        XCTAssertLessThan(adjustedCalories, tdee)
        XCTAssertEqual(adjustedCalories, tdee - 500, accuracy: 0.1)
        
        // When - Create goals and update macros
        let goals = NutritionGoals(
            dailyCalories: adjustedCalories,
            dailyProtein: 0, // Will be updated
            dailyCarbohydrates: 0, // Will be updated
            dailyFat: 0, // Will be updated
            activityLevel: activityLevel,
            goal: goal,
            bmr: bmr,
            tdee: tdee,
            weight: weight,
            height: height,
            age: age,
            biologicalSex: biologicalSex.stringRepresentation
        )
        
        goals.updateGoalsFromTDEE()
        
        // Then - Macros should be reasonable and valid
        XCTAssertTrue(goals.hasValidMacros)
        XCTAssertGreaterThan(goals.dailyProtein, 100) // Reasonable protein for cut
        XCTAssertGreaterThan(goals.dailyCarbohydrates, 100) // Reasonable carbs
        XCTAssertGreaterThan(goals.dailyFat, 40) // Reasonable fat
    }
    
    // MARK: - Helper Methods
    
    private func createNutritionGoals(goal: NutritionGoal, calories: Double) -> NutritionGoals {
        let goals = NutritionGoals(
            dailyCalories: calories,
            dailyProtein: 0,
            dailyCarbohydrates: 0,
            dailyFat: 0,
            activityLevel: .moderatelyActive,
            goal: goal,
            bmr: 1600,
            tdee: calories // Simplified for testing
        )
        return goals
    }
}

// MARK: - HKBiologicalSex Extension Tests

final class HKBiologicalSexExtensionTests: XCTestCase {
    
    func testStringRepresentation() {
        XCTAssertEqual(HKBiologicalSex.male.stringRepresentation, "male")
        XCTAssertEqual(HKBiologicalSex.female.stringRepresentation, "female")
        XCTAssertEqual(HKBiologicalSex.other.stringRepresentation, "other")
        XCTAssertEqual(HKBiologicalSex.notSet.stringRepresentation, "unknown")
    }
}