import SwiftUI
import SwiftData

struct WorkoutLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dataManager: DataManager
    @Query private var programs: [WorkoutProgram]
    @Query private var exercises: [ExerciseDefinition]
    @State private var showingStartWorkoutSheet = false
    @State private var selectedProgram: WorkoutProgram?
    @State private var showingHistory = false
    @State private var selectedExercise: ExerciseDefinition?
    @State private var showingExerciseProgress = false
    @State private var hasSeededData = false
    @State private var activeWorkout: WorkoutSession?
    @State private var showingWorkout = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Quick Start Section
                    ModernCard {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(AppColors.accent)
                            Text("Quick Start")
                                .font(.headline)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        Text("Start a workout immediately or choose from your programs.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        Button(action: { showingStartWorkoutSheet = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Start Workout")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .primaryButton()
                    }
                    
                    // Programs Section
                    if !programs.isEmpty {
                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "list.bullet")
                                        .font(.title2)
                                        .foregroundColor(AppColors.secondary)
                                    Text("Your Programs")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    Spacer()
                                }
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(programs) { program in
                                        Button(action: { selectedProgram = program }) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(program.name)
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.primary)
                                                    // Add description if needed
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding()
                                            .background(Color(.systemGray6))
                                            .cornerRadius(12)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                    }
                    
                    // Exercise Library Section
                    ModernCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "dumbbell.fill")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                                Text("Exercise Library")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            
                            Text("Browse and manage your exercise database.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                            
                            NavigationLink(destination: ExerciseLibraryView()) {
                                HStack {
                                    Image(systemName: "list.bullet")
                                    Text("View All Exercises")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .secondaryButton()
                        }
                    }
                    
                    // Workout History Section
                    ModernCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.title2)
                                    .foregroundColor(.purple)
                                Text("Workout History")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            
                            Text("View your past workouts and track progress.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                            
                            Button(action: { showingHistory = true }) {
                                HStack {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                    Text("View History")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .secondaryButton()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Train")
            .onAppear {
                if !hasSeededData {
                    DataSeeder.seedExerciseLibrary(modelContext: modelContext)
                    DataSeeder.seedSamplePrograms(modelContext: modelContext)
                    DataSeeder.seedSampleWorkoutPrograms(modelContext: modelContext)
                    hasSeededData = true
                }
            }
            .sheet(isPresented: $showingStartWorkoutSheet) {
                StartWorkoutSheet(
                    programs: programs,
                    onStartEmpty: startEmptyWorkout,
                    onStartFromLibrary: startProgramWorkout
                )
            }
            .sheet(item: $selectedProgram) { program in
                ProgramDetailView(program: program)
            }
            .sheet(isPresented: $showingHistory) {
                WorkoutHistoryView()
            }
            .sheet(isPresented: $showingExerciseProgress) {
                if let exercise = selectedExercise {
                    ExerciseProgressView(exercise: exercise)
                }
            }
            .fullScreenCover(isPresented: $showingWorkout) {
                if let workout = activeWorkout {
                    WorkoutView(workout: workout)
                }
            }
            .alert("Save Failed", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text("Unable to save your changes: \(errorMessage)")
            }
        }
    }
    
    private func startEmptyWorkout() {
        do {
            let workout = try dataManager.startWorkout()
            activeWorkout = workout
            showingWorkout = true
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
    
    private func startProgramWorkout(_ program: WorkoutProgram) {
        do {
            let workout = try dataManager.startWorkout(program: program)
            activeWorkout = workout
            showingWorkout = true
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
}

struct StartWorkoutSheet: View {
    let programs: [WorkoutProgram]
    let onStartEmpty: () -> Void
    let onStartFromLibrary: (WorkoutProgram) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProgram: WorkoutProgram?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Quick Start Option
                    ModernCard {
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text("Quick Start")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            
                            Text("Start a free-form workout without a specific program.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                            
                            Button(action: {
                                onStartEmpty()
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Start Empty Workout")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .primaryButton()
                        }
                    }
                    
                    // Program Options
                    if !programs.isEmpty {
                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "list.bullet")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                    Text("Start from Program")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    Spacer()
                                }
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(programs) { program in
                                        Button(action: {
                                            selectedProgram = program
                                        }) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(program.name)
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.primary)
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding()
                                            .background(Color(.systemGray6))
                                            .cornerRadius(12)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Start Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $selectedProgram) { program in
                ProgramDetailView(program: program)
            }
        }
    }
}

struct ProgramDetailView: View {
    let program: WorkoutProgram
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: DataManager
    @State private var showingWorkout = false
    @State private var workout: WorkoutSession?
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Program Info
                    ModernCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(program.name)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    }
                    
                    // Start Button
                    Button(action: startWorkout) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Start \(program.name)")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .primaryButton()
                }
                .padding()
            }
            .navigationTitle("Program Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showingWorkout) {
                if let workout = workout {
                    WorkoutView(workout: workout)
                }
            }
            .alert("Start Workout Failed", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func startWorkout() {
        do {
            let newWorkout = try dataManager.startWorkout(program: program)
            workout = newWorkout
            showingWorkout = true
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
}

struct ProgramHistoryView: View {
    let program: Program
    let onExerciseTap: (ExerciseDefinition) -> Void
    @Query private var allSessions: [WorkoutSession]
    
    var programSessions: [WorkoutSession] {
        allSessions.filter { $0.programName == program.name && $0.isCompleted }
            .sorted(by: { $0.date > $1.date })
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(programSessions, id: \.id) { session in
                    Section(header: Text(session.date, style: .date)) {
                        ForEach(session.completedExercises, id: \.id) { completed in
                            if let ex = completed.exercise {
                                Button(action: { onExerciseTap(ex) }) {
                                    HStack {
                                        Text(ex.name)
                                        Spacer()
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(program.name + " History")
        }
    }
}

struct ExerciseProgressView: View {
    let exercise: ExerciseDefinition
    @Query private var allSets: [WorkoutSet]
    
    var setsForExercise: [WorkoutSet] {
        allSets.filter { $0.completedExercise?.exercise?.id == exercise.id }
            .sorted(by: { $0.date < $1.date })
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text(exercise.name)
                    .font(.title)
                    .fontWeight(.bold)
                if setsForExercise.isEmpty {
                    Text("No history for this exercise.")
                        .foregroundColor(.secondary)
                } else {
                    List(setsForExercise, id: \.id) { set in
                        HStack {
                            Text(set.date, style: .date)
                                .font(.caption)
                            Spacer()
                            Text("\(set.weight, specifier: "%.1f") kg x \(set.reps) reps")
                                .font(.body)
                        }
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Progress")
        }
    }
} 