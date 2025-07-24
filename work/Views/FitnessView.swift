//
//  FitnessView.swift
//  work
//
//  Created by Kiro on 7/24/25.
//

import SwiftUI
import SwiftData

struct FitnessView: View {
    @EnvironmentObject private var dataManager: DataManager
    
    var body: some View {
        TabView {
            ActiveWorkoutView()
                .tabItem {
                    Image(systemName: "dumbbell")
                    Text("Workout")
                }
            
            ProgramsView()
                .tabItem {
                    Image(systemName: "list.clipboard")
                    Text("Programs")
                }
            
            ExerciseLibraryView()
                .tabItem {
                    Image(systemName: "book")
                    Text("Exercises")
                }
            
            WorkoutHistoryView()
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("History")
                }
        }
        .onAppear {
            // Initialize fitness data
            dataManager.fetchExercises()
            dataManager.fetchWorkoutPrograms()
            dataManager.fetchWorkoutSessions()
            
            // Seed data if needed
            seedDataIfNeeded()
        }
    }
    
    private func seedDataIfNeeded() {
        // Access the model context from the environment
        let modelContext = dataManager.modelContext
        
        // Seed exercises first
        DataSeeder.seedExerciseLibrary(modelContext: modelContext)
        
        // Then seed workout programs
        DataSeeder.seedSampleWorkoutPrograms(modelContext: modelContext)
        
        // Finally seed fake workout history
        DataSeeder.seedFakeWorkoutHistory(modelContext: modelContext)
        
        // Refresh data after seeding
        dataManager.fetchExercises()
        dataManager.fetchWorkoutPrograms()
        dataManager.fetchWorkoutSessions()
    }
}

#Preview {
    let container = try! ModelContainer(for: ExerciseDefinition.self, WorkoutProgram.self, WorkoutSession.self, WorkoutSet.self)
    let dataManager = DataManager(modelContext: container.mainContext)
    
    return FitnessView()
        .environmentObject(dataManager)
        .modelContainer(container)
}