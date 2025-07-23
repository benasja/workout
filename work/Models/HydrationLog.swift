import Foundation
import SwiftData

@Model
final class HydrationLog {
    var id: UUID
    var date: Date
    var currentIntakeInML: Int
    var goalInML: Int
    
    init(date: Date, currentIntakeInML: Int = 0, goalInML: Int = 2500) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.currentIntakeInML = currentIntakeInML
        self.goalInML = goalInML
    }
} 