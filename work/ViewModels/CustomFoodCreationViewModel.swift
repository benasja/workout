import Foundation
import SwiftUI

@MainActor
final class CustomFoodCreationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var name: String = ""
    @Published var calories: Double = 0.0
    @Published var protein: Double = 0.0
    @Published var carbohydrates: Double = 0.0
    @Published var fat: Double = 0.0
    @Published var servingSize: Double = 1.0
    @Published var servingUnit: String = "serving"
    @Published var isComposite: Bool = false
    @Published var ingredients: [CustomFoodIngredient] = []
    
    @Published var isLoading: Bool = false
    @Published var showingError: Bool = false
    @Published var errorMessage: String = ""
    @Published var shouldDismiss: Bool = false
    
    // Enhanced error handling
    @Published var errorHandler = ErrorHandler()
    @Published var loadingManager = LoadingStateManager()
    
    // MARK: - Dependencies
    let repository: FuelLogRepositoryProtocol
    private let existingFood: CustomFood?
    
    // MARK: - Computed Properties
    
    var calculatedCalories: Double {
        ingredients.reduce(0) { $0 + $1.calories }
    }
    
    var calculatedProtein: Double {
        ingredients.reduce(0) { $0 + $1.protein }
    }
    
    var calculatedCarbohydrates: Double {
        ingredients.reduce(0) { $0 + $1.carbohydrates }
    }
    
    var calculatedFat: Double {
        ingredients.reduce(0) { $0 + $1.fat }
    }
    
    var isValid: Bool {
        validationMessages.isEmpty
    }
    
    var validationMessages: [String] {
        var messages: [String] = []
        
        // Name validation
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            messages.append("Food name is required")
        } else if trimmedName.count > 100 {
            messages.append("Food name must be 100 characters or less")
        }
        
        // Nutrition validation for simple foods
        if !isComposite {
            if calories < 0 {
                messages.append("Calories cannot be negative")
            } else if calories > 10000 {
                messages.append("Calories seem unreasonably high (>10,000)")
            }
            
            if protein < 0 {
                messages.append("Protein cannot be negative")
            } else if protein > 1000 {
                messages.append("Protein seems unreasonably high (>1,000g)")
            }
            
            if carbohydrates < 0 {
                messages.append("Carbohydrates cannot be negative")
            } else if carbohydrates > 1000 {
                messages.append("Carbohydrates seem unreasonably high (>1,000g)")
            }
            
            if fat < 0 {
                messages.append("Fat cannot be negative")
            } else if fat > 1000 {
                messages.append("Fat seems unreasonably high (>1,000g)")
            }
            
            // Macro consistency validation
            if calories > 10 {
                let macroCalories = (protein * 4) + (carbohydrates * 4) + (fat * 9)
                let difference = abs(calories - macroCalories)
                let percentDifference = difference / calories
                
                if percentDifference > 0.15 { // Allow 15% variance for user input
                    messages.append("Macro calories (\(String(format: "%.0f", macroCalories))) don't match stated calories (\(String(format: "%.0f", calories)))")
                }
            }
        }
        
        // Composite meal validation
        if isComposite {
            if ingredients.isEmpty {
                messages.append("Composite meals must have at least one ingredient")
            }
        }
        
        // Serving validation
        if servingSize <= 0 {
            messages.append("Serving size must be greater than 0")
        } else if servingSize > 1000 {
            messages.append("Serving size seems unreasonably large")
        }
        
        if servingUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append("Serving unit is required")
        }
        
        return messages
    }
    
    // MARK: - Initialization
    
    init(repository: FuelLogRepositoryProtocol, existingFood: CustomFood? = nil) {
        self.repository = repository
        self.existingFood = existingFood
        
        if let food = existingFood {
            loadExistingFood(food)
        }
    }
    
    // MARK: - Public Methods
    
    func addIngredient(_ ingredient: CustomFoodIngredient) {
        ingredients.append(ingredient)
        
        // If this is the first ingredient and we're in composite mode,
        // set reasonable defaults for serving info
        if ingredients.count == 1 && isComposite {
            if servingUnit == "serving" {
                servingUnit = "recipe"
            }
        }
    }
    
    func removeIngredient(_ ingredient: CustomFoodIngredient) {
        ingredients.removeAll { $0.id == ingredient.id }
    }
    
    func saveCustomFood() async {
        guard isValid else {
            showError("Please fix validation errors before saving")
            return
        }
        
        isLoading = true
        let customFood = createCustomFood()
        let isUpdate = existingFood != nil
        
        loadingManager.startLoading(
            taskId: "save-custom-food",
            message: isUpdate ? "Updating \(customFood.name)..." : "Saving \(customFood.name)..."
        )
        
        do {
            if isUpdate {
                // Update existing food
                try await repository.updateCustomFood(customFood)
            } else {
                // Create new food
                try await repository.saveCustomFood(customFood)
            }
            
            shouldDismiss = true
        } catch {
            errorHandler.handleError(
                error,
                context: isUpdate ? "Updating custom food" : "Creating custom food"
            ) { [weak self] in
                await self?.saveCustomFood()
            }
        }
        
        isLoading = false
        loadingManager.stopLoading(taskId: "save-custom-food")
    }
    
    // MARK: - Private Methods
    
    private func loadExistingFood(_ food: CustomFood) {
        name = food.name
        calories = food.caloriesPerServing
        protein = food.proteinPerServing
        carbohydrates = food.carbohydratesPerServing
        fat = food.fatPerServing
        servingSize = food.servingSize
        servingUnit = food.servingUnit
        isComposite = food.isComposite
        ingredients = food.ingredients
    }
    
    private func createCustomFood() -> CustomFood {
        let finalCalories: Double
        let finalProtein: Double
        let finalCarbohydrates: Double
        let finalFat: Double
        
        if isComposite {
            // Use calculated values from ingredients
            finalCalories = calculatedCalories
            finalProtein = calculatedProtein
            finalCarbohydrates = calculatedCarbohydrates
            finalFat = calculatedFat
        } else {
            // Use manually entered values
            finalCalories = calories
            finalProtein = protein
            finalCarbohydrates = carbohydrates
            finalFat = fat
        }
        
        if let existing = existingFood {
            // Update existing food properties
            existing.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.caloriesPerServing = finalCalories
            existing.proteinPerServing = finalProtein
            existing.carbohydratesPerServing = finalCarbohydrates
            existing.fatPerServing = finalFat
            existing.servingSize = servingSize
            existing.servingUnit = servingUnit.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.isComposite = isComposite
            existing.ingredients = ingredients
            return existing
        } else {
            // Create new food
            return CustomFood(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                caloriesPerServing: finalCalories,
                proteinPerServing: finalProtein,
                carbohydratesPerServing: finalCarbohydrates,
                fatPerServing: finalFat,
                servingSize: servingSize,
                servingUnit: servingUnit.trimmingCharacters(in: .whitespacesAndNewlines),
                isComposite: isComposite,
                ingredients: ingredients
            )
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}