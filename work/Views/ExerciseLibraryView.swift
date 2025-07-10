//
//  ExerciseLibraryView.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import SwiftUI
import SwiftData
import Charts

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [ExerciseDefinition]
    
    @State private var searchText = ""
    @State private var selectedMuscleGroup: String = "All"
    @State private var selectedEquipment: String = "All"
    @State private var showingAddExercise = false
    @State private var selectedExercise: ExerciseDefinition?
    
    // For selection mode
    let selectionMode: Bool
    let onExerciseSelected: ((ExerciseDefinition) -> Void)?
    
    init(selectionMode: Bool = false, onExerciseSelected: ((ExerciseDefinition) -> Void)? = nil) {
        self.selectionMode = selectionMode
        self.onExerciseSelected = onExerciseSelected
    }
    
    var filteredExercises: [ExerciseDefinition] {
        exercises.filter { exercise in
            let matchesSearch = searchText.isEmpty || 
                exercise.name.localizedCaseInsensitiveContains(searchText) ||
                exercise.primaryMuscleGroup.localizedCaseInsensitiveContains(searchText)
            
            let matchesMuscleGroup = selectedMuscleGroup == "All" || 
                exercise.primaryMuscleGroup == selectedMuscleGroup
            
            let matchesEquipment = selectedEquipment == "All" || 
                exercise.equipment == selectedEquipment
            
            return matchesSearch && matchesMuscleGroup && matchesEquipment
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and filters
                VStack(spacing: 12) {
                    SearchBar(text: $searchText)
                    
                    FilterView(
                        selectedMuscleGroup: $selectedMuscleGroup,
                        selectedEquipment: $selectedEquipment
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Exercise list
                if filteredExercises.isEmpty {
                    EmptyExerciseView()
                } else {
                    ExerciseListView(
                        exercises: filteredExercises,
                        selectionMode: selectionMode,
                        onExerciseSelected: { exercise in
                            if selectionMode {
                                onExerciseSelected?(exercise)
                                dismiss() // Close the sheet after selection
                            }
                        }
                    )
                }
            }
            .navigationTitle("Exercise Library")
            .toolbar {
                if selectionMode {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .secondaryButton()
                        .accessibilityLabel("Cancel")
                    }
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingAddExercise = true }) {
                            Image(systemName: "plus")
                        }
                        .primaryButton()
                        .accessibilityLabel("Add Exercise")
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseView()
            }
            .sheet(item: $selectedExercise) { exercise in
                ExerciseDetailView(exercise: exercise)
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search exercises...", text: $text)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search Exercises")
                .accessibilityIdentifier("searchExercisesField")
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .iconButton(color: AppColors.primary)
                .accessibilityLabel("Clear Search")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppCornerRadius.lg)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

struct FilterView: View {
    @Binding var selectedMuscleGroup: String
    @Binding var selectedEquipment: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Muscle group filter
            Menu {
                Button("All") { selectedMuscleGroup = "All" }
                .secondaryButton()
                .accessibilityLabel("All Muscle Groups")
                ForEach(MuscleGroup.allCases, id: \.self) { muscleGroup in
                    Button(muscleGroup.rawValue) { selectedMuscleGroup = muscleGroup.rawValue }
                    .secondaryButton()
                    .accessibilityLabel(muscleGroup.rawValue)
                }
            } label: {
                HStack {
                    Text(selectedMuscleGroup)
                    Image(systemName: "chevron.down")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemBackground))
                .cornerRadius(AppCornerRadius.md)
            }
            .accessibilityLabel("Primary Muscle Group")
            .accessibilityIdentifier("primaryMuscleGroupPicker")
            
            // Equipment filter
            Menu {
                Button("All") { selectedEquipment = "All" }
                .secondaryButton()
                .accessibilityLabel("All Equipment")
                ForEach(Equipment.allCases, id: \.self) { equipment in
                    Button(equipment.rawValue) { selectedEquipment = equipment.rawValue }
                    .secondaryButton()
                    .accessibilityLabel(equipment.rawValue)
                }
            } label: {
                HStack {
                    Text(selectedEquipment)
                    Image(systemName: "chevron.down")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemBackground))
                .cornerRadius(AppCornerRadius.md)
            }
            .accessibilityLabel("Equipment")
            .accessibilityIdentifier("equipmentPicker")
            
            Spacer()
        }
    }
}

struct EmptyExerciseView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "dumbbell")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No exercises found")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Try adjusting your search or filters")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
}

struct ExerciseListView: View {
    let exercises: [ExerciseDefinition]
    let selectionMode: Bool
    let onExerciseSelected: ((ExerciseDefinition) -> Void)?
    
    @State private var selectedExercise: ExerciseDefinition?
    
    var body: some View {
        List(exercises, id: \.id) { exercise in
            ExerciseRowView(exercise: exercise) {
                if selectionMode {
                    onExerciseSelected?(exercise)
                } else {
                    selectedExercise = exercise
                }
            }
        }
        .sheet(item: $selectedExercise) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
    }
}

struct ExerciseRowView: View {
    @Query private var workoutSets: [WorkoutSet]
    @Query private var workouts: [WorkoutSession]
    let exercise: ExerciseDefinition
    let onTap: () -> Void
    
    var exerciseStats: (totalSets: Int, bestWeight: Double, lastWorkout: Date?) {
        var totalSets = 0
        var bestWeight = 0.0
        var lastWorkout: Date?
        
        for workout in workouts {
            for completedExercise in workout.completedExercises {
                if completedExercise.exercise?.id == exercise.id {
                    let exerciseSets = workoutSets.filter { $0.completedExercise?.id == completedExercise.id }
                    totalSets += exerciseSets.count
                    
                    for set in exerciseSets {
                        if set.weight > bestWeight {
                            bestWeight = set.weight
                        }
                    }
                    
                    if lastWorkout == nil || workout.date > lastWorkout! {
                        lastWorkout = workout.date
                    }
                }
            }
        }
        
        return (totalSets, bestWeight, lastWorkout)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Exercise icon
                Image(systemName: iconForEquipment(exercise.equipment))
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40)
                
                // Exercise details
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(exercise.primaryMuscleGroup)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if exerciseStats.totalSets > 0 {
                        HStack(spacing: 8) {
                            Text("\(exerciseStats.totalSets) sets")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            
                            if exerciseStats.bestWeight > 0 {
                                Text("Best: \(exerciseStats.bestWeight, specifier: "%.1f") kg")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .primaryButton()
        .accessibilityLabel("Select Exercise")
    }
    
    private func iconForEquipment(_ equipment: String) -> String {
        switch equipment {
        case "Barbell":
            return "dumbbell.fill"
        case "Dumbbell":
            return "dumbbell"
        case "Machine":
            return "gearshape.fill"
        case "Cable":
            return "cable.connector"
        case "Bodyweight":
            return "figure.strengthtraining.traditional"
        case "Kettlebell":
            return "dumbbell.fill"
        case "Resistance Band":
            return "bandage"
        case "Smith Machine":
            return "gearshape.fill"
        default:
            return "dumbbell"
        }
    }
}

struct AddExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var instructions = ""
    @State private var primaryMuscleGroup = MuscleGroup.chest.rawValue
    @State private var secondaryMuscleGroups: Set<String> = []
    @State private var equipment = Equipment.barbell.rawValue
    @State private var videoURL = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Exercise Details") {
                    TextField("Exercise name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Exercise Name")
                        .accessibilityIdentifier("exerciseNameField")
                    
                    TextField("Instructions", text: $instructions, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Exercise Instructions")
                        .accessibilityIdentifier("exerciseInstructionsField")
                        .lineLimit(3...6)
                }
                
                Section("Muscle Groups") {
                    Picker("Primary", selection: $primaryMuscleGroup) {
                        ForEach(MuscleGroup.allCases, id: \.self) { muscleGroup in
                            Text(muscleGroup.rawValue).tag(muscleGroup.rawValue)
                        }
                    }
                    .accessibilityLabel("Primary Muscle Group")
                    .accessibilityIdentifier("primaryMuscleGroupPicker")
                    
                    ForEach(MuscleGroup.allCases, id: \.self) { muscleGroup in
                        if muscleGroup.rawValue != primaryMuscleGroup {
                            Toggle(muscleGroup.rawValue, isOn: Binding(
                                get: { secondaryMuscleGroups.contains(muscleGroup.rawValue) },
                                set: { isSelected in
                                    if isSelected {
                                        secondaryMuscleGroups.insert(muscleGroup.rawValue)
                                    } else {
                                        secondaryMuscleGroups.remove(muscleGroup.rawValue)
                                    }
                                }
                            ))
                            .accessibilityLabel(muscleGroup.rawValue)
                            .accessibilityIdentifier("muscleGroupToggle_\(muscleGroup.rawValue)")
                        }
                    }
                }
                
                Section("Equipment") {
                    Picker("Equipment", selection: $equipment) {
                        ForEach(Equipment.allCases, id: \.self) { equipment in
                            Text(equipment.rawValue).tag(equipment.rawValue)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .accessibilityLabel("Equipment")
                    .accessibilityIdentifier("equipmentPicker")
                }
                
                Section("Video URL (Optional)") {
                    TextField("Video URL", text: $videoURL)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Exercise Video URL")
                        .accessibilityIdentifier("exerciseVideoURLField")
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .secondaryButton()
                    .accessibilityLabel("Cancel")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveExercise()
                    }
                    .primaryButton()
                    .accessibilityLabel("Save Exercise")
                }
            }
        }
    }
    
    private func saveExercise() {
        let exercise = ExerciseDefinition(
            name: name,
            instructions: instructions,
            videoURL: videoURL.isEmpty ? nil : videoURL,
            primaryMuscleGroup: primaryMuscleGroup,
            secondaryMuscleGroups: Array(secondaryMuscleGroups),
            equipment: equipment,
            userCreated: true
        )
        
        modelContext.insert(exercise)
        dismiss()
    }
}

struct ExerciseDetailView: View {
    let exercise: ExerciseDefinition
    @Environment(\.dismiss) private var dismiss
    @Query private var allSets: [WorkoutSet]
    @Query private var allWorkouts: [WorkoutSession]
    
    @State private var selectedPR: (date: Date, value: Double)? = nil
    
    var setsForExercise: [WorkoutSet] {
        allSets.filter { $0.completedExercise?.exercise?.name == exercise.name }
            .sorted(by: { $0.date < $1.date })
    }
    
    // Best 1RM per day
    var best1RMPerDay: [(date: Date, value: Double)] {
        let grouped = Dictionary(grouping: setsForExercise) { Calendar.current.startOfDay(for: $0.date) }
        for (date, sets) in grouped {
            print("Group date: \(date), set count: \(sets.count)")
        }
        return grouped.map { (date, sets) in
            let best = sets.map { $0.estimatedOneRepMax }.max() ?? 0
            return (date, best)
        }
        .sorted { $0.date < $1.date }
    }
    
    var prValue: Double {
        best1RMPerDay.map { $0.value }.max() ?? 0
    }
    
    // Precompute chart points for clarity (no limit)
    var chartPoints: [ChartPoint] {
        best1RMPerDay.map { day in
            // Find the set with the best 1RM for this day to get reps
            let setsOnDay = setsForExercise.filter { Calendar.current.isDate($0.date, inSameDayAs: day.date) }
            let bestSet = setsOnDay.max(by: { $0.estimatedOneRepMax < $1.estimatedOneRepMax })
            return ChartPoint(date: day.date, value: day.value, isPR: day.value == prValue, reps: bestSet?.reps ?? 0)
        }
    }
    
    // Calculate y-axis range with padding
    var yAxisRange: ClosedRange<Double>? {
        guard let minValue = chartPoints.map({ $0.value }).min(), let maxValue = chartPoints.map({ $0.value }).max(), minValue != maxValue else {
            return nil
        }
        let padding = (maxValue - minValue) * 0.1
        return (minValue - padding)...(maxValue + padding)
    }
    
    // MARK: - Chart Mark Computed Properties (fixed for ChartContent)
    var areaMarks: some ChartContent {
        ForEach(chartPoints) { point in
            AreaMark(
                x: .value("Date", point.date),
                y: .value("1RM", point.value)
            )
            .foregroundStyle(LinearGradient(
                gradient: Gradient(colors: [AppColors.primary.opacity(0.3), .clear]),
                startPoint: .top,
                endPoint: .bottom
            ))
        }
    }
    var lineMarks: some ChartContent {
        ForEach(chartPoints) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("1RM", point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(AppColors.primary)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }
    var pointMarks: some ChartContent {
        ForEach(chartPoints) { point in
            let symbol = Circle()
            let symbolSize = point.isPR ? 120.0 : 50.0
            let color = point.isPR ? Color.yellow : AppColors.primary
            PointMark(
                x: .value("Date", point.date),
                y: .value("1RM", point.value)
            )
            .symbol(symbol)
            .symbolSize(symbolSize)
            .foregroundStyle(color)
            .annotation(position: .top, alignment: .center, spacing: 2) {
                if point.isPR {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill").foregroundColor(.yellow)
                        Text("PR: \(Int(point.value))kg × \(point.reps) reps")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                    }
                } else {
                    EmptyView()
                }
            }
            .accessibilityLabel(dateFormatter.string(from: point.date))
            .accessibilityValue("\(point.value, specifier: "%.1f") kg")
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(exercise.name)
                            .font(.title)
                            .fontWeight(.bold)
                        Text(exercise.primaryMuscleGroup)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if !exercise.secondaryMuscleGroups.isEmpty {
                            Text("Secondary: \(exercise.secondaryMuscleGroups.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    // Equipment
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.blue)
                        Text(exercise.equipment)
                            .font(.subheadline)
                    }
                    // Instructions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instructions")
                            .font(.headline)
                        Text(exercise.instructions)
                            .font(.body)
                    }
                    // Video placeholder
                    if let videoURL = exercise.videoURL, !videoURL.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Video")
                                .font(.headline)
                            RoundedRectangle(cornerRadius: AppCornerRadius.md)
                                .fill(Color(.systemGray5))
                                .frame(height: 200)
                                .overlay(
                                    VStack {
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.blue)
                                        Text("Video Demo")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                )
                        }
                    }
                    // Performance history with chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Performance History")
                            .font(.headline)
                        if chartPoints.isEmpty {
                            RoundedRectangle(cornerRadius: AppCornerRadius.md)
                                .fill(Color(.systemGray6))
                                .frame(height: 120)
                                .overlay(
                                    VStack {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .font(.system(size: 30))
                                            .foregroundColor(.secondary)
                                        Text("No performance data yet")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                )
                        } else {
                            if let range = yAxisRange {
                                Chart {
                                    areaMarks
                                    lineMarks
                                    pointMarks
                                }
                                .chartYScale(domain: range)
                                .frame(height: 280)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(AppCornerRadius.md)
                            } else {
                                Chart {
                                    areaMarks
                                    lineMarks
                                    pointMarks
                                }
                                .frame(height: 280)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(AppCornerRadius.md)
                            }
                        }
                        // Set history
                        if !setsForExercise.isEmpty {
                            Text("Set History")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.top, 8)
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(setsForExercise, id: \ .id) { set in
                                    let isPRSet = set.estimatedOneRepMax == prValue
                                    HStack {
                                        Text(set.date, style: .date)
                                            .font(.caption)
                                        Spacer()
                                        Text("\(set.weight, specifier: "%.1f") kg x \(set.reps) reps")
                                            .font(.body)
                                            .fontWeight(isPRSet ? .bold : .regular)
                                            .foregroundColor(isPRSet ? .yellow : .primary)
                                        Text("1RM: \(set.estimatedOneRepMax, specifier: "%.1f")")
                                            .font(.caption2)
                                            .foregroundColor(isPRSet ? .yellow : .secondary)
                                        if isPRSet {
                                            Image(systemName: "trophy.fill").foregroundColor(.yellow)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                    .background(isPRSet ? Color.yellow.opacity(0.1) : Color.clear)
                                    .cornerRadius(AppCornerRadius.sm)
                                }
                            }
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(AppCornerRadius.md)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Exercise Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .primaryButton()
                    .accessibilityLabel("Done")
                }
            }
        }
    }
}

private let dateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateStyle = .medium
    return df
}()

struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let isPR: Bool
    let reps: Int
}

#Preview {
    ExerciseLibraryView()
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
