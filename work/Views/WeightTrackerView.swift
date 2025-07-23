//
//  WeightTrackerView.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct WeightTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    
    @State private var showingAddEntry = false
    @State private var manualWeightEntries: [WeightEntry] = []
    @State private var healthKitWeightData: [WeightData] = []
    @State private var isLoading = false
    @State private var isSyncing = false
    @State private var dateRange: ClosedRange<Date>? = nil
    // Prevents multiple full-history fetches which can cause loops/crashes
    @State private var hasFetchedHealthKit = false
    @State var editingEntry: WeightEntry? = nil
    @State private var lastSyncDate: Date?
    
    // Combined weight entries from both manual and HealthKit
    private var allWeightEntries: [WeightEntry] {
        var combined = weightEntries
        
        // Convert HealthKit data to WeightEntry format for display
        let healthKitEntries = healthKitWeightData.map { data in
            WeightEntry(date: data.date, weight: data.weight, notes: "From \(data.source)")
        }
        
        // Remove duplicates (prefer manual entries over HealthKit for same date)
        let calendar = Calendar.current
        let manualDates = Set(combined.map { calendar.startOfDay(for: $0.date) })
        
        let uniqueHealthKitEntries = healthKitEntries.filter { entry in
            !manualDates.contains(calendar.startOfDay(for: entry.date))
        }
        
        combined.append(contentsOf: uniqueHealthKitEntries)
        return combined.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: AppSpacing.xl) {
                    // Sync Status Banner
                    if isSyncing {
                        ModernCard {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Syncing with Apple Health...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal)
                    } else if let syncDate = lastSyncDate {
                        ModernCard {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                Text("Last synced: \(syncDate, style: .relative) ago")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(healthKitWeightData.count) from Health")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal)
                    }
                    
                    if (allWeightEntries.isEmpty) {
                        EmptyWeightView {
                            showingAddEntry = true
                        }
                    } else {
                        let sortedEntries = allWeightEntries.sorted { $0.date < $1.date }
                        let minDate = sortedEntries.first?.date ?? Date()
                        let maxDate = sortedEntries.last?.date ?? Date()
                        let range = dateRange ?? minDate...maxDate
                        let filteredEntries = sortedEntries.filter { range.contains($0.date) }
                        WeightChartView(weightEntries: filteredEntries, minDate: minDate, maxDate: maxDate)
                        if minDate < maxDate {
                            DateRangePickers(minDate: minDate, maxDate: maxDate, dateRange: $dateRange)
                        }
                        let uniqueEntries = Dictionary(grouping: allWeightEntries) { entry in
                            let comps = Calendar.current.dateComponents([.year, .month, .day], from: entry.date)
                            return Calendar.current.date(from: comps) ?? entry.date
                        }
                        .mapValues { $0.max(by: { $0.date < $1.date })! }
                        .values
                        .sorted { $0.date > $1.date }

                        VStack(spacing: 12) {
                            ForEach(uniqueEntries, id: \.id) { entry in
                                Button(action: { editingEntry = entry }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(entry.date, formatter: dateFormatter)
                                                    .font(.headline)
                                                Spacer()
                                                // Source indicator
                                                if let notes = entry.notes, notes.contains("From") || notes.contains("Synced from") {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "heart.fill")
                                                            .font(.caption2)
                                                            .foregroundColor(.red)
                                                        Text("Health")
                                                            .font(.caption2)
                                                            .foregroundColor(.secondary)
                                                    }
                                                } else {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "pencil")
                                                            .font(.caption2)
                                                            .foregroundColor(.blue)
                                                        Text("Manual")
                                                            .font(.caption2)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                            }
                                            Text("\(entry.weight, specifier: "%.1f") kg")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                            if let notes = entry.notes, !notes.isEmpty {
                                                Text(notes)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .sheet(item: $editingEntry) { entry in
                            EditWeightEntryView(entry: entry, modelContext: modelContext, onDelete: {
                                if let idx = weightEntries.firstIndex(where: { $0.id == entry.id }) {
                                    modelContext.delete(weightEntries[idx])
                                    do { try modelContext.save() } catch {}
                                }
                                editingEntry = nil
                            }) {
                                editingEntry = nil
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
            }
            .refreshable {
                syncWithHealthKit()
            }
            .background(AppColors.background)
            .navigationTitle("Weight Tracker")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // Removed leading toolbar menu for cleaner UI
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddEntry = true }) {
                        Image(systemName: "plus")
                    }
                    .iconButton(color: AppColors.primary)
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                MinimalAddWeightEntryView(modelContext: modelContext) {
                    refreshData()
                }
            }
            .onAppear {
                refreshData()
                // Trigger a single HealthKit sync on the first appearance only
                if !hasFetchedHealthKit {
                    hasFetchedHealthKit = true
                    syncWithHealthKit()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .healthKitWeightDidChange)) { _ in
                // A new weight was added via HealthKit save call; refresh lightweight arrays.
                refreshHealthKitEntries()
            }
        }
    }
    
    private func refreshData() {
        isLoading = true
        do {
            try modelContext.save()
        } catch {
            print("❌ Error saving model context: \(error)")
        }
        loadWeightEntries()
        // Removed automatic refreshHealthKitEntries to avoid repeated large fetches
        
        // Debug: Print weight entries count
        print("🔍 Weight entries count: \(weightEntries.count)")
        print("🔍 Manual weight entries count: \(manualWeightEntries.count)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isLoading = false
        }
    }
    
    private func loadWeightEntries() {
        do {
            let descriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            let entries = try modelContext.fetch(descriptor)
            manualWeightEntries = entries
        } catch {}
    }
    
    private func exportData() {
        // Export weight entries as CSV and present share sheet
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        var csv = "date,weight\n"
        for entry in weightEntries.reversed() { // oldest first
            let dateStr = dateFormatter.string(from: entry.date)
            let weightStr = String(format: "%.2f", entry.weight)
            csv += "\(dateStr),\(weightStr)\n"
        }
        guard let data = csv.data(using: .utf8) else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("weight_entries.csv")
        do {
            try data.write(to: tempURL)
            let av = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                root.present(av, animated: true)
            }
        } catch {
            print("❌ Failed to write CSV: \(error)")
        }
    }
    
    private func importData() {
        // Present document picker for CSV import
        let delegate = WeightCSVImportDelegate(modelContext: modelContext, onImport: {
            refreshData()
        })
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.commaSeparatedText])
        picker.allowsMultipleSelection = false
        picker.delegate = delegate
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(picker, animated: true)
        }
    }
    
    private func addSampleData() {
        let calendar = Calendar.current
        let today = Date()
        
        // Create sample weight entries for the past 30 days
        let sampleWeights = [75.2, 75.0, 74.8, 75.1, 74.9, 75.3, 75.0, 74.7, 74.9, 75.2,
                           75.1, 74.8, 75.0, 74.6, 74.9, 75.1, 74.8, 75.2, 75.0, 74.7,
                           74.9, 75.3, 75.1, 74.8, 75.0, 74.9, 75.2, 75.0, 74.8, 75.1]
        
        for (index, weight) in sampleWeights.enumerated() {
            if let date = calendar.date(byAdding: .day, value: -index, to: today) {
                let entry = WeightEntry(date: date, weight: weight, notes: index == 0 ? "Current weight" : nil)
                modelContext.insert(entry)
            }
        }
        
        do {
            try modelContext.save()
            print("✅ Added \(sampleWeights.count) sample weight entries")
            refreshData()
        } catch {
            print("❌ Failed to save sample weight entries: \(error)")
        }
    }
    
    private func debugWeightData() {
        print("🔍 === Weight Data Debug ===")
        print("🔍 Total weight entries: \(weightEntries.count)")
        print("🔍 Manual weight entries: \(manualWeightEntries.count)")
        
        if !weightEntries.isEmpty {
            let sortedEntries = weightEntries.sorted { $0.date < $1.date }
            print("🔍 Date range: \(sortedEntries.first?.date ?? Date()) to \(sortedEntries.last?.date ?? Date())")
            print("🔍 Weight range: \(sortedEntries.map { $0.weight }.min() ?? 0) to \(sortedEntries.map { $0.weight }.max() ?? 0)")
            
            print("🔍 Recent entries:")
            for entry in weightEntries.prefix(5) {
                print("   - \(entry.date): \(entry.weight)kg")
            }
        } else {
            print("🔍 No weight entries found")
            
            // Try to fetch directly from model context
            do {
                let descriptor = FetchDescriptor<WeightEntry>()
                let allEntries = try modelContext.fetch(descriptor)
                print("🔍 Direct fetch found \(allEntries.count) entries")
            } catch {
                print("🔍 Direct fetch failed: \(error)")
            }
        }
        print("🔍 === End Debug ===")
    }
    
    private func syncWithHealthKit() {
        guard !isSyncing else { return }
        
        isSyncing = true
        print("🔄 Starting HealthKit weight sync...")
        
        // First, request authorization
        HealthKitManager.shared.requestAuthorization { [self] success in
            guard success else {
                print("❌ HealthKit authorization failed")
                DispatchQueue.main.async {
                    self.isSyncing = false
                }
                return
            }
            
            // Fetch the user's entire weight history from HealthKit
            HealthKitManager.shared.fetchAllWeightEntries { [self] weightData in
                DispatchQueue.main.async {
                    self.healthKitWeightData = weightData
                    self.lastSyncDate = Date()
                    self.isSyncing = false
 
                    print("✅ HealthKit sync completed: \(weightData.count) entries")
                    // Note: We intentionally do NOT store all HealthKit samples into local database anymore to avoid performance issues.
                    // Skip converting every HealthKit sample into local storage to keep memory/performance in check.
                }
            }
        }
    }

    // MARK: - Fetch latest HealthKit weight data on demand
    private func refreshHealthKitEntries() {
        // Optional manual refresh if needed (not called automatically anymore)
        HealthKitManager.shared.fetchAllWeightEntries { data in
            DispatchQueue.main.async {
                self.healthKitWeightData = data
                self.lastSyncDate = Date()
            }
        }
    }

    private func convertHealthKitDataToLocalEntries(_ weightData: [WeightData]) {
        let calendar = Calendar.current
        var addedCount = 0
        
        // Get existing manual entry dates to avoid duplicates
        let existingDates = Set(weightEntries.map { calendar.startOfDay(for: $0.date) })
        
        for data in weightData {
            let entryDate = calendar.startOfDay(for: data.date)
            
            // Only add if we don't already have a manual entry for this date
            if !existingDates.contains(entryDate) {
                let entry = WeightEntry(
                    date: data.date,
                    weight: data.weight,
                    notes: "Synced from \(data.source)"
                )
                modelContext.insert(entry)
                addedCount += 1
            }
        }
        
        if addedCount > 0 {
            do {
                try modelContext.save()
                print("✅ Added \(addedCount) weight entries from HealthKit")
                refreshData()
            } catch {
                print("❌ Failed to save HealthKit weight entries: \(error)")
            }
        } else {
            print("ℹ️ No new weight entries to add from HealthKit")
        }
    }
}

private let dateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateStyle = .short
    return df
}()

struct EmptyWeightView: View {
    let onAddEntry: () -> Void
    
    var body: some View {
        EmptyStateView(
            icon: "scalemass",
            title: "No Weight Entries Yet",
            message: "Start tracking your weight to see your progress over time and monitor your fitness journey.",
            actionTitle: "Add First Entry",
            action: onAddEntry
        )
    }
}

struct WeightChartView: View {
    let weightEntries: [WeightEntry]
    let minDate: Date
    let maxDate: Date
    
    private var chartEntries: [WeightEntry] {
        // Keep only the entries from the last 90 days for the chart view
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        return weightEntries.filter { $0.date >= ninetyDaysAgo }
                          .sorted { $0.date < $1.date }
    }

    private var stats: (lowest: Double, lowestDate: Date?, highest: Double, highestDate: Date?, started: Double, startedDate: Date?, current: Double, currentDate: Date?) {
        let sorted = weightEntries.sorted { $0.date < $1.date }
        let lowest = sorted.min(by: { $0.weight < $1.weight })
        let highest = sorted.max(by: { $0.weight < $1.weight })
        let started = sorted.first
        let current = sorted.last
        return (
            lowest: lowest?.weight ?? 0,
            lowestDate: lowest?.date,
            highest: highest?.weight ?? 0,
            highestDate: highest?.date,
            started: started?.weight ?? 0,
            startedDate: started?.date,
            current: current?.weight ?? 0,
            currentDate: current?.date
        )
    }
    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SectionHeaderView(
                    title: "Weight Progress",
                    subtitle: statsSubtitle,
                    actionTitle: nil,
                    action: nil
                )
                if chartEntries.count < 2 {
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundColor(AppColors.textTertiary)
                        Text("Add more entries to see your progress chart")
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(height: 120)
                } else {
                    VStack(spacing: AppSpacing.lg) {
                        GeometryReader { geometry in
                            ZStack {
                                VStack(spacing: 0) {
                                    ForEach(0..<5, id: \ .self) { _ in
                                        Divider()
                                            .frame(height: 1)
                                            .background(AppColors.textTertiary.opacity(0.2))
                                        Spacer()
                                    }
                                }
                                let sortedEntries = chartEntries // safe shortcut

                                Path { path in
                                    let sortedEntries = chartEntries // safe shortcut
                                    let minWeight = sortedEntries.map { $0.weight }.min() ?? 0
                                    let maxWeight = sortedEntries.map { $0.weight }.max() ?? 100
                                    let weightRange = maxWeight - minWeight
                                    let width = geometry.size.width - 40
                                    let height = geometry.size.height - 40
                                    let minDate = sortedEntries.first?.date ?? Date()
                                    let maxDate = sortedEntries.last?.date ?? Date()
                                    let totalTime = maxDate.timeIntervalSince(minDate)
                                    for (index, entry) in sortedEntries.enumerated() {
                                        let timeSinceStart = entry.date.timeIntervalSince(minDate)
                                        let x = 20 + (CGFloat(totalTime == 0 ? 0 : timeSinceStart / totalTime)) * width
                                        let normalizedWeight = weightRange > 0 ? (entry.weight - minWeight) / weightRange : 0.5
                                        let y = 20 + (1 - normalizedWeight) * height
                                        if index == 0 {
                                            path.move(to: CGPoint(x: x, y: y))
                                        } else {
                                            path.addLine(to: CGPoint(x: x, y: y))
                                        }
                                    }
                                }
                                .stroke(
                                    LinearGradient(
                                        colors: [AppColors.primary, AppColors.secondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                                )
                                // No per-point circles – keeps view hierarchy light
                                // X-axis labels
                                HStack {
                                    Text(minDate, style: .date)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(maxDate, style: .date)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, geometry.size.height - 20)
                            }
                        }
                        .frame(height: 200)
                    }
                }
            }
        }
    }

    private var statsSubtitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        func dateStr(_ d: Date?) -> String { d.map { formatter.string(from: $0) } ?? "-" }
        return "lowest: \(String(format: "%.1f", stats.lowest))kg (\(dateStr(stats.lowestDate)))  " +
               "highest: \(String(format: "%.1f", stats.highest))kg (\(dateStr(stats.highestDate)))\n" +
               "started: \(String(format: "%.1f", stats.started))kg (\(dateStr(stats.startedDate)))  " +
               "current: \(String(format: "%.1f", stats.current))kg (\(dateStr(stats.currentDate)))"
    }
}

struct DateRangePickers: View {
    let minDate: Date
    let maxDate: Date
    @Binding var dateRange: ClosedRange<Date>?
    @State private var start: Date = Date()
    @State private var end: Date = Date()
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                DatePicker("Start", selection: Binding(
                    get: { dateRange?.lowerBound ?? minDate },
                    set: { newValue in
                        let upper = dateRange?.upperBound ?? maxDate
                        dateRange = newValue...max(upper, newValue)
                    }
                ), in: minDate...maxDate, displayedComponents: .date)
                .labelsHidden()
                Spacer()
                DatePicker("End", selection: Binding(
                    get: { dateRange?.upperBound ?? maxDate },
                    set: { newValue in
                        let lower = dateRange?.lowerBound ?? minDate
                        dateRange = min(lower, newValue)...newValue
                    }
                ), in: minDate...maxDate, displayedComponents: .date)
                .labelsHidden()
            }
        }
        .padding(.horizontal, 8)
    }
}

struct WeightEntriesList: View {
    let weightEntries: [WeightEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var editingEntry: WeightEntry? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            SectionHeaderView(
                title: "Weight Entries",
                subtitle: "Your weight tracking history",
                actionTitle: nil,
                action: nil
            )
            
            List {
                ForEach(weightEntries, id: \.id) { entry in
                    WeightEntryRow(entry: entry)
                        .onTapGesture { editingEntry = entry }
                }
                .onDelete(perform: deleteEntries)
            }
            .listStyle(.plain)
        }
        .sheet(item: $editingEntry) { entry in
            EditWeightEntryView(entry: entry, modelContext: modelContext, onDelete: {
                if let idx = weightEntries.firstIndex(where: { $0.id == entry.id }) {
                    modelContext.delete(weightEntries[idx])
                    do { try modelContext.save() } catch {}
                }
                editingEntry = nil
            }, onSave: {
                editingEntry = nil
            })
        }
    }
    
    private func deleteEntries(offsets: IndexSet) {
        for index in offsets {
            let entry = weightEntries[index]
            modelContext.delete(entry)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Error deleting weight entries: \(error)")
        }
    }
}

struct WeightEntryRow: View {
    let entry: WeightEntry
    
    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            // Date and weight info
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(entry.date, style: .date)
                    .font(AppTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Weight display with enhanced styling
            VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                Text("\(entry.weight, specifier: "%.1f")")
                    .font(AppTypography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primary)
                 
                Text("kg")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

struct MinimalAddWeightEntryView: View {
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @State private var weightText = ""
    @State private var date = Date()
    let onEntryAdded: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("0.0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("kg")
                            .foregroundColor(.secondary)
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
            }
            .navigationTitle("Add Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEntry()
                    }.disabled(!isValidWeight)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private var isValidWeight: Bool {
        Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? 0 > 0
    }
    private func saveEntry() {
        let parsedWeight = Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let entry = WeightEntry(date: date, weight: parsedWeight)
        modelContext.insert(entry)
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save entry to SwiftData: \(error)")
        }

        // Save to Apple Health in background
        HealthKitManager.shared.saveWeightEntry(weight: parsedWeight, date: date) { success, error in
            if let error = error {
                print("❌ Failed to write weight to HealthKit: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                // Trigger a lightweight refresh of in-memory HealthKit array so the chart reflects the new value
                if let parent = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    // Broadcast notification; WeightTrackerView listens to refresh
                    NotificationCenter.default.post(name: .healthKitWeightDidChange, object: nil)
                }
                dismiss()
                onEntryAdded()
            }
        }
    }
}

struct EditWeightEntryView: View {
    @ObservedObject var entry: WeightEntry
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @State private var weightText: String
    @State private var date: Date
    let onDelete: () -> Void
    let onSave: () -> Void

    init(entry: WeightEntry, modelContext: ModelContext, onDelete: @escaping () -> Void, onSave: @escaping () -> Void) {
        self.entry = entry
        self.modelContext = modelContext
        self.onDelete = onDelete
        self.onSave = onSave
        _weightText = State(initialValue: String(entry.weight).replacingOccurrences(of: ".", with: ","))
        _date = State(initialValue: entry.date)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("0.0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("kg")
                            .foregroundColor(.secondary)
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Delete Entry", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Edit Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let parsedWeight = Double(weightText.replacingOccurrences(of: ",", with: ".")), parsedWeight > 0 {
                            entry.weight = parsedWeight
                            entry.date = date
                            do { try modelContext.save() } catch {}
                        }
                        dismiss()
                        onSave()
                    }.disabled(!isValidWeight)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss(); onSave() }
                }
            }
        }
    }

    private var isValidWeight: Bool {
        Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? 0 > 0
    }
}

// MARK: - CSV Import Delegate

class WeightCSVImportDelegate: NSObject, UIDocumentPickerDelegate {
    let modelContext: ModelContext
    let onImport: () -> Void
    
    init(modelContext: ModelContext, onImport: @escaping () -> Void) {
        self.modelContext = modelContext
        self.onImport = onImport
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        // Start accessing security-scoped resource
        let shouldStop = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStop { url.stopAccessingSecurityScopedResource() }
        }
        
        do {
            let data = try Data(contentsOf: url)
            if let text = String(data: data, encoding: .utf8) {
                importCSV(text)
            }
        } catch {
            print("❌ Failed to read CSV file: \(error)")
        }
    }
    
    private func importCSV(_ text: String) {
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 0 else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let numberFormatterComma = NumberFormatter()
        numberFormatterComma.decimalSeparator = ","
        let numberFormatterDot = NumberFormatter()
        numberFormatterDot.decimalSeparator = "."

        // Skip header if present
        let dataLines = lines.first?.lowercased().contains("date") == true ? lines.dropFirst() : lines[...]
        
        var importedCount = 0
        for line in dataLines {
            let fields = line.components(separatedBy: ",")
            guard fields.count >= 2 else { continue }
            
            let dateString = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
            var weightString = fields[1...].joined(separator: ",")
            weightString = weightString.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Remove quotes if present
            if weightString.hasPrefix("\"") && weightString.hasSuffix("\"") {
                weightString = String(weightString.dropFirst().dropLast())
            }
            
            guard let date = dateFormatter.date(from: dateString) else { continue }
            
            let weight: Double?
            if let w = numberFormatterComma.number(from: weightString)?.doubleValue {
                weight = w
            } else if let w = numberFormatterDot.number(from: weightString)?.doubleValue {
                weight = w
            } else if let w = Double(weightString) {
                weight = w
            } else {
                continue
            }
            
            guard let validWeight = weight, validWeight > 0 else { continue }
            
            let entry = WeightEntry(date: date, weight: validWeight)
            modelContext.insert(entry)
            importedCount += 1
        }
        
        do {
            try modelContext.save()
            print("✅ Successfully imported \(importedCount) weight entries")
        } catch {
            print("❌ Failed to save imported weight entries: \(error)")
        }
        
        onImport()
    }
}

#Preview {
    WeightTrackerView()
        .modelContainer(for: [
            UserProfile.self,
            WorkoutSession.self,
            CompletedExercise.self,
            WorkoutSet.self,
            ExerciseDefinition.self,
            Program.self,
            ProgramDay.self,
            ProgramExercise.self,
            WeightEntry.self
        ])
} 

// MARK: - Notification helper
extension Notification.Name {
    static let healthKitWeightDidChange = Notification.Name("healthKitWeightDidChange")
} 
