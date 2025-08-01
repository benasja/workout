import Foundation

/// Enum for different nutrient types used throughout the app
enum NutrientType: CaseIterable {
    case calories
    case protein
    case carbohydrates
    case fat
    
    var displayName: String {
        switch self {
        case .calories:
            return "Calories"
        case .protein:
            return "Protein"
        case .carbohydrates:
            return "Carbs"
        case .fat:
            return "Fat"
        }
    }
    
    var unit: String {
        switch self {
        case .calories:
            return "kcal"
        case .protein, .carbohydrates, .fat:
            return "g"
        }
    }
} 