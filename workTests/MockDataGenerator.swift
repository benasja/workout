import Foundation
@testable import work

/// Centralized mock data generator for testing scenarios
final class MockDataGenerator {
    
    // MARK: - Singleton
    static let shared = MockDataGenerator()
    private init() {}
    
    // MARK: - FoodLog Mock Data
    
    func createMockFoodLog(
        name: String = "Test Food",
        calories: Double = 250,
        protein: Double = 15,
        carbohydrates: Double = 30,
        fat: Double = 8,
        mealType: MealType = .breakfast,
        timestamp: Date = Date(),
        servingSize: Double = 1,
        servingUnit: String = "serving",
        barcode: String? = nil,
        customFoodId: UUID? = nil
    ) -> FoodLog {
        return FoodLog(
            timestamp: timestamp,
            name: name,
            calories: calories,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat,
            mealType: mealType,
            servingSize: servingSize,
            servingUnit: servingUnit,
            barcode: barcode,
            customFoodId: customFoodId
        )
    }
    
    func createMockFoodLogs(count: Int = 5) -> [FoodLog] {
        let mealTypes: [MealType] = [.breakfast, .lunch, .dinner, .snacks]
        let foodNames = ["Chicken Breast", "Brown Rice", "Broccoli", "Salmon", "Sweet Potato", "Spinach", "Eggs", "Oatmeal", "Banana", "Greek Yogurt"]
        
        return (0..<count).map { index in
            let mealType = mealTypes[index % mealTypes.count]
            let name = foodNames[index % foodNames.count]
            
            return createMockFoodLog(
                name: "\(name) \(index + 1)",
                calories: Double.random(in: 100...500),
                protein: Double.random(in: 10...50),
                carbohydrates: Double.random(in: 15...80),
                fat: Double.random(in: 5...30),
                mealType: mealType,
                timestamp: Date().addingTimeInterval(TimeInterval(index * 3600)) // Spread across hours
            )
        }
    }
    
    func createMockFoodLogsForDate(_ date: Date, count: Int = 8) -> [FoodLog] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        return createMockFoodLogs(count: count).enumerated().map { index, foodLog in
            // Distribute throughout the day
            let hourOffset = (index % 4) * 4 + 8 // 8am, 12pm, 4pm, 8pm pattern
            let timestamp = calendar.date(byAdding: .hour, value: hourOffset, to: startOfDay) ?? startOfDay
            
            foodLog.timestamp = timestamp
            return foodLog
        }
    }
    
    // MARK: - CustomFood Mock Data
    
    func createMockCustomFood(
        name: String = "Custom Test Food",
        caloriesPerServing: Double = 200,
        proteinPerServing: Double = 20,
        carbohydratesPerServing: Double = 25,
        fatPerServing: Double = 10,
        servingSize: Double = 100,
        servingUnit: String = "g",
        isComposite: Bool = false
    ) -> CustomFood {
        return CustomFood(
            name: name,
            caloriesPerServing: caloriesPerServing,
            proteinPerServing: proteinPerServing,
            carbohydratesPerServing: carbohydratesPerServing,
            fatPerServing: fatPerServing,
            servingSize: servingSize,
            servingUnit: servingUnit,
            isComposite: isComposite
        )
    }
    
    func createMockCustomFoods(count: Int = 10) -> [CustomFood] {
        let foodNames = [
            "Homemade Protein Shake", "Custom Salad Mix", "Meal Prep Chicken",
            "Homemade Granola", "Custom Smoothie Bowl", "Protein Pancakes",
            "Veggie Stir Fry", "Custom Energy Balls", "Homemade Soup",
            "Protein Muffins", "Custom Trail Mix", "Meal Prep Rice Bowl"
        ]
        
        return (0..<count).map { index in
            let name = foodNames[index % foodNames.count]
            
            return createMockCustomFood(
                name: "\(name) \(index + 1)",
                caloriesPerServing: Double.random(in: 150...400),
                proteinPerServing: Double.random(in: 15...40),
                carbohydratesPerServing: Double.random(in: 20...60),
                fatPerServing: Double.random(in: 8...25),
                servingSize: Double.random(in: 80...150),
                servingUnit: ["g", "cup", "serving", "piece"].randomElement()!,
                isComposite: Bool.random()
            )
        }
    }
    
    // MARK: - NutritionGoals Mock Data
    
    func createMockNutritionGoals(
        userId: String = "test-user",
        dailyCalories: Double = 2000,
        dailyProtein: Double = 150,
        dailyCarbohydrates: Double = 250,
        dailyFat: Double = 67,
        activityLevel: ActivityLevel = .moderatelyActive,
        goal: NutritionGoal = .maintain,
        bmr: Double = 1600,
        tdee: Double = 2000,
        weight: Double? = 75,
        height: Double? = 175,
        age: Int? = 30,
        biologicalSex: String? = "male"
    ) -> NutritionGoals {
        return NutritionGoals(
            userId: userId,
            dailyCalories: dailyCalories,
            dailyProtein: dailyProtein,
            dailyCarbohydrates: dailyCarbohydrates,
            dailyFat: dailyFat,
            activityLevel: activityLevel,
            goal: goal,
            bmr: bmr,
            tdee: tdee,
            weight: weight,
            height: height,
            age: age,
            biologicalSex: biologicalSex
        )
    }
    
    func createMockNutritionGoalsVariations() -> [NutritionGoals] {
        return [
            // Cutting goals
            createMockNutritionGoals(
                userId: "user-cut",
                dailyCalories: 1800,
                dailyProtein: 140,
                dailyCarbohydrates: 180,
                dailyFat: 60,
                goal: .cut,
                bmr: 1600,
                tdee: 1800
            ),
            
            // Bulking goals
            createMockNutritionGoals(
                userId: "user-bulk",
                dailyCalories: 2500,
                dailyProtein: 180,
                dailyCarbohydrates: 300,
                dailyFat: 83,
                goal: .bulk,
                bmr: 1800,
                tdee: 2500
            ),
            
            // Maintenance goals
            createMockNutritionGoals(
                userId: "user-maintain",
                dailyCalories: 2200,
                dailyProtein: 165,
                dailyCarbohydrates: 275,
                dailyFat: 73,
                goal: .maintain,
                bmr: 1700,
                tdee: 2200
            )
        ]
    }
    
    // MARK: - UserPhysicalData Mock Data
    
    func createMockUserPhysicalData(
        weight: Double? = 75,
        height: Double? = 175,
        age: Int? = 30,
        biologicalSex: String? = "male",
        bmr: Double? = 1650,
        tdee: Double? = 2000
    ) -> UserPhysicalData {
        return UserPhysicalData(
            weight: weight,
            height: height,
            age: age,
            biologicalSex: biologicalSex,
            bmr: bmr,
            tdee: tdee
        )
    }
    
    // MARK: - OpenFoodFacts Mock Data
    
    func createMockOpenFoodFactsProduct(
        id: String = "1234567890123",
        productName: String = "Test Product",
        brands: String = "Test Brand",
        energyKcal100g: Double = 250,
        proteins100g: Double = 20,
        carbohydrates100g: Double = 30,
        fat100g: Double = 10,
        servingSize: String = "100g",
        servingQuantity: Double = 100
    ) -> OpenFoodFactsProduct {
        let nutriments = OpenFoodFactsNutriments(
            energyKcal100g: energyKcal100g,
            proteins100g: proteins100g,
            carbohydrates100g: carbohydrates100g,
            fat100g: fat100g,
            fiber100g: 5,
            sugars100g: 8,
            sodium100g: 0.5
        )
        
        return OpenFoodFactsProduct(
            id: id,
            productName: productName,
            brands: brands,
            nutriments: nutriments,
            servingSize: servingSize,
            servingQuantity: servingQuantity
        )
    }
    
    func createMockOpenFoodFactsResponse(
        status: Int = 1,
        statusVerbose: String = "product found",
        product: OpenFoodFactsProduct? = nil
    ) -> OpenFoodFactsResponse {
        let mockProduct = product ?? createMockOpenFoodFactsProduct()
        
        return OpenFoodFactsResponse(
            status: status,
            statusVerbose: statusVerbose,
            product: mockProduct
        )
    }
    
    // MARK: - FoodSearchResult Mock Data
    
    func createMockFoodSearchResult(
        id: String = "test-result-1",
        name: String = "Test Search Result",
        calories: Double = 200,
        protein: Double = 15,
        carbohydrates: Double = 25,
        fat: Double = 8,
        servingSize: Double = 100,
        servingUnit: String = "g",
        source: FoodSearchResultSource = .openFoodFacts
    ) -> FoodSearchResult {
        return FoodSearchResult(
            id: id,
            name: name,
            calories: calories,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat,
            servingSize: servingSize,
            servingUnit: servingUnit,
            source: source
        )
    }
    
    func createMockFoodSearchResults(count: Int = 10) -> [FoodSearchResult] {
        let foodNames = [
            "Chicken Breast", "Brown Rice", "Broccoli", "Salmon", "Sweet Potato",
            "Spinach", "Eggs", "Oatmeal", "Banana", "Greek Yogurt", "Quinoa",
            "Avocado", "Almonds", "Tuna", "Black Beans"
        ]
        
        let sources: [FoodSearchResultSource] = [.openFoodFacts, .custom]
        
        return (0..<count).map { index in
            let name = foodNames[index % foodNames.count]
            let source = sources[index % sources.count]
            
            return createMockFoodSearchResult(
                id: "result-\(index)",
                name: "\(name) \(index + 1)",
                calories: Double.random(in: 100...400),
                protein: Double.random(in: 10...40),
                carbohydrates: Double.random(in: 15...60),
                fat: Double.random(in: 5...25),
                servingSize: Double.random(in: 80...150),
                servingUnit: ["g", "cup", "serving", "piece"].randomElement()!,
                source: source
            )
        }
    }
    
    // MARK: - DailyNutritionTotals Mock Data
    
    func createMockDailyNutritionTotals(
        totalCalories: Double = 1500,
        totalProtein: Double = 120,
        totalCarbohydrates: Double = 180,
        totalFat: Double = 50
    ) -> DailyNutritionTotals {
        var totals = DailyNutritionTotals()
        totals.totalCalories = totalCalories
        totals.totalProtein = totalProtein
        totals.totalCarbohydrates = totalCarbohydrates
        totals.totalFat = totalFat
        return totals
    }
    
    // MARK: - Test Scenarios
    
    /// Creates a complete day's worth of food logs with realistic distribution
    func createRealisticDayScenario(date: Date = Date()) -> [FoodLog] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        var foodLogs: [FoodLog] = []
        
        // Breakfast (7-9 AM)
        let breakfastTime = calendar.date(byAdding: .hour, value: 8, to: startOfDay)!
        foodLogs.append(createMockFoodLog(
            name: "Oatmeal with Berries",
            calories: 320,
            protein: 12,
            carbohydrates: 58,
            fat: 6,
            mealType: .breakfast,
            timestamp: breakfastTime
        ))
        
        // Mid-morning snack (10 AM)
        let snackTime1 = calendar.date(byAdding: .hour, value: 10, to: startOfDay)!
        foodLogs.append(createMockFoodLog(
            name: "Greek Yogurt",
            calories: 150,
            protein: 20,
            carbohydrates: 8,
            fat: 4,
            mealType: .snacks,
            timestamp: snackTime1
        ))
        
        // Lunch (12-1 PM)
        let lunchTime = calendar.date(byAdding: .hour, value: 12, to: startOfDay)!
        foodLogs.append(createMockFoodLog(
            name: "Grilled Chicken Salad",
            calories: 450,
            protein: 35,
            carbohydrates: 25,
            fat: 18,
            mealType: .lunch,
            timestamp: lunchTime
        ))
        
        // Afternoon snack (3 PM)
        let snackTime2 = calendar.date(byAdding: .hour, value: 15, to: startOfDay)!
        foodLogs.append(createMockFoodLog(
            name: "Apple with Almond Butter",
            calories: 200,
            protein: 6,
            carbohydrates: 25,
            fat: 12,
            mealType: .snacks,
            timestamp: snackTime2
        ))
        
        // Dinner (6-7 PM)
        let dinnerTime = calendar.date(byAdding: .hour, value: 18, to: startOfDay)!
        foodLogs.append(createMockFoodLog(
            name: "Salmon with Sweet Potato",
            calories: 520,
            protein: 40,
            carbohydrates: 35,
            fat: 22,
            mealType: .dinner,
            timestamp: dinnerTime
        ))
        
        return foodLogs
    }
    
    /// Creates a scenario with nutrition goals nearly met
    func createNearGoalCompletionScenario() -> (goals: NutritionGoals, foodLogs: [FoodLog]) {
        let goals = createMockNutritionGoals(
            dailyCalories: 2000,
            dailyProtein: 150,
            dailyCarbohydrates: 250,
            dailyFat: 67
        )
        
        // Create food logs that are 90% of the way to goals
        let foodLogs = [
            createMockFoodLog(name: "Breakfast", calories: 400, protein: 30, carbohydrates: 50, fat: 12, mealType: .breakfast),
            createMockFoodLog(name: "Lunch", calories: 600, protein: 45, carbohydrates: 75, fat: 20, mealType: .lunch),
            createMockFoodLog(name: "Dinner", colors: 700, protein: 50, carbohydrates: 90, fat: 25, mealType: .dinner),
            createMockFoodLog(name: "Snacks", calories: 100, protein: 10, carbohydrates: 15, fat: 3, mealType: .snacks)
        ]
        
        return (goals: goals, foodLogs: foodLogs)
    }
    
    /// Creates a scenario with exceeded nutrition goals
    func createExceededGoalsScenario() -> (goals: NutritionGoals, foodLogs: [FoodLog]) {
        let goals = createMockNutritionGoals(
            dailyCalories: 1800,
            dailyProtein: 120,
            dailyCarbohydrates: 200,
            dailyFat: 60
        )
        
        // Create food logs that exceed goals by 20%
        let foodLogs = [
            createMockFoodLog(name: "Breakfast", calories: 500, protein: 35, carbohydrates: 60, fat: 18, mealType: .breakfast),
            createMockFoodLog(name: "Lunch", calories: 700, protein: 50, carbohydrates: 80, fat: 25, mealType: .lunch),
            createMockFoodLog(name: "Dinner", calories: 800, protein: 60, carbohydrates: 100, fat: 30, mealType: .dinner),
            createMockFoodLog(name: "Snacks", calories: 200, protein: 15, carbohydrates: 25, fat: 8, mealType: .snacks)
        ]
        
        return (goals: goals, foodLogs: foodLogs)
    }
    
    // MARK: - Performance Test Data
    
    /// Creates large datasets for performance testing
    func createLargeDataset(foodLogCount: Int = 1000, customFoodCount: Int = 200) -> (foodLogs: [FoodLog], customFoods: [CustomFood]) {
        let foodLogs = createMockFoodLogs(count: foodLogCount)
        let customFoods = createMockCustomFoods(count: customFoodCount)
        
        return (foodLogs: foodLogs, customFoods: customFoods)
    }
    
    /// Creates data spread across multiple dates for range queries
    func createMultiDateDataset(dayCount: Int = 30, foodLogsPerDay: Int = 8) -> [FoodLog] {
        let calendar = Calendar.current
        let today = Date()
        
        var allFoodLogs: [FoodLog] = []
        
        for dayOffset in 0..<dayCount {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            let dayLogs = createMockFoodLogsForDate(date, count: foodLogsPerDay)
            allFoodLogs.append(contentsOf: dayLogs)
        }
        
        return allFoodLogs
    }
}

// MARK: - Extensions for Test Convenience

extension MockDataGenerator {
    
    /// Quick access to common test scenarios
    enum TestScenario {
        case empty
        case singleMeal
        case fullDay
        case nearGoalCompletion
        case exceededGoals
        case multipleUsers
        case performanceTest
    }
    
    func createScenario(_ scenario: TestScenario) -> (goals: NutritionGoals?, foodLogs: [FoodLog], customFoods: [CustomFood]) {
        switch scenario {
        case .empty:
            return (goals: nil, foodLogs: [], customFoods: [])
            
        case .singleMeal:
            let goals = createMockNutritionGoals()
            let foodLogs = [createMockFoodLog()]
            let customFoods = [createMockCustomFood()]
            return (goals: goals, foodLogs: foodLogs, customFoods: customFoods)
            
        case .fullDay:
            let goals = createMockNutritionGoals()
            let foodLogs = createRealisticDayScenario()
            let customFoods = createMockCustomFoods(count: 5)
            return (goals: goals, foodLogs: foodLogs, customFoods: customFoods)
            
        case .nearGoalCompletion:
            let scenario = createNearGoalCompletionScenario()
            let customFoods = createMockCustomFoods(count: 3)
            return (goals: scenario.goals, foodLogs: scenario.foodLogs, customFoods: customFoods)
            
        case .exceededGoals:
            let scenario = createExceededGoalsScenario()
            let customFoods = createMockCustomFoods(count: 3)
            return (goals: scenario.goals, foodLogs: scenario.foodLogs, customFoods: customFoods)
            
        case .multipleUsers:
            let goals = createMockNutritionGoalsVariations().first
            let foodLogs = createMockFoodLogs(count: 10)
            let customFoods = createMockCustomFoods(count: 15)
            return (goals: goals, foodLogs: foodLogs, customFoods: customFoods)
            
        case .performanceTest:
            let goals = createMockNutritionGoals()
            let dataset = createLargeDataset()
            return (goals: goals, foodLogs: dataset.foodLogs, customFoods: dataset.customFoods)
        }
    }
}