//
//  WorkoutHistoryView.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import SwiftUI
import SwiftData

struct WorkoutHistoryView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var allWorkouts: [WorkoutSession]
    
    var completedWorkouts: [WorkoutSession] {
        allWorkouts.filter { $0.isCompleted }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if completedWorkouts.isEmpty {
                    EmptyHistoryView()
                } else {
                    WorkoutList(workouts: completedWorkouts)
                }
            }
            .navigationTitle("Workout History")
        }
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No workout history yet")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Complete your first workout to see it here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
}

struct WorkoutList: View {
    let workouts: [WorkoutSession]
    @State private var selectedWorkout: WorkoutSession?
    
    var body: some View {
        List(workouts, id: \.id) { workout in
            WorkoutHistoryRow(workout: workout)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedWorkout = workout
                }
        }
        .sheet(item: $selectedWorkout) { workout in
            WorkoutDetailView(workout: workout)
        }
    }
}

struct WorkoutHistoryRow: View {
    let workout: WorkoutSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.programName ?? "Workout")
                        .font(.headline)
                    
                    Text(workout.date, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(workout.completedExercises.count) exercises")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(workout.duration / 60))m")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !workout.completedExercises.isEmpty {
                Text("\(workout.completedExercises.prefix(3).compactMap { $0.exercise?.name }.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .cornerRadius(AppCornerRadius.sm)
    }
}

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let workout: WorkoutSession
    @State private var showingEditSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Workout header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(workout.programName ?? "Workout")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(workout.date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Label("\(Int(workout.duration / 60)) minutes", systemImage: "clock")
                            Spacer()
                            Label("\(workout.completedExercises.count) exercises", systemImage: "dumbbell")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    // Exercises
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Exercises")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("Edit") {
                                showingEditSheet = true
                            }
                            .primaryButton()
                            .accessibilityLabel("Edit Workout")
                        }
                        
                        ForEach(workout.completedExercises, id: \.id) { completedExercise in
                            if let exercise = completedExercise.exercise {
                                ExerciseDetailRow(exercise: exercise, completedExercise: completedExercise)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Workout Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .primaryButton()
                    .accessibilityLabel("Done Editing")
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditWorkoutView(workout: workout)
            }
        }
        .cornerRadius(AppCornerRadius.md)
    }
}

struct ExerciseDetailRow: View {
    let exercise: ExerciseDefinition
    let completedExercise: CompletedExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(exercise.primaryMuscleGroup)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }
            
            if let warmupSets = completedExercise.warmupSets, warmupSets > 0 {
                Text("\(warmupSets) warmup sets")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            let targetSets = completedExercise.targetSets ?? 3
            let targetReps = completedExercise.targetReps ?? "8-12"
            Text("Target: \(targetSets) sets × \(targetReps)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(AppCornerRadius.sm)
    }
}

struct EditWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let workout: WorkoutSession
    
    @State private var workoutDate: Date
    @State private var workoutNotes: String
    @State private var showingDeleteAlert = false
    
    init(workout: WorkoutSession) {
        self.workout = workout
        self._workoutDate = State(initialValue: workout.date)
        self._workoutNotes = State(initialValue: workout.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Workout Details") {
                    DatePicker("Date", selection: $workoutDate, displayedComponents: .date)
                        .accessibilityLabel("Workout Date")
                        .accessibilityIdentifier("workoutDatePicker")
                    
                    TextField("Notes", text: $workoutNotes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Workout Notes")
                        .accessibilityIdentifier("workoutNotesField")
                        .lineLimit(3...6)
                }
                
                Section("Exercises") {
                    ForEach(workout.completedExercises, id: \.id) { completedExercise in
                        if let exercise = completedExercise.exercise {
                            NavigationLink(destination: EditExerciseView(completedExercise: completedExercise)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text(exercise.primaryMuscleGroup)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteExercise)
                }
                
                Section {
                    Button("Delete Workout", role: .destructive) {
                        showingDeleteAlert = true
                    }
                    .secondaryButton()
                    .accessibilityLabel("Delete Workout")
                }
            }
            .navigationTitle("Edit Workout")
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
                    Button("Save") {
                        saveChanges()
                    }
                    .primaryButton()
                    .accessibilityLabel("Save Changes")
                }
            }
            .alert("Delete Workout", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteWorkout()
                }
            } message: {
                Text("Are you sure you want to delete this workout? This action cannot be undone.")
            }
        }
    }
    
    private func saveChanges() {
        workout.date = workoutDate
        workout.notes = workoutNotes.isEmpty ? nil : workoutNotes
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Error saving workout changes: \(error)")
        }
        
        dismiss()
    }
    
    private func deleteExercise(offsets: IndexSet) {
        for index in offsets {
            let exercise = workout.completedExercises[index]
            modelContext.delete(exercise)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Error deleting exercise: \(error)")
        }
    }
    
    private func deleteWorkout() {
        // Delete all exercises first
        for exercise in workout.completedExercises {
            modelContext.delete(exercise)
        }
        
        // Delete the workout
        modelContext.delete(workout)
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Error deleting workout: \(error)")
        }
        
        dismiss()
    }
}

struct EditExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let completedExercise: CompletedExercise
    @Query private var workoutSets: [WorkoutSet]
    
    @State private var targetSets: Int
    @State private var targetReps: String
    @State private var warmupSets: Int
    @State private var showingDeleteAlert = false
    
    init(completedExercise: CompletedExercise) {
        self.completedExercise = completedExercise
        self._targetSets = State(initialValue: completedExercise.targetSets ?? 3)
        self._targetReps = State(initialValue: completedExercise.targetReps ?? "8-12")
        self._warmupSets = State(initialValue: completedExercise.warmupSets ?? 0)
    }
    
    var exerciseSets: [WorkoutSet] {
        workoutSets.filter { $0.completedExercise?.id == completedExercise.id }
    }
    
    var body: some View {
        Form {
            Section("Exercise Details") {
                if let exercise = completedExercise.exercise {
                    Text(exercise.name)
                        .font(.headline)
                    
                    Text(exercise.primaryMuscleGroup)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Stepper("Target Sets: \(targetSets)", value: $targetSets, in: 1...10)
                
                TextField("Target Reps (e.g., 8-12)", text: $targetReps)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Target Reps")
                    .accessibilityIdentifier("targetRepsField")
                
                Stepper("Warmup Sets: \(warmupSets)", value: $warmupSets, in: 0...5)
            }
            
            Section("Sets") {
                ForEach(exerciseSets, id: \.id) { set in
                    EditSetRow(set: set)
                }
                .onDelete(perform: deleteSet)
                
                Button("Add Set") {
                    addSet()
                }
                .primaryButton()
                .accessibilityLabel("Add Set")
            }
            
            Section {
                Button("Delete Exercise", role: .destructive) {
                    showingDeleteAlert = true
                }
                .secondaryButton()
                .accessibilityLabel("Delete Exercise")
            }
        }
        .navigationTitle("Edit Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveChanges()
                }
                .primaryButton()
                .accessibilityLabel("Save Exercise")
            }
        }
        .alert("Delete Exercise", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteExercise()
            }
        } message: {
            Text("Are you sure you want to delete this exercise? This action cannot be undone.")
        }
    }
    
    private func saveChanges() {
        completedExercise.targetSets = targetSets
        completedExercise.targetReps = targetReps
        completedExercise.warmupSets = warmupSets
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Error saving exercise changes: \(error)")
        }
        
        dismiss()
    }
    
    private func addSet() {
        let newSet = WorkoutSet(
            weight: 0.0,
            reps: 0,
            rpe: nil,
            notes: nil,
            completedExercise: completedExercise
        )
        
        modelContext.insert(newSet)
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Error adding set: \(error)")
        }
    }
    
    private func deleteSet(offsets: IndexSet) {
        for index in offsets {
            let set = exerciseSets[index]
            modelContext.delete(set)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Error deleting set: \(error)")
        }
    }
    
    private func deleteExercise() {
        // Delete all sets first
        for set in exerciseSets {
            modelContext.delete(set)
        }
        
        // Delete the exercise
        modelContext.delete(completedExercise)
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Error deleting exercise: \(error)")
        }
        
        dismiss()
    }
}

struct EditSetRow: View {
    @Environment(\.modelContext) private var modelContext
    let set: WorkoutSet
    @State private var weight: String
    @State private var reps: String
    
    init(set: WorkoutSet) {
        self.set = set
        self._weight = State(initialValue: String(format: "%.1f", set.weight))
        self._reps = State(initialValue: "\(set.reps)")
    }
    
    var body: some View {
        HStack {
            TextField("Weight", text: $weight)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Set Weight")
                .accessibilityIdentifier("setWeightField")
                .keyboardType(.decimalPad)
                .frame(width: 80)
            
            Text("kg")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            TextField("Reps", text: $reps)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Set Reps")
                .accessibilityIdentifier("setRepsField")
                .keyboardType(.numberPad)
                .frame(width: 60)
            
            Text("reps")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onChange(of: weight) { _, newValue in
            if let weightDouble = Double(newValue) {
                set.weight = weightDouble
                try? modelContext.save()
            }
        }
        .onChange(of: reps) { _, newValue in
            if let repsInt = Int(newValue) {
                set.reps = repsInt
                try? modelContext.save()
            }
        }
    }
}

#Preview {
    WorkoutHistoryView()
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