//
//  ExerciseLibraryView.swift
//  work
//
//  Created by Kiro on 7/24/25.
//

import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @EnvironmentObject private var dataManager: DataManager
    @State private var searchText = ""
    @State private var selectedBodyPart = "All"
    @State private var showingAddExercise = false
    @State private var exerciseToDelete: ExerciseDefinition? = nil
    @State private var showingDeleteAlert = false
    @State private var dedupSummary: String? = nil
    @State private var showingDedupAlert = false
    
    private let bodyParts = ["All", "Chest", "Back", "Shoulders", "Biceps", "Triceps", "Legs", "Core", "Calves", "Forearms", "Glutes", "Hamstrings", "Quadriceps"]
    
    private var filteredExercises: [ExerciseDefinition] {
        dataManager.exercises.filter { exercise in
            let matchesSearch = searchText.isEmpty || exercise.name.localizedCaseInsensitiveContains(searchText)
            let matchesBodyPart = selectedBodyPart == "All" || exercise.primaryMuscleGroup == selectedBodyPart
            return matchesSearch && matchesBodyPart
        }
    }
    
    private var duplicateNames: Set<String> {
        let lowercasedNames = dataManager.exercises.map { $0.name.lowercased() }
        let duplicates = lowercasedNames.filter { name in lowercasedNames.filter { $0 == name }.count > 1 }
        return Set(duplicates)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(bodyParts, id: \.self) { bodyPart in
                            Button(action: {
                                selectedBodyPart = bodyPart
                            }) {
                                Text(bodyPart)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(selectedBodyPart == bodyPart ? Color.accentColor : Color(.systemGray6))
                                    )
                                    .foregroundColor(selectedBodyPart == bodyPart ? .white : .primary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                // Exercise list
                List {
                    ForEach(filteredExercises, id: \.id) { exercise in
                        ExerciseRowView(exercise: exercise, isDuplicate: duplicateNames.contains(exercise.name.lowercased()))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    exerciseToDelete = exercise
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .searchable(text: $searchText, prompt: "Search exercises...")
                .alert("Delete Exercise?", isPresented: $showingDeleteAlert, presenting: exerciseToDelete) { exercise in
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        deleteExercise(exercise)
                    }
                } message: { exercise in
                    Text("Are you sure you want to delete the exercise '\(exercise.name)'? This cannot be undone.")
                }
                .alert("Duplicates Removed", isPresented: $showingDedupAlert) {
                    Button("OK") { dedupSummary = nil }
                } message: {
                    Text(dedupSummary ?? "Duplicates removed.")
                }
            }
            .navigationTitle("Exercise Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            showingAddExercise = true
                        }) {
                            Image(systemName: "plus")
                        }
                        Button(action: {
                            deduplicateExercises()
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .help("Remove duplicate exercises")
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseView()
            }
            .onAppear {
                dataManager.fetchExercises()
            }
        }
    }
    
    private func deleteExercise(_ exercise: ExerciseDefinition) {
        let context = dataManager.modelContext
        context.delete(exercise)
        do {
            try context.save()
            dataManager.fetchExercises()
        } catch {
            // Optionally handle error
        }
    }
    
    private func deduplicateExercises() {
        let context = dataManager.modelContext
        var seen = Set<String>()
        var deleted: [String] = []
        for exercise in dataManager.exercises {
            let name = exercise.name.lowercased()
            if seen.contains(name) {
                context.delete(exercise)
                deleted.append(exercise.name)
            } else {
                seen.insert(name)
            }
        }
        if !deleted.isEmpty {
            do {
                try context.save()
                dataManager.fetchExercises()
                dedupSummary = "Removed duplicates: \(deleted.joined(separator: ", "))"
                showingDedupAlert = true
            } catch {
                // Optionally handle error
            }
        }
    }
}

struct ExerciseRowView: View {
    let exercise: ExerciseDefinition
    var isDuplicate: Bool = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if isDuplicate {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .help("Duplicate exercise name")
                    }
                }
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
                    Spacer()
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct AddExerciseView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var selectedBodyPart = "Chest"
    @State private var selectedEquipment = "Barbell"
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    private let bodyParts = ["Chest", "Back", "Shoulders", "Biceps", "Triceps", "Legs", "Core", "Calves", "Forearms", "Glutes", "Hamstrings", "Quadriceps"]
    private let equipment = ["Barbell", "Dumbbell", "Machine", "Cable", "Bodyweight", "Kettlebell", "Resistance Band", "Smith Machine"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Exercise Details") {
                    TextField("Exercise Name", text: $name)
                    
                    Picker("Body Part", selection: $selectedBodyPart) {
                        ForEach(bodyParts, id: \.self) { bodyPart in
                            Text(bodyPart).tag(bodyPart)
                        }
                    }
                    
                    Picker("Equipment", selection: $selectedEquipment) {
                        ForEach(equipment, id: \.self) { equipment in
                            Text(equipment).tag(equipment)
                        }
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        do {
                            let _ = try dataManager.createExercise(
                                name: name,
                                bodyPart: selectedBodyPart,
                                category: selectedEquipment
                            )
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                            showingErrorAlert = true
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .alert("Save Failed", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text("Unable to save exercise: \(errorMessage)")
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: ExerciseDefinition.self)
    let dataManager = DataManager(modelContext: container.mainContext)
    
    return ExerciseLibraryView()
        .environmentObject(dataManager)
        .modelContainer(container)
}