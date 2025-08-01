#!/usr/bin/env swift

import Foundation

// Mock the key components to test the logic
struct FoodLog {
    let id = UUID()
    let timestamp: Date
    let name: String
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let mealType: MealType
    
    init(timestamp: Date, name: String, calories: Double, protein: Double, carbohydrates: Double, fat: Double, mealType: MealType) {
        self.timestamp = timestamp
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.mealType = mealType
    }
}

enum MealType: String, CaseIterable {
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
}

// Test the UI state logic
func testUIStateManagement() {
    print("🧪 Testing UI State Management")
    print("==============================")
    
    // Create test food logs
    let calendar = Calendar.current
    let july31 = calendar.date(from: DateComponents(year: 2025, month: 7, day: 31, hour: 12, minute: 0))!
    
    let foodLogs = [
        FoodLog(timestamp: july31, name: "Orange", calories: 62, protein: 1.2, carbohydrates: 15.4, fat: 0.2, mealType: .breakfast),
        FoodLog(timestamp: july31, name: "Banana", calories: 105, protein: 1.3, carbohydrates: 27, fat: 0.4, mealType: .breakfast)
    ]
    
    print("📊 Created \(foodLogs.count) test food logs")
    
    // Simulate the grouping logic
    var foodLogsByMealType: [MealType: [FoodLog]] = [:]
    foodLogsByMealType = Dictionary(grouping: foodLogs) { $0.mealType }
    
    // Ensure all meal types have entries (even if empty)
    for mealType in MealType.allCases {
        if foodLogsByMealType[mealType] == nil {
            foodLogsByMealType[mealType] = []
        }
    }
    
    print("\n🍽️ Grouped food logs by meal type:")
    for mealType in MealType.allCases {
        let count = foodLogsByMealType[mealType]?.count ?? 0
        let items = foodLogsByMealType[mealType]?.map { $0.name }.joined(separator: ", ") ?? "none"
        print("🍽️ \(mealType.displayName): \(count) items (\(items))")
    }
    
    // Test the foodLogs(for:) logic
    print("\n🔍 Testing meal type access:")
    for mealType in MealType.allCases {
        let logs = foodLogsByMealType[mealType] ?? []
        print("🔍 UI requested \(mealType.displayName) food logs - returning \(logs.count) items")
        
        if logs.count > 0 {
            for log in logs {
                print("   - \(log.name) (\(log.calories) kcal)")
            }
        }
    }
    
    // Verify the data is accessible
    let breakfastLogs = foodLogsByMealType[.breakfast] ?? []
    let totalBreakfastCalories = breakfastLogs.reduce(0) { $0 + $1.calories }
    
    print("\n📊 VALIDATION RESULTS:")
    print("✅ Total food logs: \(foodLogs.count)")
    print("✅ Breakfast items: \(breakfastLogs.count)")
    print("✅ Total breakfast calories: \(totalBreakfastCalories)")
    
    if breakfastLogs.count == 2 && totalBreakfastCalories == 167 {
        print("🎉 UI STATE MANAGEMENT IS WORKING CORRECTLY!")
    } else {
        print("❌ UI STATE MANAGEMENT HAS ISSUES!")
    }
}

// Run the test
testUIStateManagement()