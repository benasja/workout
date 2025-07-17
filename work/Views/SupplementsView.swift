import SwiftUI
import SwiftData

struct SupplementsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyJournal.date, order: .reverse) private var journalEntries: [DailyJournal]
    
    @State private var selectedDate = Date()
    @State private var selectedTime: TimeOfDay = .morning
    @State private var supplementLog: [TimeOfDay: Set<Supplement>] = [
        .morning: [], .midday: [], .evening: []
    ]
    var tabSelection: Binding<Int>?
    
    @State private var showSaveConfirmation = false
    
    let allSupplements: [Supplement] = [
        .creatine, .vitaminC, .vitaminD, .vitaminB, .magnesium, .zinc, .omega3, .multivitamin, .probiotic
    ]
    
    private var currentJournalEntry: DailyJournal? {
        let calendar = Calendar.current
        return journalEntries.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                // Date Slider
                DateSliderView(selectedDate: $selectedDate)
                    .padding(.horizontal)
                
                // Time of Day Picker
                Picker("Time of Day", selection: $selectedTime) {
                    ForEach(TimeOfDay.allCases, id: \.self) { time in
                        Text(time.displayName).tag(time)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Supplements Grid
                ModernCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Supplements for \(selectedTime.displayName)")
                                .font(.headline)
                            Spacer()
                            Text(selectedDate, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 16)], spacing: 16) {
                            ForEach(allSupplements, id: \.self) { supplement in
                                SupplementToggle(
                                    supplement: supplement,
                                    isOn: isSupplementTaken(supplement, at: selectedTime),
                                    toggle: {
                                        toggleSupplement(supplement, at: selectedTime)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Daily Summary
                if let entry = currentJournalEntry {
                    ModernCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Today's Summary")
                                .font(.headline)
                            
                            let takenSupplements = getTakenSupplements(for: entry)
                            if takenSupplements.isEmpty {
                                Text("No supplements logged yet")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                                    ForEach(takenSupplements, id: \.self) { supplement in
                                        HStack(spacing: 4) {
                                            Image(systemName: supplement.icon)
                                                .foregroundColor(.green)
                                                .font(.caption)
                                            Text(supplement.rawValue)
                                                .font(.caption)
                                                .foregroundColor(.primary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Supplements")
            .navigationBarTitleDisplayMode(.large)
            .background(AppColors.background)
            .refreshable {
                loadSupplementsForDate()
            }
            .onAppear {
                loadSupplementsForDate()
            }
            .onChange(of: selectedDate) { _, _ in
                loadSupplementsForDate()
            }
            .onChange(of: selectedTime) { _, _ in
                // No need to reload, just refresh UI
            }
            .overlay(
                Group {
                    if showSaveConfirmation {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("Saved!")
                                    .padding(12)
                                    .background(Color.green.opacity(0.9))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .shadow(radius: 4)
                                Spacer()
                            }
                            Spacer()
                        }
                        .transition(.opacity)
                    }
                }
            )
        }
    }
    
    private func isSupplementTaken(_ supplement: Supplement, at time: TimeOfDay) -> Bool {
        return supplementLog[time, default: []].contains(supplement)
    }
    
    private func toggleSupplement(_ supplement: Supplement, at time: TimeOfDay) {
        if supplementLog[time, default: []].contains(supplement) {
            supplementLog[time]?.remove(supplement)
        } else {
            supplementLog[time, default: []].insert(supplement)
        }
        // Auto-save immediately when toggling
        saveSupplementsForDate()
    }
    
    private func loadSupplementsForDate() {
        // Always reset first
        supplementLog = [.morning: [], .midday: [], .evening: []]
        
        // Load from journal entry if exists
        if let entry = currentJournalEntry {
            // Load supplements for each time period
            let morningSupps = entry.getSupplementsForTime("morning")
            let middaySupps = entry.getSupplementsForTime("midday")
            let eveningSupps = entry.getSupplementsForTime("evening")
            
            // Convert string names back to Supplement enum
            supplementLog[.morning] = Set(morningSupps.compactMap { supplementName in
                allSupplements.first { $0.rawValue == supplementName }
            })
            
            supplementLog[.midday] = Set(middaySupps.compactMap { supplementName in
                allSupplements.first { $0.rawValue == supplementName }
            })
            
            supplementLog[.evening] = Set(eveningSupps.compactMap { supplementName in
                allSupplements.first { $0.rawValue == supplementName }
            })
            
            print("📋 Loaded supplements for \(selectedDate): Morning: \(morningSupps.count), Midday: \(middaySupps.count), Evening: \(eveningSupps.count)")
        } else {
            print("📋 No journal entry found for \(selectedDate)")
        }
    }
    
    private func saveSupplementsForDate() {
        let entry: DailyJournal
        if let existingEntry = currentJournalEntry {
            entry = existingEntry
        } else {
            entry = DailyJournal(date: selectedDate)
            modelContext.insert(entry)
        }
        // Convert supplement enums to string names and save for each time period
        let morningNames = Set(supplementLog[.morning, default: []].map { $0.rawValue })
        let middayNames = Set(supplementLog[.midday, default: []].map { $0.rawValue })
        let eveningNames = Set(supplementLog[.evening, default: []].map { $0.rawValue })
        entry.setSupplementsForTime("morning", supplements: morningNames)
        entry.setSupplementsForTime("midday", supplements: middayNames)
        entry.setSupplementsForTime("evening", supplements: eveningNames)
        do {
            try modelContext.save()
            // Reload to ensure UI is up to date
            loadSupplementsForDate()
            // Show confirmation
            showSaveConfirmation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showSaveConfirmation = false
            }
        } catch {
            print("❌ Failed to save supplements: \(error)")
        }
    }
    
    private func getTakenSupplements(for entry: DailyJournal) -> [Supplement] {
        var supplements: [Supplement] = []
        
        // Get all supplements taken throughout the day
        let allTakenNames = Set([
            entry.getSupplementsForTime("morning"),
            entry.getSupplementsForTime("midday"),
            entry.getSupplementsForTime("evening")
        ].flatMap { $0 })
        
        // Convert back to Supplement enum
        supplements = allTakenNames.compactMap { supplementName in
            allSupplements.first { $0.rawValue == supplementName }
        }
        
        return supplements.sorted { $0.rawValue < $1.rawValue }
    }
    
    enum TimeOfDay: String, CaseIterable {
        case morning, midday, evening
        var displayName: String {
            switch self {
            case .morning: return "Morning"
            case .midday: return "Midday"
            case .evening: return "Evening"
            }
        }
    }
    
    enum Supplement: String, CaseIterable, Hashable {
        case creatine = "Creatine"
        case vitaminC = "Vitamin C"
        case vitaminD = "Vitamin D"
        case vitaminB = "Vitamin B Complex"
        case magnesium = "Magnesium"
        case zinc = "Zinc"
        case omega3 = "Omega-3"
        case multivitamin = "Multivitamin"
        case probiotic = "Probiotic"
        
        var icon: String {
            switch self {
            case .creatine: return "bolt.heart.fill"
            case .vitaminC: return "sun.max.fill"
            case .vitaminD: return "sun.max"
            case .vitaminB: return "capsule.portrait.fill"
            case .magnesium: return "leaf.fill"
            case .zinc: return "drop.fill"
            case .omega3: return "fish.fill"
            case .multivitamin: return "pills.fill"
            case .probiotic: return "face.smiling"
            }
        }
    }
}

struct SupplementToggle: View {
    let supplement: SupplementsView.Supplement
    let isOn: Bool
    let toggle: () -> Void
    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Image(systemName: supplement.icon)
                    .font(.title2)
                    .foregroundColor(isOn ? .blue : .gray)
                Text(supplement.rawValue)
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isOn ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
} 