import Foundation
import SwiftData

@MainActor
class DataManager: ObservableObject {
    private var modelContext: ModelContext

    // MARK: - Published Properties for UI Updates
    @Published var currentSupplementRecord: DailySupplementRecord?
    @Published var currentJournalEntry: DailyJournal?
    @Published var currentHydrationLog: HydrationLog?
    
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
    
    // MARK: - Hydration Methods
    
    private let globalHydrationGoalKey = "GlobalHydrationGoalInML"
    
    func getGlobalHydrationGoal() -> Int {
        UserDefaults.standard.integer(forKey: globalHydrationGoalKey) == 0 ? 2500 : UserDefaults.standard.integer(forKey: globalHydrationGoalKey)
    }
    
    func setGlobalHydrationGoal(_ newGoal: Int) {
        UserDefaults.standard.set(newGoal, forKey: globalHydrationGoalKey)
    }
    
    func fetchHydrationLog(for date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<HydrationLog> { log in
            log.date >= startOfDay && log.date < endOfDay
        }
        let descriptor = FetchDescriptor<HydrationLog>(predicate: predicate)
        
        do {
            let logs = try modelContext.fetch(descriptor)
            if let log = logs.first {
                currentHydrationLog = log
            } else {
                // Use global goal if no log exists
                let newLog = HydrationLog(date: startOfDay, currentIntakeInML: 0, goalInML: getGlobalHydrationGoal())
                modelContext.insert(newLog)
                currentHydrationLog = newLog
                save()
            }
        } catch {
            print("❌ Failed to fetch hydration log for \(date): \(error)")
            currentHydrationLog = nil
        }
    }
    
    func addWater(amountInML: Int, for date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let log: HydrationLog
        if let existingLog = currentHydrationLog, calendar.isDate(existingLog.date, inSameDayAs: startOfDay) {
            log = existingLog
        } else {
            log = HydrationLog(date: startOfDay, currentIntakeInML: 0, goalInML: getGlobalHydrationGoal())
            modelContext.insert(log)
            currentHydrationLog = log
        }
        
        log.currentIntakeInML += amountInML
        save()
    }

    func updateHydrationGoal(newGoal: Int, for date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let log: HydrationLog
        if let existingLog = currentHydrationLog, calendar.isDate(existingLog.date, inSameDayAs: startOfDay) {
            log = existingLog
        } else {
            log = HydrationLog(date: startOfDay)
            modelContext.insert(log)
            currentHydrationLog = log
        }
        log.goalInML = newGoal
        save()
    }

    func updateHydrationGoalForAllDays(newGoal: Int) {
        setGlobalHydrationGoal(newGoal)
        let fetchDescriptor = FetchDescriptor<HydrationLog>()
        do {
            let logs = try modelContext.fetch(fetchDescriptor)
            for log in logs {
                log.goalInML = newGoal
            }
            save()
        } catch {
            print("❌ Failed to update hydration goal for all days: \(error)")
        }
    }

    func resetHydrationIntake(for date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let log: HydrationLog
        if let existingLog = currentHydrationLog, calendar.isDate(existingLog.date, inSameDayAs: startOfDay) {
            log = existingLog
        } else {
            log = HydrationLog(date: startOfDay, currentIntakeInML: 0, goalInML: getGlobalHydrationGoal())
            modelContext.insert(log)
            currentHydrationLog = log
        }
        log.currentIntakeInML = 0
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