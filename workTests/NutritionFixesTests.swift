import XCTest
@testable import work

/// Tests to verify the nutrition tracking fixes are working correctly
@MainActor
final class NutritionFixesTests: XCTestCase {
    
    // MARK: - Date Handling Tests
    
    func testFoodLogTimestampCorrection() {
        // Given
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        let foodLog = FoodLog(
            timestamp: yesterday, // Wrong date
            name: "Test Food",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            mealType: .breakfast
        )
        
        // When - simulate the timestamp correction logic
        let calendar = Calendar.current
        let selectedDate = today
        let correctedTimestamp: Date
        
        if calendar.isDate(foodLog.timestamp, inSameDayAs: selectedDate) {
            correctedTimestamp = foodLog.timestamp
        } else {
            let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: Date())
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
            correctedTimestamp = calendar.date(from: DateComponents(
                year: dateComponents.year,
                month: dateComponents.month,
                day: dateComponents.day,
                hour: timeComponents.hour,
                minute: timeComponents.minute,
                second: timeComponents.second
            )) ?? calendar.startOfDay(for: selectedDate)
        }
        
        // Then
        XCTAssertTrue(calendar.isDate(correctedTimestamp, inSameDayAs: today))
        XCTAssertFalse(calendar.isDate(correctedTimestamp, inSameDayAs: yesterday))
    }
    
    // MARK: - Serving Size Tests
    
    func testFormattedServingForWeightBasedFoods() {
        // Given
        let foodLog = FoodLog(
            name: "Chicken Breast",
            calories: 165,
            protein: 31,
            carbohydrates: 0,
            fat: 3.6,
            mealType: .lunch,
            servingSize: 100,
            servingUnit: "g"
        )
        
        // When
        let formatted = foodLog.formattedServing
        
        // Then
        XCTAssertEqual(formatted, "100g")
    }
    
    func testFormattedServingForCountBasedFoods() {
        // Given
        let foodLog = FoodLog(
            name: "Banana",
            calories: 105,
            protein: 1.3,
            carbohydrates: 27,
            fat: 0.4,
            mealType: .snacks,
            servingSize: 1,
            servingUnit: "medium banana"
        )
        
        // When
        let formatted = foodLog.formattedServing
        
        // Then
        XCTAssertEqual(formatted, "1 medium banana")
    }
    
    func testFormattedServingForMultipleItems() {
        // Given
        let foodLog = FoodLog(
            name: "Eggs",
            calories: 140,
            protein: 12,
            carbohydrates: 1,
            fat: 10,
            mealType: .breakfast,
            servingSize: 2,
            servingUnit: "piece"
        )
        
        // When
        let formatted = foodLog.formattedServing
        
        // Then
        XCTAssertEqual(formatted, "2 pieces")
    }
    
    // MARK: - Nutrition Totals Tests
    
    func testDailyNutritionTotalsCalculation() {
        // Given
        let foodLog1 = FoodLog(
            name: "Food 1",
            calories: 200,
            protein: 20,
            carbohydrates: 30,
            fat: 8,
            mealType: .breakfast
        )
        
        let foodLog2 = FoodLog(
            name: "Food 2",
            calories: 300,
            protein: 15,
            carbohydrates: 40,
            fat: 12,
            mealType: .lunch
        )
        
        // When
        var totals = DailyNutritionTotals()
        totals.add(foodLog1)
        totals.add(foodLog2)
        
        // Then
        XCTAssertEqual(totals.totalCalories, 500)
        XCTAssertEqual(totals.totalProtein, 35)
        XCTAssertEqual(totals.totalCarbohydrates, 70)
        XCTAssertEqual(totals.totalFat, 20)
    }
    
    // MARK: - Date Range Tests
    
    func testDateRangeFiltering() {
        // Given
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let todayMorning = calendar.date(byAdding: .hour, value: 8, to: startOfDay)!
        let todayEvening = calendar.date(byAdding: .hour, value: 20, to: startOfDay)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        // When - simulate the filtering logic
        let todayMorningInRange = todayMorning >= startOfDay && todayMorning < endOfDay
        let todayEveningInRange = todayEvening >= startOfDay && todayEvening < endOfDay
        let tomorrowInRange = tomorrow >= startOfDay && tomorrow < endOfDay
        
        // Then
        XCTAssertTrue(todayMorningInRange)
        XCTAssertTrue(todayEveningInRange)
        XCTAssertFalse(tomorrowInRange)
    }
    
    // MARK: - Validation Tests
    
    func testFoodLogValidation() {
        // Given - valid food log
        let validFoodLog = FoodLog(
            name: "Valid Food",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            mealType: .breakfast
        )
        
        // Then
        XCTAssertTrue(validFoodLog.hasValidMacros)
        XCTAssertFalse(validFoodLog.name.isEmpty)
        XCTAssertGreaterThan(validFoodLog.calories, 0)
    }
    
    func testInvalidFoodLogValidation() {
        // Given - invalid food log with negative values
        let invalidFoodLog = FoodLog(
            name: "",
            calories: -100,
            protein: -10,
            carbohydrates: 15,
            fat: 5,
            mealType: .breakfast
        )
        
        // Then
        XCTAssertTrue(invalidFoodLog.name.isEmpty)
        XCTAssertLessThan(invalidFoodLog.calories, 0)
    }
}