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
            print("WorkoutView appeared with \(workout.completedExercises.count) exercises")
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
            print("Added exercise: \(exercise.name)")
        }
    }
    
    private func finishWorkout() {
        print("=== FINISHING WORKOUT ===")
        
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
        
        print("✅ Workout completed:")
        print("   Duration: \(Int(workout.duration / 60)) minutes")
        print("   Exercises: \(workout.completedExercises.count)")
        print("   Total sets: \(totalSets)")
        
        do {
            try modelContext.save()
            print("✅ Workout saved successfully")
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
            
            // Add set button
            Button(action: { showingAddSet = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Set")
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
    let set: WorkoutSet
    let setNumber: Int
    @State private var reps: String = ""
    @State private var weight: String = ""
    @State private var isCompleted = false
    
    var body: some View {
        HStack {
            Text("\(setNumber)")
                .font(.caption)
                .frame(width: 40, alignment: .leading)
            
            Text("\(set.reps) × \(String(format: "%.1f", set.weight))")
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.secondary)
            
            TextField("0", text: $reps)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Reps")
                .accessibilityIdentifier("repsField")
                .frame(width: 60)
            
            TextField("0", text: $weight)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Weight")
                .accessibilityIdentifier("weightField")
                .frame(width: 60)
            
            Button(action: { isCompleted.toggle() }) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isCompleted ? .green : .secondary)
            }
            .iconButton(color: AppColors.primary)
            .accessibilityLabel("Toggle Completed")
        }
        .onAppear {
            reps = "\(set.reps)"
            weight = String(format: "%.1f", set.weight)
        }
        .onChange(of: reps) { _, newValue in
            if let repsInt = Int(newValue) {
                set.reps = repsInt
            }
        }
        .onChange(of: weight) { _, newValue in
            if let weightDouble = Double(newValue) {
                set.weight = weightDouble
            }
        }
    }
}

struct AddSetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let completedExercise: CompletedExercise
    @State private var reps = 0
    @State private var weight = 0.0
    @State private var isWarmup = false
    @State private var isFailure = false
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Set Details") {
                    Stepper("Reps: \(reps)", value: $reps, in: 0...50)
                    
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("0.0", value: $weight, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Set Weight")
                            .accessibilityIdentifier("setWeightField")
                    }
                    
                    Toggle("Warmup Set", isOn: $isWarmup)
                        .accessibilityLabel("Warmup Set")
                        .accessibilityIdentifier("warmupSetToggle")
                    Toggle("Failure Set", isOn: $isFailure)
                        .accessibilityLabel("Failure Set")
                        .accessibilityIdentifier("failureSetToggle")
                }
                
                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Set Notes")
                        .accessibilityIdentifier("setNotesField")
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
                    .secondaryButton()
                    .accessibilityLabel("Cancel")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addSet()
                    }
                    .primaryButton()
                    .accessibilityLabel("Add")
                }
            }
        }
    }
    
    private func addSet() {
        print("=== ADDING WORKOUT SET ===")
        print("Exercise: \(completedExercise.exercise?.name ?? "Unknown")")
        print("Weight: \(weight) kg, Reps: \(reps)")
        
        let newSet = WorkoutSet(
            weight: weight,
            reps: reps,
            rpe: nil,
            notes: notes.isEmpty ? nil : notes,
            completedExercise: completedExercise
        )
        
        modelContext.insert(newSet)
        
        do {
            try modelContext.save()
            print("✅ Workout set saved successfully")
            
            // Verify the save worked
            let descriptor = FetchDescriptor<WorkoutSet>()
            let count = try modelContext.fetchCount(descriptor)
            print("✅ Database now contains \(count) workout sets")
            
        } catch {
            print("❌ Error saving workout set: \(error)")
        }
        
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