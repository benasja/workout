import Foundation
import SwiftData

@Model
final class ScoreHistory {
    var id: UUID
    var date: Date
    var scoreType: ScoreType
    var score: Int
    var calculatedAt: Date
    
    // Baseline snapshot properties
    var hrv60: Double?
    var rhr60: Double?
    var sleepDuration90: Double?
    var bedtime90: Date?
    var wake90: Date?
    
    init(date: Date, scoreType: ScoreType, score: Int, baseline: BaselineSnapshot, calculatedAt: Date = Date()) {
        self.id = UUID()
        self.date = date
        self.scoreType = scoreType
        self.score = score
        self.calculatedAt = calculatedAt
        
        // Store baseline data as individual properties
        self.hrv60 = baseline.hrv60
        self.rhr60 = baseline.rhr60
        self.sleepDuration90 = baseline.sleepDuration90
        self.bedtime90 = baseline.bedtime90
        self.wake90 = baseline.wake90
    }
    
    // Computed property for compatibility
    var baseline: BaselineSnapshot {
        BaselineSnapshot(
            hrv60: hrv60,
            rhr60: rhr60,
            sleepDuration90: sleepDuration90,
            bedtime90: bedtime90,
            wake90: wake90
        )
    }
}

enum ScoreType: String, CaseIterable, Codable {
    case recovery
    case sleep
}

struct BaselineSnapshot: Codable {
    let hrv60: Double?
    let rhr60: Double?
    let sleepDuration90: Double?
    let bedtime90: Date?
    let wake90: Date?
}

@MainActor
class ScoreHistoryStore {
    static let shared = ScoreHistoryStore()
    private var modelContext: ModelContext?
    
    private init() {}
    
    func initialize(with context: ModelContext) {
        self.modelContext = context
        migrateFromFileStorageIfNeeded()
    }
    
    func add(_ entry: ScoreHistory) {
        guard let context = modelContext else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: entry.date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let targetScoreType = entry.scoreType
        
        // Remove existing entry for same date and type
        let descriptor = FetchDescriptor<ScoreHistory>(
            predicate: #Predicate<ScoreHistory> { history in
                history.date >= startOfDay && 
                history.date < endOfDay && 
                history.scoreType == targetScoreType
            }
        )
        
        do {
            let existing = try context.fetch(descriptor)
            for existingEntry in existing {
                context.delete(existingEntry)
            }
            
            context.insert(entry)
            try context.save()
        } catch {
            print("❌ Failed to save score history: \(error)")
        }
    }
    
    func entry(for date: Date, type: ScoreType) -> ScoreHistory? {
        guard let context = modelContext else { return nil }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let targetType = type
        
        let descriptor = FetchDescriptor<ScoreHistory>(
            predicate: #Predicate<ScoreHistory> { history in
                history.date >= startOfDay && 
                history.date < endOfDay && 
                history.scoreType == targetType
            }
        )
        
        do {
            let entries = try context.fetch(descriptor)
            return entries.first
        } catch {
            print("❌ Failed to fetch score history: \(error)")
            return nil
        }
    }
    
    func allEntries() -> [ScoreHistory] {
        guard let context = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<ScoreHistory>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ Failed to fetch all score history: \(error)")
            return []
        }
    }
    
    private func migrateFromFileStorageIfNeeded() {
        guard let context = modelContext else { return }
        
        // Check if migration is needed
        let existingCount = (try? context.fetch(FetchDescriptor<ScoreHistory>()).count) ?? 0
        if existingCount > 0 {
            return // Already migrated
        }
        
        // Try to load from old file storage
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docs.appendingPathComponent("score_history.json")
        
        do {
            let data = try Data(contentsOf: fileURL)
            let legacyEntries = try JSONDecoder().decode([LegacyScoreHistoryEntry].self, from: data)
            
            // Convert to SwiftData models
            for legacyEntry in legacyEntries {
                let scoreHistory = ScoreHistory(
                    date: legacyEntry.date,
                    scoreType: legacyEntry.scoreType,
                    score: legacyEntry.score,
                    baseline: legacyEntry.baseline,
                    calculatedAt: legacyEntry.calculatedAt
                )
                context.insert(scoreHistory)
            }
            
            try context.save()
            
            // Remove old file
            try FileManager.default.removeItem(at: fileURL)
            print("✅ Migrated score history from file storage to SwiftData")
            
        } catch {
            // No existing file or migration failed - that's fine
            print("ℹ️ No existing score history file to migrate")
        }
    }
}

// Legacy structure for migration
private struct LegacyScoreHistoryEntry: Codable {
    let id: UUID
    let date: Date
    let scoreType: ScoreType
    let score: Int
    let baseline: BaselineSnapshot
    let calculatedAt: Date
} 