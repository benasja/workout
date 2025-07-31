import Foundation
import SwiftData

@Model
final class FoodLog: @unchecked Sendable {
    var id: UUID
    var timestamp: Date
    var name: String
    var calories: Double
    var protein: Double
    var carbohydrates: Double
    var fat: Double
    var mealTypeRawValue: String
    var servingSize: Double
    var servingUnit: String
    var barcode: String?
    var customFoodId: UUID?
    
    init(
        timestamp: Date = Date(),
        name: String,
        calories: Double,
        protein: Double,
        carbohydrates: Double,
        fat: Double,
        mealType: MealType,
        servingSize: Double = 1.0,
        servingUnit: String = "serving",
        barcode: String? = nil,
        customFoodId: UUID? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.mealTypeRawValue = mealType.rawValue
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.barcode = barcode
        self.customFoodId = customFoodId
    }
    
    // MARK: - Computed Properties
    
    var mealType: MealType {
        get { MealType(rawValue: mealTypeRawValue) ?? .breakfast }
        set { mealTypeRawValue = newValue.rawValue }
    }
    
    /// Calculates total calories from macronutrients (4 cal/g protein, 4 cal/g carbs, 9 cal/g fat)
    var totalMacroCalories: Double {
        (protein * 4) + (carbohydrates * 4) + (fat * 9)
    }
    
    /// Indicates if this is a quick add entry (no specific food item)
    var isQuickAdd: Bool {
        customFoodId == nil && barcode == nil
    }
    
    /// Validates that macro calories are reasonably close to stated calories
    var hasValidMacros: Bool {
        guard calories > 0 else { return false }
        let difference = abs(calories - totalMacroCalories)
        
        // For very small calorie differences, be very lenient
        if difference <= 25 {
            return true // Allow up to 25 calorie difference regardless of percentage
        }
        
        // For larger differences, check percentage (30% tolerance for real-world data)
        let percentDifference = difference / calories
        return percentDifference <= 0.3
    }
    
    /// Returns formatted serving size with unit
    var formattedServing: String {
        if servingSize == 1.0 {
            return "1 \(servingUnit)"
        } else if servingSize.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(servingSize)) \(servingUnit)"
        } else {
            return String(format: "%.1f", servingSize) + " \(servingUnit)"
        }
    }
}

// MARK: - MealType Enum

enum MealType: String, CaseIterable, Codable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    case snacks = "snacks"
    
    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snacks: return "Snacks"
        }
    }
    
    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "sunset.fill"
        case .snacks: return "star.fill"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .breakfast: return 0
        case .lunch: return 1
        case .dinner: return 2
        case .snacks: return 3
        }
    }
}