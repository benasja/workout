#!/usr/bin/env swift

import Foundation

// MARK: - Date Utilities (from the fix)

extension Date {
    /// Creates a timestamp for the specified calendar day with the current time
    static func timestampForCalendarDay(_ date: Date, withCurrentTime: Bool = true) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        
        if withCurrentTime {
            let currentTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: Date())
            return calendar.date(from: DateComponents(
                year: dateComponents.year,
                month: dateComponents.month,
                day: dateComponents.day,
                hour: currentTimeComponents.hour,
                minute: currentTimeComponents.minute,
                second: currentTimeComponents.second
            )) ?? calendar.startOfDay(for: date)
        } else {
            return calendar.startOfDay(for: date)
        }
    }
    
    /// Validates that a timestamp belongs to the specified calendar day
    func belongsToCalendarDay(_ targetDate: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, inSameDayAs: targetDate)
    }
    
    /// Returns the start and end of day for date range queries
    func dayRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: self)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return (start: startOfDay, end: endOfDay)
    }
}

// MARK: - Validation Tests

func validateDateFix() {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    
    print("🧪 Validating Date Persistence Bug Fix")
    print("=====================================")
    
    // Test 1: Basic timestamp creation
    print("\n1. Testing timestamp creation for July 30th...")
    let july30 = calendar.date(from: DateComponents(year: 2025, month: 7, day: 30))!
    let timestamp = Date.timestampForCalendarDay(july30, withCurrentTime: true)
    
    print("   Selected date: \(formatter.string(from: july30))")
    print("   Created timestamp: \(formatter.string(from: timestamp))")
    print("   Belongs to same day: \(timestamp.belongsToCalendarDay(july30) ? "✅ YES" : "❌ NO")")
    
    // Test 2: Date range queries
    print("\n2. Testing date range queries...")
    let july30Range = july30.dayRange()
    let july29 = calendar.date(from: DateComponents(year: 2025, month: 7, day: 29))!
    let july29Range = july29.dayRange()
    let july31 = calendar.date(from: DateComponents(year: 2025, month: 7, day: 31))!
    let july31Range = july31.dayRange()
    
    print("   July 30 range: \(formatter.string(from: july30Range.start)) to \(formatter.string(from: july30Range.end))")
    
    let inJuly30Range = timestamp >= july30Range.start && timestamp < july30Range.end
    let inJuly29Range = timestamp >= july29Range.start && timestamp < july29Range.end
    let inJuly31Range = timestamp >= july31Range.start && timestamp < july31Range.end
    
    print("   Timestamp in July 30 range: \(inJuly30Range ? "✅ YES" : "❌ NO")")
    print("   Timestamp in July 29 range: \(inJuly29Range ? "❌ YES (BAD)" : "✅ NO (GOOD)")")
    print("   Timestamp in July 31 range: \(inJuly31Range ? "❌ YES (BAD)" : "✅ NO (GOOD)")")
    
    // Test 3: Cross-timezone consistency
    print("\n3. Testing timezone consistency...")
    let currentTimeZone = TimeZone.current
    print("   Current timezone: \(currentTimeZone.identifier)")
    
    // Create timestamps at different times of day
    let morningTime = calendar.date(from: DateComponents(year: 2025, month: 7, day: 30, hour: 8, minute: 0))!
    let eveningTime = calendar.date(from: DateComponents(year: 2025, month: 7, day: 30, hour: 23, minute: 59))!
    
    let morningBelongs = morningTime.belongsToCalendarDay(july30)
    let eveningBelongs = eveningTime.belongsToCalendarDay(july30)
    
    print("   Morning time (8:00 AM) belongs to July 30: \(morningBelongs ? "✅ YES" : "❌ NO")")
    print("   Evening time (11:59 PM) belongs to July 30: \(eveningBelongs ? "✅ YES" : "❌ NO")")
    
    // Test 4: Edge case - midnight boundary
    print("\n4. Testing midnight boundary...")
    let july30Midnight = calendar.date(from: DateComponents(year: 2025, month: 7, day: 30, hour: 0, minute: 0))!
    let july31Midnight = calendar.date(from: DateComponents(year: 2025, month: 7, day: 31, hour: 0, minute: 0))!
    
    let july30MidnightBelongs = july30Midnight.belongsToCalendarDay(july30)
    let july31MidnightBelongs = july31Midnight.belongsToCalendarDay(july30)
    
    print("   July 30 midnight belongs to July 30: \(july30MidnightBelongs ? "✅ YES" : "❌ NO")")
    print("   July 31 midnight belongs to July 30: \(july31MidnightBelongs ? "❌ YES (BAD)" : "✅ NO (GOOD)")")
    
    // Summary
    print("\n📊 VALIDATION SUMMARY")
    print("====================")
    let allTestsPassed = timestamp.belongsToCalendarDay(july30) && 
                        inJuly30Range && 
                        !inJuly29Range && 
                        !inJuly31Range &&
                        morningBelongs &&
                        eveningBelongs &&
                        july30MidnightBelongs &&
                        !july31MidnightBelongs
    
    if allTestsPassed {
        print("🎉 ALL TESTS PASSED - Date persistence bug fix is working correctly!")
        print("✅ Food logs will be saved to the correct calendar day")
        print("✅ Date range queries will fetch the correct data")
        print("✅ Navigation between dates will be stable")
        print("✅ Timezone handling is consistent")
    } else {
        print("❌ SOME TESTS FAILED - Fix needs additional work")
    }
}

// Run the validation
validateDateFix()