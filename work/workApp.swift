//
//  workApp.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import SwiftUI
import SwiftData
import HealthKit

// Create the container outside the struct
private let sharedContainer: ModelContainer = {
    do {
        return try ModelContainer(for:
            UserProfile.self,
            WorkoutSession.self,
            CompletedExercise.self,
            WorkoutSet.self,
            ExerciseDefinition.self,
            Program.self,
            ProgramDay.self,
            ProgramExercise.self,
            WorkoutProgram.self,
            WeightEntry.self,
            DailyJournal.self,
            Supplement.self,
            SupplementLog.self,
            DailySupplementRecord.self,
            HydrationLog.self,
            ScoreHistory.self,
            RecoveryScore.self,
            // Fuel Log models
            FoodLog.self,
            CustomFood.self,
            NutritionGoals.self
        )
    } catch {
        fatalError("Failed to initialize ModelContainer: \(error)")
    }
}()

@main
struct workApp: App {
    @StateObject private var dataManager = DataManager(modelContext: sharedContainer.mainContext)
    @State private var hasSeededData = false
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(dataManager)
                .onAppear {
                    // print("App launched")
                    
                    // Initialize ScoreHistoryStore with model context
                    ScoreHistoryStore.shared.initialize(with: sharedContainer.mainContext)
                    
                    // Seed data if not seeded yet
                    if !hasSeededData {
                        seedDataIfNeeded()
                        hasSeededData = true
                    }
                    
                    // Initialize baseline engine with your personal data
                    initializeBaselineEngine()
                }
                .preferredColorScheme(
                    AppearanceMode(rawValue: appearanceMode) == .light ? .light :
                    AppearanceMode(rawValue: appearanceMode) == .dark ? .dark : nil
                )
        }
        // The single, shared container is provided to the entire view hierarchy.
        .modelContainer(sharedContainer)
    }
    
    private func seedDataIfNeeded() {
        print("🌱 Starting data seeding...")
        // This will be called when the app launches
        // The actual seeding will happen in the views when they access the model context
        
        // Seed exercise library and workout data
        let modelContext = sharedContainer.mainContext
        
        // Seed exercises first
        print("📚 Seeding exercise library...")
        DataSeeder.seedExerciseLibrary(modelContext: modelContext)
        
        // Then seed workout programs
        print("📋 Seeding workout programs...")
        DataSeeder.seedSampleWorkoutPrograms(modelContext: modelContext)
        
        // Finally seed fake workout history
        print("📊 Seeding workout history...")
        DataSeeder.seedFakeWorkoutHistory(modelContext: modelContext)
        
        // Also seed the legacy programs for compatibility
        print("🔄 Seeding legacy programs...")
        DataSeeder.seedSamplePrograms(modelContext: modelContext)
        
        print("✅ Data seeding completed!")
    }
    
    // MARK: - Manual Data Management
    
    /// Force seed all test data (useful for testing or recovery)
    func forceSeedAllData() {
        print("🔄 Force seeding all test data...")
        hasSeededData = false
        seedDataIfNeeded()
    }
    

    

    

    
    private func initializeBaselineEngine() {
        // print("Initializing baseline engine...")
        
        // Request HealthKit authorization first
        HealthKitManager.shared.requestAuthorization { success in
            if success {
                // print("HealthKit authorization granted, updating baselines...")
                
                // Reset old baseline data first to ensure clean personal data
                DynamicBaselineEngine.shared.resetBaselines()
                
                // Update with corrected algorithm
                DynamicBaselineEngine.shared.updateAndStoreBaselines {
                    // print("Baseline engine initialized successfully")
                }
            } else {
                // print("HealthKit authorization denied")
            }
        }
    }
    

    
    /// Forces a complete reset of all data to ensure only personal data is used
    private func forceDataReset() {
        // print("🔄 Force resetting all data to use only personal data...")
        
        // Reset baselines
        DynamicBaselineEngine.shared.resetBaselines()
        
        // Clear any cached data
        UserDefaults.standard.removeObject(forKey: "DynamicBaselines")
        
        // Re-request authorization and rebuild baselines
        HealthKitManager.shared.requestAuthorization { success in
            if success {
                // print("✅ Authorization granted, rebuilding baselines with personal data...")
                DynamicBaselineEngine.shared.updateAndStoreBaselines {
                    // print("✅ Baseline engine rebuilt with personal data")
                }
            } else {
                // print("❌ Authorization denied - cannot access personal health data")
            }
        }
    }
}
