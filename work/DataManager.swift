import Foundation
import SwiftData

@MainActor
class DataManager: ObservableObject {
    private var modelContext: ModelContext

    // MARK: - Published Properties for UI Updates
    @Published var currentSupplementRecord: DailySupplementRecord?
    @Published var currentJournalEntry: DailyJournal?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Supplement Methods
    
    func fetchSupplementRecord(for date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<DailySupplementRecord> { record in
            record.date >= startOfDay && record.date < endOfDay
        }
        
        let descriptor = FetchDescriptor<DailySupplementRecord>(predicate: predicate)
        
        do {
            let records = try modelContext.fetch(descriptor)
            currentSupplementRecord = records.first
        } catch {
            print("❌ Failed to fetch supplement record for \(date): \(error)")
            currentSupplementRecord = nil
        }
    }
    
    func toggleSupplement(_ supplementName: String, for date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let record: DailySupplementRecord
        if let existingRecord = currentSupplementRecord {
            record = existingRecord
        } else {
            record = DailySupplementRecord(date: startOfDay)
            modelContext.insert(record)
            currentSupplementRecord = record
        }
        
        if let index = record.takenSupplements.firstIndex(of: supplementName) {
            record.takenSupplements.remove(at: index)
        } else {
            record.takenSupplements.append(supplementName)
        }
        
        save()
    }

    func isSupplementTaken(_ supplementName: String) -> Bool {
        return currentSupplementRecord?.takenSupplements.contains(supplementName) ?? false
    }

    // MARK: - Journal Methods
    
    func fetchJournalEntry(for date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<DailyJournal> { record in
            record.date >= startOfDay && record.date < endOfDay
        }
        let descriptor = FetchDescriptor<DailyJournal>(predicate: predicate)
        
        do {
            let entries = try modelContext.fetch(descriptor)
            currentJournalEntry = entries.first
        } catch {
            print("❌ Failed to fetch journal entry for \(date): \(error)")
            currentJournalEntry = nil
        }
    }
    
    func saveJournalEntry(for date: Date, tags: Set<String>, notes: String) {
        let entry: DailyJournal
        if let existingEntry = currentJournalEntry {
            entry = existingEntry
        } else {
            entry = DailyJournal(date: date)
            modelContext.insert(entry)
            currentJournalEntry = entry
        }
        
        entry.selectedTags = Array(tags)
        entry.notes = notes.isEmpty ? nil : notes
        
        // --- Note: The logic for legacy booleans from the old manager is preserved here ---
        let tagEnums = tags.compactMap { JournalTag(rawValue: $0) }
        let tagSet = Set(tagEnums)
        
        entry.consumedAlcohol = tagSet.contains(.alcohol)
        entry.caffeineAfter2PM = tagSet.contains(.caffeine) || tagSet.contains(.coffee)
        entry.ateLate = tagSet.contains(.lateEating)
        entry.highStressDay = tagSet.contains(.stress)
        entry.alcohol = tagSet.contains(.alcohol)
        entry.illness = tagSet.contains(.illness)
        
        if tagSet.contains(.poorSleep) {
            entry.wellness = .poor
        } else if tagSet.contains(.goodSleep) {
            entry.wellness = .excellent
        } else {
            entry.wellness = nil
        }
        // --- End of legacy boolean logic ---
        
        save()
    }
    
    // MARK: - Private Save Method
    
    private func save() {
        do {
            try modelContext.save()
            print("✅ DataManager saved successfully.")
        } catch {
            print("❌ DataManager failed to save: \(error)")
        }
    }
} 