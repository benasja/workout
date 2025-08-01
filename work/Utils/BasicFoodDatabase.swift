import Foundation

/// A simple built-in food database with common foods
struct BasicFoodDatabase {
    static let shared = BasicFoodDatabase()
    
    private init() {}
    
    /// Basic food items with nutrition information - European measurements and whole numbers
    let foods: [BasicFoodItem] = [
        // Fruits
        BasicFoodItem(name: "Banana", calories: 89, protein: 1, carbs: 23, fat: 0, servingSize: 1, servingUnit: "banana"),
        BasicFoodItem(name: "Apple", calories: 52, protein: 0, carbs: 14, fat: 0, servingSize: 1, servingUnit: "apple"),
        BasicFoodItem(name: "Orange", calories: 47, protein: 1, carbs: 12, fat: 0, servingSize: 1, servingUnit: "orange"),
        BasicFoodItem(name: "Strawberries", calories: 32, protein: 1, carbs: 8, fat: 0, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Blueberries", calories: 57, protein: 1, carbs: 15, fat: 0, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Grapes", calories: 62, protein: 1, carbs: 16, fat: 0, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Pineapple", calories: 50, protein: 1, carbs: 13, fat: 0, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Mango", calories: 60, protein: 1, carbs: 15, fat: 0, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Kiwi", calories: 61, protein: 1, carbs: 15, fat: 1, servingSize: 1, servingUnit: "kiwi"),
        BasicFoodItem(name: "Peach", calories: 39, protein: 1, carbs: 10, fat: 0, servingSize: 1, servingUnit: "peach"),
        
        // Vegetables
        BasicFoodItem(name: "Broccoli", calories: 34, protein: 3, carbs: 7, fat: 0, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Spinach", calories: 23, protein: 3, carbs: 4, fat: 0, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Carrots", calories: 41, protein: 1, carbs: 10, fat: 0, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Bell Pepper", calories: 31, protein: 1, carbs: 7, fat: 0, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Tomato", calories: 18, protein: 1, carbs: 4, fat: 0, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Cucumber", calories: 16, protein: 1, carbs: 4, fat: 0, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Lettuce", calories: 15, protein: 1, carbs: 3, fat: 0, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Onion", calories: 40, protein: 1, carbs: 9, fat: 0, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Mushrooms", calories: 22, protein: 3, carbs: 3, fat: 0, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Zucchini", calories: 17, protein: 1, carbs: 3, fat: 0, servingSize: 100, servingUnit: "g"),
        
        // Proteins
        BasicFoodItem(name: "Chicken Breast", calories: 165, protein: 31, carbs: 0, fat: 4, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Salmon", calories: 208, protein: 22, carbs: 0, fat: 12, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Tuna", calories: 132, protein: 28, carbs: 0, fat: 1, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Cod", calories: 82, protein: 18, carbs: 0, fat: 1, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Turkey Breast", calories: 135, protein: 30, carbs: 0, fat: 1, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Lean Beef", calories: 250, protein: 26, carbs: 0, fat: 15, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Pork Tenderloin", calories: 143, protein: 26, carbs: 0, fat: 4, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Eggs", calories: 155, protein: 13, carbs: 1, fat: 11, servingSize: 1, servingUnit: "egg"),
        BasicFoodItem(name: "Tofu", calories: 76, protein: 8, carbs: 2, fat: 5, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Tempeh", calories: 193, protein: 19, carbs: 9, fat: 11, servingSize: 100, servingUnit: "g"),
        
        // Grains & Starches
        BasicFoodItem(name: "Brown Rice", calories: 111, protein: 3, carbs: 22, fat: 1, servingSize: 100, servingUnit: "g cooked"),
        BasicFoodItem(name: "White Rice", calories: 130, protein: 3, carbs: 28, fat: 0, servingSize: 100, servingUnit: "g cooked"),
        BasicFoodItem(name: "Quinoa", calories: 222, protein: 8, carbs: 39, fat: 4, servingSize: 100, servingUnit: "g cooked"),
        BasicFoodItem(name: "Oats", calories: 389, protein: 17, carbs: 66, fat: 7, servingSize: 50, servingUnit: "g dry"),
        BasicFoodItem(name: "Sweet Potato", calories: 86, protein: 2, carbs: 20, fat: 0, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Potato", calories: 77, protein: 2, carbs: 17, fat: 0, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Whole Wheat Bread", calories: 247, protein: 13, carbs: 41, fat: 4, servingSize: 1, servingUnit: "slice"),
        BasicFoodItem(name: "White Bread", calories: 265, protein: 9, carbs: 49, fat: 3, servingSize: 1, servingUnit: "slice"),
        BasicFoodItem(name: "Pasta", calories: 131, protein: 5, carbs: 25, fat: 1, servingSize: 100, servingUnit: "g cooked"),
        BasicFoodItem(name: "Couscous", calories: 112, protein: 4, carbs: 23, fat: 0, servingSize: 100, servingUnit: "g cooked"),
        
        // Dairy
        BasicFoodItem(name: "Milk (2%)", calories: 50, protein: 3, carbs: 5, fat: 2, servingSize: 100, servingUnit: "ml"),
        BasicFoodItem(name: "Whole Milk", calories: 61, protein: 3, carbs: 5, fat: 3, servingSize: 100, servingUnit: "ml"),
        BasicFoodItem(name: "Skimmed Milk", calories: 34, protein: 3, carbs: 5, fat: 0, servingSize: 100, servingUnit: "ml"),
        BasicFoodItem(name: "Greek Yogurt", calories: 59, protein: 10, carbs: 4, fat: 0, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Natural Yogurt", calories: 61, protein: 4, carbs: 5, fat: 3, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Cheddar Cheese", calories: 403, protein: 25, carbs: 1, fat: 33, servingSize: 30, servingUnit: "g"),
        BasicFoodItem(name: "Mozzarella", calories: 280, protein: 28, carbs: 3, fat: 17, servingSize: 30, servingUnit: "g"),
        BasicFoodItem(name: "Cottage Cheese", calories: 98, protein: 11, carbs: 3, fat: 4, servingSize: 100, servingUnit: "g"),
        BasicFoodItem(name: "Feta Cheese", calories: 264, protein: 14, carbs: 4, fat: 21, servingSize: 30, servingUnit: "g"),
        
        // Nuts & Seeds
        BasicFoodItem(name: "Almonds", calories: 579, protein: 21, carbs: 22, fat: 50, servingSize: 30, servingUnit: "g"),
        BasicFoodItem(name: "Walnuts", calories: 654, protein: 15, carbs: 14, fat: 65, servingSize: 30, servingUnit: "g"),
        BasicFoodItem(name: "Cashews", calories: 553, protein: 18, carbs: 30, fat: 44, servingSize: 30, servingUnit: "g"),
        BasicFoodItem(name: "Peanuts", calories: 567, protein: 26, carbs: 16, fat: 49, servingSize: 30, servingUnit: "g"),
        BasicFoodItem(name: "Peanut Butter", calories: 588, protein: 25, carbs: 20, fat: 50, servingSize: 20, servingUnit: "g"),
        BasicFoodItem(name: "Sunflower Seeds", calories: 584, protein: 21, carbs: 20, fat: 51, servingSize: 30, servingUnit: "g"),
        BasicFoodItem(name: "Pumpkin Seeds", calories: 559, protein: 30, carbs: 11, fat: 49, servingSize: 30, servingUnit: "g"),
        BasicFoodItem(name: "Chia Seeds", calories: 486, protein: 17, carbs: 42, fat: 31, servingSize: 15, servingUnit: "g"),
        
        // Legumes
        BasicFoodItem(name: "Black Beans", calories: 132, protein: 9, carbs: 24, fat: 1, servingSize: 100, servingUnit: "g cooked"),
        BasicFoodItem(name: "Chickpeas", calories: 164, protein: 9, carbs: 27, fat: 3, servingSize: 100, servingUnit: "g cooked"),
        BasicFoodItem(name: "Lentils", calories: 116, protein: 9, carbs: 20, fat: 0, servingSize: 100, servingUnit: "g cooked"),
        BasicFoodItem(name: "Kidney Beans", calories: 127, protein: 9, carbs: 23, fat: 1, servingSize: 100, servingUnit: "g cooked"),
        BasicFoodItem(name: "White Beans", calories: 139, protein: 10, carbs: 25, fat: 1, servingSize: 100, servingUnit: "g cooked"),
        BasicFoodItem(name: "Green Peas", calories: 81, protein: 5, carbs: 14, fat: 0, servingSize: 100, servingUnit: "g"),
        
        // Beverages
        BasicFoodItem(name: "Orange Juice", calories: 45, protein: 1, carbs: 10, fat: 0, servingSize: 100, servingUnit: "ml"),
        BasicFoodItem(name: "Apple Juice", calories: 46, protein: 0, carbs: 11, fat: 0, servingSize: 100, servingUnit: "ml"),
        BasicFoodItem(name: "Green Tea", calories: 1, protein: 0, carbs: 0, fat: 0, servingSize: 100, servingUnit: "ml"),
        BasicFoodItem(name: "Coffee", calories: 2, protein: 0, carbs: 0, fat: 0, servingSize: 100, servingUnit: "ml"),
        
        // Other
        BasicFoodItem(name: "Avocado", calories: 160, protein: 2, carbs: 9, fat: 15, servingSize: 1, servingUnit: "avocado"),
        BasicFoodItem(name: "Olive Oil", calories: 884, protein: 0, carbs: 0, fat: 100, servingSize: 100, servingUnit: "ml"),
        BasicFoodItem(name: "Coconut Oil", calories: 862, protein: 0, carbs: 0, fat: 100, servingSize: 100, servingUnit: "ml"),
        BasicFoodItem(name: "Honey", calories: 304, protein: 0, carbs: 82, fat: 0, servingSize: 20, servingUnit: "g"),
        BasicFoodItem(name: "Dark Chocolate", calories: 546, protein: 8, carbs: 46, fat: 31, servingSize: 20, servingUnit: "g")
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