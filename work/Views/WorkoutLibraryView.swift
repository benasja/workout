import SwiftUI
import SwiftData

struct WorkoutLibraryView: View {
    @Query private var programs: [Program]
    @State private var selectedProgram: Program?
    @State private var selectedExercise: ExerciseDefinition?
    @State private var showingHistory = false
    @State private var showingExerciseProgress = false
    
    var body: some View {
        NavigationView {
            List(programs, id: \.id) { program in
                Button(action: {
                    selectedProgram = program
                    showingHistory = true
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(program.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(program.programDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            ForEach(program.days.first?.exercises ?? [], id: \.id) { progEx in
                                if let ex = progEx.exercise {
                                    Text(ex.name)
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workout Library")
            .sheet(isPresented: $showingHistory) {
                if let program = selectedProgram {
                    ProgramHistoryView(program: program, onExerciseTap: { exercise in
                        selectedExercise = exercise
                        showingExerciseProgress = true
                    })
                }
            }
            .sheet(isPresented: $showingExerciseProgress) {
                if let exercise = selectedExercise {
                    ExerciseProgressView(exercise: exercise)
                }
            }
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