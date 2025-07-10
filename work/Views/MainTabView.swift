//
//  MainTabView.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selection: Int = 0
    @State private var showingMoreMenu = false
    @StateObject private var dateModel = PerformanceDateModel()
    
    var body: some View {
        TabView(selection: $selection) {
            PerformanceView()
                .environmentObject(dateModel)
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Performance")
                }
                .tag(0)
            
            SleepDetailView()
                .environmentObject(dateModel)
                .tabItem {
                    Image(systemName: "bed.double.fill")
                    Text("Sleep")
                }
                .tag(1)
            
            RecoveryDetailView()
                .environmentObject(dateModel)
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Recovery")
                }
                .tag(2)
            
            MoreView(showingMenu: $showingMoreMenu)
                .tabItem {
                    Image(systemName: "ellipsis.circle.fill")
                    Text("More")
                }
                .tag(3)
        }
        .accentColor(.blue)
    }
}

// RecoveryView is now defined in RecoveryView.swift

struct MoreView: View {
    @Binding var showingMenu: Bool
    
    var body: some View {
        NavigationView {
            List {
                Section("Training") {
                    NavigationLink(destination: WorkoutLibraryView()) {
                        HStack {
                            Image(systemName: "dumbbell.fill")
                                .foregroundColor(.blue)
                            Text("Train")
                        }
                    }
                    
                    NavigationLink(destination: WorkoutHistoryView()) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.green)
                            Text("History")
                        }
                    }
                }
                
                Section("Health & Wellness") {
                    NavigationLink(destination: JournalView(tabSelection: .constant(0))) {
                        HStack {
                            Image(systemName: "book.closed.fill")
                                .foregroundColor(.teal)
                            Text("Journal")
                        }
                    }
                    
                    NavigationLink(destination: WeightTrackerView()) {
                        HStack {
                            Image(systemName: "scalemass.fill")
                                .foregroundColor(.orange)
                            Text("Weight")
                        }
                    }
                    
                    NavigationLink(destination: SupplementsView(tabSelection: .constant(0))) {
                        HStack {
                            Image(systemName: "pills.fill")
                                .foregroundColor(.purple)
                            Text("Supplements")
                        }
                    }
                }
                
                Section("Analytics") {
                    NavigationLink(destination: CorrelationView()) {
                        HStack {
                            Image(systemName: "function")
                                .foregroundColor(.indigo)
                            Text("Correlations")
                        }
                    }
                }
                
                Section("Settings") {
                    NavigationLink(destination: SettingsView()) {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.gray)
                            Text("Settings")
                        }
                    }
                }
            }
            .navigationTitle("More")
        }
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
