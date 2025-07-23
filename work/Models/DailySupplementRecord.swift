import Foundation
import SwiftData

@Model
final class DailySupplementRecord {
    var id: UUID
    var date: Date
    var takenSupplements: [String]
    
    init(date: Date, takenSupplements: [String] = []) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.takenSupplements = takenSupplements
    }
} 