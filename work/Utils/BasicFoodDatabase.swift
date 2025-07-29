import Foundation

/// A simple built-in food database with common foods
struct BasicFoodDatabase {
    static let shared = BasicFoodDatabase()
    
    private init() {}
    
    /// Basic food items with nutrition information per 100g
    let foods: [BasicFoodItem] = [
        // Fruits
        BasicFoodItem(name: "Banana", calories: 89, protein: 1.1, carbs: 22.8, fat: 0.3, servingSize: 1, servingUnit: "medium banana"),
        BasicFoodItem(name: "Apple", calories: 52, protein: 0.3, carbs: 13.8, fat: 0.2, servingSize: 1, servingUnit: "medium apple"),
        BasicFoodItem(name: "Orange", calories: 47, protein: 0.9, carbs: 11.8, fat: 0.1, servingSize: 1, servingUnit: "medium orange"),
        BasicFoodItem(name: "Strawberries", calories: 32, protein: 0.7, carbs: 7.7, fat: 0.3, servingSize: 1, servingUnit: "cup"),
        BasicFoodItem(name: "Blueberries", calories: 57, protein: 0.7, carbs: 14.5, fat: 0.3, servingSize: 1, servingUnit: "cup"),
        
        // Vegetables
        BasicFoodItem(name: "Broccoli", calories: 34, protein: 2.8, carbs: 7.0, fat: 0.4, servingSize: 1, servingUnit: "cup chopped"),
        BasicFoodItem(name: "Spinach", calories: 23, protein: 2.9, carbs: 3.6, fat: 0.4, servingSize: 1, servingUnit: "cup"),
        BasicFoodItem(name: "Carrots", calories: 41, protein: 0.9, carbs: 9.6, fat: 0.2, servingSize: 1, servingUnit: "medium carrot"),
        BasicFoodItem(name: "Bell Pepper", calories: 31, protein: 1.0, carbs: 7.3, fat: 0.3, servingSize: 1, servingUnit: "medium pepper"),
        BasicFoodItem(name: "Tomato", calories: 18, protein: 0.9, carbs: 3.9, fat: 0.2, servingSize: 1, servingUnit: "medium tomato"),
        
        // Proteins
        BasicFoodItem(name: "Chicken Breast", calories: 165, protein: 31.0, carbs: 0.0, fat: 3.6, servingSize: 1, servingUnit: "3 oz"),
        BasicFoodItem(name: "Salmon", calories: 208, protein: 22.1, carbs: 0.0, fat: 12.4, servingSize: 1, servingUnit: "3 oz"),
        BasicFoodItem(name: "Eggs", calories: 155, protein: 13.0, carbs: 1.1, fat: 11.0, servingSize: 1, servingUnit: "large egg"),
        BasicFoodItem(name: "Greek Yogurt", calories: 59, protein: 10.0, carbs: 3.6, fat: 0.4, servingSize: 1, servingUnit: "3/4 cup"),
        BasicFoodItem(name: "Tuna", calories: 132, protein: 28.0, carbs: 0.0, fat: 1.3, servingSize: 1, servingUnit: "3 oz"),
        
        // Grains & Starches
        BasicFoodItem(name: "Brown Rice", calories: 111, protein: 2.6, carbs: 22.0, fat: 0.9, servingSize: 1, servingUnit: "cup cooked"),
        BasicFoodItem(name: "Quinoa", calories: 222, protein: 8.1, carbs: 39.4, fat: 3.6, servingSize: 1, servingUnit: "cup cooked"),
        BasicFoodItem(name: "Oats", calories: 389, protein: 16.9, carbs: 66.3, fat: 6.9, servingSize: 1, servingUnit: "1/2 cup dry"),
        BasicFoodItem(name: "Sweet Potato", calories: 86, protein: 1.6, carbs: 20.1, fat: 0.1, servingSize: 1, servingUnit: "medium potato"),
        BasicFoodItem(name: "Whole Wheat Bread", calories: 247, protein: 13.0, carbs: 41.0, fat: 4.2, servingSize: 1, servingUnit: "slice"),
        
        // Dairy
        BasicFoodItem(name: "Milk (2%)", calories: 50, protein: 3.3, carbs: 4.8, fat: 2.0, servingSize: 1, servingUnit: "cup"),
        BasicFoodItem(name: "Cheddar Cheese", calories: 403, protein: 25.0, carbs: 1.3, fat: 33.0, servingSize: 1, servingUnit: "1 oz"),
        BasicFoodItem(name: "Cottage Cheese", calories: 98, protein: 11.1, carbs: 3.4, fat: 4.3, servingSize: 1, servingUnit: "1/2 cup"),
        
        // Nuts & Seeds
        BasicFoodItem(name: "Almonds", calories: 579, protein: 21.2, carbs: 21.6, fat: 49.9, servingSize: 1, servingUnit: "1 oz (23 nuts)"),
        BasicFoodItem(name: "Peanut Butter", calories: 588, protein: 25.1, carbs: 19.6, fat: 50.4, servingSize: 1, servingUnit: "2 tbsp"),
        BasicFoodItem(name: "Walnuts", calories: 654, protein: 15.2, carbs: 13.7, fat: 65.2, servingSize: 1, servingUnit: "1 oz (14 halves)"),
        
        // Legumes
        BasicFoodItem(name: "Black Beans", calories: 132, protein: 8.9, carbs: 23.7, fat: 0.5, servingSize: 1, servingUnit: "cup cooked"),
        BasicFoodItem(name: "Chickpeas", calories: 164, protein: 8.9, carbs: 27.4, fat: 2.6, servingSize: 1, servingUnit: "cup cooked"),
        BasicFoodItem(name: "Lentils", calories: 116, protein: 9.0, carbs: 20.1, fat: 0.4, servingSize: 1, servingUnit: "cup cooked"),
        
        // Other
        BasicFoodItem(name: "Avocado", calories: 160, protein: 2.0, carbs: 8.5, fat: 14.7, servingSize: 1, servingUnit: "medium avocado")
    ]
    
    /// Search foods by name (case-insensitive)
    func searchFoods(query: String) -> [BasicFoodItem] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return foods
        }
        
        let lowercaseQuery = query.lowercased()
        return foods.filter { food in
            food.name.lowercased().contains(lowercaseQuery)
        }
    }
    
    /// Convert BasicFoodItem to FoodSearchResult
    func convertToFoodSearchResult(_ basicFood: BasicFoodItem) -> FoodSearchResult {
        return FoodSearchResult(
            id: "basic_\(basicFood.name.replacingOccurrences(of: " ", with: "_").lowercased())",
            name: basicFood.name,
            brand: "Built-in Database",
            calories: basicFood.calories,
            protein: basicFood.protein,
            carbohydrates: basicFood.carbs,
            fat: basicFood.fat,
            servingSize: basicFood.servingSize,
            servingUnit: basicFood.servingUnit,
            imageUrl: nil,
            source: .custom,
            customFood: nil
        )
    }
}

/// Basic food item structure
struct BasicFoodItem {
    let name: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let servingSize: Double
    let servingUnit: String
}