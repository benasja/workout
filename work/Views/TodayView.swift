//
//  TodayView.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [ExerciseDefinition]
    @Query private var activeProgram: [Program]
    @Query private var userProfile: [UserProfile]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    @Query(sort: \DailyJournal.date, order: .reverse) private var journals: [DailyJournal]
    
    @State private var currentWorkout: WorkoutSession?
    @State private var showingWorkoutView = false
    @State private var showingProfileEditor = false
    @State private var showingStartWorkoutSheet = false
    @State private var timeOfDay: TimeOfDay = .morning
    
    var lastWeight: Double? {
        weightEntries.first?.weight
    }
    
    var todayJournal: DailyJournal? {
        journals.first { Calendar.current.isDate($0.date, inSameDayAs: Date()) }
    }
    
    enum TimeOfDay: String, CaseIterable {
        case morning = "morning"
        case midday = "midday"
        case evening = "evening"
        
        var greeting: String {
            switch self {
            case .morning: return "Good morning"
            case .midday: return "Keep up the momentum"
            case .evening: return "Time to wind down"
            }
        }
        
        var subtitle: String {
            switch self {
            case .morning: return "Here's your readiness for today."
            case .midday: return "Track your activity and fuel your day."
            case .evening: return "Prepare for a restorative night."
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Time-aware greeting
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(timeOfDay.greeting), \(userProfile.first?.name ?? "there")")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text(timeOfDay.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Time-specific content
                    switch timeOfDay {
                    case .morning:
                        MorningView(todayJournal: todayJournal)
                    case .midday:
                        MiddayView(weightEntries: weightEntries)
                    case .evening:
                        EveningView(todayJournal: todayJournal)
                    }
                    
                    // Common elements
                    CommonElementsView(
                        showingStartWorkoutSheet: $showingStartWorkoutSheet,
                        currentWorkout: $currentWorkout,
                        showingWorkoutView: $showingWorkoutView
                    )
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
            }
            .background(AppColors.background)
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingWorkoutView) {
                if let workout = currentWorkout {
                    WorkoutView(workout: workout)
                }
            }
            .sheet(isPresented: $showingProfileEditor) {
                if let profile = userProfile.first {
                    ProfileEditorView(profile: profile)
                }
            }
            .onAppear {
                updateTimeOfDay()
                seedDataIfNeeded()
            }
        }
    }
    
    private func updateTimeOfDay() {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 5 && hour < 12 {
            timeOfDay = .morning
        } else if hour >= 12 && hour < 18 {
            timeOfDay = .midday
        } else {
            timeOfDay = .evening
        }
    }
    
    private func seedDataIfNeeded() {
        if exercises.isEmpty {
            DataSeeder.seedExerciseLibrary(modelContext: modelContext)
        }
        if activeProgram.isEmpty {
            DataSeeder.seedSamplePrograms(modelContext: modelContext)
        }
        // Always seed demo push/pull/legs if not present
        if activeProgram.filter({ $0.name == "Push Day" || $0.name == "Pull Day" || $0.name == "Legs Day" }).isEmpty {
            DataSeeder.seedDemoPushPullLegs(modelContext: modelContext)
        }
    }
    
    private func startEmptyWorkout() {
        let workout = WorkoutSession()
        modelContext.insert(workout)
        try? modelContext.save()
        currentWorkout = workout
        showingWorkoutView = true
        showingStartWorkoutSheet = false
    }
    
    private func startProgramWorkout(_ program: Program) {
        let workout = WorkoutSession()
        workout.programName = program.name
        modelContext.insert(workout)
        try? modelContext.save()
        currentWorkout = workout
        showingWorkoutView = true
        showingStartWorkoutSheet = false
    }
}

// MARK: - Time-Specific Views

struct MorningView: View {
    let todayJournal: DailyJournal?
    
    var body: some View {
        VStack(spacing: 16) {
            // Recovery Card (if we have health data)
            if let journal = todayJournal, let recoveryScore = journal.recoveryScore {
                RecoveryCard(recoveryScore: recoveryScore, hrv: journal.hrv, rhr: journal.rhr)
            }
            
            // Sleep Card (if we have sleep data)
            if let journal = todayJournal, let sleepScore = journal.sleepScore {
                SleepCard(sleepScore: sleepScore, duration: journal.sleepDuration)
            }
            
            // Quick Journal Entry
            if todayJournal == nil {
                QuickJournalCard {
                    // This would open the journal entry sheet
                    // For now, we'll leave it empty since we don't have the sheet binding here
                }
            }
        }
    }
}

struct MiddayView: View {
    let weightEntries: [WeightEntry]
    
    var body: some View {
        VStack(spacing: 16) {
            // Today's Weight
            WeightCard(weightEntries: weightEntries)
            
            // Daily Strain (placeholder for now)
            StrainCard()
            
            // Nutrition Summary (placeholder for now)
            NutritionSummaryCard()
        }
    }
}

struct EveningView: View {
    let todayJournal: DailyJournal?
    
    var body: some View {
        VStack(spacing: 16) {
            // Sleep Debt Card
            SleepDebtCard(todayJournal: todayJournal)
            
            // Daily Strain
            StrainCard()
            
            // Mindfulness Card
            MindfulnessCard()
            
            // Wind Down Suggestions
            WindDownCard()
        }
    }
}

struct CommonElementsView: View {
    @Binding var showingStartWorkoutSheet: Bool
    @Binding var currentWorkout: WorkoutSession?
    @Binding var showingWorkoutView: Bool
    @Environment(\.modelContext) private var modelContext
    @Query private var activeProgram: [Program]
    
    var body: some View {
        VStack(spacing: 16) {
            // Start Workout Button
            Button(action: { showingStartWorkoutSheet = true }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                    Text("Start a Workout")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
            }
            .primaryButton()
            .accessibilityLabel("Start a Workout")
            .sheet(isPresented: $showingStartWorkoutSheet) {
                StartWorkoutSheet(
                    programs: activeProgram,
                    onStartEmpty: startEmptyWorkout,
                    onStartFromLibrary: startProgramWorkout
                )
            }
        }
    }
    
    private func startEmptyWorkout() {
        let workout = WorkoutSession()
        modelContext.insert(workout)
        try? modelContext.save()
        currentWorkout = workout
        showingWorkoutView = true
        showingStartWorkoutSheet = false
    }
    
    private func startProgramWorkout(_ program: Program) {
        let workout = WorkoutSession()
        workout.programName = program.name
        modelContext.insert(workout)
        try? modelContext.save()
        currentWorkout = workout
        showingWorkoutView = true
        showingStartWorkoutSheet = false
    }
}

// MARK: - Card Components

struct RecoveryCard: View {
    let recoveryScore: Int
    let hrv: Double?
    let rhr: Double?
    
    private func getRecoveryColor(_ score: Int) -> Color {
        if score > 66 { return .green }
        if score > 33 { return .orange }
        return .red
    }
    
    var body: some View {
        ModernCard {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("Recovery")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    Text("\(recoveryScore)%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(getRecoveryColor(recoveryScore))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if let hrv = hrv {
                        Text("HRV: \(String(format: "%.0f", hrv)) ms")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let rhr = rhr {
                        Text("RHR: \(String(format: "%.0f", rhr)) bpm")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Text("Based on your recovery, an optimal strain for today is between 12-16.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }
}

struct SleepCard: View {
    let sleepScore: Int
    let duration: TimeInterval?
    
    var body: some View {
        ModernCard {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bed.double.fill")
                            .foregroundColor(.blue)
                        Text("Sleep Performance")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    Text("\(sleepScore)%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                }
                Spacer()
                if let duration = duration {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Total: \(String(format: "%.1f", duration/3600)) hrs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct WeightCard: View {
    let weightEntries: [WeightEntry]
    
    var lastWeight: Double? {
        weightEntries.first?.weight
    }
    
    var body: some View {
        ModernCard {
            HStack {
                Image(systemName: "scalemass")
                    .font(.title2)
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Weight")
                        .font(.headline)
                        .fontWeight(.bold)
                    if let weight = lastWeight {
                        Text("\(String(format: "%.1f", weight)) kg")
                            .font(.title2)
                            .fontWeight(.bold)
                    } else {
                        Text("No entry")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
        }
    }
}

struct StrainCard: View {
    var body: some View {
        ModernCard {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("Daily Strain")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    Text("0.0")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("/ 12-16")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress bar
            ProgressView(value: 0.0, total: 16.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                .padding(.top, 8)
        }
    }
}

struct NutritionSummaryCard: View {
    var body: some View {
        ModernCard {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "apple.logo")
                            .foregroundColor(.green)
                        Text("Nutrition")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    Text("0")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("Calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Protein: 0g")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Carbs: 0g")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Fat: 0g")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct SleepDebtCard: View {
    let todayJournal: DailyJournal?
    
    var sleepDebt: Double {
        guard let journal = todayJournal, let duration = journal.sleepDuration else { return 0.0 }
        return max(0, (8.0 - (duration/3600)))
    }
    
    var body: some View {
        ModernCard {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.purple)
                        Text("Sleep Debt")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    Text("\(String(format: "%.1f", sleepDebt))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.purple)
                    Text("hours")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Aim for at least \(String(format: "%.1f", 8.0 + sleepDebt)) hours of sleep tonight to fully recover.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Consider a guided meditation to help you wind down.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
    }
}

struct WindDownCard: View {
    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "moon.stars.fill")
                        .foregroundColor(.purple)
                    Text("Wind Down")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("• Avoid screens 1 hour before bed")
                    Text("• Practice deep breathing")
                    Text("• Keep your bedroom cool and dark")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }
}

struct MindfulnessCard: View {
    @State private var stressScore = Int.random(in: 50...80)
    @State private var inSession = false
    @State private var sessionResult: (before: Int, after: Int, reduction: Int)?
    
    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundColor(.purple)
                    Text("Stress Level")
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(stressScore)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(stressScore > 60 ? .red : stressScore > 35 ? .orange : .green)
                }
                
                if let result = sessionResult {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Session Complete!")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        
                        Text("Stress reduced by \(result.reduction) points")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if stressScore > 45 {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Elevated Stress")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                        
                        Text("Consider a quick breathing exercise")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: startBreathingSession) {
                    HStack {
                        Image(systemName: "lungs.fill")
                        Text("3-Minute Breathing")
                    }
                    .frame(maxWidth: .infinity)
                }
                .secondaryButton()
            }
        }
        .fullScreenCover(isPresented: $inSession) {
            BreathingSessionView(onComplete: endBreathingSession)
        }
    }
    
    private func startBreathingSession() {
        inSession = true
    }
    
    private func endBreathingSession() {
        let newStressScore = max(10, stressScore - Int.random(in: 15...35))
        sessionResult = (before: stressScore, after: newStressScore, reduction: stressScore - newStressScore)
        stressScore = newStressScore
        inSession = false
    }
}

struct BreathingSessionView: View {
    let onComplete: () -> Void
    @State private var instruction = "Get ready..."
    @State private var progress: Double = 0
    @Environment(\.dismiss) private var dismiss
    
    private let totalDuration: TimeInterval = 180 // 3 minutes
    private let sequence = ["Breathe In (4s)", "Hold (4s)", "Breathe Out (4s)", "Hold (4s)"]
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Breathing Circle
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 8)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: progress / 100)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text(instruction)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                }
            }
            
            Text("Follow the instructions. Relax your body.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Button("End Session") {
                dismiss()
            }
            .secondaryButton()
        }
        .padding()
        .onAppear {
            startSession()
        }
    }
    
    private func startSession() {
        var sequenceIndex = 0
        var elapsedTime: TimeInterval = 0
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            elapsedTime += 1
            self.progress = (elapsedTime / self.totalDuration) * 100
            
            if Int(elapsedTime) % 4 == 1 {
                self.instruction = self.sequence[sequenceIndex % 4]
                sequenceIndex += 1
            }
            
            if elapsedTime >= self.totalDuration {
                timer.invalidate()
                self.onComplete()
                self.dismiss()
            }
        }
    }
}


struct StartWorkoutSheet: View {
    let programs: [Program]
    let onStartEmpty: () -> Void
    let onStartFromLibrary: (Program) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.xl) {
                Text("Start a Workout")
                    .font(AppTypography.title2)
                    .padding(.top, AppSpacing.xl)
                if programs.isEmpty {
                    Text("No programs available. Please create a program in the Programs tab.")
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    List(programs, id: \.id) { program in
                        Button(action: {
                            onStartFromLibrary(program)
                        }) {
                            VStack(alignment: .leading) {
                                Text(program.name)
                                    .font(AppTypography.title3)
                                Text(program.programDescription)
                                    .font(AppTypography.body)
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .frame(maxHeight: 250)
                }
                Button(action: onStartEmpty) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Start Empty Workout")
                    }
                    .frame(maxWidth: .infinity)
                }
                .secondaryButton()
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    TodayView()
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
