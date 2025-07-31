import Foundation
import SwiftData

@Model
final class CustomFood: @unchecked Sendable {
    var id: UUID
    var name: String
    var caloriesPerServing: Double
    var proteinPerServing: Double
    var carbohydratesPerServing: Double
    var fatPerServing: Double
    var servingSize: Double
    var servingUnit: String
    var createdDate: Date
    var isComposite: Bool
    var ingredientsData: Data? // Encoded CustomFoodIngredient array for composite meals
    
    init(
        name: String,
        caloriesPerServing: Double,
        proteinPerServing: Double,
        carbohydratesPerServing: Double,
        fatPerServing: Double,
        servingSize: Double = 1.0,
        servingUnit: String = "serving",
        isComposite: Bool = false,
        ingredients: [CustomFoodIngredient] = []
    ) {
        self.id = UUID()
        self.name = name
        self.caloriesPerServing = caloriesPerServing
        self.proteinPerServing = proteinPerServing
        self.carbohydratesPerServing = carbohydratesPerServing
        self.fatPerServing = fatPerServing
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.createdDate = Date()
        self.isComposite = isComposite
        
        // Encode ingredients if provided
        if !ingredients.isEmpty {
            self.ingredientsData = try? JSONEncoder().encode(ingredients)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Calculates total calories from macronutrients per serving
    var totalMacroCalories: Double {
        (proteinPerServing * 4) + (carbohydratesPerServing * 4) + (fatPerServing * 9)
    }
    
    /// Validates that macro calories are reasonably close to stated calories
    var hasValidMacros: Bool {
        guard caloriesPerServing > 0 else { return false }
        let difference = abs(caloriesPerServing - totalMacroCalories)
        
        // For very small calorie differences, be very lenient
        if difference <= 25 {
            return true // Allow up to 25 calorie difference regardless of percentage
        }
        
        // For larger differences, check percentage (30% tolerance for real-world data)
        let percentDifference = difference / caloriesPerServing
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
    
    /// Decoded ingredients for composite meals
    var ingredients: [CustomFoodIngredient] {
        get {
            guard let data = ingredientsData else { return [] }
            return (try? JSONDecoder().decode([CustomFoodIngredient].self, from: data)) ?? []
        }
        set {
            ingredientsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    // MARK: - Validation Methods
    
    /// Validates all nutritional values are non-negative
    var hasValidNutrition: Bool {
        return caloriesPerServing >= 0 &&
               proteinPerServing >= 0 &&
               carbohydratesPerServing >= 0 &&
               fatPerServing >= 0 &&
               servingSize > 0
    }
    
    /// Validates that the food name is not empty and reasonable
    var hasValidName: Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               name.count <= 100
    }
    
    /// Overall validation check
    var isValid: Bool {
        return hasValidName && hasValidNutrition && hasValidMacros
    }
}

// MARK: - CustomFoodIngredient

struct CustomFoodIngredient: Codable, Identifiable {
    let id: UUID
    let name: String
    let quantity: Double
    let unit: String
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    
    init(
        name: String,
        quantity: Double,
        unit: String,
        calories: Double,
        protein: Double,
        carbohydrates: Double,
        fat: Double
    ) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
    }
    
    /// Formatted quantity with unit
    var formattedQuantity: String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(quantity)) \(unit)"
        } else {
            return String(format: "%.1f", quantity) + " \(unit)"
        }
    }
}