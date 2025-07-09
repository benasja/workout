//
//  ProgramsView.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import SwiftUI
import SwiftData

struct ProgramsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var programs: [Program]
    
    @State private var showingAddProgram = false
    @State private var selectedProgram: Program?
    
    var body: some View {
        NavigationView {
            VStack {
                if programs.isEmpty {
                    EmptyProgramsView {
                        showingAddProgram = true
                    }
                } else {
                    ProgramsListView(
                        programs: programs,
                        onProgramSelected: { program in
                            selectedProgram = program
                        }
                    )
                }
            }
            .navigationTitle("Programs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddProgram = true }) {
                        Image(systemName: "plus")
                    }
                    .primaryButton()
                    .accessibilityLabel("Add Program")
                }
            }
            .sheet(isPresented: $showingAddProgram) {
                AddProgramView()
            }
            .sheet(item: $selectedProgram) { program in
                ProgramDetailView(program: program)
            }
        }
    }
}

struct EmptyProgramsView: View {
    let onAddProgram: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Programs Yet")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Create your first workout program to get started with structured training")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onAddProgram) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Program")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(AppCornerRadius.sm)
                .primaryButton()
                .accessibilityLabel("Add Program")
            }
            
            Spacer()
        }
        .padding()
    }
}

struct ProgramsListView: View {
    let programs: [Program]
    let onProgramSelected: (Program) -> Void
    
    var body: some View {
        List(programs, id: \.id) { program in
            ProgramRowView(program: program) {
                onProgramSelected(program)
            }
        }
    }
}

struct ProgramRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPrograms: [Program]
    let program: Program
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Program icon
                Image(systemName: program.isActive ? "star.fill" : "calendar")
                    .font(.title2)
                    .foregroundColor(program.isActive ? .yellow : .blue)
                    .frame(width: 40)
                
                // Program details
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(program.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if program.isActive {
                            Text("ACTIVE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(AppCornerRadius.sm)
                        }
                    }
                    
                    Text(program.programDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Text("\(program.weeks) weeks • \(program.days.count) workout days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .trailing) {
            if !program.isActive {
                Button("Activate") {
                    activateProgram(program)
                }
                .tint(.green)
                .primaryButton()
                .accessibilityLabel("Activate Program")
            }
            
            Button("Delete", role: .destructive) {
                deleteProgram(program)
            }
            .secondaryButton()
            .accessibilityLabel("Delete Program")
        }
    }
    
    private func activateProgram(_ program: Program) {
        // Deactivate all other programs
        for p in allPrograms {
            p.isActive = false
        }
        program.isActive = true
    }
    
    private func deleteProgram(_ program: Program) {
        modelContext.delete(program)
    }
}

struct AddProgramView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var weeks = 4
    @State private var showingAddDay = false
    @State private var programDays: [ProgramDay] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section("Program Details") {
                    TextField("Program name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Program Name")
                        .accessibilityIdentifier("programNameField")
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Program Description")
                        .accessibilityIdentifier("programDescriptionField")
                        .lineLimit(3...6)
                    
                    Stepper("Duration: \(weeks) weeks", value: $weeks, in: 1...52)
                }
                
                Section("Workout Days") {
                    ForEach(programDays, id: \.dayName) { day in
                        HStack {
                            Text(day.dayName)
                            Spacer()
                            Text("\(day.exercises.count) exercises")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete(perform: deleteDay)
                    
                    Button(action: { showingAddDay = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Workout Day")
                        }
                        .primaryButton()
                        .accessibilityLabel("Add Day")
                    }
                }
            }
            .navigationTitle("New Program")
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
                        saveProgram()
                    }
                    .primaryButton()
                    .accessibilityLabel("Save")
                }
            }
            .sheet(isPresented: $showingAddDay) {
                AddProgramDayView { day in
                    programDays.append(day)
                }
            }
        }
    }
    
    private func deleteDay(offsets: IndexSet) {
        programDays.remove(atOffsets: offsets)
    }
    
    private func saveProgram() {
        let program = Program(name: name, description: description, weeks: weeks)
        program.days = programDays
        
        modelContext.insert(program)
        dismiss()
    }
}

struct AddProgramDayView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var dayName = ""
    @State private var exercises: [ProgramExercise] = []
    @State private var showingExerciseLibrary = false
    @State private var selectedExercise: ProgramExercise?
    
    let onSave: (ProgramDay) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Day Details") {
                    TextField("Day name (e.g., Push Day)", text: $dayName)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Day Name")
                        .accessibilityIdentifier("dayNameField")
                }
                
                Section("Exercises") {
                    ForEach(exercises, id: \.exercise?.id) { programExercise in
                        if let exercise = programExercise.exercise {
                            Button(action: { selectedExercise = programExercise }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exercise.name)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        
                                        Text("\(programExercise.targetSets) sets × \(programExercise.targetReps)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        if programExercise.warmupSets > 0 {
                                            Text("\(programExercise.warmupSets) warmup sets")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Text(programExercise.progressionRule.displayName)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(AppCornerRadius.sm)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .primaryButton()
                                .accessibilityLabel("Select Exercise")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .onDelete(perform: deleteExercise)
                    
                    Button(action: { showingExerciseLibrary = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Exercise")
                        }
                        .primaryButton()
                        .accessibilityLabel("Show Exercise Library")
                    }
                }
            }
            .navigationTitle("Add Workout Day")
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
                        saveDay()
                    }
                    .primaryButton()
                    .accessibilityLabel("Save")
                }
            }
            .sheet(isPresented: $showingExerciseLibrary) {
                ExerciseLibraryView(selectionMode: true) { exercise in
                    addExerciseToDay(exercise)
                }
            }
            .sheet(item: $selectedExercise) { exercise in
                EditProgramExerciseView(programExercise: exercise) { updatedExercise in
                    if let index = exercises.firstIndex(where: { $0.exercise?.id == updatedExercise.exercise?.id }) {
                        exercises[index] = updatedExercise
                    }
                }
            }
        }
    }
    
    private func deleteExercise(offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
    }
    
    private func addExerciseToDay(_ exercise: ExerciseDefinition) {
        let programExercise = ProgramExercise(
            exercise: exercise,
            targetSets: 3,
            targetReps: "8-12",
            progressionRule: .doubleProgression,
            warmupSets: 0
        )
        exercises.append(programExercise)
    }
    
    private func saveDay() {
        let day = ProgramDay(dayName: dayName)
        day.exercises = exercises
        onSave(day)
        dismiss()
    }
}

struct EditProgramExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    let programExercise: ProgramExercise
    let onSave: (ProgramExercise) -> Void
    
    @State private var targetSets: Int
    @State private var targetReps: String
    @State private var progressionRule: ProgressionRule
    @State private var warmupSets: Int
    
    init(programExercise: ProgramExercise, onSave: @escaping (ProgramExercise) -> Void) {
        self.programExercise = programExercise
        self.onSave = onSave
        self._targetSets = State(initialValue: programExercise.targetSets)
        self._targetReps = State(initialValue: programExercise.targetReps)
        self._progressionRule = State(initialValue: programExercise.progressionRule)
        self._warmupSets = State(initialValue: programExercise.warmupSets)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Exercise Details") {
                    if let exercise = programExercise.exercise {
                        Text(exercise.name)
                            .font(.headline)
                        
                        Text(exercise.primaryMuscleGroup)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Sets & Reps") {
                    Stepper("Target Sets: \(targetSets)", value: $targetSets, in: 1...10)
                    
                    TextField("Target Reps (e.g., 8-12)", text: $targetReps)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Target Reps")
                        .accessibilityIdentifier("targetRepsField")
                    
                    Stepper("Warmup Sets: \(warmupSets)", value: $warmupSets, in: 0...5)
                }
                
                Section("Progression") {
                    Picker("Progression Rule", selection: $progressionRule) {
                        ForEach(ProgressionRule.allCases, id: \.self) { rule in
                            Text(rule.displayName).tag(rule)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .accessibilityLabel("Progression Rule")
                    .accessibilityIdentifier("progressionRulePicker")
                }
            }
            .navigationTitle("Edit Exercise")
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
                        saveExercise()
                    }
                    .primaryButton()
                    .accessibilityLabel("Save")
                }
            }
        }
    }
    
    private func saveExercise() {
        guard let exercise = programExercise.exercise else {
            dismiss()
            return
        }
        
        let updatedExercise = ProgramExercise(
            exercise: exercise,
            targetSets: targetSets,
            targetReps: targetReps,
            progressionRule: progressionRule,
            warmupSets: warmupSets
        )
        onSave(updatedExercise)
        dismiss()
    }
}

struct ProgramDayCard: View {
    let day: ProgramDay
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(day.dayName)
                .font(.headline)
            
            ForEach(day.exercises, id: \.exercise?.id) { programExercise in
                if let exercise = programExercise.exercise {
                    HStack {
                        Text("• \(exercise.name)")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(programExercise.targetSets) × \(programExercise.targetReps)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(AppCornerRadius.sm)
    }
}

struct EditProgramView: View {
    @Environment(\.dismiss) private var dismiss
    let program: Program
    
    var body: some View {
        NavigationView {
            Text("Edit Program - Coming Soon")
                .navigationTitle("Edit Program")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .primaryButton()
                        .accessibilityLabel("Done")
                    }
                }
        }
    }
}

#Preview {
    ProgramsView()
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