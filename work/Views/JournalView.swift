import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyJournal.date, order: .reverse) private var journals: [DailyJournal]
    @State private var showingAddJournal = false
    @State private var selectedDate = Date()
    @State private var isSyncing = false
    @State private var editingJournal: DailyJournal? = nil
    var tabSelection: Binding<Int>?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Demo Data Button (only show if no data)
                    if journals.isEmpty {
                        DemoDataButton {
                            // DataSeeder.seedJournalData(context: modelContext) // Disabled demo data
                        }
                    }
                    
                    // Clear Demo Data Button (if there's data)
                    if journals.contains(where: { $0.notes?.contains("demo") == true }) ||
                        (try? modelContext.fetch(FetchDescriptor<Program>())).map { $0.contains(where: { ["Push Day", "Pull Day", "Legs Day"].contains($0.name) }) } == true {
                        ClearDemoDataButton {
                            clearAllDemoData()
                        }
                    }
                    
                    // Sync Health Data Button
                    // if journals.count > 0 {
                    //     SyncHealthDataButton(isSyncing: $isSyncing)
                    // }
                    
                    // Today's Quick Journal
                    QuickJournalCard {
                        editingJournal = nil
                        showingAddJournal = true
                    }
                    
                    // Insights Engine
                    if journals.count < 7 {
                        ModernCard {
                            HStack {
                                Image(systemName: "lightbulb")
                                    .foregroundColor(.orange)
                                Text("Track at least 7 days to unlock lifestyle insights.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                    } else if journals.count >= 7 {
                        InsightsCard(journals: journals)
                    }
                    
                    // Journal History
                    JournalHistoryView(journals: journals)
                }
                .padding()
            }
            .navigationTitle("Daily Journal")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        editingJournal = nil
                        showingAddJournal = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .primaryButton()
                }
            }
            .sheet(isPresented: $showingAddJournal) {
                AddJournalView(existingJournal: editingJournal, allJournals: journals) { saved in
                    // After saving, update the local list if needed
                }
            }
        }
    }
    
    private func clearAllDemoData() {
        // Clear all journal entries
        for journal in journals {
            modelContext.delete(journal)
        }
        
        // Clear all workout sessions
        let workoutDescriptor = FetchDescriptor<WorkoutSession>()
        if let workouts = try? modelContext.fetch(workoutDescriptor) {
            for workout in workouts {
                modelContext.delete(workout)
            }
        }
        
        // Clear all weight entries
        let weightDescriptor = FetchDescriptor<WeightEntry>()
        if let weights = try? modelContext.fetch(weightDescriptor) {
            for weight in weights {
                modelContext.delete(weight)
            }
        }
        
        // Clear all programs (except user-created ones)
        let programDescriptor = FetchDescriptor<Program>()
        if let programs = try? modelContext.fetch(programDescriptor) {
            for program in programs {
                if program.name == "Push Day" || program.name == "Pull Day" || program.name == "Legs Day" {
                    modelContext.delete(program)
                }
            }
        }
        
        // Save changes
        try? modelContext.save()
    }
}

struct SyncHealthDataButton: View {
    @Binding var isSyncing: Bool
    
    var body: some View {
        ModernCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("Sync Health Data")
                        .font(.headline)
                    Spacer()
                }
                
                Text("Connect your journal entries with HealthKit data to discover correlations between lifestyle factors and your health metrics.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                Button(action: syncHealthData) {
                    HStack {
                        if isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "heart.fill")
                        }
                        Text(isSyncing ? "Syncing..." : "Sync Now")
                    }
                    .frame(maxWidth: .infinity)
                }
                .primaryButton()
                .disabled(isSyncing)
            }
        }
    }
    
    private func syncHealthData() {
        isSyncing = true
        
        Task {
            await HealthKitManager.shared.syncJournalWithHealthData()
            
            await MainActor.run {
                isSyncing = false
            }
        }
    }
}

struct QuickJournalCard: View {
    let onAdd: () -> Void
    
    var body: some View {
        ModernCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "book.closed.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("Today's Journal")
                        .font(.headline)
                    Spacer()
                }
                
                Text("Track your lifestyle factors to discover patterns with your recovery and sleep.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                Button(action: onAdd) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Today's Entry")
                    }
                    .frame(maxWidth: .infinity)
                }
                .primaryButton()
            }
        }
    }
}

struct TodayJournalCard: View {
    let journal: DailyJournal
    let onEdit: () -> Void
    
    var body: some View {
        ModernCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    Text("Today's Entry")
                        .font(.headline)
                    Spacer()
                    Button("Edit") {
                        onEdit()
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                
                if journal.tags.isEmpty {
                    Text("No lifestyle factors recorded")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(journal.tags, id: \.self) { tag in
                            HStack {
                                Image(systemName: "tag.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text(tag)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // Health Metrics Section
                if hasHealthData(journal) {
                    HealthMetricsSection(journal: journal)
                }
                
                if let notes = journal.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    private func hasHealthData(_ journal: DailyJournal) -> Bool {
        return journal.recoveryScore != nil || journal.sleepScore != nil || journal.hrv != nil || journal.rhr != nil
    }
}

struct HealthMetricsSection: View {
    let journal: DailyJournal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Metrics")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                if let recoveryScore = journal.recoveryScore {
                    HealthMetricCard(
                        title: "Recovery",
                        value: "\(recoveryScore)",
                        icon: "heart.fill",
                        color: recoveryScore > 70 ? .green : recoveryScore > 50 ? .orange : .red
                    )
                }
                
                if let sleepScore = journal.sleepScore {
                    HealthMetricCard(
                        title: "Sleep",
                        value: "\(sleepScore)",
                        icon: "bed.double.fill",
                        color: sleepScore > 70 ? .green : sleepScore > 50 ? .orange : .red
                    )
                }
                
                if let hrv = journal.hrv {
                    HealthMetricCard(
                        title: "HRV",
                        value: String(format: "%.1f", hrv),
                        icon: "waveform.path.ecg",
                        color: hrv > 30 ? .green : hrv > 20 ? .orange : .red
                    )
                }
                
                if let rhr = journal.rhr {
                    HealthMetricCard(
                        title: "RHR",
                        value: String(format: "%.0f", rhr),
                        icon: "heart.circle.fill",
                        color: rhr < 60 ? .green : rhr < 70 ? .orange : .red
                    )
                }
            }
        }
    }
}

struct HealthMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct InsightsCard: View {
    let journals: [DailyJournal]
    
    var insights: [String] {
        var insights: [String] = []
        
        // Alcohol correlation
        let alcoholDays = journals.filter { $0.consumedAlcohol && $0.recoveryScore != nil }
        if alcoholDays.count >= 3 {
            let avgRecovery = Double(alcoholDays.map { $0.recoveryScore! }.reduce(0, +)) / Double(alcoholDays.count)
            let nonAlcoholDays = journals.filter { !$0.consumedAlcohol && $0.recoveryScore != nil }
            if nonAlcoholDays.count >= 3 {
                let avgNonAlcohol = Double(nonAlcoholDays.map { $0.recoveryScore! }.reduce(0, +)) / Double(nonAlcoholDays.count)
                let difference = avgNonAlcohol - avgRecovery
                if difference > 10 {
                    insights.append("On days you consume alcohol, your recovery score is \(String(format: "%.1f", difference)) points lower on average.")
                }
            }
        }
        
        // Magnesium correlation
        let magnesiumDays = journals.filter { $0.tookMagnesium && $0.sleepScore != nil }
        if magnesiumDays.count >= 3 {
            let avgSleep = Double(magnesiumDays.map { $0.sleepScore! }.reduce(0, +)) / Double(magnesiumDays.count)
            let nonMagnesiumDays = journals.filter { !$0.tookMagnesium && $0.sleepScore != nil }
            if nonMagnesiumDays.count >= 3 {
                let avgNonMagnesium = Double(nonMagnesiumDays.map { $0.sleepScore! }.reduce(0, +)) / Double(nonMagnesiumDays.count)
                let difference = avgSleep - avgNonMagnesium
                if difference > 5 {
                    insights.append("On days you take magnesium, your sleep score is \(String(format: "%.1f", difference)) points higher on average.")
                }
            }
        }
        
        // Stress correlation
        let stressDays = journals.filter { $0.highStressDay && $0.hrv != nil }
        if stressDays.count >= 3 {
            let avgHRV = stressDays.map { $0.hrv! }.reduce(0, +) / Double(stressDays.count)
            let nonStressDays = journals.filter { !$0.highStressDay && $0.hrv != nil }
            if nonStressDays.count >= 3 {
                let avgNonStress = nonStressDays.map { $0.hrv! }.reduce(0, +) / Double(nonStressDays.count)
                let difference = avgNonStress - avgHRV
                if difference > 5 {
                    insights.append("On high-stress days, your HRV is \(String(format: "%.1f", difference))ms lower on average.")
                }
            }
        }
        
        if insights.isEmpty {
            insights.append("Continue tracking to discover patterns with your lifestyle factors.")
        }
        
        return insights
    }
    
    var body: some View {
        ModernCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("Insights")
                        .font(.headline)
                    Spacer()
                }
                
                ForEach(insights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.top, 2)
                        Text(insight)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct JournalHistoryView: View {
    let journals: [DailyJournal]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Journal History")
                .font(.headline)
            
            LazyVStack(spacing: 12) {
                ForEach(journals.prefix(10)) { journal in
                    JournalHistoryRow(journal: journal)
                }
            }
        }
    }
}

struct JournalHistoryRow: View {
    let journal: DailyJournal
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(journal.date, style: .date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if !journal.tags.isEmpty {
                    HStack {
                        ForEach(journal.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                        if journal.tags.count > 3 {
                            Text("+\(journal.tags.count - 3)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Health Metrics Summary
            HStack(spacing: 8) {
                if let recoveryScore = journal.recoveryScore {
                    VStack(spacing: 2) {
                        Text("\(recoveryScore)")
                            .font(.headline)
                            .foregroundColor(recoveryScore > 70 ? .green : recoveryScore > 50 ? .orange : .red)
                        Text("Recovery")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let sleepScore = journal.sleepScore {
                    VStack(spacing: 2) {
                        Text("\(sleepScore)")
                            .font(.headline)
                            .foregroundColor(sleepScore > 70 ? .green : sleepScore > 50 ? .orange : .red)
                        Text("Sleep")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AddJournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let existingJournal: DailyJournal?
    let allJournals: [DailyJournal]
    let onSave: (Bool) -> Void
    
    @State private var consumedAlcohol = false
    @State private var caffeineAfter2PM = false
    @State private var ateLate = false
    @State private var highStressDay = false
    @State private var tookMagnesium = false
    @State private var tookAshwagandha = false
    @State private var notes = ""
    @State private var entryDate: Date = Date()
    @State private var editingJournal: DailyJournal? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Date Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Entry Date")
                            .font(.headline)
                        DatePicker("", selection: $entryDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .onChange(of: entryDate) { newDate in
                                if let match = allJournals.first(where: { Calendar.current.isDate($0.date, inSameDayAs: newDate) }) {
                                    loadJournal(match)
                                    editingJournal = match
                                } else {
                                    clearFieldsForNewDate()
                                    editingJournal = nil
                                }
                            }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    // Lifestyle Factors
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Lifestyle Factors")
                            .font(.headline)
                        VStack(spacing: 12) {
                            ToggleRow(title: "Consumed Alcohol", icon: "wineglass", isOn: $consumedAlcohol)
                            ToggleRow(title: "Caffeine after 2 PM", icon: "cup.and.saucer", isOn: $caffeineAfter2PM)
                            ToggleRow(title: "Ate Late (within 3hrs of bed)", icon: "clock", isOn: $ateLate)
                            ToggleRow(title: "High Stress Day", icon: "exclamationmark.triangle", isOn: $highStressDay)
                            ToggleRow(title: "Took Magnesium", icon: "pills", isOn: $tookMagnesium)
                            ToggleRow(title: "Took Ashwagandha", icon: "leaf", isOn: $tookAshwagandha)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        TextField("Any additional notes...", text: $notes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }
                }
                .padding()
            }
            .navigationTitle("Daily Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveJournal()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let existing = existingJournal {
                    loadJournal(existing)
                    editingJournal = existing
                }
            }
        }
    }

    private func loadJournal(_ journal: DailyJournal) {
        consumedAlcohol = journal.consumedAlcohol
        caffeineAfter2PM = journal.caffeineAfter2PM
        ateLate = journal.ateLate
        highStressDay = journal.highStressDay
        tookMagnesium = journal.tookMagnesium
        tookAshwagandha = journal.tookAshwagandha
        notes = journal.notes ?? ""
        entryDate = journal.date
    }

    private func clearFieldsForNewDate() {
        consumedAlcohol = false
        caffeineAfter2PM = false
        ateLate = false
        highStressDay = false
        tookMagnesium = false
        tookAshwagandha = false
        notes = ""
    }

    private func saveJournal() {
        // Check if a journal for this date exists
        let match = allJournals.first(where: { Calendar.current.isDate($0.date, inSameDayAs: entryDate) })
        if let existing = match ?? editingJournal {
            // Update existing
            existing.consumedAlcohol = consumedAlcohol
            existing.caffeineAfter2PM = caffeineAfter2PM
            existing.ateLate = ateLate
            existing.highStressDay = highStressDay
            existing.tookMagnesium = tookMagnesium
            existing.tookAshwagandha = tookAshwagandha
            existing.notes = notes.isEmpty ? nil : notes
            existing.date = entryDate
        } else {
            // Create new
            let newJournal = DailyJournal(
                date: entryDate,
                consumedAlcohol: consumedAlcohol,
                caffeineAfter2PM: caffeineAfter2PM,
                ateLate: ateLate,
                highStressDay: highStressDay,
                tookMagnesium: tookMagnesium,
                tookAshwagandha: tookAshwagandha,
                notes: notes.isEmpty ? nil : notes
            )
            modelContext.insert(newJournal)
        }
        try? modelContext.save()
        dismiss()
        onSave(true)
    }
}

struct ToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

struct DemoDataButton: View {
    let onTap: () -> Void
    
    var body: some View {
        ModernCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "database.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("No Journal Data")
                        .font(.headline)
                    Spacer()
                }
                
                Text("Start tracking your daily lifestyle factors to discover patterns with your health metrics.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                Button(action: onTap) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Your First Entry")
                    }
                    .frame(maxWidth: .infinity)
                }
                .primaryButton()
            }
        }
    }
}

struct ClearDemoDataButton: View {
    let onClear: () -> Void
    
    var body: some View {
        ModernCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "trash.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    Text("Clear Demo Data")
                        .font(.headline)
                    Spacer()
                }
                
                Text("Remove all demo data and start fresh with your own personal HealthKit data.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                Button(action: onClear) {
                    HStack {
                        Image(systemName: "trash.circle.fill")
                        Text("Clear All Demo Data")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
    }
} 