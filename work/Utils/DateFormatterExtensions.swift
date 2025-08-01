import Foundation

// MARK: - DateFormatter Extensions

extension DateFormatter {
    /// Short date formatter for logging and display
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    /// Full date formatter for detailed display
    static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    /// Time formatter for timestamps
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    /// Debug formatter showing both date and time in local timezone
    static let debugDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}

// MARK: - Date Utilities for Nutrition Tracking

extension Date {
    /// Creates a timestamp for the specified calendar day with the current time
    /// This ensures food logs are saved to the correct day while preserving natural timing
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