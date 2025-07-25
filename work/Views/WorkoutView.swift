//
//  WorkoutView.swift
//  work
//
//  Created by Benas on 6/27/25.
//  Redesigned as Interactive Logbook for optimal gym experience
//

import SwiftUI
import SwiftData

// MARK: - Main Workout View: Interactive Logbook
struct WorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: DataManager
    
    let workout: WorkoutSession
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showingAddExercise = false
    @State private var showingNotes = false
    @State private var showingEndWorkoutAlert = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header with Timer and Finish Button
            workoutHeader
            
            // MARK: - Main Content: Smart Exercise Cards
            if workout.completedExercises.isEmpty {
                emptyWorkoutState
            } else {
                exerciseCardsList
            }
            
            // MARK: - Footer Toolbar
            workoutFooter
        }
        .navigationBarBackButtonHidden(true)
        .background(AppColors.background)
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
        .sheet(isPresented: $showingAddExercise) {
            ExerciseSelectionSheet { exercise in
                addExerciseToWorkout(exercise)
            }
        }
        .sheet(isPresented: $showingNotes) {
            WorkoutNotesSheet(notes: workout.notes ?? "") { newNotes in
                workout.notes = newNotes
                try? modelContext.save()
            }
        }
        .alert("Finish Workout", isPresented: $showingEndWorkoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Finish", role: .destructive) { endWorkout() }
        } message: {
            Text("Are you sure you want to finish this workout? Your progress will be saved.")
        }
        .alert("Error", isPresented: Binding<Bool>(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unexpected error occurred")
        }
    }
    
    // MARK: - Header Component
    private var workoutHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Elapsed Time")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .fontWeight(.medium)
                
                Text(formatTime(elapsedTime))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(AppColors.primary)
            }
            
            Spacer()
            
            Button(action: { showingEndWorkoutAlert = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.headline)
                    Text("Finish Workout")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [AppColors.accent, AppColors.accent.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: AppColors.accent.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [AppColors.secondaryBackground, AppColors.tertiaryBackground.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Empty State
    private var emptyWorkoutState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 60))
                .foregroundColor(AppColors.primary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Ready to Start")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Add your first exercise to begin logging sets")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showingAddExercise = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Exercise")
                        .fontWeight(.semibold)
                }
                .font(.headline)
            }
            .primaryButton()
            .padding(.top, 8)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Exercise Cards List
    private var exerciseCardsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(workout.completedExercises, id: \.id) { completedExercise in
                    if let exercise = completedExercise.exercise {
                        SmartExerciseCard(
                            completedExercise: completedExercise,
                            exercise: exercise,
                            workout: workout
                        )
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Footer Toolbar
    private var workoutFooter: some View {
        HStack(spacing: 12) {
            Button(action: { showingAddExercise = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.headline)
                    Text("Add Exercise")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            .primaryButton()
            
            Button(action: { showingNotes = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.headline)
                    Text("Notes")
                        .font(.headline)
                        .fontWeight(.medium)
                }
            }
            .secondaryButton()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.background)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: -2)
    }
    
    // MARK: - Helper Methods
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
    
    private func addExerciseToWorkout(_ exercise: ExerciseDefinition) {
        let completedExercise = CompletedExercise(exercise: exercise)
        completedExercise.workoutSession = workout
        workout.completedExercises.append(completedExercise)
        modelContext.insert(completedExercise)
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to add exercise: \(error.localizedDescription)"
        }
    }
    
    private func endWorkout() {
        workout.isCompleted = true
        workout.endDate = Date()
        workout.duration = Date().timeIntervalSince(workout.date)
        
        // Ensure all relationships are properly saved
        for completedExercise in workout.completedExercises {
            for set in completedExercise.sets {
                if set.completedExercise == nil {
                    set.completedExercise = completedExercise
                }
                if !workout.sets.contains(set) {
                    workout.sets.append(set)
                }
            }
        }
        
        do {
            try modelContext.save()
            dataManager.currentWorkoutSession = nil
            dismiss()
        } catch {
            errorMessage = "Failed to finish workout: \(error.localizedDescription)"
        }
    }
}

// MARK: - Smart Exercise Card: The Core Interactive Component
struct SmartExerciseCard: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dataManager: DataManager
    
    let completedExercise: CompletedExercise
    let exercise: ExerciseDefinition
    let workout: WorkoutSession
    
    @State private var setInputs: [SetInput] = []
    @State private var previousWorkoutSets: [WorkoutSet] = []
    @State private var errorMessage: String? = nil
    @State private var isExpanded = true
    
    // Data structure for set inputs
    struct SetInput: Identifiable {
        let id = UUID()
        var weight: String
        var reps: String
        var isCompleted: Bool
        var isLoading: Bool = false
    }
    
    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                // MARK: - Card Header with Exercise Name
                exerciseHeader
                
                // MARK: - Historical Context (Progressive Overload)
                historicalContext
                
                // MARK: - Set Table (The Core Interface)
                if isExpanded {
                    setTable
                    
                    // MARK: - Add Set Button
                    addSetButton
                }
            }
        }
        .onAppear {
            loadExerciseData()
        }
        .alert("Error", isPresented: Binding<Bool>(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unexpected error occurred")
        }
    }
    
    // MARK: - Exercise Header
    private var exerciseHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Show current session progress
                if !setInputs.isEmpty {
                    let completedSets = setInputs.filter { $0.isCompleted }.count
                    Text("\(completedSets) of \(setInputs.count) sets completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Collapse/Expand button for space efficiency
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.title2)
                    .foregroundColor(AppColors.primary)
            }
        }
    }
    
    // MARK: - Historical Context for Progressive Overload
    private var historicalContext: some View {
        Group {
            if let bestPreviousSet = getBestPreviousSet() {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundColor(AppColors.accent)
                    
                    Text("Last time: \(bestPreviousSet.weight, specifier: "%.0f") kg × \(bestPreviousSet.reps) reps")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Spacer()
                    
                    // Show estimated 1RM for motivation
                    Text("e1RM: \(bestPreviousSet.e1RM, specifier: "%.0f") kg")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppColors.accent.opacity(0.1))
                        .cornerRadius(4)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColors.tertiaryBackground)
                .cornerRadius(8)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.warning)
                    
                    Text("First time doing this exercise!")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColors.warning.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Set Table (Clean, Easy-to-Read)
    private var setTable: some View {
        VStack(spacing: 8) {
            // Table Header
            HStack {
                Text("SET")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .center)
                
                Text("PREVIOUS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .center)
                
                Text("KG")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .center)
                
                Text("REPS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .center)
                
                Spacer()
                
                Text("✓")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .frame(width: 32, alignment: .center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppColors.secondaryBackground.opacity(0.5))
            .cornerRadius(8)
            
            // Set Rows
            ForEach(setInputs.indices, id: \.self) { index in
                SetRowView(
                    setNumber: index + 1,
                    setInput: $setInputs[index],
                    previousSet: getPreviousSet(for: index),
                    onLogSet: { logSet(at: index) }
                )
            }
        }
    }
    
    // MARK: - Add Set Button
    private var addSetButton: some View {
        Button(action: addNewSet) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.headline)
                Text("Add Set")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(AppColors.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppColors.primary.opacity(0.1))
            .cornerRadius(10)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helper Methods
    private func loadExerciseData() {
        // Load existing sets for this exercise in current workout
        let existingSets = completedExercise.sets.sorted { $0.date < $1.date }
        
        // Load previous workout sets for this exercise
        previousWorkoutSets = dataManager.getSetsForExercise(exercise)
            .filter { $0.completedExercise?.workoutSession?.id != workout.id }
            .sorted { $0.date > $1.date }
        
        // Initialize set inputs
        if existingSets.isEmpty {
            // Create first set with auto-fill from previous workout
            if let bestPrevious = getBestPreviousSet() {
                setInputs = [SetInput(
                    weight: String(format: "%.0f", bestPrevious.weight),
                    reps: "\(bestPrevious.reps)",
                    isCompleted: false
                )]
            } else {
                setInputs = [SetInput(weight: "", reps: "", isCompleted: false)]
            }
        } else {
            // Load existing sets
            setInputs = existingSets.map { set in
                SetInput(
                    weight: String(format: "%.0f", set.weight),
                    reps: "\(set.reps)",
                    isCompleted: set.isCompleted
                )
            }
        }
    }
    
    private func getBestPreviousSet() -> WorkoutSet? {
        // Return the best working set from the most recent workout
        let workingSets = previousWorkoutSets.filter { $0.setType == .working }
        return workingSets.max { $0.e1RM < $1.e1RM }
    }
    
    private func getPreviousSet(for index: Int) -> WorkoutSet? {
        // Get the corresponding set from the previous workout
        let previousWorkingSets = previousWorkoutSets.filter { $0.setType == .working }
        return index < previousWorkingSets.count ? previousWorkingSets[index] : nil
    }
    
    private func addNewSet() {
        // Auto-fill with the last completed set from this session, or best previous set
        let lastCompletedSet = completedExercise.sets.last
        let referenceSet = lastCompletedSet ?? getBestPreviousSet()
        
        if let reference = referenceSet {
            setInputs.append(SetInput(
                weight: String(format: "%.0f", reference.weight),
                reps: "\(reference.reps)",
                isCompleted: false
            ))
        } else {
            setInputs.append(SetInput(weight: "", reps: "", isCompleted: false))
        }
    }
    
    private func logSet(at index: Int) {
        guard index < setInputs.count,
              let weight = Double(setInputs[index].weight),
              let reps = Int(setInputs[index].reps),
              weight > 0, reps > 0 else {
            errorMessage = "Please enter valid weight and reps"
            return
        }
        
        setInputs[index].isLoading = true
        
        // Create new WorkoutSet
        let newSet = WorkoutSet(
            weight: weight,
            reps: reps,
            date: Date(),
            setType: .working,
            isCompleted: true,
            exercise: exercise,
            completedExercise: completedExercise
        )
        
        // Establish all relationships
        newSet.completedExercise = completedExercise
        newSet.exercise = exercise
        completedExercise.sets.append(newSet)
        workout.sets.append(newSet)
        
        modelContext.insert(newSet)
        
        do {
            try modelContext.save()
            setInputs[index].isCompleted = true
            setInputs[index].isLoading = false
            
            // Provide haptic feedback for successful set completion
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
        } catch {
            setInputs[index].isLoading = false
            errorMessage = "Failed to save set: \(error.localizedDescription)"
        }
    }
}

// MARK: - Set Row Component
struct SetRowView: View {
    let setNumber: Int
    @Binding var setInput: SmartExerciseCard.SetInput
    let previousSet: WorkoutSet?
    let onLogSet: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Set Number
            Text("\(setNumber)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(width: 40, alignment: .center)
            
            // Previous Set Data
            VStack {
                if let prev = previousSet {
                    Text("\(prev.weight, specifier: "%.0f")kg × \(prev.reps)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundColor(Color.secondary.opacity(0.6))
                }
            }
            .frame(width: 80, alignment: .center)
            
            // Weight Input
            TextField("kg", text: $setInput.weight)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .disabled(setInput.isCompleted)
                .opacity(setInput.isCompleted ? 0.6 : 1.0)
            
            // Reps Input
            TextField("reps", text: $setInput.reps)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 50)
                .disabled(setInput.isCompleted)
                .opacity(setInput.isCompleted ? 0.6 : 1.0)
            
            Spacer()
            
            // Checkmark Button
            Button(action: onLogSet) {
                VStack {
                    if setInput.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: setInput.isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.title2)
                    }
                }
                .foregroundColor(setInput.isCompleted ? AppColors.success : AppColors.primary)
            }
            .disabled(setInput.isCompleted || setInput.weight.isEmpty || setInput.reps.isEmpty || setInput.isLoading)
            .frame(width: 32, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            setInput.isCompleted ? 
            AppColors.success.opacity(0.1) : 
            Color.clear
        )
        .cornerRadius(8)
        .animation(.easeInOut(duration: 0.2), value: setInput.isCompleted)
    }
}



// MARK: - Workout Notes Sheet
struct WorkoutNotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var notes: String
    let onSave: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "note.text")
                            .font(.title2)
                            .foregroundColor(AppColors.primary)
                        
                        Text("Workout Notes")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                    }
                    
                    Text("Add notes about your workout, how you felt, or any observations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                TextEditor(text: $notes)
                    .padding(16)
                    .background(AppColors.secondaryBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
                    )
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .secondaryButton()
                    
                    Button("Save Notes") {
                        onSave(notes)
                        dismiss()
                    }
                    .primaryButton()
                }
            }
            .padding(20)
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Exercise Selection Sheet
struct ExerciseSelectionSheet: View {
    let onExerciseSelected: (ExerciseDefinition) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [ExerciseDefinition]
    @State private var searchText = ""
    @State private var selectedCategory: String = "All"
    
    private var categories: [String] {
        let allCategories = exercises.map { exercise in
            exercise.primaryMuscleGroup
        }.unique().sorted()
        return ["All"] + allCategories
    }
    
    private var filteredExercises: [ExerciseDefinition] {
        var filtered = exercises
        
        // Filter by category
        if selectedCategory != "All" {
            filtered = filtered.filter { exercise in
                exercise.primaryMuscleGroup == selectedCategory
            }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { exercise in
                exercise.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered.sorted { first, second in
            first.name < second.name
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            Button(category) {
                                selectedCategory = category
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedCategory == category ? .white : AppColors.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedCategory == category ? 
                                AppColors.primary : 
                                AppColors.primary.opacity(0.1)
                            )
                            .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
                .background(AppColors.secondaryBackground)
                
                // Exercise List
                List(filteredExercises, id: \.id) { exercise in
                    Button(action: {
                        onExerciseSelected(exercise)
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            // Exercise icon based on muscle group
                            Image(systemName: iconForMuscleGroup(exercise.primaryMuscleGroup))
                                .font(.title2)
                                .foregroundColor(AppColors.primary)
                                .frame(width: 32, height: 32)
                                .background(AppColors.primary.opacity(0.1))
                                .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text(exercise.primaryMuscleGroup)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(AppColors.accent)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .searchable(text: $searchText, prompt: "Search exercises...")
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
        }
    }
    
    private func iconForMuscleGroup(_ muscleGroup: String) -> String {
        let group = muscleGroup.lowercased()
        
        switch group {
        case "chest": 
            return "heart.fill"
        case "back": 
            return "figure.strengthtraining.traditional"
        case "shoulders": 
            return "figure.arms.open"
        case "arms", "biceps", "triceps": 
            return "arm.flex"
        case "legs", "quadriceps", "hamstrings": 
            return "figure.walk"
        case "glutes": 
            return "figure.squat"
        case "core", "abs": 
            return "figure.core.training"
        case "cardio": 
            return "heart.circle"
        default: 
            return "dumbbell"
        }
    }
}

// MARK: - Array Extension for Unique Values
extension Array where Element: Hashable {
    func unique() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - Preview
#Preview("Active Workout") {
    let container = try! ModelContainer(for: WorkoutSession.self, CompletedExercise.self, WorkoutSet.self, ExerciseDefinition.self)
    
    let workout = WorkoutSession()
    let dataManager = DataManager(modelContext: container.mainContext)
    
    NavigationStack {
        WorkoutView(workout: workout)
            .environmentObject(dataManager)
    }
    .modelContainer(container)
}

#Preview("Empty Workout") {
    let container = try! ModelContainer(for: WorkoutSession.self, CompletedExercise.self, WorkoutSet.self, ExerciseDefinition.self)
    
    let workout = WorkoutSession()
    let dataManager = DataManager(modelContext: container.mainContext)
    
    NavigationStack {
        WorkoutView(workout: workout)
            .environmentObject(dataManager)
    }
    .modelContainer(container)
}