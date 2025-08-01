import XCTest
@testable import work

/// Tests specifically for date handling issues in nutrition tracking
@MainActor
final class DateHandlingTests: XCTestCase {
    
    func testFoodLogTimestampCreation() {
        // Given
        let calendar = Calendar.current
        let today = Date()
        let selectedDate = calendar.startOfDay(for: today)
        
        // Simulate the fixed createFoodLogForSelectedDate logic
        let currentTime = Date()
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: currentTime)
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        
        let targetTimestamp = calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: timeComponents.hour,
            minute: timeComponents.minute,
            second: timeComponents.second
        )) ?? calendar.startOfDay(for: selectedDate)
        
        // When - Create FoodLog with the exact timestamp (no normalization in initializer)
        let foodLog = FoodLog(
            timestamp: targetTimestamp,
            name: "Test Food",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            mealType: .breakfast
        )
        
        // Then - Verify the timestamp is preserved exactly as provided
        XCTAssertEqual(foodLog.timestamp, targetTimestamp, "Food log should preserve the exact timestamp provided")
        
        let foodDate = calendar.startOfDay(for: foodLog.timestamp)
        let expectedDate = calendar.startOfDay(for: selectedDate)
        
        XCTAssertEqual(foodDate, expectedDate, "Food log should be saved to the selected date")
        XCTAssertTrue(calendar.isDate(foodLog.timestamp, inSameDayAs: selectedDate), "Food log timestamp should be on the selected date")
    }
    
    func testDateRangeFiltering() {
        // Given
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Create timestamps for testing
        let morningTime = calendar.date(byAdding: .hour, value: 8, to: startOfDay)!
        let eveningTime = calendar.date(byAdding: .hour, value: 20, to: startOfDay)!
        let nextDayTime = calendar.date(byAdding: .day, value: 1, to: today)!
        
        // When - simulate repository filtering logic
        let morningInRange = morningTime >= startOfDay && morningTime < endOfDay
        let eveningInRange = eveningTime >= startOfDay && eveningTime < endOfDay
        let nextDayInRange = nextDayTime >= startOfDay && nextDayTime < endOfDay
        
        // Then
        XCTAssertTrue(morningInRange, "Morning time should be in range")
        XCTAssertTrue(eveningInRange, "Evening time should be in range")
        XCTAssertFalse(nextDayInRange, "Next day time should not be in range")
    }
    
    func testSelectedDateNormalization() {
        // Given
        let calendar = Calendar.current
        let now = Date()
        let selectedDate = now // Not normalized
        
        // When - simulate the normalization logic
        let normalizedSelectedDate = calendar.startOfDay(for: selectedDate)
        
        // Then
        let startOfToday = calendar.startOfDay(for: now)
        XCTAssertEqual(normalizedSelectedDate, startOfToday, "Selected date should be normalized to start of day")
    }
    
    func testCrossDateIssueScenario() {
        // Given - simulate the scenario from the debug logs
        let calendar = Calendar.current
        
        // Create a date that represents July 31st
        let july31 = calendar.date(from: DateComponents(year: 2025, month: 7, day: 31))!
        let august1 = calendar.date(from: DateComponents(year: 2025, month: 8, day: 1))!
        
        // Create a food log with July 31st timestamp
        let foodLog = FoodLog(
            timestamp: july31,
            name: "Test Food",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            mealType: .breakfast
        )
        
        // When - check if this food would appear on August 1st query
        let august1Start = calendar.startOfDay(for: august1)
        let august1End = calendar.date(byAdding: .day, value: 1, to: august1Start)!
        
        let wouldAppearOnAugust1 = foodLog.timestamp >= august1Start && foodLog.timestamp < august1End
        
        // Then
        XCTAssertFalse(wouldAppearOnAugust1, "July 31st food should not appear on August 1st")
        
        // Verify it would appear on July 31st
        let july31Start = calendar.startOfDay(for: july31)
        let july31End = calendar.date(byAdding: .day, value: 1, to: july31Start)!
        
        let wouldAppearOnJuly31 = foodLog.timestamp >= july31Start && foodLog.timestamp < july31End
        XCTAssertTrue(wouldAppearOnJuly31, "July 31st food should appear on July 31st")
    }
    
    func testTimezoneConsistency() {
        // Given
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        let today = Date()
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: today)
        
        // When - create start of day using explicit components
        let startOfDay = calendar.date(from: DateComponents(
            timeZone: TimeZone.current,
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: 0,
            minute: 0,
            second: 0
        ))!
        
        let endOfDay = calendar.date(from: DateComponents(
            timeZone: TimeZone.current,
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: 23,
            minute: 59,
            second: 59
        ))!
        
        // Then
        XCTAssertTrue(calendar.isDate(startOfDay, inSameDayAs: today), "Start of day should be same day as today")
        XCTAssertTrue(calendar.isDate(endOfDay, inSameDayAs: today), "End of day should be same day as today")
        XCTAssertLessThan(startOfDay, endOfDay, "Start of day should be before end of day")
        
        // Test that a timestamp created for today falls within the range
        let nowComponents = calendar.dateComponents([.hour, .minute, .second], from: Date())
        let testTimestamp = calendar.date(from: DateComponents(
            timeZone: TimeZone.current,
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: nowComponents.hour,
            minute: nowComponents.minute,
            second: nowComponents.second
        ))!
        
        XCTAssertTrue(testTimestamp >= startOfDay && testTimestamp <= endOfDay, "Test timestamp should fall within the day range")
    }
    
    func testDatePersistenceBugFix() {
        // Given - Simulate the exact scenario from the bug report
        let calendar = Calendar.current
        
        // Create July 30th as the selected date
        let july30 = calendar.date(from: DateComponents(year: 2025, month: 7, day: 30))!
        
        // When - Use the new date utility to create a timestamp (like the fixed ViewModel does)
        let targetTimestamp = Date.timestampForCalendarDay(july30, withCurrentTime: true)
        
        // Create the food log (with the fix applied)
        let foodLog = FoodLog(
            timestamp: targetTimestamp,
            name: "Orange",
            calories: 62,
            protein: 1.2,
            carbohydrates: 15.4,
            fat: 0.2,
            mealType: .breakfast
        )
        
        // Then - Verify the food log is correctly associated with July 30th using new utilities
        XCTAssertTrue(foodLog.timestamp.belongsToCalendarDay(july30), "Food log should belong to July 30th")
        XCTAssertEqual(foodLog.timestamp, targetTimestamp, "Food log should preserve the exact timestamp")
        
        // Verify it would be fetched correctly when querying for July 30th using new utilities
        let july30Range = july30.dayRange()
        let wouldBeFetched = foodLog.timestamp >= july30Range.start && foodLog.timestamp < july30Range.end
        XCTAssertTrue(wouldBeFetched, "Food log should be fetched when querying for July 30th")
        
        // Verify it would NOT be fetched when querying for July 29th
        let july29 = calendar.date(from: DateComponents(year: 2025, month: 7, day: 29))!
        let july29Range = july29.dayRange()
        let wouldBeFetchedOnJuly29 = foodLog.timestamp >= july29Range.start && foodLog.timestamp < july29Range.end
        XCTAssertFalse(wouldBeFetchedOnJuly29, "Food log should NOT be fetched when querying for July 29th")
        
        // Verify it would NOT be fetched when querying for July 31st
        let july31 = calendar.date(from: DateComponents(year: 2025, month: 7, day: 31))!
        let july31Range = july31.dayRange()
        let wouldBeFetchedOnJuly31 = foodLog.timestamp >= july31Range.start && foodLog.timestamp < july31Range.end
        XCTAssertFalse(wouldBeFetchedOnJuly31, "Food log should NOT be fetched when querying for July 31st")
    }
    
    func testNewDateUtilities() {
        // Given
        let calendar = Calendar.current
        let testDate = calendar.date(from: DateComponents(year: 2025, month: 7, day: 30, hour: 14, minute: 30))!
        
        // When - Test timestampForCalendarDay
        let timestampWithCurrentTime = Date.timestampForCalendarDay(testDate, withCurrentTime: true)
        let timestampWithoutCurrentTime = Date.timestampForCalendarDay(testDate, withCurrentTime: false)
        
        // Then
        XCTAssertTrue(timestampWithCurrentTime.belongsToCalendarDay(testDate), "Timestamp with current time should belong to the same calendar day")
        XCTAssertTrue(timestampWithoutCurrentTime.belongsToCalendarDay(testDate), "Timestamp without current time should belong to the same calendar day")
        XCTAssertEqual(timestampWithoutCurrentTime, calendar.startOfDay(for: testDate), "Timestamp without current time should be start of day")
        
        // Test dayRange utility
        let dayRange = testDate.dayRange()
        XCTAssertEqual(dayRange.start, calendar.startOfDay(for: testDate), "Day range start should be start of day")
        XCTAssertEqual(dayRange.end, calendar.date(byAdding: .day, value: 1, to: dayRange.start), "Day range end should be start of next day")
        
        // Test that timestamps created with the utility fall within the day range
        XCTAssertTrue(timestampWithCurrentTime >= dayRange.start && timestampWithCurrentTime < dayRange.end, "Timestamp should fall within day range")
        XCTAssertTrue(timestampWithoutCurrentTime >= dayRange.start && timestampWithoutCurrentTime < dayRange.end, "Start of day timestamp should fall within day range")
    }
}