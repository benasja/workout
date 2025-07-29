import Foundation

/// Helper structure for calculating and tracking daily nutrition totals
struct DailyNutritionTotals {
    var totalCalories: Double = 0
    var totalProtein: Double = 0
    var totalCarbohydrates: Double = 0
    var totalFat: Double = 0
    
    /// Calculates total calories from macronutrients
    var caloriesFromMacros: Double {
        (totalProtein * 4) + (totalCarbohydrates * 4) + (totalFat * 9)
    }
    
    /// Indicates if macro calories align with total calories (within 5%)
    var hasValidMacros: Bool {
        guard totalCalories > 0 else { return totalProtein == 0 && totalCarbohydrates == 0 && totalFat == 0 }
        let difference = abs(totalCalories - caloriesFromMacros)
        let percentDifference = difference / totalCalories
        return percentDifference <= 0.05
    }
    
    /// Adds a food log entry to the totals
    mutating func add(_ foodLog: FoodLog) {
        totalCalories += foodLog.calories
        totalProtein += foodLog.protein
        totalCarbohydrates += foodLog.carbohydrates
        totalFat += foodLog.fat
    }
    
    /// Subtracts a food log entry from the totals
    mutating func subtract(_ foodLog: FoodLog) {
        totalCalories = max(0, totalCalories - foodLog.calories)
        totalProtein = max(0, totalProtein - foodLog.protein)
        totalCarbohydrates = max(0, totalCarbohydrates - foodLog.carbohydrates)
        totalFat = max(0, totalFat - foodLog.fat)
    }
    
    /// Resets all totals to zero
    mutating func reset() {
        totalCalories = 0
        totalProtein = 0
        totalCarbohydrates = 0
        totalFat = 0
    }
    
    /// Calculates remaining values against goals
    func remaining(against goals: NutritionGoals) -> DailyNutritionTotals {
        return DailyNutritionTotals(
            totalCalories: max(0, goals.dailyCalories - totalCalories),
            totalProtein: max(0, goals.dailyProtein - totalProtein),
            totalCarbohydrates: max(0, goals.dailyCarbohydrates - totalCarbohydrates),
            totalFat: max(0, goals.dailyFat - totalFat)
        )
    }
    
    /// Calculates progress percentages against goals
    func progress(against goals: NutritionGoals) -> NutritionProgress {
        return NutritionProgress(
            caloriesProgress: goals.dailyCalories > 0 ? min(1.0, totalCalories / goals.dailyCalories) : 0,
            proteinProgress: goals.dailyProtein > 0 ? min(1.0, totalProtein / goals.dailyProtein) : 0,
            carbohydratesProgress: goals.dailyCarbohydrates > 0 ? min(1.0, totalCarbohydrates / goals.dailyCarbohydrates) : 0,
            fatProgress: goals.dailyFat > 0 ? min(1.0, totalFat / goals.dailyFat) : 0
        )
    }
    
    /// Calculates totals grouped by meal type
    static func calculateByMealType(_ foodLogs: [FoodLog]) -> [MealType: DailyNutritionTotals] {
        var mealTotals: [MealType: DailyNutritionTotals] = [:]
        
        for mealType in MealType.allCases {
            mealTotals[mealType] = DailyNutritionTotals()
        }
        
        for foodLog in foodLogs {
            mealTotals[foodLog.mealType]?.add(foodLog)
        }
        
        return mealTotals
    }
}

/// Helper structure for tracking nutrition progress percentages
struct NutritionProgress {
    let caloriesProgress: Double
    let proteinProgress: Double
    let carbohydratesProgress: Double
    let fatProgress: Double
    
    /// Indicates if any goal has been completed (100% or more)
    var hasCompletedGoals: Bool {
        return caloriesProgress >= 1.0 || 
               proteinProgress >= 1.0 || 
               carbohydratesProgress >= 1.0 || 
               fatProgress >= 1.0
    }
    
    /// Returns the number of completed goals
    var completedGoalsCount: Int {
        var count = 0
        if caloriesProgress >= 1.0 { count += 1 }
        if proteinProgress >= 1.0 { count += 1 }
        if carbohydratesProgress >= 1.0 { count += 1 }
        if fatProgress >= 1.0 { count += 1 }
        return count
    }
    
    /// Overall progress as average of all macros
    var overallProgress: Double {
        return (caloriesProgress + proteinProgress + carbohydratesProgress + fatProgress) / 4.0
    }
}