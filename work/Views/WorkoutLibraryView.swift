import SwiftUI
import SwiftData

struct WorkoutLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var programs: [Program]
    @Query private var exercises: [ExerciseDefinition]
    @State private var showingStartWorkoutSheet = false
    @State private var selectedProgram: Program?
    @State private var showingHistory = false
    @State private var selectedExercise: ExerciseDefinition?
    @State private var showingExerciseProgress = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Quick Start Section
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
                    }
                    
                    // Programs Section
                    if !programs.isEmpty {
                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "list.bullet")
                                        .font(.title2)
                                        .foregroundColor(.green)
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
                                                    Text(program.programDescription)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(2)
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
        }
    }
    
    private func startEmptyWorkout() {
        let workout = WorkoutSession()
        modelContext.insert(workout)
        try? modelContext.save()
        // Navigate to workout view
    }
    
    private func startProgramWorkout(_ program: Program) {
        let workout = WorkoutSession()
        workout.programName = program.name
        modelContext.insert(workout)
        try? modelContext.save()
        // Navigate to workout view
    }
}

struct StartWorkoutSheet: View {
    let programs: [Program]
    let onStartEmpty: () -> Void
    let onStartFromLibrary: (Program) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProgram: Program?
    
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
                                                    Text(program.programDescription)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(2)
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
    let program: Program
    @Environment(\.dismiss) private var dismiss
    @State private var showingWorkout = false
    @State private var workout: WorkoutSession?
    
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
                            
                            Text(program.programDescription)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Label("\(program.weeks) weeks", systemImage: "calendar")
                                Spacer()
                                Label("\(program.days.count) days", systemImage: "list.bullet")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
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
        }
    }
    
    private func startWorkout() {
        let newWorkout = WorkoutSession()
        newWorkout.programName = program.name
        workout = newWorkout
        showingWorkout = true
        dismiss()
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