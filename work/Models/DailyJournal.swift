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
    
    // Enhanced supplement tracking
    var tookCreatine: Bool = false
    var tookVitaminC: Bool = false
    var tookVitaminD: Bool = false
    var tookVitaminB: Bool = false
    var tookZinc: Bool = false
    var tookOmega3: Bool = false
    var tookMultivitamin: Bool = false
    var tookProbiotic: Bool = false
    
    // Time-based supplement tracking (stored as comma-separated strings)
    var morningSupplements: String = ""
    var middaySupplements: String = ""
    var eveningSupplements: String = ""
    
    // NEW: Persist all selected tags
    var selectedTags: [String]? = []
    
    enum Wellness: String, Codable, CaseIterable {
        case excellent, good, fair, poor
    }
    var wellness: Wellness? = nil
    var alcohol: Bool = false
    var illness: Bool = false
    
    init(date: Date = Date(), consumedAlcohol: Bool = false, caffeineAfter2PM: Bool = false, ateLate: Bool = false, highStressDay: Bool = false, tookMagnesium: Bool = false, tookAshwagandha: Bool = false, notes: String? = nil, selectedTags: [String]? = []) {
        self.id = UUID()
        self.date = date
        self.consumedAlcohol = consumedAlcohol
        self.caffeineAfter2PM = caffeineAfter2PM
        self.ateLate = ateLate
        self.highStressDay = highStressDay
        self.tookMagnesium = tookMagnesium
        self.tookAshwagandha = tookAshwagandha
        self.notes = notes
        self.selectedTags = selectedTags ?? []
    }
    

    
    var tags: [String] {
        var tags: [String] = []
        if consumedAlcohol { tags.append("Alcohol") }
        if caffeineAfter2PM { tags.append("Late Caffeine") }
        if ateLate { tags.append("Late Meal") }
        if highStressDay { tags.append("High Stress") }
        if tookMagnesium { tags.append("Magnesium") }
        if tookAshwagandha { tags.append("Ashwagandha") }
        if tookCreatine { tags.append("Creatine") }
        if tookVitaminC { tags.append("Vitamin C") }
        if tookVitaminD { tags.append("Vitamin D") }
        if tookVitaminB { tags.append("Vitamin B") }
        if tookZinc { tags.append("Zinc") }
        if tookOmega3 { tags.append("Omega-3") }
        if tookMultivitamin { tags.append("Multivitamin") }
        if tookProbiotic { tags.append("Probiotic") }
        return tags
    }
    
    // Helper methods for supplement tracking
    func getSupplementsForTime(_ time: String) -> Set<String> {
        let supplementString: String
        switch time.lowercased() {
        case "morning":
            supplementString = morningSupplements
        case "midday":
            supplementString = middaySupplements
        case "evening":
            supplementString = eveningSupplements
        default:
            return []
        }
        
        return Set(supplementString.components(separatedBy: ",").filter { !$0.isEmpty })
    }
    
    func setSupplementsForTime(_ time: String, supplements: Set<String>) {
        let supplementString = supplements.joined(separator: ",")
        switch time.lowercased() {
        case "morning":
            morningSupplements = supplementString
        case "midday":
            middaySupplements = supplementString
        case "evening":
            eveningSupplements = supplementString
        default:
            break
        }
        
        // Update individual boolean flags
        updateSupplementFlags()
    }
    
    private func updateSupplementFlags() {
        let allSupplements = Set([morningSupplements, middaySupplements, eveningSupplements]
            .flatMap { $0.components(separatedBy: ",") }
            .filter { !$0.isEmpty })
        
        tookCreatine = allSupplements.contains("Creatine")
        tookVitaminC = allSupplements.contains("Vitamin C")
        tookVitaminD = allSupplements.contains("Vitamin D")
        tookVitaminB = allSupplements.contains("Vitamin B Complex")
        tookMagnesium = allSupplements.contains("Magnesium")
        tookZinc = allSupplements.contains("Zinc")
        tookOmega3 = allSupplements.contains("Omega-3")
        tookMultivitamin = allSupplements.contains("Multivitamin")
        tookProbiotic = allSupplements.contains("Probiotic")
        tookAshwagandha = allSupplements.contains("Ashwagandha")
    }
} 