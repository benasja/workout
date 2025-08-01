import Foundation
import SwiftData

@Model
final class FoodLog: @unchecked Sendable, Identifiable {
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
        // CRITICAL FIX: Do NOT normalize timestamp here - preserve the exact timestamp passed in
        // This allows the ViewModel to control the exact date/time when food is logged
        self.timestamp = timestamp
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.mealTypeRawValue = mealType.rawValue
        
        // Debug logging commented out - issue was in UI meal type selection
        // print("🍽️ FOODLOG INIT DEBUG: Creating food '\(name)' with meal type: \(mealType.displayName) (\(mealType.rawValue))")
        // print("🍽️ FOODLOG INIT DEBUG: Stored raw value: \(mealType.rawValue)")
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.barcode = barcode
        self.customFoodId = customFoodId
    }
    
    // MARK: - Computed Properties
    
    var mealType: MealType {
        get { 
            let result = MealType(rawValue: mealTypeRawValue) ?? .breakfast
            // Debug logging commented out - issue was in UI meal type selection
            // if result == .breakfast && mealTypeRawValue != "breakfast" {
            //     print("⚠️ MEAL TYPE WARNING: Raw value '\(mealTypeRawValue)' defaulted to breakfast for food ID \(id)")
            // }
            return result
        }
        set { 
            // print("🍽️ MEAL TYPE SET DEBUG: Setting meal type for food ID \(id) to \(newValue.displayName) (\(newValue.rawValue))")
            mealTypeRawValue = newValue.rawValue 
        }
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
        // Handle common serving units more intelligently
        let cleanUnit = servingUnit.lowercased()
        
        // For weight-based servings, show the actual amount
        if cleanUnit.contains("g") || cleanUnit.contains("gram") || 
           cleanUnit.contains("oz") || cleanUnit.contains("ounce") ||
           cleanUnit.contains("lb") || cleanUnit.contains("pound") {
            if servingSize.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(servingSize))\(servingUnit)"
            } else {
                return String(format: "%.1f", servingSize) + servingUnit
            }
        }
        
        // For volume-based servings, show the actual amount
        if cleanUnit.contains("ml") || cleanUnit.contains("l") || cleanUnit.contains("liter") ||
           cleanUnit.contains("cup") || cleanUnit.contains("tbsp") || cleanUnit.contains("tsp") ||
           cleanUnit.contains("fl oz") {
            if servingSize.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(servingSize)) \(servingUnit)"
            } else {
                return String(format: "%.1f", servingSize) + " \(servingUnit)"
            }
        }
        
        // For count-based items (pieces, slices, etc.), be more descriptive
        if cleanUnit.contains("piece") || cleanUnit.contains("slice") || 
           cleanUnit.contains("item") || cleanUnit == "serving" {
            if servingSize == 1.0 {
                return "1 \(servingUnit)"
            } else if servingSize.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(servingSize)) \(servingUnit)s"
            } else {
                return String(format: "%.1f", servingSize) + " \(servingUnit)s"
            }
        }
        
        // Default formatting
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