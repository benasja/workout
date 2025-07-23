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
    @State private var showingHealthKitAlert = false
    @State private var healthKitAuthorized = false
    
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
            // Today Tab - Main Performance Dashboard
            NavigationStack {
                PerformanceView()
                    .environmentObject(dateModel)
                    .environmentObject(tabSelectionModel)
            }
            .tabItem {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("Today")
            }
            .tag(0)
            
            // Recovery Tab
            NavigationStack {
                RecoveryDetailView()
                    .environmentObject(dateModel)
                    .environmentObject(tabSelectionModel)
            }
            .tabItem {
                Image(systemName: "heart.fill")
                Text("Recovery")
            }
            .tag(1)
            
            // Sleep Tab
            NavigationStack {
                SleepDetailView()
                    .environmentObject(dateModel)
                    .environmentObject(tabSelectionModel)
            }
            .tabItem {
                Image(systemName: "bed.double.fill")
                Text("Sleep")
            }
            .tag(2)
            
            // Environment Tab
            NavigationStack {
                EnvironmentView()
                    .environmentObject(dateModel)
                    .environmentObject(tabSelectionModel)
            }
            .tabItem {
                Image(systemName: "leaf.fill")
                Text("Environment")
            }
            .tag(3)
            
            // More Tab
            NavigationStack {
                MoreView()
                    .environmentObject(dateModel)
                    .environmentObject(tabSelectionModel)
            }
            .tabItem {
                Image(systemName: "ellipsis.circle.fill")
                Text("More")
            }
            .tag(5)
        }
        .accentColor(AppColors.primary)
        .preferredColorScheme(colorScheme)
        .onAppear {
            checkHealthKitAuthorization()
            
            // Sync latest sleep data to server on app launch
            Task {
                await HealthKitManager.shared.checkAndSyncSleepDataIfNeeded()
            }
        }
        .alert("HealthKit Required", isPresented: $showingHealthKitAlert) {
            Button("Grant Access") {
                requestHealthKitAccess()
            }
            Button("Skip", role: .cancel) { }
        } message: {
            Text("This app requires HealthKit access to provide personalized health insights. Please grant access to continue.")
        }
        .onChange(of: tabSelectionModel.selection) { oldValue, newValue in
            if newValue == 0 && oldValue == 0 {
                let today = Calendar.current.startOfDay(for: Date())
                dateModel.selectedDate = today
            }
        }
    }
    
    private func checkHealthKitAuthorization() {
        healthKitAuthorized = HealthKitManager.shared.checkAuthorizationStatus()
        if !healthKitAuthorized {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showingHealthKitAlert = true
            }
        }
    }
    
    private func requestHealthKitAccess() {
        HealthKitManager.shared.requestAuthorization { success in
            DispatchQueue.main.async {
                healthKitAuthorized = success
                if success {
                    // Initialize baselines after authorization
                    DynamicBaselineEngine.shared.updateAndStoreBaselines {
                        print("✅ Baselines initialized")
                    }
                }
            }
        }
    }
}

// Separate More view for better organization
struct MoreView: View {
    @EnvironmentObject var dateModel: PerformanceDateModel
    @EnvironmentObject var tabSelectionModel: TabSelectionModel
    
    var body: some View {
        List {
            Section("Health & Wellness") {
                NavigationLink(destination: WeightTrackerView()) {
                    Label("Weight Tracker", systemImage: "scalemass")
                        .foregroundColor(.primary)
                }
                
                NavigationLink(destination: JournalView()) {
                    Label("Journal", systemImage: "book.closed.fill")
                        .foregroundColor(.primary)
                }
                
                NavigationLink(destination: StepsView()) {
                    Label("Steps", systemImage: "figure.walk")
                        .foregroundColor(.primary)
                }
                
                NavigationLink(destination: SupplementsView()) {
                    Label("Supplements", systemImage: "pills.fill")
                        .foregroundColor(.primary)
                }
                
                NavigationLink(destination: HydrationView()) {
                    Label("Hydration", systemImage: "drop.fill")
                        .foregroundColor(.primary)
                }
            }
            
            Section("Fitness") {
                NavigationLink(destination: WorkoutLibraryView()) {
                    Label("Train", systemImage: "dumbbell.fill")
                        .foregroundColor(.primary)
                }
                NavigationLink(destination: WorkoutHistoryView()) {
                    Label("Workout History", systemImage: "clock.arrow.circlepath")
                        .foregroundColor(.primary)
                }
                NavigationLink(destination: ProgramsView()) {
                    Label("Programs", systemImage: "list.bullet.rectangle")
                        .foregroundColor(.primary)
                }
                NavigationLink(destination: ExerciseLibraryView()) {
                    Label("Exercise Library", systemImage: "figure.strengthtraining.traditional")
                        .foregroundColor(.primary)
                }
            }
            
            Section("Analytics") {
                NavigationLink(destination: SleepLabView()) {
                    Label("Sleep Lab", systemImage: "moon.stars")
                        .foregroundColor(.primary)
                }
            }
            
            Section("Settings") {
                NavigationLink(destination: SettingsView()) {
                    Label("Settings", systemImage: "gearshape.fill")
                        .foregroundColor(.primary)
                }
            }
        }
        .navigationTitle("More")
        .listStyle(.insetGrouped)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
} 
