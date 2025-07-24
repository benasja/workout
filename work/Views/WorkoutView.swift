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
    @EnvironmentObject private var dataManager: DataManager
    
    let workout: WorkoutSession
    @State private var selectedExercise: ExerciseDefinition?
    @State private var showingExerciseSelection = false
    @State private var showingEndWorkoutAlert = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Timer header
                VStack(spacing: 8) {
                    Text("Workout in Progress")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(formatTime(elapsedTime))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundColor(.accentColor)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Workout content
                if workout.completedExercises.isEmpty {
                    // No exercises yet
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "plus.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.accentColor)
                        
                        Text("Add Your First Exercise")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Tap the + button to add exercises to your workout")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                    }
                    .padding()
                } else {
                    // Show exercises
                    List {
                        ForEach(workout.completedExercises, id: \.id) { completedExercise in
                            if let exercise = completedExercise.exercise {
                                ExerciseWorkoutRowView(
                                    completedExercise: completedExercise,
                                    exercise: exercise
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle(workout.programName ?? "Quick Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("End Workout") {
                        showingEndWorkoutAlert = true
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingExerciseSelection = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
            .sheet(isPresented: $showingExerciseSelection) {
                ExerciseSelectionSheet { exercise in
                    addExerciseToWorkout(exercise)
                }
            }
            .alert("End Workout", isPresented: $showingEndWorkoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("End Workout", role: .destructive) {
                    endWorkout()
                }
            } message: {
                Text("Are you sure you want to end this workout?")
            }
            .alert("Save Failed", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text("Unable to save your changes: \(errorMessage)")
            }
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime = Date().timeIntervalSince(workout.date)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    private func addExerciseToWorkout(_ exercise: ExerciseDefinition) {
        let completedExercise = CompletedExercise(exercise: exercise)
        completedExercise.workoutSession = workout
        
        modelContext.insert(completedExercise)
        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
    
    private func endWorkout() {
        workout.isCompleted = true
        workout.endDate = Date()
        
        do {
            try modelContext.save()
            // Clear current workout from DataManager
            dataManager.currentWorkoutSession = nil
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
}

struct ExerciseWorkoutRowView: View {
    let completedExercise: CompletedExercise
    let exercise: ExerciseDefinition
    @Environment(\.modelContext) private var modelContext
    @State private var showingSetEntry = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise header
            HStack {
                Text(exercise.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    showingSetEntry = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            
            // Sets
            if completedExercise.sets.isEmpty {
                Text("No sets yet - tap + to add a set")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(completedExercise.sets.enumerated()), id: \.offset) { index, set in
                        HStack {
                            Text("Set \(index + 1)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .leading)
                            
                            Text("\(set.weight.formatted(.number.precision(.fractionLength(1)))) kg")
                                .font(.subheadline)
                                .frame(width: 60, alignment: .trailing)
                            
                            Text("×")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("\(set.reps)")
                                .font(.subheadline)
                                .frame(width: 30, alignment: .leading)
                            
                            Spacer()
                            
                            let e1rm = set.e1RM
                            Text("e1RM: \(e1rm.formatted(.number.precision(.fractionLength(1))))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showingSetEntry) {
            SetEntrySheet(completedExercise: completedExercise)
        }
    }
}

struct ExerciseSelectionSheet: View {
    let onExerciseSelected: (ExerciseDefinition) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [ExerciseDefinition]
    @State private var searchText = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var filteredExercises: [ExerciseDefinition] {
        if searchText.isEmpty {
            return exercises
        } else {
            return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            List(filteredExercises, id: \.id) { exercise in
                Button(exercise.name) {
                    onExerciseSelected(exercise)
                    dismiss()
                }
                .foregroundColor(.primary)
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Save Failed", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text("Unable to save your changes: \(errorMessage)")
            }
        }
    }
}

struct SetEntrySheet: View {
    let completedExercise: CompletedExercise
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var weight: String = ""
    @State private var reps: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add Set")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 16) {
                    HStack {
                        Text("Weight (kg)")
                            .frame(width: 100, alignment: .leading)
                        TextField("0.0", text: $weight)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("Reps")
                            .frame(width: 100, alignment: .leading)
                        TextField("0", text: $reps)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Button("Add Set") {
                    addSet()
                }
                .buttonStyle(.borderedProminent)
                .disabled(weight.isEmpty || reps.isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    private func addSet() {
        guard let weightValue = Double(weight),
              let repsValue = Int(reps) else { return }
        
        let set = WorkoutSet(weight: weightValue, reps: repsValue, date: Date())
        set.completedExercise = completedExercise
        
        modelContext.insert(set)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
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
            Program.self
        ])
}