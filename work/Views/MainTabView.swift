//
//  MainTabView.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Image(systemName: "bolt.fill")
                    Text("Today")
                }
            
            WorkoutView(workout: WorkoutSession())
                .tabItem {
                    Image(systemName: "dumbbell.fill")
                    Text("Train")
                }
            
            PerformanceDashboardView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Performance")
                }
            
            TrendsView()
                .tabItem {
                    Image(systemName: "chart.xyaxis.line")
                    Text("Trends")
                }
            
            JournalView()
                .tabItem {
                    Image(systemName: "book.closed.fill")
                    Text("Journal")
                }
            
            CorrelationView()
                .tabItem {
                    Image(systemName: "function")
                    Text("Correlations")
                }
            
            WeightTrackerView()
                .tabItem {
                    Image(systemName: "scalemass.fill")
                    Text("Weight")
                }
            
            WorkoutHistoryView()
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("History")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
        .accentColor(.blue)
    }
}





#Preview {
    MainTabView()
        .modelContainer(for: [
            UserProfile.self,
            WorkoutSession.self,
            CompletedExercise.self,
            WorkoutSet.self,
            ExerciseDefinition.self,
            Program.self,
            ProgramDay.self,
            ProgramExercise.self,
            WeightEntry.self
        ])
} 
