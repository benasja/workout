import SwiftUI

struct JournalEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let text: String
    let tags: [String]
    let supplements: [String: Bool] // supplement name -> taken
    let timestamp: Date
    
    init(date: Date, text: String, tags: [String], supplements: [String: Bool]) {
        self.id = UUID()
        self.date = date
        self.text = text
        self.tags = tags
        self.supplements = supplements
        self.timestamp = Date()
    }
}

class JournalManager: ObservableObject {
    static let shared = JournalManager()
    
    @Published var entries: [JournalEntry] = []
    @Published var customTags: [String] = []
    
    private let defaultTags = [
        "#stressful-day", "#ate-late", "#alcohol", "#caffeine-pm", 
        "#sauna", "#cold-plunge", "#felt-energetic", "#sore-muscles", 
        "#traveled", "#workout", "#poor-sleep", "#good-sleep",
        "#meditation", "#social-event", "#sick", "#recovery-day"
    ]
    
    let morningSupplements = [
        "Omega 3 (500/250)",
        "Vitamin D3 (2000IU)", 
        "Vitamin C (500mg)",
        "Creatine (5g)"
    ]
    
    let eveningSupplements = [
        "Zinc (40mg)",
        "Magnesium Glycinate (200mg)",
        "Ashwagandha (570mg)",
        "L-Theanine (200mg)"
    ]
    
    var allTags: [String] {
        return defaultTags + customTags
    }
    
    var allSupplements: [String] {
        return morningSupplements + eveningSupplements
    }
    
    private init() {
        loadData()
    }
    
    func addEntry(_ entry: JournalEntry) {
        entries.append(entry)
        saveData()
    }
    
    func getEntry(for date: Date) -> JournalEntry? {
        let calendar = Calendar.current
        return entries.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    func addCustomTag(_ tag: String) {
        if !customTags.contains(tag) && !defaultTags.contains(tag) {
            customTags.append(tag)
            saveData()
        }
    }
    
    private func saveData() {
        // Save to UserDefaults for now, could be Core Data in production
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: "journalEntries")
        }
        if let encoded = try? JSONEncoder().encode(customTags) {
            UserDefaults.standard.set(encoded, forKey: "customTags")
        }
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: "journalEntries"),
           let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data) {
            entries = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "customTags"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            customTags = decoded
        }
    }
}

struct JournalView: View {
    @Binding var tabSelection: Int
    @StateObject private var journalManager = JournalManager.shared
    @State private var selectedDate = Date()
    @State private var journalText = ""
    @State private var selectedTags: Set<String> = []
    @State private var supplementStatus: [String: Bool] = [:]
    @State private var showingAddTag = false
    @State private var newTagName = ""
    @State private var showingSupplements = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Date Selector
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding()
                        .background(AppColors.secondaryBackground)
                        .cornerRadius(12)
                        .onChange(of: selectedDate) { _, _ in
                            loadEntryForDate()
                        }
                    
                    // Journal Text Entry
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How are you feeling today?")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextEditor(text: $journalText)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(AppColors.tertiaryBackground)
                            .cornerRadius(8)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(AppColors.secondaryBackground)
                    .cornerRadius(12)
                    
                    // Tag Cloud
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Tags")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button("+ Add Tag") {
                                showingAddTag = true
                            }
                            .foregroundColor(.blue)
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                            ForEach(journalManager.allTags, id: \.self) { tag in
                                TagButton(
                                    tag: tag,
                                    isSelected: selectedTags.contains(tag),
                                    action: {
                                        if selectedTags.contains(tag) {
                                            selectedTags.remove(tag)
                                        } else {
                                            selectedTags.insert(tag)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding()
                    .background(AppColors.secondaryBackground)
                    .cornerRadius(12)
                    
                    // Supplements Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Supplements")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(showingSupplements ? "Hide" : "Show") {
                                withAnimation {
                                    showingSupplements.toggle()
                                }
                            }
                            .foregroundColor(.blue)
                        }
                        
                        if showingSupplements {
                            SupplementTrackerView(
                                supplementStatus: $supplementStatus,
                                morningSupplements: journalManager.morningSupplements,
                                eveningSupplements: journalManager.eveningSupplements
                            )
                        }
                    }
                    .padding()
                    .background(AppColors.secondaryBackground)
                    .cornerRadius(12)
                    
                    // Save Button
                    Button("Save Entry") {
                        saveEntry()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding()
            }
            .background(AppColors.background)
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadEntryForDate()
            }
            .alert("Add Custom Tag", isPresented: $showingAddTag) {
                TextField("Tag name", text: $newTagName)
                Button("Add") {
                    if !newTagName.isEmpty {
                        journalManager.addCustomTag(newTagName)
                        newTagName = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    newTagName = ""
                }
            }
        }
    }
    
    private func loadEntryForDate() {
        if let entry = journalManager.getEntry(for: selectedDate) {
            journalText = entry.text
            selectedTags = Set(entry.tags)
            supplementStatus = entry.supplements
        } else {
            journalText = ""
            selectedTags = []
            supplementStatus = [:]
        }
    }
    
    private func saveEntry() {
        let entry = JournalEntry(
            date: selectedDate,
            text: journalText,
            tags: Array(selectedTags),
            supplements: supplementStatus
        )
        journalManager.addEntry(entry)
        
        // Show success feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

struct TagButton: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(red: 0.3, green: 0.3, blue: 0.3))
                .foregroundColor(.white)
                .cornerRadius(16)
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
    }
}

struct SupplementTrackerView: View {
    @Binding var supplementStatus: [String: Bool]
    let morningSupplements: [String]
    let eveningSupplements: [String]
    
    var body: some View {
        VStack(spacing: 16) {
            // Morning Stack
            VStack(alignment: .leading, spacing: 8) {
                Text("Morning Stack")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                ForEach(morningSupplements, id: \.self) { supplement in
                    SupplementRow(
                        supplement: supplement,
                        isTaken: supplementStatus[supplement] ?? false
                    ) {
                        supplementStatus[supplement] = !(supplementStatus[supplement] ?? false)
                    }
                }
                
                Button("Mark All as Taken") {
                    for supplement in morningSupplements {
                        supplementStatus[supplement] = true
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            Divider()
                .background(Color.gray)
            
            // Evening Stack
            VStack(alignment: .leading, spacing: 8) {
                Text("Evening Stack")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                ForEach(eveningSupplements, id: \.self) { supplement in
                    SupplementRow(
                        supplement: supplement,
                        isTaken: supplementStatus[supplement] ?? false
                    ) {
                        supplementStatus[supplement] = !(supplementStatus[supplement] ?? false)
                    }
                }
                
                Button("Mark All as Taken") {
                    for supplement in eveningSupplements {
                        supplementStatus[supplement] = true
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
    }
}

struct SupplementRow: View {
    let supplement: String
    let isTaken: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isTaken ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isTaken ? .green : .gray)
                
                Text(supplement)
                    .foregroundColor(.primary)
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    JournalView(tabSelection: .constant(0))
} 