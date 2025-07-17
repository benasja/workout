//
//  SettingsView.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import SwiftUI
import SwiftData

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    var id: String { rawValue }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfile: [UserProfile]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    
    @State private var showingProfileEditor = false
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @State private var isSyncing = false
    
    var currentWeight: Double {
        weightEntries.first?.weight ?? 0.0
    }
    
    var colorScheme: ColorScheme? {
        let mode = AppearanceMode(rawValue: appearanceMode)
        switch mode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        case .none:
            return nil
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Profile Section
                    ModernCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                Text("Profile")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }
                            
                            if let profile = userProfile.first {
                                ProfileRowView(profile: profile, currentWeight: currentWeight) {
                                    showingProfileEditor = true
                                }
                            } else {
                                Button("Set Up Profile") {
                                    showingProfileEditor = true
                                }
                                .foregroundColor(.blue)
                                .font(.body)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Appearance Section
                    ModernCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "paintbrush.fill")
                                    .foregroundColor(.purple)
                                    .font(.title2)
                                Text("Appearance")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }
                            
                            Picker("Appearance", selection: $appearanceMode) {
                                ForEach(AppearanceMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode.rawValue)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .accessibilityLabel("Appearance Mode")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Health Data Section
                    ModernCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                                    .font(.title2)
                                Text("Health Data")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }
                            
                            Button(action: { syncHealthData() }) {
                                HStack {
                                    if isSyncing {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Syncing...")
                                            .foregroundColor(.secondary)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .foregroundColor(.blue)
                                        Text("Sync with Apple Health")
                                            .foregroundColor(.blue)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            .disabled(isSyncing)
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // About Section
                    ModernCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.title2)
                                Text("About")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }
                            
                            HStack {
                                Text("Version")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("1.0.0")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    Spacer(minLength: 50)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .background(AppColors.background)
            .refreshable {
                await refreshAllData()
            }
            .sheet(isPresented: $showingProfileEditor) {
                ProfileEditorView(profile: userProfile.first ?? createDefaultProfile())
            }
        }
        .preferredColorScheme(colorScheme)
    }
    
    @discardableResult
    private func createDefaultProfile() -> UserProfile {
        let profile = UserProfile()
        modelContext.insert(profile)
        try? modelContext.save()
        return profile
    }
    
    private func syncHealthData() {
        guard !isSyncing else { return }
        
        isSyncing = true
        
        HealthKitManager.shared.requestAuthorization { success in
            DispatchQueue.main.async {
                if success {
                    // Sync completed
                    print("✅ Health data sync completed")
                } else {
                    print("❌ Health data sync failed")
                }
                self.isSyncing = false
            }
        }
    }
    
    private func refreshAllData() async {
        // Refresh all data sources
        try? modelContext.save()
        
        // Trigger a sync with HealthKit
        await MainActor.run {
            syncHealthData()
        }
    }
}

struct ProfileRowView: View {
    let profile: UserProfile
    let currentWeight: Double
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name.isEmpty ? "Set Name" : profile.name)
                        .font(.subheadline)
                        .foregroundColor(profile.name.isEmpty ? .secondary : .primary)
                    
                    if currentWeight > 0 {
                        Text("\(String(format: "%.1f", currentWeight)) \(profile.unit.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Set bodyweight")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var profile: UserProfile
    
    @State private var name: String = ""
    @State private var height: Double = 0
    
    var body: some View {
        NavigationView {
            Form {
                Section("Personal Information") {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("User Name")
                        .accessibilityIdentifier("userNameField")
                    
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("0", value: $height, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("User Height")
                            .accessibilityIdentifier("userHeightField")
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("cm")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("About Weight Tracking") {
                    Text("Your weight is automatically imported from the Weight Tracker. Add weight entries in the Weight tab to see your current weight here and in analytics.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                }
            }
            .onAppear {
                name = profile.name
                height = profile.height
            }
        }
    }
    
    private func saveProfile() {
        profile.name = name
        profile.height = height
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    SettingsView()
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