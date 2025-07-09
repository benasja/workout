//
//  AnalyticsView.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import SwiftUI
import SwiftData

struct AnalyticsView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var allWorkouts: [WorkoutSession]
    @Query private var workoutSets: [WorkoutSet]
    @Environment(\.modelContext) private var modelContext
    @State private var refreshTrigger = false
    
    var completedWorkouts: [WorkoutSession] {
        allWorkouts.filter { $0.isCompleted }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Debug info
                    DebugInfoView(workouts: completedWorkouts, workoutSets: workoutSets)
                    
                    // Summary cards
                    SummaryCardsView(workouts: completedWorkouts, workoutSets: workoutSets)
                    
                    // Volume chart
                    VolumeChartView(workouts: completedWorkouts)
                    
                    // Personal records
                    PersonalRecordsView(workouts: completedWorkouts, workoutSets: workoutSets)
                    
                    // Muscle group breakdown
                    MuscleGroupBreakdownView(workouts: completedWorkouts, workoutSets: workoutSets)
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshData) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .primaryButton()
                    .accessibilityLabel("Refresh Analytics")
                }
            }
            .onAppear {
                print("=== ANALYTICS DEBUG ===")
                print("Total workouts: \(allWorkouts.count)")
                print("Completed workouts: \(completedWorkouts.count)")
                print("Total workout sets: \(workoutSets.count)")
                
                for (index, workout) in completedWorkouts.enumerated() {
                    print("Workout \(index + 1): \(workout.completedExercises.count) exercises")
                    for exercise in workout.completedExercises {
                        let exerciseSets = workoutSets.filter { $0.completedExercise?.id == exercise.id }
                        print("  - \(exercise.exercise?.name ?? "Unknown"): \(exerciseSets.count) sets")
                    }
                }
                print("=== END DEBUG ===")
            }
            .onChange(of: refreshTrigger) { _, _ in
                // Force refresh when triggered
            }
        }
    }
    
    private func refreshData() {
        print("=== REFRESHING ANALYTICS ===")
        
        // Force save any pending changes
        do {
            try modelContext.save()
            print("✅ Model context saved")
        } catch {
            print("❌ Model context save failed: \(error)")
        }
        
        // Force UI update
        DispatchQueue.main.async {
            refreshTrigger.toggle()
        }
        
        print("=== END REFRESH ===")
    }
}

struct DebugInfoView: View {
    let workouts: [WorkoutSession]
    let workoutSets: [WorkoutSet]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug Info")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Completed Workouts: \(workouts.count)")
                    .font(.caption)
                Text("Total Workout Sets: \(workoutSets.count)")
                    .font(.caption)
                
                ForEach(workouts, id: \.id) { workout in
                    Text("• \(workout.programName ?? "Workout") (\(workout.completedExercises.count) exercises)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(AppCornerRadius.md)
    }
}

struct SummaryCardsView: View {
    let workouts: [WorkoutSession]
    let workoutSets: [WorkoutSet]
    
    var totalWorkouts: Int { workouts.count }
    var totalVolume: Double { 
        var volume = 0.0
        for workout in workouts {
            for completedExercise in workout.completedExercises {
                let exerciseSets = workoutSets.filter { $0.completedExercise?.id == completedExercise.id }
                volume += exerciseSets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
            }
        }
        return volume
    }
    var averageDuration: TimeInterval {
        let totalDuration = workouts.reduce(0) { $0 + $1.duration }
        return totalWorkouts > 0 ? totalDuration / Double(totalWorkouts) : 0
    }
    var totalSets: Int { 
        var sets = 0
        for workout in workouts {
            for completedExercise in workout.completedExercises {
                let exerciseSets = workoutSets.filter { $0.completedExercise?.id == completedExercise.id }
                sets += exerciseSets.count
            }
        }
        return sets
    }
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            SummaryCard(
                title: "Total Workouts",
                value: "\(totalWorkouts)",
                icon: "dumbbell.fill",
                color: .blue
            )
            
            SummaryCard(
                title: "Total Volume",
                value: "\(Int(totalVolume))",
                icon: "chart.bar.fill",
                color: .green
            )
            
            SummaryCard(
                title: "Avg Duration",
                value: "\(Int(averageDuration / 60))m",
                icon: "clock.fill",
                color: .orange
            )
            
            SummaryCard(
                title: "Total Sets",
                value: "\(totalSets)",
                icon: "list.bullet",
                color: .purple
            )
        }
    }
}

struct VolumeChartView: View {
    let workouts: [WorkoutSession]
    
    var weeklyData: [(week: String, volume: Double, workoutDays: [Date])] {
        let calendar = Calendar.current
        let groupedWorkouts = Dictionary(grouping: workouts) { workout in
            calendar.startOfWeek(for: workout.date)
        }
        
        return groupedWorkouts.map { (week, workouts) in
            let volume = workouts.reduce(0) { $0 + $1.totalVolume }
            let weekString = calendar.dateFormatter.string(from: week)
            let workoutDays = workouts.map { $0.date }
            return (week: weekString, volume: volume, workoutDays: workoutDays)
        }.sorted { $0.week < $1.week }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Volume")
                .font(.headline)
            
            if weeklyData.isEmpty {
                EmptyChartView(message: "No workout data yet")
            } else {
                // Weekly calendar view
                VStack(spacing: 8) {
                    ForEach(weeklyData, id: \.week) { data in
                        WeeklyCalendarRow(week: data.week, volume: data.volume, workoutDays: data.workoutDays)
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(AppCornerRadius.md)
    }
}

struct WeeklyCalendarRow: View {
    let week: String
    let volume: Double
    let workoutDays: [Date]
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(week)
                    .font(.caption)
                    .frame(width: 60, alignment: .leading)
                
                Spacer()
                
                Text("\(Int(volume)) kg")
                    .font(.caption)
                    .frame(width: 50, alignment: .trailing)
            }
            
            // Week days
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { dayIndex in
                    let dayDate = getDayDate(for: dayIndex, in: week)
                    let isWorkoutDay = workoutDays.contains { workoutDate in
                        Calendar.current.isDate(workoutDate, inSameDayAs: dayDate)
                    }
                    
                    VStack(spacing: 2) {
                        Text(getDayLabel(for: dayIndex))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Circle()
                            .fill(isWorkoutDay ? Color.green : Color(.systemGray4))
                            .frame(width: 20, height: 20)
                    }
                }
            }
        }
    }
    
    private func getDayDate(for dayIndex: Int, in weekString: String) -> Date {
        let calendar = Calendar.current
        
        // Parse the week string (e.g., "Jun 24") to get the week start
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        if let weekStartDate = formatter.date(from: weekString) {
            // Add the day offset to get the specific day
            return calendar.date(byAdding: .day, value: dayIndex, to: weekStartDate) ?? Date()
        }
        
        // Fallback: calculate from current date
        let today = Date()
        let weekStart = calendar.startOfWeek(for: today)
        return calendar.date(byAdding: .day, value: dayIndex, to: weekStart) ?? Date()
    }
    
    private func getDayLabel(for dayIndex: Int) -> String {
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        return labels[dayIndex]
    }
}

struct PersonalRecordsView: View {
    let workouts: [WorkoutSession]
    let workoutSets: [WorkoutSet]
    
    var personalRecords: [PersonalRecord] {
        var records: [String: PersonalRecord] = [:]
        
        for workout in workouts {
            for completedExercise in workout.completedExercises {
                guard let exercise = completedExercise.exercise else { continue }
                
                let exerciseSets = workoutSets.filter { $0.completedExercise?.id == completedExercise.id }
                
                for set in exerciseSets {
                    let key = exercise.name
                    let estimated1RM = set.estimatedOneRepMax
                    
                    if let existingRecord = records[key] {
                        if estimated1RM > existingRecord.estimated1RM {
                            records[key] = PersonalRecord(
                                exerciseName: exercise.name,
                                weight: set.weight,
                                reps: set.reps,
                                estimated1RM: estimated1RM,
                                date: workout.date
                            )
                        }
                    } else {
                        records[key] = PersonalRecord(
                            exerciseName: exercise.name,
                            weight: set.weight,
                            reps: set.reps,
                            estimated1RM: estimated1RM,
                            date: workout.date
                        )
                    }
                }
            }
        }
        
        return Array(records.values).sorted { $0.estimated1RM > $1.estimated1RM }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Records")
                .font(.headline)
            
            if personalRecords.isEmpty {
                EmptyChartView(message: "No personal records yet")
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(personalRecords.prefix(5), id: \.exerciseName) { record in
                        PersonalRecordRow(record: record)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(AppCornerRadius.md)
    }
}

struct PersonalRecord: Identifiable {
    let id = UUID()
    let exerciseName: String
    let weight: Double
    let reps: Int
    let estimated1RM: Double
    let date: Date
}

struct PersonalRecordRow: View {
    let record: PersonalRecord
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.exerciseName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(record.weight, specifier: "%.1f") kg × \(record.reps) reps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(record.estimated1RM, specifier: "%.1f")")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Text("Est. 1RM")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StrengthScoreView: View {
    @Query private var workoutSets: [WorkoutSet]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    let workouts: [WorkoutSession]
    let userProfile: UserProfile
    
    var currentWeight: Double {
        weightEntries.first?.weight ?? 0.0
    }
    
    var strengthScore: Double {
        // Calculate strength score based on key lifts
        let keyLifts = ["Bench Press", "Squat", "Deadlift"]
        var totalScore = 0.0
        var liftCount = 0
        
        for lift in keyLifts {
            if let best1RM = getBest1RM(for: lift) {
                let relativeStrength = best1RM / currentWeight
                totalScore += relativeStrength
                liftCount += 1
            }
        }
        
        return liftCount > 0 ? totalScore / Double(liftCount) : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Strength Score")
                .font(.headline)
            
            if currentWeight > 0 {
                VStack(spacing: 8) {
                    Text("\(strengthScore, specifier: "%.2f")")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Bodyweight Relative")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Simple gauge
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color(.systemGray4))
                                .frame(height: 8)
                                .cornerRadius(4)
                            
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: min(CGFloat(strengthScore) * 20, geometry.size.width), height: 8)
                                .cornerRadius(4)
                        }
                    }
                    .frame(height: 8)
                }
            } else {
                EmptyChartView(message: "Add weight entries to see strength score")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(AppCornerRadius.md)
    }
    
    private func getBest1RM(for exerciseName: String) -> Double? {
        var best1RM = 0.0
        
        for workout in workouts {
            for completedExercise in workout.completedExercises {
                guard let exercise = completedExercise.exercise,
                      exercise.name.localizedCaseInsensitiveContains(exerciseName) else { continue }
                
                let exerciseSets = workoutSets.filter { $0.completedExercise?.id == completedExercise.id }
                
                for set in exerciseSets {
                    let estimated1RM = set.estimatedOneRepMax
                    if estimated1RM > best1RM {
                        best1RM = estimated1RM
                    }
                }
            }
        }
        
        return best1RM > 0 ? best1RM : nil
    }
}

struct MuscleBalanceView: View {
    @Query private var workoutSets: [WorkoutSet]
    let workouts: [WorkoutSession]
    
    var muscleGroupVolume: [String: Double] {
        var volumeByMuscleGroup: [String: Double] = [:]
        
        // Get workouts from last 30 days
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentWorkouts = workouts.filter { $0.date >= thirtyDaysAgo }
        
        for workout in recentWorkouts {
            for completedExercise in workout.completedExercises {
                guard let exercise = completedExercise.exercise else { continue }
                
                // Calculate volume from workout sets
                let exerciseSets = workoutSets.filter { $0.completedExercise?.id == completedExercise.id }
                let volume = exerciseSets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
                let muscleGroup = exercise.primaryMuscleGroup
                
                volumeByMuscleGroup[muscleGroup, default: 0] += volume
            }
        }
        
        return volumeByMuscleGroup
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Muscle Balance (30 Days)")
                .font(.headline)
            
            if muscleGroupVolume.isEmpty {
                EmptyChartView(message: "No recent workout data")
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(muscleGroupVolume.sorted { $0.value > $1.value }), id: \.key) { muscleGroup, volume in
                        MuscleGroupRow(muscleGroup: muscleGroup, volume: volume)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(AppCornerRadius.md)
    }
}

struct MuscleGroupRow: View {
    let muscleGroup: String
    let volume: Double
    
    var body: some View {
        HStack {
            Text(muscleGroup)
                .font(.subheadline)
            
            Spacer()
            
            Text("\(Int(volume))")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }
}

struct EmptyChartView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 30))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 100)
    }
}

struct MuscleGroupBreakdownView: View {
    let workouts: [WorkoutSession]
    let workoutSets: [WorkoutSet]
    
    var muscleGroupData: [(muscleGroup: String, volume: Double)] {
        var muscleGroups: [String: Double] = [:]
        
        for workout in workouts {
            for completedExercise in workout.completedExercises {
                if let exercise = completedExercise.exercise {
                    let muscleGroup = exercise.primaryMuscleGroup
                    let exerciseSets = workoutSets.filter { $0.completedExercise?.id == completedExercise.id }
                    let volume = exerciseSets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
                    muscleGroups[muscleGroup, default: 0] += volume
                }
            }
        }
        
        return muscleGroups.map { (muscleGroup: $0.key, volume: $0.value) }
            .sorted { $0.volume > $1.volume }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Muscle Group Breakdown")
                .font(.headline)
            
            if muscleGroupData.isEmpty {
                EmptyChartView(message: "No muscle group data yet")
            } else {
                VStack(spacing: 8) {
                    ForEach(muscleGroupData, id: \.muscleGroup) { data in
                        MuscleGroupRow(muscleGroup: data.muscleGroup, volume: data.volume)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(AppCornerRadius.md)
    }
}

// Calendar extension for week formatting
extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }
}

#Preview {
    AnalyticsView()
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