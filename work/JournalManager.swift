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
} 