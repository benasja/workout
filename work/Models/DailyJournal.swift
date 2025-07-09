import Foundation
import SwiftData

@Model
final class DailyJournal {
    var id: UUID
    var date: Date
    var consumedAlcohol: Bool
    var caffeineAfter2PM: Bool
    var ateLate: Bool
    var highStressDay: Bool
    var tookMagnesium: Bool
    var tookAshwagandha: Bool
    var notes: String?
    var recoveryScore: Int?
    var sleepScore: Int?
    var hrv: Double?
    var rhr: Double?
    var sleepDuration: TimeInterval?
    
    init(date: Date = Date(), consumedAlcohol: Bool = false, caffeineAfter2PM: Bool = false, ateLate: Bool = false, highStressDay: Bool = false, tookMagnesium: Bool = false, tookAshwagandha: Bool = false, notes: String? = nil) {
        self.id = UUID()
        self.date = date
        self.consumedAlcohol = consumedAlcohol
        self.caffeineAfter2PM = caffeineAfter2PM
        self.ateLate = ateLate
        self.highStressDay = highStressDay
        self.tookMagnesium = tookMagnesium
        self.tookAshwagandha = tookAshwagandha
        self.notes = notes
    }
    
    var tags: [String] {
        var tags: [String] = []
        if consumedAlcohol { tags.append("Alcohol") }
        if caffeineAfter2PM { tags.append("Late Caffeine") }
        if ateLate { tags.append("Late Meal") }
        if highStressDay { tags.append("High Stress") }
        if tookMagnesium { tags.append("Magnesium") }
        if tookAshwagandha { tags.append("Ashwagandha") }
        return tags
    }
} 