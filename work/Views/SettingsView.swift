//
//  SettingsView.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import SwiftUI
import SwiftData
import Combine
import UniformTypeIdentifiers

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
    @State private var showingClearDataAlert = false
    @State private var showingResetAlert = false
    @State private var showingDatabaseHelp = false
    @State private var showingNuclearResetAlert = false
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @State private var csvImportDelegate: CSVImportDelegate? = nil
    @State private var showingDeleteAllWeightsAlert = false
    @State private var showingNinetyDayInfoAlert = false
    @State private var showingNinetyDayRecoveryInfoAlert = false
    
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
            List {
                Section("Profile") {
                    if let profile = userProfile.first {
                        ProfileRowView(profile: profile, currentWeight: currentWeight) {
                            showingProfileEditor = true
                        }
                    } else {
                        Button("Set Up Profile") {
                            createDefaultProfile()
                        }
                    }
                }
                
                Section("Appearance") {
                    Picker("Appearance", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .accessibilityLabel("Appearance Mode")
                }
                
                Section("Health Data") {
                    Button("Sync Health Data") {
                        syncHealthData()
                    }
                    .foregroundColor(.green)
                    
                    Button("Reset Health Baselines") {
                        resetHealthBaselines()
                    }
                    .foregroundColor(.orange)
                    
                    Button("Re-request HealthKit Permissions") {
                        forceReauthorization()
                    }
                    .foregroundColor(.blue)

                    Button("Print 90-Day Health Summary") {
                        Task {
                            await HealthKitManager.shared.printNinetyDaySummary()
                        }
                    }
                    .foregroundColor(.purple)
                }

                Section("Data") {
                    Button("Export Data") {
                        exportData()
                    }
                    
                    Button("Import Data") {
                        importData()
                    }

                    Button("Delete All Weight Entries", role: .destructive) {
                        showingDeleteAllWeightsAlert = true
                    }
                    
                    Button("Test Database") {
                        testDatabase()
                    }
                    
                    Button("Diagnose Database") {
                        diagnoseDatabase()
                    }
                    
                    Button("Refresh Views") {
                        refreshViews()
                    }
                    
                    Button("Force Reset Database", role: .destructive) {
                        showingResetAlert = true
                    }
                    
                    Button("Clear All Data", role: .destructive) {
                        showingClearDataAlert = true
                    }
                }
                
                Section("Help") {
                    Button("Database Issues?") {
                        showingDatabaseHelp = true
                    }
                    
                    Button("Nuclear Reset", role: .destructive) {
                        showingNuclearResetAlert = true
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    
                    Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingProfileEditor) {
                if let profile = userProfile.first {
                    ProfileEditorView(profile: profile)
                }
            }
            .alert("Clear All Data", isPresented: $showingClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will permanently delete all your data. This action cannot be undone.")
            }
            .alert("Reset Database", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    forceResetDatabase()
                }
            } message: {
                Text("The database is corrupted. The app will exit. Please delete the app from simulator and reinstall to start fresh.")
            }
            .alert("Database Help", isPresented: $showingDatabaseHelp) {
                Button("OK") { }
            } message: {
                Text("If you're experiencing data issues:\n\n1. Try 'Refresh Views' first\n2. Use 'Diagnose Database' to check health\n3. If corrupted, use 'Force Reset Database'\n4. Delete app from simulator and reinstall")
            }
            .alert("Nuclear Reset", isPresented: $showingNuclearResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset Everything", role: .destructive) {
                    nuclearReset()
                }
            } message: {
                Text("This will completely destroy all data and force a fresh start. The app will exit and you must delete it from simulator and reinstall.")
            }
            .alert("Delete All Weight Entries?", isPresented: $showingDeleteAllWeightsAlert) {
                Button("Delete All", role: .destructive) { deleteAllWeightEntries() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all weight entries. This action cannot be undone.")
            }
        }
        .preferredColorScheme(colorScheme)
    }
    
    private func createDefaultProfile() {
        let profile = UserProfile()
        modelContext.insert(profile)
        try? modelContext.save()
        showingProfileEditor = true
    }
    
    private func exportData() {
        // Export weight entries as CSV and present share sheet
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        var csv = "date,weight\n"
        for entry in weightEntries.reversed() { // oldest first
            let dateStr = dateFormatter.string(from: entry.date)
            let weightStr = String(format: "%.2f", entry.weight)
            csv += "\(dateStr),\(weightStr)\n"
        }
        guard let data = csv.data(using: .utf8) else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("weight_entries.csv")
        do {
            try data.write(to: tempURL)
            let av = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                root.present(av, animated: true)
            }
        } catch {
            print("❌ Failed to write CSV: \(error)")
        }
    }
    
    private func importData() {
        // Present document picker for CSV import
        let delegate = CSVImportDelegate(modelContext: modelContext, onImport: {
            refreshViews()
            csvImportDelegate = nil // release after import
        })
        csvImportDelegate = delegate // retain
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.commaSeparatedText])
        picker.allowsMultipleSelection = false
        picker.delegate = delegate
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(picker, animated: true)
        }
    }
    
    private func testDatabase() {
        // Test 1: Create a test weight entry
        let testEntry = WeightEntry(date: Date(), weight: 75.5, notes: "Test entry")
        modelContext.insert(testEntry)
        
        // Test 2: Create a test user profile
        let testProfile = UserProfile(name: "Test User", height: 180)
        modelContext.insert(testProfile)
        
        // Test 3: Save the data
        do {
            try modelContext.save()
        } catch {
            return
        }
        
        // Test 4: Query the data using the same context
        do {
            let weightDescriptor = FetchDescriptor<WeightEntry>()
            let profileDescriptor = FetchDescriptor<UserProfile>()
            
            let _ = try modelContext.fetch(weightDescriptor)
            let _ = try modelContext.fetch(profileDescriptor)
            
            //
        } catch {
            //
        }
    }
    
    private func diagnoseDatabase() {
        // Test each entity type individually to see which ones are accessible
        diagnoseEntity("WeightEntry") {
            let descriptor = FetchDescriptor<WeightEntry>()
            return try modelContext.fetchCount(descriptor)
        }
        
        diagnoseEntity("WorkoutSet") {
            let descriptor = FetchDescriptor<WorkoutSet>()
            return try modelContext.fetchCount(descriptor)
        }
        
        diagnoseEntity("CompletedExercise") {
            let descriptor = FetchDescriptor<CompletedExercise>()
            return try modelContext.fetchCount(descriptor)
        }
        
        diagnoseEntity("WorkoutSession") {
            let descriptor = FetchDescriptor<WorkoutSession>()
            return try modelContext.fetchCount(descriptor)
        }
        
        diagnoseEntity("ProgramExercise") {
            let descriptor = FetchDescriptor<ProgramExercise>()
            return try modelContext.fetchCount(descriptor)
        }
        
        diagnoseEntity("ProgramDay") {
            let descriptor = FetchDescriptor<ProgramDay>()
            return try modelContext.fetchCount(descriptor)
        }
        
        diagnoseEntity("Program") {
            let descriptor = FetchDescriptor<Program>()
            return try modelContext.fetchCount(descriptor)
        }
        
        diagnoseEntity("ExerciseDefinition") {
            let descriptor = FetchDescriptor<ExerciseDefinition>()
            return try modelContext.fetchCount(descriptor)
        }
        
        diagnoseEntity("UserProfile") {
            let descriptor = FetchDescriptor<UserProfile>()
            return try modelContext.fetchCount(descriptor)
        }
        
        // Test basic save/query cycle
        testBasicDatabaseOperations()
    }
    
    private func testBasicDatabaseOperations() {
        // Test 1: Create and immediately query
        let testEntry = WeightEntry(date: Date(), weight: 100.0, notes: "BASIC TEST")
        modelContext.insert(testEntry)
        
        do {
            try modelContext.save()
            
            let descriptor = FetchDescriptor<WeightEntry>()
            let _ = try modelContext.fetch(descriptor)
            
            // Clean up
            modelContext.delete(testEntry)
            try modelContext.save()
            
        } catch {
            //
        }
    }
    
    private func diagnoseEntity(_ name: String, _ operation: () throws -> Int) {
        do {
            let _ = try operation()
            //
        } catch {
            //
        }
    }
    
    private func clearAllData() {
        // Try to clear data safely, but don't crash if entities don't exist
        do {
            // Try to delete each entity type individually
            try? modelContext.delete(model: WeightEntry.self)
            try? modelContext.delete(model: WorkoutSet.self)
            try? modelContext.delete(model: CompletedExercise.self)
            try? modelContext.delete(model: WorkoutSession.self)
            try? modelContext.delete(model: ProgramExercise.self)
            try? modelContext.delete(model: ProgramDay.self)
            try? modelContext.delete(model: Program.self)
            try? modelContext.delete(model: ExerciseDefinition.self)
            try? modelContext.delete(model: UserProfile.self)
            
            try modelContext.save()
        } catch {
            //
        }
    }
    
    private func forceResetDatabase() {
        // Try to completely destroy the database
        do {
            // Delete all entities with error handling
            try? modelContext.delete(model: WeightEntry.self)
            try? modelContext.delete(model: WorkoutSet.self)
            try? modelContext.delete(model: CompletedExercise.self)
            try? modelContext.delete(model: WorkoutSession.self)
            try? modelContext.delete(model: ProgramExercise.self)
            try? modelContext.delete(model: ProgramDay.self)
            try? modelContext.delete(model: Program.self)
            try? modelContext.delete(model: ExerciseDefinition.self)
            try? modelContext.delete(model: UserProfile.self)
            
            try modelContext.save()
        } catch {
            //
        }
        
        // Show a message to the user before exiting
        
        // Show an alert to the user
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Database Reset",
                message: "The database is corrupted and will be reset. The app will exit. Please delete the app from simulator and reinstall to start fresh.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                // Exit after user acknowledges
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    exit(0)
                }
            })
            
            // Present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(alert, animated: true)
            }
        }
    }
    
    private func refreshViews() {
        // Force a save to ensure all pending changes are persisted
        do {
            try modelContext.save()
        } catch {
            //
        }
        
        // Query all data to verify it exists
        do {
            let weightDescriptor = FetchDescriptor<WeightEntry>()
            let profileDescriptor = FetchDescriptor<UserProfile>()
            let workoutDescriptor = FetchDescriptor<WorkoutSession>()
            
            let _ = try modelContext.fetch(weightDescriptor)
            let _ = try modelContext.fetch(profileDescriptor)
            let _ = try modelContext.fetch(workoutDescriptor)
            
            //
        } catch {
            //
        }
    }
    
    private func nuclearReset() {
        // Show detailed instructions
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Nuclear Reset Required",
                message: "The database is completely corrupted.\n\nTo fix this:\n1. Exit this app\n2. In iOS Simulator: Device → Erase All Content and Settings\n3. Reinstall the app\n\nThis will give you a completely fresh start.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Exit App", style: .destructive) { _ in
                exit(0)
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                // Do nothing, stay in app
            })
            
            // Present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(alert, animated: true)
            }
        }
    }

    private func deleteAllWeightEntries() {
        do {
            try? modelContext.delete(model: WeightEntry.self)
            try modelContext.save()
        } catch {
            //
        }
        refreshViews()
    }
    
    private func resetHealthBaselines() {
        // Reset baselines
        DynamicBaselineEngine.shared.resetBaselines()
        
        // Clear cached data
        UserDefaults.standard.removeObject(forKey: "DynamicBaselines")
        
        // Re-request authorization and rebuild baselines
        HealthKitManager.shared.requestAuthorization { success in
            if success {
                DynamicBaselineEngine.shared.updateAndStoreBaselines {
                    //
                }
            } else {
                //
            }
        }
    }
    
    private func syncHealthData() {
        HealthKitManager.shared.requestAuthorization { success in
            if success {
                DynamicBaselineEngine.shared.updateAndStoreBaselines {
                    //
                }
            } else {
                //
            }
        }
    }
    
    private func forceReauthorization() {
        HealthKitManager.shared.forceReauthorization { success in
            if success {
                DynamicBaselineEngine.shared.updateAndStoreBaselines {
                    //
                }
            } else {
                //
            }
        }
    }
}

// MARK: - CSV Import Delegate

class CSVImportDelegate: NSObject, UIDocumentPickerDelegate {
    let modelContext: ModelContext
    let onImport: () -> Void
    init(modelContext: ModelContext, onImport: @escaping () -> Void) {
        self.modelContext = modelContext
        self.onImport = onImport
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        // Start accessing security-scoped resource
        let shouldStop = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStop { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let data = try Data(contentsOf: url)
            if let text = String(data: data, encoding: .utf8) {
                importCSV(text)
            }
        } catch {
            //
        }
    }
    private func importCSV(_ text: String) {
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 0 else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let numberFormatterComma = NumberFormatter()
        numberFormatterComma.decimalSeparator = ","
        let numberFormatterDot = NumberFormatter()
        numberFormatterDot.decimalSeparator = "."

        // Skip header if present
        let dataLines = lines.first?.lowercased().contains("date") == true ? lines.dropFirst() : lines[...]
        for line in dataLines {
            let fields = line.components(separatedBy: ",")
            guard fields.count >= 2 else { continue }
            let dateString = fields[0]
            // Join the rest in case the weight is quoted and contains a comma
            var weightString = fields[1...].joined(separator: ",")
            weightString = weightString.trimmingCharacters(in: .whitespacesAndNewlines)
            // Remove quotes if present
            if weightString.hasPrefix("\"") && weightString.hasSuffix("\"") {
                weightString = String(weightString.dropFirst().dropLast())
            }
            guard let date = dateFormatter.date(from: dateString) else { continue }
            let weight: Double?
            if let w = numberFormatterComma.number(from: weightString)?.doubleValue {
                weight = w
            } else if let w = numberFormatterDot.number(from: weightString)?.doubleValue {
                weight = w
            } else if let w = Double(weightString) {
                weight = w
            } else {
                continue
            }
            let entry = WeightEntry(date: date, weight: weight!)
            modelContext.insert(entry)
        }
        do { try modelContext.save() } catch { //
        }
        onImport()
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
    let profile: UserProfile
    
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
            ProgramExercise.self
        ])
} 