import Foundation
import SwiftData
import HealthKit

@Model
final class NutritionGoals: @unchecked Sendable {
    var id: UUID
    var userId: String // For future multi-user support
    var dailyCalories: Double
    var dailyProtein: Double
    var dailyCarbohydrates: Double
    var dailyFat: Double
    var activityLevelRawValue: String
    var goalRawValue: String
    var bmr: Double
    var tdee: Double
    var lastUpdated: Date
    
    // HealthKit derived data
    var weight: Double?
    var height: Double?
    var age: Int?
    var biologicalSex: String?
    
    init(
        userId: String = "default",
        dailyCalories: Double,
        dailyProtein: Double,
        dailyCarbohydrates: Double,
        dailyFat: Double,
        activityLevel: ActivityLevel,
        goal: NutritionGoal,
        bmr: Double,
        tdee: Double,
        weight: Double? = nil,
        height: Double? = nil,
        age: Int? = nil,
        biologicalSex: String? = nil
    ) {
        self.id = UUID()
        self.userId = userId
        self.dailyCalories = dailyCalories
        self.dailyProtein = dailyProtein
        self.dailyCarbohydrates = dailyCarbohydrates
        self.dailyFat = dailyFat
        self.activityLevelRawValue = activityLevel.rawValue
        self.goalRawValue = goal.rawValue
        self.bmr = bmr
        self.tdee = tdee
        self.lastUpdated = Date()
        self.weight = weight
        self.height = height
        self.age = age
        self.biologicalSex = biologicalSex
    }
    
    // MARK: - Computed Properties
    
    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityLevelRawValue) ?? .sedentary }
        set { 
            activityLevelRawValue = newValue.rawValue
            lastUpdated = Date()
        }
    }
    
    var goal: NutritionGoal {
        get { NutritionGoal(rawValue: goalRawValue) ?? .maintain }
        set { 
            goalRawValue = newValue.rawValue
            lastUpdated = Date()
        }
    }
    
    /// Calculates total calories from macronutrients
    var totalMacroCalories: Double {
        (dailyProtein * 4) + (dailyCarbohydrates * 4) + (dailyFat * 9)
    }
    
    /// Validates that macro calories align with total calories (within 5%)
    var hasValidMacros: Bool {
        guard dailyCalories > 0 else { return false }
        let difference = abs(dailyCalories - totalMacroCalories)
        let percentDifference = difference / dailyCalories
        return percentDifference <= 0.05 // Allow 5% variance for goals
    }
    
    /// Returns protein as percentage of total calories
    var proteinPercentage: Double {
        guard dailyCalories > 0 else { return 0 }
        return (dailyProtein * 4) / dailyCalories * 100
    }
    
    /// Returns carbohydrates as percentage of total calories
    var carbohydratesPercentage: Double {
        guard dailyCalories > 0 else { return 0 }
        return (dailyCarbohydrates * 4) / dailyCalories * 100
    }
    
    /// Returns fat as percentage of total calories
    var fatPercentage: Double {
        guard dailyCalories > 0 else { return 0 }
        return (dailyFat * 9) / dailyCalories * 100
    }
    
    /// Indicates if goals need recalculation (older than 30 days)
    var needsUpdate: Bool {
        Date().timeIntervalSince(lastUpdated) > 30 * 24 * 60 * 60 // 30 days
    }
    
    // MARK: - Goal Calculation Methods
    
    /// Updates goals based on current TDEE and selected goal
    func updateGoalsFromTDEE() {
        let adjustedCalories = tdee + goal.calorieAdjustment
        dailyCalories = adjustedCalories
        
        // Apply standard macro distribution based on goal
        switch goal {
        case .cut:
            // Higher protein for muscle preservation during cut
            dailyProtein = adjustedCalories * 0.35 / 4 // 35% protein
            dailyFat = adjustedCalories * 0.25 / 9     // 25% fat
            dailyCarbohydrates = adjustedCalories * 0.40 / 4 // 40% carbs
        case .maintain:
            // Balanced macros for maintenance
            dailyProtein = adjustedCalories * 0.25 / 4 // 25% protein
            dailyFat = adjustedCalories * 0.30 / 9     // 30% fat
            dailyCarbohydrates = adjustedCalories * 0.45 / 4 // 45% carbs
        case .bulk:
            // Higher carbs for energy during bulk
            dailyProtein = adjustedCalories * 0.20 / 4 // 20% protein
            dailyFat = adjustedCalories * 0.25 / 9     // 25% fat
            dailyCarbohydrates = adjustedCalories * 0.55 / 4 // 55% carbs
        }
        
        lastUpdated = Date()
    }
    
    /// Calculates BMR using Mifflin-St Jeor formula
    static func calculateBMR(weight: Double, height: Double, age: Int, biologicalSex: HKBiologicalSex) -> Double {
        let baseRate: Double
        switch biologicalSex {
        case .male:
            baseRate = (10 * weight) + (6.25 * height) - (5 * Double(age)) + 5
        case .female:
            baseRate = (10 * weight) + (6.25 * height) - (5 * Double(age)) - 161
        default:
            // Use average of male and female formulas for other/unknown
            let maleRate = (10 * weight) + (6.25 * height) - (5 * Double(age)) + 5
            let femaleRate = (10 * weight) + (6.25 * height) - (5 * Double(age)) - 161
            baseRate = (maleRate + femaleRate) / 2
        }
        return max(baseRate, 1000) // Minimum 1000 calories BMR
    }
    
    /// Calculates TDEE from BMR and activity level
    static func calculateTDEE(bmr: Double, activityLevel: ActivityLevel) -> Double {
        return bmr * activityLevel.multiplier
    }
}

// MARK: - ActivityLevel Enum

enum ActivityLevel: String, CaseIterable, Codable {
    case sedentary = "sedentary"
    case lightlyActive = "lightly_active"
    case moderatelyActive = "moderately_active"
    case veryActive = "very_active"
    case extremelyActive = "extremely_active"
    
    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .lightlyActive: return "Lightly Active"
        case .moderatelyActive: return "Moderately Active"
        case .veryActive: return "Very Active"
        case .extremelyActive: return "Extremely Active"
        }
    }
    
    var description: String {
        switch self {
        case .sedentary: return "Little or no exercise"
        case .lightlyActive: return "Light exercise 1-3 days/week"
        case .moderatelyActive: return "Moderate exercise 3-5 days/week"
        case .veryActive: return "Hard exercise 6-7 days/week"
        case .extremelyActive: return "Very hard exercise, physical job"
        }
    }
    
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        case .extremelyActive: return 1.9
        }
    }
}

// MARK: - NutritionGoal Enum

enum NutritionGoal: String, CaseIterable, Codable {
    case cut = "cut"
    case maintain = "maintain"
    case bulk = "bulk"
    
    var displayName: String {
        switch self {
        case .cut: return "Cut (Lose Weight)"
        case .maintain: return "Maintain Weight"
        case .bulk: return "Bulk (Gain Weight)"
        }
    }
    
    var description: String {
        switch self {
        case .cut: return "500 calorie deficit for weight loss"
        case .maintain: return "Maintain current weight"
        case .bulk: return "300 calorie surplus for weight gain"
        }
    }
    
    var calorieAdjustment: Double {
        switch self {
        case .cut: return -500 // 500 calorie deficit
        case .maintain: return 0
        case .bulk: return 300 // 300 calorie surplus
        }
    }
    
    var icon: String {
        switch self {
        case .cut: return "arrow.down.circle.fill"
        case .maintain: return "equal.circle.fill"
        case .bulk: return "arrow.up.circle.fill"
        }
    }
}