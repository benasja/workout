//
//  WeightTrackerView.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import SwiftUI
import Charts
import SwiftData
import UniformTypeIdentifiers

// MARK: - Time Range Enum
enum TimeRange: String, CaseIterable {
    case ninetyDays = "90D"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case all = "All"
    
    var displayName: String {
        return self.rawValue
    }
    
    func filterDate(from referenceDate: Date = Date()) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .ninetyDays:
            return calendar.date(byAdding: .day, value: -90, to: referenceDate)
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: referenceDate)
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: referenceDate)
        case .all:
            return nil // No filter
        }
    }
}

struct WeightTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    
    @State private var showingAddEntry = false
    @State private var manualWeightEntries: [WeightEntry] = []
    @State private var healthKitWeightData: [WeightData] = []
    @State private var isLoading = false
    @State private var isSyncing = false
    @State private var selectedRange: TimeRange = .oneYear
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
    
    // Filtered entries based on selected time range
    private var filteredEntries: [WeightEntry] {
        let allEntries = allWeightEntries.sorted { $0.date < $1.date }
        
        guard let filterDate = selectedRange.filterDate() else {
            return allEntries // Return all for "All" option
        }
        
        return allEntries.filter { $0.date >= filterDate }
    }
    
    // Dynamic date range string for subtitle
    private var currentDateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        let sortedEntries = filteredEntries.sorted { $0.date < $1.date }
        guard let earliest = sortedEntries.first?.date,
              let latest = sortedEntries.last?.date else {
            return "No data available"
        }
        
        if Calendar.current.isDate(earliest, inSameDayAs: latest) {
            return formatter.string(from: earliest)
        } else {
            return "\(formatter.string(from: earliest)) - \(formatter.string(from: latest))"
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
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
                    
                    if allWeightEntries.isEmpty {
                        EmptyWeightView {
                            showingAddEntry = true
                        }
                    } else {
                        // Modern Weight Progress Card
                        WeightProgressCard(
                            filteredEntries: filteredEntries,
                            selectedRange: $selectedRange,
                            currentDateRangeString: currentDateRangeString
                        )
                        
                        // Modernized Weight Entry List
                        ModernWeightEntriesList(
                            filteredEntries: filteredEntries,
                            editingEntry: $editingEntry,
                            selectedRange: selectedRange
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .refreshable {
                syncWithHealthKit()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Weight Tracker")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddEntry = true }) {
                        Image(systemName: "plus")
                    }
                    .iconButton(color: .blue)
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                MinimalAddWeightEntryView(modelContext: modelContext) {
                    refreshData()
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
            .onAppear {
                refreshData()
                if !hasFetchedHealthKit {
                    hasFetchedHealthKit = true
                    syncWithHealthKit()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .healthKitWeightDidChange)) { _ in
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
    
    private func syncWithHealthKit() {
        guard !isSyncing else { return }
        
        isSyncing = true
        print("🔄 Starting HealthKit weight sync...")
        
        HealthKitManager.shared.requestAuthorization { [self] success in
            guard success else {
                print("❌ HealthKit authorization failed")
                DispatchQueue.main.async {
                    self.isSyncing = false
                }
                return
            }
            
            HealthKitManager.shared.fetchAllWeightEntries { [self] weightData in
                DispatchQueue.main.async {
                    self.healthKitWeightData = weightData
                    self.lastSyncDate = Date()
                    self.isSyncing = false
                    print("✅ HealthKit sync completed: \(weightData.count) entries")
                }
            }
        }
    }

    private func refreshHealthKitEntries() {
        HealthKitManager.shared.fetchAllWeightEntries { data in
            DispatchQueue.main.async {
                self.healthKitWeightData = data
                self.lastSyncDate = Date()
            }
        }
    }
}

// MARK: - Weight Progress Card
struct WeightProgressCard: View {
    let filteredEntries: [WeightEntry]
    @Binding var selectedRange: TimeRange
    let currentDateRangeString: String
    @State private var selectedEntry: WeightEntry? = nil
    
    private var stats: (lowest: Double, highest: Double, started: Double, current: Double) {
        let sorted = filteredEntries.sorted { $0.date < $1.date }
        let lowest = sorted.min(by: { $0.weight < $1.weight })?.weight ?? 0
        let highest = sorted.max(by: { $0.weight < $1.weight })?.weight ?? 0
        let started = sorted.first?.weight ?? 0
        let current = sorted.last?.weight ?? 0
        return (lowest: lowest, highest: highest, started: started, current: current)
    }
    
    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 20) {
                // Header with dynamic subtitle
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weight Progress")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(currentDateRangeString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .animation(.easeInOut(duration: 0.3), value: currentDateRangeString)
                }
                
                // Time Range Segmented Control
                Picker("Time Range", selection: $selectedRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .animation(.easeInOut(duration: 0.3), value: selectedRange)
                
                // Stats Row
                if !filteredEntries.isEmpty {
                    HStack(spacing: 16) {
                        StatItem(title: "Lowest", value: "\(String(format: "%.1f", stats.lowest)) kg")
                        StatItem(title: "Highest", value: "\(String(format: "%.1f", stats.highest)) kg")
                        StatItem(title: "Started", value: "\(String(format: "%.1f", stats.started)) kg")
                        StatItem(title: "Current", value: "\(String(format: "%.1f", stats.current)) kg")
                    }
                }
                
                // Interactive Chart
                if filteredEntries.count < 2 {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.6))
                        Text("Add more entries to see your progress chart")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(height: 200)
                } else {
                    ModernWeightChart(entries: filteredEntries, selectedEntry: $selectedEntry)
                        .animation(.easeInOut(duration: 0.8), value: filteredEntries.count)
                }
            }
        }
    }
}

// MARK: - Stat Item Component
struct StatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Modern Weight Chart
struct ModernWeightChart: View {
    let entries: [WeightEntry]
    @Binding var selectedEntry: WeightEntry?
    
    var body: some View {
        let sortedEntries = entries.sorted { $0.date < $1.date }
        let gradient = LinearGradient(
            colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.2), Color.clear],
            startPoint: .top,
            endPoint: .bottom
        )
        
        Chart {
            // Area fill with gradient
            ForEach(sortedEntries) { entry in
                AreaMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.weight)
                )
                .foregroundStyle(gradient)
            }
            
            // Line overlay
            ForEach(sortedEntries) { entry in
                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.weight)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(.init(lineWidth: 3))
                .foregroundStyle(.blue)
            }
            
            // Interactive points
            ForEach(sortedEntries) { entry in
                PointMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.weight)
                )
                .symbolSize(selectedEntry?.id == entry.id ? 80 : 30)
                .foregroundStyle(.blue)
                .opacity(selectedEntry?.id == entry.id ? 1.0 : 0.7)
            }
            
            // Interactive rule mark
            if let selected = selectedEntry {
                RuleMark(x: .value("Date", selected.date))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 3]))
                    .foregroundStyle(.gray)
                    .annotation(position: .top, alignment: .center) {
                        VStack(alignment: .center, spacing: 4) {
                            Text("\(String(format: "%.1f", selected.weight)) kg")
                                .font(.title3.bold())
                            Text(selected.date, formatter: fullDateFormatter)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(.thinMaterial)
                        .cornerRadius(8)
                        .shadow(radius: 3)
                    }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    .foregroundStyle(.secondary.opacity(0.3))
                AxisValueLabel()
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(.clear)
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 240)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleChartInteraction(value: value, geometry: geometry, proxy: proxy)
                            }
                            .onEnded { _ in
                                selectedEntry = nil
                            }
                    )
            }
        }
    }
    
    private func handleChartInteraction(value: DragGesture.Value, geometry: GeometryProxy, proxy: ChartProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let xPosition = value.location.x - geometry[plotFrame].origin.x
        guard let date: Date = proxy.value(atX: xPosition) else { return }
        
        // Find closest entry
        var closestEntry: WeightEntry?
        var smallestDifference = TimeInterval.greatestFiniteMagnitude
        
        for entry in entries {
            let difference = abs(entry.date.timeIntervalSince(date))
            if difference < smallestDifference {
                smallestDifference = difference
                closestEntry = entry
            }
        }
        
        if let closest = closestEntry, closest.id != selectedEntry?.id {
            selectedEntry = closest
            // Haptic feedback
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        }
    }
}

// MARK: - Modern Weight Entries List
struct ModernWeightEntriesList: View {
    let filteredEntries: [WeightEntry]
    @Binding var editingEntry: WeightEntry?
    let selectedRange: TimeRange
    
    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Recent Entries")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if filteredEntries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 32))
                            .foregroundColor(.gray.opacity(0.6))
                        Text("No entries in this time period")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    // Group entries by date (remove duplicates)
                    let uniqueEntries = Dictionary(grouping: filteredEntries.sorted { $0.date > $1.date }) { entry in
                        Calendar.current.startOfDay(for: entry.date)
                    }
                    .compactMapValues { $0.first }
                    .values
                    .sorted { $0.date > $1.date }
                    
                    let entriesToShow: [WeightEntry] = {
                        if selectedRange == .all || selectedRange == .oneYear {
                            return Array(uniqueEntries)
                        } else {
                            return Array(uniqueEntries.prefix(10))
                        }
                    }()
                    LazyVStack(spacing: 12) {
                        ForEach(entriesToShow, id: \.id) { entry in
                            ModernWeightEntryRow(entry: entry)
                                .onTapGesture {
                                    editingEntry = entry
                                }
                        }
                        if !(selectedRange == .all || selectedRange == .oneYear) && uniqueEntries.count > 10 {
                            Text("+ \(uniqueEntries.count - 10) more entries")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Modern Weight Entry Row
struct ModernWeightEntryRow: View {
    let entry: WeightEntry
    
    private var isFromHealth: Bool {
        entry.notes?.contains("From") == true || entry.notes?.contains("Synced from") == true
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Date and source info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date, format: .dateTime.weekday(.wide).month().day())
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Image(systemName: isFromHealth ? "heart.fill" : "pencil")
                        .font(.caption)
                        .foregroundColor(isFromHealth ? .red : .blue)
                    
                    Text(isFromHealth ? "Health" : "Manual")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Weight display
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.1f", entry.weight))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("kg")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Views (keeping existing functionality)

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

        HealthKitManager.shared.saveWeightEntry(weight: parsedWeight, date: date) { success, error in
            if let error = error {
                print("❌ Failed to write weight to HealthKit: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                if UIApplication.shared.connectedScenes.first is UIWindowScene {
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

// MARK: - Notification Helper
extension Notification.Name {
    static let healthKitWeightDidChange = Notification.Name("healthKitWeightDidChange")
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
            WeightEntry.self
        ])
} 

private let fullDateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateStyle = .long
    return df
}() 
