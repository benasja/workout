//
//  WorkoutHistoryView.swift
//  work
//
//  Created by Kiro on 7/24/25.
//

import SwiftUI
import SwiftData

struct WorkoutHistoryView: View {
    @EnvironmentObject private var dataManager: DataManager
    @State private var selectedTimeframe: TimeFrame = .all
    @State private var sessionToDelete: WorkoutSession? = nil
    @State private var showingDeleteAlert = false
    @State private var editingSession: WorkoutSession? = nil
    @State private var showingEditSheet = false
    
    private enum TimeFrame: String, CaseIterable {
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
    }
    
    private var filteredSessions: [WorkoutSession] {
        let now = Date()
        let calendar = Calendar.current
        
        switch selectedTimeframe {
        case .week:
            let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            return dataManager.workoutSessions.filter { $0.date >= weekAgo }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return dataManager.workoutSessions.filter { $0.date >= monthAgo }
        case .all:
            return dataManager.workoutSessions
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Time frame picker
                Picker("Time Frame", selection: $selectedTimeframe) {
                    ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                        Text(timeframe.rawValue).tag(timeframe)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Workout list
                if filteredSessions.isEmpty {
                    EmptyHistoryView()
                } else {
                    List {
                        ForEach(filteredSessions, id: \.id) { session in
                            HStack {
                                NavigationLink(destination: WorkoutDetailView(session: session)) {
                                    WorkoutHistoryRowView(session: session)
                                }
                                Spacer()
                                Button {
                                    editingSession = session
                                    showingEditSheet = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.blue)
                                        .padding(.trailing, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .onDelete { indexSet in
                            if let index = indexSet.first {
                                sessionToDelete = filteredSessions[index]
                                showingDeleteAlert = true
                            }
                        }
                    }
                    .alert("Delete Workout?", isPresented: $showingDeleteAlert, presenting: sessionToDelete) { session in
                        Button("Cancel", role: .cancel) {}
                        Button("Delete", role: .destructive) {
                            if let session = sessionToDelete {
                                deleteSession(session)
                            }
                        }
                    } message: { session in
                        Text("Are you sure you want to delete this workout? This action cannot be undone.")
                    }
                    .sheet(item: $editingSession) { session in
                        EditWorkoutView(session: session)
                    }
                }
            }
            .navigationTitle("Workout History")
            .onAppear {
                dataManager.fetchWorkoutSessions()
            }
        }
    }
    
    private func deleteSession(_ session: WorkoutSession) {
        if let index = dataManager.workoutSessions.firstIndex(where: { $0.id == session.id }) {
            let context = dataManager.modelContext
            context.delete(session)
            do {
                try context.save()
                dataManager.fetchWorkoutSessions()
            } catch {
                // Optionally handle error (show alert, etc.)
            }
        }
    }
}

// New EditWorkoutView for editing sets, reps, weight, etc.
struct EditWorkoutView: View {
    var session: WorkoutSession
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSetSheet = false
    @State private var setToEdit: WorkoutSet? = nil
    @State private var showingEditSetSheet = false
    @State private var setToDelete: WorkoutSet? = nil
    @State private var showingDeleteSetAlert = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(session.completedExercises, id: \.id) { completedExercise in
                    Section(header: Text(completedExercise.exercise?.name ?? "Exercise").font(.headline)) {
                        ForEach(completedExercise.sets, id: \.self) { set in
                            HStack {
                                Text("\(set.weight, specifier: "%.1f") kg × \(set.reps) reps")
                                Spacer()
                                Button {
                                    setToEdit = set
                                    showingEditSetSheet = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                Button(role: .destructive) {
                                    setToDelete = set
                                    showingDeleteSetAlert = true
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Button("Add Set") {
                            setToEdit = nil
                            showingAddSetSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddSetSheet) {
                EditSetSheet(completedExercise: session.completedExercises.first(where: { $0.exercise?.id == setToEdit?.exercise?.id }), set: nil) { dismiss() }
            }
            .sheet(item: $setToEdit) { set in
                EditSetSheet(completedExercise: set.completedExercise, set: set) { dismiss() }
            }
            .alert("Delete Set?", isPresented: $showingDeleteSetAlert, presenting: setToDelete) { set in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteSet(set)
                }
            } message: { set in
                Text("Are you sure you want to delete this set?")
            }
        }
    }
    
    private func deleteSet(_ set: WorkoutSet) {
        let context = dataManager.modelContext
        context.delete(set)
        do {
            try context.save()
        } catch {
            // Optionally handle error
        }
    }
}

// EditSetSheet for adding/editing a set
struct EditSetSheet: View {
    var completedExercise: CompletedExercise?
    var set: WorkoutSet?
    var onSave: () -> Void
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var weight: String = ""
    @State private var reps: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Set Details") {
                    TextField("Weight (kg)", text: $weight)
                        .keyboardType(.decimalPad)
                    TextField("Reps", text: $reps)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(set == nil ? "Add Set" : "Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSet()
                        onSave()
                        dismiss()
                    }
                    .disabled(weight.isEmpty || reps.isEmpty)
                }
            }
            .onAppear {
                if let set = set {
                    weight = String(format: "%.1f", set.weight)
                    reps = "\(set.reps)"
                }
            }
        }
    }
    
    private func saveSet() {
        guard let completedExercise = completedExercise,
              let weightValue = Double(weight),
              let repsValue = Int(reps) else { return }
        let context = dataManager.modelContext
        if let set = set {
            set.weight = weightValue
            set.reps = repsValue
        } else {
            let newSet = WorkoutSet(weight: weightValue, reps: repsValue, date: Date())
            newSet.completedExercise = completedExercise
            context.insert(newSet)
        }
        do {
            try context.save()
        } catch {
            // Optionally handle error
        }
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Workouts Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your completed workouts will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct WorkoutHistoryRowView: View {
    let session: WorkoutSession
    @EnvironmentObject private var dataManager: DataManager
    
    private var totalVolume: Double {
        let sets = session.sets
        return sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
    
    private var setCount: Int {
        return session.sets.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.programName ?? "Quick Workout")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(session.date, format: .dateTime.weekday(.wide).month().day().year())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatDuration(session.duration))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(setCount) sets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Label("\(session.completedExercises.count) exercises", systemImage: "dumbbell")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label("\(totalVolume.formatted(.number.precision(.fractionLength(0)))) kg total", systemImage: "scalemass")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Exercise preview
            if !session.completedExercises.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(session.completedExercises.prefix(3), id: \.id) { completedExercise in
                            if let exercise = completedExercise.exercise {
                                Text(exercise.name)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.2))
                                    .foregroundColor(.accentColor)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        if session.completedExercises.count > 3 {
                            Text("+\(session.completedExercises.count - 3)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .foregroundColor(.secondary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct WorkoutDetailView: View {
    let session: WorkoutSession
    @EnvironmentObject private var dataManager: DataManager
    
    private var totalVolume: Double {
        let sets = session.sets
        return sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
    
    private var exerciseGroups: [(ExerciseDefinition, [WorkoutSet])] {
        let groupedSets = Dictionary(grouping: session.sets) { set in
            set.exercise?.id ?? UUID()
        }
        
        return session.completedExercises.compactMap { completedExercise in
            guard let exercise = completedExercise.exercise else { return nil }
            let sets = groupedSets[exercise.id] ?? []
            return (exercise, sets.sorted { $0.date < $1.date })
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Workout summary card
                WorkoutSummaryCard(session: session, totalVolume: totalVolume)
                
                // Exercise breakdown
                VStack(alignment: .leading, spacing: 16) {
                    Text("Exercises")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    ForEach(exerciseGroups, id: \.0.id) { exercise, sets in
                        ExerciseBreakdownCard(exercise: exercise, sets: sets)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WorkoutSummaryCard: View {
    let session: WorkoutSession
    let totalVolume: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.programName ?? "Quick Workout")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(session.date, format: .dateTime.weekday(.wide).month().day().year())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatView(title: "Duration", value: formatDuration(session.duration), icon: "clock")
                StatView(title: "Total Volume", value: "\(totalVolume.formatted(.number.precision(.fractionLength(0)))) kg", icon: "scalemass")
                StatView(title: "Sets", value: "\(session.sets.count)", icon: "list.number")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ExerciseBreakdownCard: View {
    let exercise: ExerciseDefinition
    let sets: [WorkoutSet]
    
    private var bestSet: WorkoutSet? {
        sets.max { $0.e1RM < $1.e1RM }
    }
    
    private var totalVolume: Double {
        sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(exercise.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    if let bestSet = bestSet {
                        Text("Best: \(bestSet.weight.formatted(.number.precision(.fractionLength(1)))) kg × \(bestSet.reps)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Volume: \(totalVolume.formatted(.number.precision(.fractionLength(0)))) kg")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Sets table
            LazyVGrid(columns: [
                GridItem(.fixed(40)),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                Text("Set")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text("Weight")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text("Reps")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text("e1RM")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                    Text("\(index + 1)")
                        .font(.subheadline)
                    
                    Text("\(set.weight.formatted(.number.precision(.fractionLength(1))))")
                        .font(.subheadline)
                    
                    Text("\(set.reps)")
                        .font(.subheadline)
                    
                    Text("\(set.e1RM.formatted(.number.precision(.fractionLength(1))))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(set == bestSet ? .accentColor : .primary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    let container = try! ModelContainer(for: WorkoutSession.self, ExerciseDefinition.self, WorkoutSet.self)
    let dataManager = DataManager(modelContext: container.mainContext)
    
    return WorkoutHistoryView()
        .environmentObject(dataManager)
        .modelContainer(container)
}