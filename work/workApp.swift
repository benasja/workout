//
//  workApp.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import SwiftUI
import SwiftData

@main
struct workApp: App {
    @State private var hasSeededData = false
    @State private var shouldResetDatabase = false
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    print("App launched")
                    if shouldResetDatabase {
                        resetDatabase()
                        shouldResetDatabase = false
                    }
                    if !hasSeededData {
                        seedDataIfNeeded()
                        hasSeededData = true
                    }
                }
                .preferredColorScheme(
                    AppearanceMode(rawValue: appearanceMode) == .light ? .light :
                    AppearanceMode(rawValue: appearanceMode) == .dark ? .dark : nil
                )
        }
        .modelContainer(for: [
            UserProfile.self,
            WorkoutSession.self,
            CompletedExercise.self,
            WorkoutSet.self,
            ExerciseDefinition.self,
            Program.self,
            ProgramDay.self,
            ProgramExercise.self,
            WeightEntry.self,
            DailyJournal.self
        ], isAutosaveEnabled: true, isUndoEnabled: false)
    }
    
    private func seedDataIfNeeded() {
        print("Seeding data if needed")
        // This will be called when the app launches
        // The actual seeding will happen in the views when they access the model context
    }
    
    private func resetDatabase() {
        print("Resetting database...")
        // This will be called when the app launches
        // The actual seeding will happen in the views when they access the model context
    }
}
