//
//  ProgramsView.swift
//  work
//
//  Created by Kiro on 7/24/25.
//

import SwiftUI
import SwiftData

struct ProgramsView: View {
    @EnvironmentObject private var dataManager: DataManager
    @State private var showingProgramEditor = false
    @State private var editingProgram: WorkoutProgram? = nil
    @State private var errorMessage = ""
    @State private var showingErrorAlert = false
    @State private var programToDelete: WorkoutProgram? = nil
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            List {
                if dataManager.workoutPrograms.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "dumbbell")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No Programs Yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Create your first workout program to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Create Program") {
                            editingProgram = nil
                            showingProgramEditor = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(dataManager.workoutPrograms, id: \.id) { program in
                        ProgramRowView(program: program)
                            .swipeActions(edge: .trailing) {
                                Button {
                                    editingProgram = program
                                    showingProgramEditor = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                                Button(role: .destructive) {
                                    programToDelete = program
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .navigationTitle("Programs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        editingProgram = nil
                        showingProgramEditor = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingProgramEditor) {
                ProgramEditorView(editingProgram: editingProgram)
            }
            .alert("Operation Failed", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text("Unable to complete operation: \(errorMessage)")
            }
            .alert("Delete Program?", isPresented: $showingDeleteAlert, presenting: programToDelete) { program in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteProgram(program)
                }
            } message: { program in
                Text("Are you sure you want to delete the program ' [1m\(program.name) [0m'? This cannot be undone.")
            }
            .onAppear {
                dataManager.fetchWorkoutPrograms()
            }
        }
    }
    
    private func deleteProgram(_ program: WorkoutProgram) {
        let context = dataManager.modelContext
        context.delete(program)
        do {
            try context.save()
            dataManager.fetchWorkoutPrograms()
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
}

struct ProgramRowView: View {
    let program: WorkoutProgram
    @EnvironmentObject private var dataManager: DataManager
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        Button(action: {
            do {
                let _ = try dataManager.startWorkout(program: program)
            } catch {
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(program.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(program.exercises.count) exercises")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !program.exercises.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(program.exercises.prefix(3), id: \.id) { exercise in
                                    Text(exercise.name)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.2))
                                        .foregroundColor(.accentColor)
                                        .clipShape(Capsule())
                                }
                                
                                if program.exercises.count > 3 {
                                    Text("+\(program.exercises.count - 3)")
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
                
                Spacer()
                
                VStack {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    Text("Start")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .alert("Workout Failed", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text("Unable to start workout: \(errorMessage)")
        }
    }
}

struct ProgramEditorView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    
    var editingProgram: WorkoutProgram? = nil
    @State private var programName = ""
    @State private var selectedExercises: Set<UUID> = []
    @State private var searchText = ""
    @State private var errorMessage = ""
    @State private var showingErrorAlert = false
    
    private var filteredExercises: [ExerciseDefinition] {
        if searchText.isEmpty {
            return dataManager.exercises
        } else {
            return dataManager.exercises.filter { exercise in
                exercise.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Program name section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Program Name")
                        .font(.headline)
                        .padding(.horizontal)
                    TextField("Enter program name", text: $programName)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                }
                .padding(.vertical)
                .background(Color(.systemGray6))
                // Exercise selection
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Select Exercises")
                            .font(.headline)
                        Spacer()
                        Text("\(selectedExercises.count) selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    List(filteredExercises, id: \.id) { exercise in
                        ExerciseSelectionRow(
                            exercise: exercise,
                            isSelected: selectedExercises.contains(exercise.id)
                        ) { isSelected in
                            if isSelected {
                                selectedExercises.insert(exercise.id)
                            } else {
                                selectedExercises.remove(exercise.id)
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search exercises...")
                }
            }
            .navigationTitle(editingProgram == nil ? "New Program" : "Edit Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let selectedExerciseObjects = dataManager.exercises.filter { exercise in
                            selectedExercises.contains(exercise.id)
                        }
                        do {
                            if let editingProgram = editingProgram {
                                editingProgram.name = programName
                                editingProgram.exercises = selectedExerciseObjects
                            } else {
                                let _ = try dataManager.createWorkoutProgram(
                                    name: programName,
                                    exercises: selectedExerciseObjects
                                )
                            }
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                            showingErrorAlert = true
                        }
                    }
                    .disabled(programName.isEmpty || selectedExercises.isEmpty)
                }
            }
            .onAppear {
                dataManager.fetchExercises()
                if let editingProgram = editingProgram {
                    programName = editingProgram.name
                    selectedExercises = Set(editingProgram.exercises.map { $0.id })
                }
            }
        }
        .alert("Save Failed", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text("Unable to save program: \(errorMessage)")
        }
    }
}

struct ExerciseSelectionRow: View {
    let exercise: ExerciseDefinition
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        Button(action: {
            onToggle(!isSelected)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(exercise.primaryMuscleGroup)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .foregroundColor(.accentColor)
                            .clipShape(Capsule())
                        
                        Text(exercise.equipment)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .foregroundColor(.secondary)
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let container = try! ModelContainer(for: WorkoutProgram.self, ExerciseDefinition.self)
    let dataManager = DataManager(modelContext: container.mainContext)
    
    return ProgramsView()
        .environmentObject(dataManager)
        .modelContainer(container)
}