//
//  MainTabView.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selection: Int = 0
    var body: some View {
        TabView(selection: $selection) {
            TodayView(tabSelection: $selection)
                .tabItem {
                    Image(systemName: "bolt.fill")
                    Text("Today")
                }
                .tag(0)
            
            WorkoutLibraryView()
                .tabItem {
                    Image(systemName: "dumbbell.fill")
                    Text("Train")
                }
                .tag(1)
            
            PerformanceDashboardView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Performance")
                }
                .tag(2)
            
            TrendsView()
                .tabItem {
                    Image(systemName: "chart.xyaxis.line")
                    Text("Trends")
                }
                .tag(3)
            SleepAnalysisView()
                .tabItem {
                    Image(systemName: "bed.double.fill")
                    Text("Sleep")
                }
                .tag(4)
            
            JournalView(tabSelection: $selection)
                .tabItem {
                    Image(systemName: "book.closed.fill")
                    Text("Journal")
                }
                .tag(5)
            
            CorrelationView()
                .tabItem {
                    Image(systemName: "function")
                    Text("Correlations")
                }
                .tag(6)
            
            WeightTrackerView()
                .tabItem {
                    Image(systemName: "scalemass.fill")
                    Text("Weight")
                }
                .tag(7)
            
            WorkoutHistoryView()
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("History")
                }
                .tag(8)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(9)
            
            SupplementsView(tabSelection: $selection)
                .tabItem {
                    Image(systemName: "pills.fill")
                    Text("Supplements")
                }
                .tag(10)
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
            WeightEntry.self,
            DailyJournal.self
        ])
} 
