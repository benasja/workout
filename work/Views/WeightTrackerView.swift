//
//  WeightTrackerView.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import SwiftUI
import SwiftData

struct WeightTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    
    @State private var showingAddEntry = false
    @State private var manualWeightEntries: [WeightEntry] = []
    @State private var isLoading = false
    @State private var dateRange: ClosedRange<Date>? = nil
    @State var editingEntry: WeightEntry? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: AppSpacing.xl) {
                    if (weightEntries.isEmpty && manualWeightEntries.isEmpty) {
                        EmptyWeightView {
                            showingAddEntry = true
                        }
                    } else {
                        let sortedEntries = weightEntries.sorted { $0.date < $1.date }
                        let minDate = sortedEntries.first?.date ?? Date()
                        let maxDate = sortedEntries.last?.date ?? Date()
                        let range = dateRange ?? minDate...maxDate
                        let filteredEntries = sortedEntries.filter { range.contains($0.date) }
                        WeightChartView(weightEntries: filteredEntries, minDate: minDate, maxDate: maxDate)
                        if minDate < maxDate {
                            DateRangePickers(minDate: minDate, maxDate: maxDate, dateRange: $dateRange)
                        }
                        let uniqueEntries = Dictionary(grouping: weightEntries) { entry in
                            let comps = Calendar.current.dateComponents([.year, .month, .day], from: entry.date)
                            return Calendar.current.date(from: comps) ?? entry.date
                        }
                        .mapValues { $0.max(by: { $0.date < $1.date })! }
                        .values
                        .sorted { $0.date > $1.date }

                        VStack(spacing: 12) {
                            ForEach(uniqueEntries, id: \.id) { entry in
                                Button(action: { editingEntry = entry }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.date, formatter: dateFormatter)
                                            .font(.headline)
                                        Text("\(entry.weight, specifier: "%.1f") kg")
                                            .font(.title2)
                                            .fontWeight(.bold)
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
            .background(AppColors.background)
            .navigationTitle("Weight Tracker")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
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
            }
        }
    }
    
    private func refreshData() {
        isLoading = true
        do {
            try modelContext.save()
        } catch {}
        loadWeightEntries()
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
                if weightEntries.count < 2 {
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
                                Path { path in
                                    let sortedEntries = weightEntries.sorted { $0.date < $1.date }
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
                                ForEach(weightEntries.sorted { $0.date < $1.date }, id: \.id) { entry in
                                    let sortedEntries = weightEntries.sorted { $0.date < $1.date }
                                    let minWeight = sortedEntries.map { $0.weight }.min() ?? 0
                                    let maxWeight = sortedEntries.map { $0.weight }.max() ?? 100
                                    let weightRange = maxWeight - minWeight
                                    let width = geometry.size.width - 40
                                    let height = geometry.size.height - 40
                                    let minDate = sortedEntries.first?.date ?? Date()
                                    let maxDate = sortedEntries.last?.date ?? Date()
                                    let totalTime = maxDate.timeIntervalSince(minDate)
                                    if sortedEntries.firstIndex(where: { $0.id == entry.id }) != nil {
                                        let timeSinceStart = entry.date.timeIntervalSince(minDate)
                                        let x = 20 + (CGFloat(totalTime == 0 ? 0 : timeSinceStart / totalTime)) * width
                                        let normalizedWeight = weightRange > 0 ? (entry.weight - minWeight) / weightRange : 0.5
                                        let y = 20 + (1 - normalizedWeight) * height
                                        Circle()
                                            .fill(AppColors.primary)
                                            .frame(width: 7, height: 7)
                                            .shadow(color: AppColors.primary.opacity(0.3), radius: 2, x: 0, y: 1)
                                            .position(x: x, y: y)
                                    }
                                }
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
        do { try modelContext.save() } catch {}
        dismiss()
        onEntryAdded()
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
