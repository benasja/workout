import Foundation
import SwiftData

class JournalManager: ObservableObject {
    static let shared = JournalManager()
    
    // All journal entries (fetched from SwiftData)
    @Published var entries: [DailyJournal] = []
    
    // All tags (from JournalTag enum)
    var allTags: [String] {
        JournalTag.allCases.map { $0.rawValue }
    }
    
    // All supplements (from SupplementsView.Supplement enum if available, else hardcoded)
    var allSupplements: [String] {
        [
            "Creatine", "Vitamin C", "Vitamin D", "Vitamin B Complex", "Magnesium", "Zinc", "Omega-3", "Multivitamin", "Probiotic"
        ]
    }
    
    private init() {
        loadEntries()
    }
    
    // Loads all journal entries from SwiftData
    func loadEntries() {
        let context = try? ModelContext(
            ModelContainer(for: DailyJournal.self)
        )
        let descriptor = FetchDescriptor<DailyJournal>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        if let context = context, let fetched = try? context.fetch(descriptor) {
            self.entries = fetched
        }
    }
    
    // Call this to refresh entries if needed
    func refresh() {
        loadEntries()
    }

    // Loads a journal entry for a specific date
    func fetchEntry(for date: Date, context: ModelContext) -> DailyJournal? {
        let calendar = Calendar.current
        let descriptor = FetchDescriptor<DailyJournal>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        if let entries = try? context.fetch(descriptor) {
            return entries.first { calendar.isDate($0.date, inSameDayAs: date) }
        }
        return nil
    }

    // Saves or updates a journal entry for a specific date
    func saveEntry(for date: Date, tags: Set<JournalTag>, notes: String, context: ModelContext) {
        let calendar = Calendar.current
        let descriptor = FetchDescriptor<DailyJournal>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let entry: DailyJournal
        if let entries = try? context.fetch(descriptor), let existing = entries.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            entry = existing
        } else {
            entry = DailyJournal(date: date)
            context.insert(entry)
        }
        // Persist all selected tags as strings
        entry.selectedTags = tags.map { $0.rawValue }
        // Optionally, update legacy booleans for analytics/compatibility
        entry.consumedAlcohol = tags.contains(.alcohol)
        entry.caffeineAfter2PM = tags.contains(.caffeine) || tags.contains(.coffee)
        entry.ateLate = tags.contains(.lateEating)
        entry.highStressDay = tags.contains(.stress)
        entry.alcohol = tags.contains(.alcohol)
        entry.illness = tags.contains(.illness)
        // Sleep quality
        if tags.contains(.poorSleep) {
            entry.wellness = .poor
        } else if tags.contains(.goodSleep) {
            entry.wellness = .excellent
        } else {
            entry.wellness = nil
        }
        entry.notes = notes.isEmpty ? nil : notes
        do {
            try context.save()
            print("✅ Journal entry auto-saved for \(date)")
        } catch {
            print("❌ Failed to auto-save journal entry: \(error)")
        }
    }
} 