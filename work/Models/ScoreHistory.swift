import Foundation

struct ScoreHistoryEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let scoreType: ScoreType // .recovery or .sleep
    let score: Int
    let baseline: BaselineSnapshot
    let calculatedAt: Date
    
    enum ScoreType: String, Codable {
        case recovery
        case sleep
    }
    
    struct BaselineSnapshot: Codable {
        let hrv60: Double?
        let rhr60: Double?
        let sleepDuration90: Double?
        let bedtime90: Date?
        let wake90: Date?
        // Add more as needed
    }
    
    init(date: Date, scoreType: ScoreType, score: Int, baseline: BaselineSnapshot, calculatedAt: Date = Date()) {
        self.id = UUID()
        self.date = date
        self.scoreType = scoreType
        self.score = score
        self.baseline = baseline
        self.calculatedAt = calculatedAt
    }
}

class ScoreHistoryStore {
    static let shared = ScoreHistoryStore()
    private let fileURL: URL
    private(set) var entries: [ScoreHistoryEntry] = []
    
    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = docs.appendingPathComponent("score_history.json")
        load()
    }
    
    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            entries = try JSONDecoder().decode([ScoreHistoryEntry].self, from: data)
        } catch {
            entries = []
        }
    }
    
    func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save score history: \(error)")
        }
    }
    
    func add(_ entry: ScoreHistoryEntry) {
        entries.removeAll { $0.date == entry.date && $0.scoreType == entry.scoreType }
        entries.append(entry)
        save()
    }
    
    func entry(for date: Date, type: ScoreHistoryEntry.ScoreType) -> ScoreHistoryEntry? {
        entries.first { Calendar.current.isDate($0.date, inSameDayAs: date) && $0.scoreType == type }
    }
} 