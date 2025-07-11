//
//  MainTabView.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var tabSelectionModel = TabSelectionModel()
    @StateObject private var dateModel = PerformanceDateModel()
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @AppStorage("openRecoveryFromToday") private var openRecoveryFromToday: Bool = false
    @AppStorage("openSleepFromToday") private var openSleepFromToday: Bool = false
    @State private var showRecoverySheet = false
    @State private var showSleepSheet = false
    
    private var colorScheme: ColorScheme? {
        let mode = AppearanceMode(rawValue: appearanceMode)
        switch mode {
        case .light: return .light
        case .dark: return .dark
        case .system, .none: return nil
        }
    }
    
    var body: some View {
        TabView(selection: $tabSelectionModel.selection) {
            PerformanceView()
                .environmentObject(dateModel)
                .environmentObject(tabSelectionModel)
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Today")
                }
                .tag(0)
            
            NavigationStack {
                if tabSelectionModel.moreTabDetail == .recovery {
                    VStack(spacing: 0) {
                        HStack {
                            Button(action: { tabSelectionModel.moreTabDetail = .none }) {
                                Image(systemName: "chevron.left")
                                    .font(.title2)
                                    .padding(.leading)
                            }
                            Spacer()
                        }
                        RecoveryDetailView()
                            .environmentObject(dateModel)
                            .environmentObject(tabSelectionModel)
                    }
                    .navigationBarHidden(true)
                } else if tabSelectionModel.moreTabDetail == .sleep {
                    VStack(spacing: 0) {
                        HStack {
                            Button(action: { tabSelectionModel.moreTabDetail = .none }) {
                                Image(systemName: "chevron.left")
                                    .font(.title2)
                                    .padding(.leading)
                            }
                            Spacer()
                        }
                        SleepDetailView()
                            .environmentObject(dateModel)
                            .environmentObject(tabSelectionModel)
                    }
                    .navigationBarHidden(true)
                } else {
                    List {
                        Section(header: Text("Settings")) {
                            NavigationLink(destination: SettingsView()) {
                                Label("Settings", systemImage: "gearshape.fill")
                            }
                        }
                        Section(header: Text("Done")) {
                            NavigationLink(destination: SleepDetailView().environmentObject(dateModel).environmentObject(tabSelectionModel)) {
                                Label("Sleep", systemImage: "bed.double.fill")
                            }
                            NavigationLink(destination: RecoveryDetailView().environmentObject(dateModel).environmentObject(tabSelectionModel)) {
                                Label("Recovery", systemImage: "heart.fill")
                            }
                            NavigationLink(destination: WeightTrackerView()) {
                                Label("Weight Tracker", systemImage: "scalemass")
                            }
                        }
                        Section(header: Text("Work in Progress")) {
                            NavigationLink(destination: JournalView(tabSelection: $tabSelectionModel.selection)) {
                                Label("Journal", systemImage: "book.closed.fill")
                            }
                            NavigationLink(destination: StepsView()) {
                                Label("Steps", systemImage: "figure.walk")
                            }
                            NavigationLink(destination: SupplementsView()) {
                                Label("Supplements", systemImage: "pills.fill")
                            }
                            NavigationLink(destination: WorkoutLibraryView()) {
                                Label("Workouts", systemImage: "dumbbell.fill")
                            }
                            NavigationLink(destination: WorkoutHistoryView()) {
                                Label("History", systemImage: "clock.arrow.circlepath")
                            }
                            NavigationLink(destination: ProgramsView()) {
                                Label("Programs", systemImage: "list.bullet.rectangle")
                            }
                            NavigationLink(destination: ExerciseLibraryView()) {
                                Label("Exercises", systemImage: "figure.strengthtraining.traditional")
                            }
                            NavigationLink(destination: AnalyticsView()) {
                                Label("Analytics", systemImage: "chart.bar.xaxis")
                            }
                            NavigationLink(destination: InsightsView()) {
                                Label("Insights", systemImage: "lightbulb.fill")
                            }
                        }
                    }
                    .navigationTitle("More")
                    .listStyle(.insetGrouped)
                }
            }
            .tabItem {
                Image(systemName: "ellipsis.circle.fill")
                Text("More")
            }
            .tag(1)
        }
        .accentColor(.blue)
        .preferredColorScheme(colorScheme)
        .onChange(of: tabSelectionModel.selection) { oldValue, newValue in
            if newValue == 0 && oldValue == 0 {
                let today = Calendar.current.startOfDay(for: Date())
                dateModel.selectedDate = today
            }
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
} 
