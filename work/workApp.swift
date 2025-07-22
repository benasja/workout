//
//  workApp.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import SwiftUI
import SwiftData
import HealthKit

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
                    
                    // Initialize baseline engine with your personal data
                    initializeBaselineEngine()
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
            WeightEntry.self,
            DailyJournal.self,
            Supplement.self,
            SupplementLog.self
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
    
    private func initializeBaselineEngine() {
        print("Initializing baseline engine...")
        
        // Request HealthKit authorization first
        HealthKitManager.shared.requestAuthorization { success in
            if success {
                print("HealthKit authorization granted, updating baselines...")
                
                // Reset old baseline data first to ensure clean personal data
                DynamicBaselineEngine.shared.resetBaselines()
                
                // Update with corrected algorithm
                DynamicBaselineEngine.shared.updateAndStoreBaselines {
                    print("Baseline engine initialized successfully")
                }
            } else {
                print("HealthKit authorization denied")
            }
        }
    }
    
    /// Forces a complete reset of all data to ensure only personal data is used
    private func forceDataReset() {
        print("🔄 Force resetting all data to use only personal data...")
        
        // Reset baselines
        DynamicBaselineEngine.shared.resetBaselines()
        
        // Clear any cached data
        UserDefaults.standard.removeObject(forKey: "DynamicBaselines")
        
        // Re-request authorization and rebuild baselines
        HealthKitManager.shared.requestAuthorization { success in
            if success {
                print("✅ Authorization granted, rebuilding baselines with personal data...")
                DynamicBaselineEngine.shared.updateAndStoreBaselines {
                    print("✅ Baseline engine rebuilt with personal data")
                }
            } else {
                print("❌ Authorization denied - cannot access personal health data")
            }
        }
    }
}
