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
    @State private var shouldResetDatabase = false
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(dataManager)
                .onAppear {
                    // print("App launched")
                    if shouldResetDatabase {
                        resetDatabase()
                        shouldResetDatabase = false
                    }
                    if !hasSeededData {
                        seedDataIfNeeded()
                        hasSeededData = true
                    }
                    
                    // Initialize ScoreHistoryStore with model context
                    ScoreHistoryStore.shared.initialize(with: sharedContainer.mainContext)
                    
                    // Initialize baseline engine with your personal data
                    initializeBaselineEngine()
                    
                    // Check for database schema issues
                    checkDatabaseSchema()
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
        // print("Seeding data if needed")
        // This will be called when the app launches
        // The actual seeding will happen in the views when they access the model context
    }
    
    private func resetDatabase() {
        print("🔄 Resetting database due to schema issues...")
        
        // Delete the existing database file
        let containerURL = sharedContainer.configurations.first?.url
        if let url = containerURL {
            do {
                try FileManager.default.removeItem(at: url)
                print("✅ Database file deleted successfully")
            } catch {
                print("❌ Failed to delete database file: \(error)")
            }
        }
        
        // Force app restart to recreate database
        exit(0)
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
    
    private func checkDatabaseSchema() {
        // Test if the database can access FoodLog table
        let context = sharedContainer.mainContext
        var descriptor = FetchDescriptor<FoodLog>()
        descriptor.fetchLimit = 1
        
        do {
            _ = try context.fetch(descriptor)
            print("✅ Database schema is valid")
        } catch {
            print("❌ Database schema error detected: \(error)")
            print("🔄 Resetting database...")
            resetDatabase()
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
