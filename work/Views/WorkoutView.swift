//
//  WorkoutView.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import SwiftUI
import SwiftData

struct WorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let workout: WorkoutSession
    @State private var startTime = Date()
    @State private var showingExerciseLibrary = false
    @State private var showingFinishWorkout = false
    @State private var showingCancelAlert = false
    @State private var restTimer: Timer?
    @State private var restTimeRemaining: TimeInterval = 0
    @State private var isRestTimerActive = false
    @State private var showingRestTimer = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Timer header
                WorkoutTimerView(startTime: startTime)
                
                // Exercise list
                if workout.completedExercises.isEmpty {
                    EmptyWorkoutView {
                        showingExerciseLibrary = true
                    }
                } else {
                    WorkoutExerciseListView(workout: workout)
                }
                
                Spacer()
                
                // Bottom buttons
                VStack(spacing: 12) {
                    Button(action: { showingExerciseLibrary = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Exercise")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(AppCornerRadius.md)
                    }
                    .primaryButton()
                    .accessibilityLabel("Show Exercise Library")
                    
                    Button(action: { showingFinishWorkout = true }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Finish Workout")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(AppCornerRadius.md)
                    }
                    .primaryButton()
                    .accessibilityLabel("Finish Workout")
                }
                .padding()
            }
            .navigationTitle(workout.programName ?? "Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingCancelAlert = true
                    }
                    .secondaryButton()
                    .accessibilityLabel("Cancel")
                }
            }
            .sheet(isPresented: $showingExerciseLibrary) {
                ExerciseLibraryView(selectionMode: true) { exercise in
                    addExerciseToWorkout(exercise)
                }
            }
            .alert("Finish Workout", isPresented: $showingFinishWorkout) {
                Button("Cancel", role: .cancel) { }
                Button("Finish") {
                    finishWorkout()
                }
            } message: {
                Text("Are you sure you want to finish this workout?")
            }
            .alert("Cancel Workout", isPresented: $showingCancelAlert) {
                Button("Continue Workout", role: .cancel) { }
                Button("Cancel Workout", role: .destructive) {
                    cancelWorkout()
                }
            } message: {
                Text("Are you sure you want to cancel this workout? This action cannot be undone.")
            }
        }
        .interactiveDismissDisabled()
        .onAppear {
            startTime = Date()
        }
    }
    
    private func addExerciseToWorkout(_ exercise: ExerciseDefinition) {
        // Check if exercise is already added to prevent duplicates
        let isAlreadyAdded = workout.completedExercises.contains { completedExercise in
            completedExercise.exercise?.id == exercise.id
        }
        
        if !isAlreadyAdded {
            let completedExercise = CompletedExercise(exercise: exercise)
            workout.completedExercises.append(completedExercise)
            modelContext.insert(completedExercise)
            try? modelContext.save()
        }
    }
    
    private func finishWorkout() {
        
        workout.duration = Date().timeIntervalSince(startTime)
        workout.isCompleted = true
        
        // Count total sets by querying WorkoutSet data
        let descriptor = FetchDescriptor<WorkoutSet>()
        let allSets = (try? modelContext.fetch(descriptor)) ?? []
        
        var totalSets = 0
        for exercise in workout.completedExercises {
            let exerciseSets = allSets.filter { $0.completedExercise?.id == exercise.id }
            totalSets += exerciseSets.count
        }
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Error saving workout: \(error)")
        }
        
        dismiss()
    }
    
    private func cancelWorkout() {
        // Delete the workout and all its data
        for exercise in workout.completedExercises {
            modelContext.delete(exercise)
        }
        modelContext.delete(workout)
        try? modelContext.save()
        dismiss()
    }
}

struct WorkoutTimerView: View {
    let startTime: Date
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Workout Time")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(timeString(from: elapsedTime))
                .font(.title)
                .fontWeight(.bold)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

struct EmptyWorkoutView: View {
    let onAddExercise: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "dumbbell")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No exercises added yet")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Tap 'Add Exercise' to start building your workout")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onAddExercise) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Your First Exercise")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(AppCornerRadius.md)
            }
            .primaryButton()
            .accessibilityLabel("Add Exercise")
            
            Spacer()
        }
        .padding()
    }
}

struct WorkoutExerciseListView: View {
    let workout: WorkoutSession
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(workout.completedExercises, id: \.exercise?.id) { completedExercise in
                    if completedExercise.exercise != nil {
                        ExerciseCardView(completedExercise: completedExercise)
                    }
                }
            }
            .padding()
        }
    }
}

struct ExerciseCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workoutSets: [WorkoutSet]
    let completedExercise: CompletedExercise
    @State private var showingAddSet = false
    
    var filteredSets: [WorkoutSet] {
        workoutSets.filter { $0.completedExercise?.id == completedExercise.id }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(completedExercise.exercise?.name ?? "Unknown Exercise")
                        .font(.headline)
                    
                    Text(completedExercise.exercise?.primaryMuscleGroup ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { showingAddSet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .primaryButton()
                .accessibilityLabel("Add Set")
            }
            
            // Sets table
            if !filteredSets.isEmpty {
                SetsTableView(sets: filteredSets)
            }
            
            // Quick add buttons
            QuickAddSetView(completedExercise: completedExercise)
            
            // Add set button
            Button(action: { showingAddSet = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Custom Set")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(AppCornerRadius.md)
            }
            .primaryButton()
            .accessibilityLabel("Add Set")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(AppCornerRadius.md)
        .sheet(isPresented: $showingAddSet) {
            AddSetView(completedExercise: completedExercise)
        }
    }
}

struct SetsTableView: View {
    let sets: [WorkoutSet]
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Text("Set")
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(width: 40, alignment: .leading)
                
                Text("Previous")
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Reps")
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(width: 60, alignment: .center)
                
                Text("Weight")
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(width: 60, alignment: .center)
            }
            .foregroundColor(.secondary)
            
            // Sets
            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                SetRowView(set: set, setNumber: index + 1)
            }
        }
    }
}

struct SetRowView: View {
    @Environment(\.modelContext) private var modelContext
    let set: WorkoutSet
    let setNumber: Int
    @State private var reps: String = ""
    @State private var weight: String = ""
    @State private var isCompleted = false
    @State private var showingSetOptions = false
    @State private var restTimer: Timer?
    @State private var restTimeRemaining: TimeInterval = 0
    @State private var isRestTimerActive = false
    @State private var showingRestTimer = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Set number with type indicator
            VStack(spacing: 2) {
                Text("\(setNumber)")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Image(systemName: set.setType.icon)
                    .font(.caption2)
                    .foregroundColor(set.setType.color)
            }
            .frame(width: 40)
            
            // Previous set info (if available)
            VStack(alignment: .leading, spacing: 2) {
                Text("Previous")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(set.reps) × \(String(format: "%.1f", set.weight))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80, alignment: .leading)
            
            // Current reps input
            VStack(spacing: 2) {
                Text("Reps")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                TextField("0", text: $reps)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
            }
            
            // Current weight input
            VStack(spacing: 2) {
                Text("Weight")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                TextField("0", text: $weight)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .frame(width: 60)
                    .multilineTextAlignment(.center)
            }
            
            // Set options button
            Button(action: { showingSetOptions = true }) {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
            .frame(width: 30)
            
            // Completion checkbox
            Button(action: { 
                isCompleted.toggle()
                set.isCompleted = isCompleted
                try? modelContext.save()
                
                // Start rest timer when set is completed
                if isCompleted {
                    startRestTimer()
                }
            }) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isCompleted ? .green : .secondary)
                    .font(.title3)
            }
            .frame(width: 30)
        }
        .padding(.vertical, 4)
        .background(set.setType == .warmup ? Color.orange.opacity(0.1) : 
                   set.setType == .dropset ? Color.purple.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .onAppear {
            reps = set.reps > 0 ? "\(set.reps)" : ""
            weight = set.weight > 0 ? String(format: "%.1f", set.weight) : ""
            isCompleted = set.isCompleted
        }
        .onChange(of: reps) { _, newValue in
            if let repsInt = Int(newValue) {
                set.reps = repsInt
                try? modelContext.save()
            }
        }
        .onChange(of: weight) { _, newValue in
            if let weightDouble = Double(newValue) {
                set.weight = weightDouble
                try? modelContext.save()
            }
        }
        .sheet(isPresented: $showingSetOptions) {
            SetOptionsView(set: set)
        }
    }
    
    private func startRestTimer() {
        // Start a 90-second rest timer
        restTimeRemaining = 90
        isRestTimerActive = true
        showingRestTimer = true
        
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if restTimeRemaining > 0 {
                restTimeRemaining -= 1
            } else {
                isRestTimerActive = false
                restTimer?.invalidate()
                
                // Simple haptic feedback when rest is complete
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
}

struct AddSetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var workoutSets: [WorkoutSet]
    
    let completedExercise: CompletedExercise
    @State private var reps = 0
    @State private var weight = 0.0
    @State private var setType: SetType = .working
    @State private var rpe: Int = 7
    @State private var notes = ""
    @State private var useRPE = false
    
    // Get previous sets for this exercise to suggest weight/reps
    var previousSets: [WorkoutSet] {
        workoutSets.filter { $0.completedExercise?.exercise?.id == completedExercise.exercise?.id }
            .sorted { $0.date > $1.date }
    }
    
    var suggestedWeight: Double {
        guard let lastSet = previousSets.first else { return 0.0 }
        return lastSet.weight
    }
    
    var suggestedReps: Int {
        guard let lastSet = previousSets.first else { return 8 }
        return lastSet.reps
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Set Details") {
                    // Set Type Picker
                    Picker("Set Type", selection: $setType) {
                        ForEach(SetType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(type.color)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    // Reps
                    HStack {
                        Text("Reps")
                        Spacer()
                        Stepper("\(reps)", value: $reps, in: 0...50)
                            .frame(width: 100)
                    }
                    
                    // Weight
                    HStack {
                        Text("Weight (kg)")
                        Spacer()
                        TextField("0.0", value: $weight, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                            .multilineTextAlignment(.center)
                    }
                    
                    // RPE (optional)
                    Toggle("Use RPE", isOn: $useRPE)
                    
                    if useRPE {
                        HStack {
                            Text("RPE")
                            Spacer()
                            Stepper("\(rpe)", value: $rpe, in: 1...10)
                                .frame(width: 100)
                        }
                    }
                }
                
                // Previous set suggestion
                if !previousSets.isEmpty {
                    Section("Previous Performance") {
                        HStack {
                            Text("Last set:")
                            Spacer()
                            Text("\(previousSets[0].reps) × \(String(format: "%.1f", previousSets[0].weight)) kg")
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Use Previous Values") {
                            reps = suggestedReps
                            weight = suggestedWeight
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addSet()
                    }
                    .disabled(reps == 0 && weight == 0)
                }
            }
            .onAppear {
                // Auto-suggest values from previous sets
                if reps == 0 && weight == 0.0 {
                    reps = suggestedReps
                    weight = suggestedWeight
                }
            }
        }
    }
    
    private func addSet() {
        let newSet = WorkoutSet(
            weight: weight,
            reps: reps,
            rpe: useRPE ? rpe : nil,
            notes: notes.isEmpty ? nil : notes,
            setType: setType,
            completedExercise: completedExercise
        )
        
        modelContext.insert(newSet)
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Error saving workout set: \(error)")
        }
        
        dismiss()
    }
}

struct QuickAddSetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workoutSets: [WorkoutSet]
    
    let completedExercise: CompletedExercise
    
    // Get previous sets for this exercise to suggest weight/reps
    var previousSets: [WorkoutSet] {
        workoutSets.filter { $0.completedExercise?.exercise?.id == completedExercise.exercise?.id }
            .sorted { $0.date > $1.date }
    }
    
    var suggestedWeight: Double {
        guard let lastSet = previousSets.first else { return 20.0 }
        return lastSet.weight
    }
    
    var suggestedReps: Int {
        guard let lastSet = previousSets.first else { return 8 }
        return lastSet.reps
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Quick Add")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                // Warmup Set
                QuickSetButton(
                    title: "Warmup",
                    icon: "flame",
                    color: .orange,
                    weight: suggestedWeight * 0.6, // 60% of working weight
                    reps: suggestedReps + 2 // More reps for warmup
                ) {
                    addQuickSet(type: .warmup, weight: suggestedWeight * 0.6, reps: suggestedReps + 2)
                }
                
                // Working Set
                QuickSetButton(
                    title: "Working",
                    icon: "dumbbell",
                    color: .blue,
                    weight: suggestedWeight,
                    reps: suggestedReps
                ) {
                    addQuickSet(type: .working, weight: suggestedWeight, reps: suggestedReps)
                }
                
                // Drop Set
                QuickSetButton(
                    title: "Drop",
                    icon: "arrow.down.circle",
                    color: .purple,
                    weight: suggestedWeight * 0.8, // 80% of working weight
                    reps: suggestedReps + 3 // More reps for drop set
                ) {
                    addQuickSet(type: .dropset, weight: suggestedWeight * 0.8, reps: suggestedReps + 3)
                }
            }
        }
    }
    
    private func addQuickSet(type: SetType, weight: Double, reps: Int) {
        let newSet = WorkoutSet(
            weight: weight,
            reps: reps,
            setType: type,
            completedExercise: completedExercise
        )
        
        modelContext.insert(newSet)
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Error saving quick set: \(error)")
        }
    }
}

struct QuickSetButton: View {
    let title: String
    let icon: String
    let color: Color
    let weight: Double
    let reps: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                
                Text("\(String(format: "%.0f", weight))kg")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("\(reps) reps")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SetOptionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let set: WorkoutSet
    @State private var setType: SetType
    @State private var rpe: Int
    @State private var notes: String
    @State private var useRPE: Bool
    @State private var showingDeleteAlert = false
    
    init(set: WorkoutSet) {
        self.set = set
        self._setType = State(initialValue: set.setType)
        self._rpe = State(initialValue: set.rpe ?? 7)
        self._notes = State(initialValue: set.notes ?? "")
        self._useRPE = State(initialValue: set.rpe != nil)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Set Type") {
                    Picker("Type", selection: $setType) {
                        ForEach(SetType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(type.color)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                
                Section("Performance") {
                    HStack {
                        Text("Weight")
                        Spacer()
                        Text("\(String(format: "%.1f", set.weight)) kg")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Reps")
                        Spacer()
                        Text("\(set.reps)")
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Use RPE", isOn: $useRPE)
                    
                    if useRPE {
                        HStack {
                            Text("RPE")
                            Spacer()
                            Stepper("\(rpe)", value: $rpe, in: 1...10)
                                .frame(width: 100)
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button("Delete Set", role: .destructive) {
                        showingDeleteAlert = true
                    }
                }
            }
            .navigationTitle("Set Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
            .alert("Delete Set", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteSet()
                }
            } message: {
                Text("Are you sure you want to delete this set?")
            }
        }
    }
    
    private func saveChanges() {
        set.setType = setType
        set.rpe = useRPE ? rpe : nil
        set.notes = notes.isEmpty ? nil : notes
        
        try? modelContext.save()
        dismiss()
    }
    
    private func deleteSet() {
        modelContext.delete(set)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    WorkoutView(workout: WorkoutSession())
        .modelContainer(for: [
            UserProfile.self,
            WorkoutSession.self,
            CompletedExercise.self,
            WorkoutSet.self,
            ExerciseDefinition.self,
            Program.self,
            ProgramDay.self,
            ProgramExercise.self
        ])
} 
