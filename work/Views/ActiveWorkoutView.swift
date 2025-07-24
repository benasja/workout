//
//  ActiveWorkoutView.swift
//  work
//
//  Created by Kiro on 7/24/25.
//

import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @EnvironmentObject private var dataManager: DataManager
    @State private var showingWorkoutOptions = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let currentSession = dataManager.currentWorkoutSession {
                    // Active workout in progress
                    WorkoutInProgressView(session: currentSession)
                } else {
                    // No active workout - show start options
                    VStack(spacing: 30) {
                        Image(systemName: "dumbbell")
                            .font(.system(size: 80))
                            .foregroundColor(.accentColor)
                        
                        VStack(spacing: 12) {
                            Text("Ready to Train?")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Start a new workout or choose from your programs")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        VStack(spacing: 16) {
                            Button("Start Quick Workout") {
                                startQuickWorkout()
                            }
                            .buttonStyle(.borderedProminent)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            
                            Button("Choose from Programs") {
                                showingWorkoutOptions = true
                            }
                            .buttonStyle(.bordered)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 40)
                    }
                    .padding()
                }
            }
                    .navigationTitle("Workout")
        .sheet(isPresented: $showingWorkoutOptions) {
            WorkoutOptionsSheet()
        }
        .alert("Workout Failed", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text("Unable to start workout: \(errorMessage)")
        }
            .onAppear {
                dataManager.fetchWorkoutPrograms()
            }
        }
    }
    
    private func startQuickWorkout() {
        do {
            let _ = try dataManager.startWorkout()
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
}

struct WorkoutInProgressView: View {
    let session: WorkoutSession
    @EnvironmentObject private var dataManager: DataManager
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showingEndWorkoutAlert = false
    @State private var errorMessage = ""
    @State private var showingErrorAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Timer header
            VStack(spacing: 8) {
                Text("Workout in Progress")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(formatTime(elapsedTime))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundColor(.accentColor)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Workout info
            VStack(spacing: 12) {
                if let programName = session.programName {
                    Text("Program: \(programName)")
                        .font(.headline)
                } else {
                    Text("Quick Workout")
                        .font(.headline)
                }
                
                HStack(spacing: 30) {
                    VStack {
                        Text("\(session.completedExercises.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Exercises")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(session.sets.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Sets")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        let totalVolume = session.sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
                        Text("\(totalVolume.formatted(.number.precision(.fractionLength(0))))")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("kg Total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 12) {
                NavigationLink(destination: WorkoutView(workout: session)) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Continue Workout")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button("End Workout") {
                    showingEndWorkoutAlert = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
            .padding(.horizontal)
        }
        .padding()
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .alert("End Workout", isPresented: $showingEndWorkoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End Workout", role: .destructive) {
                do {
                    try dataManager.endWorkout()
                } catch {
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
        } message: {
            Text("Are you sure you want to end this workout?")
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime = Date().timeIntervalSince(session.date)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

struct WorkoutOptionsSheet: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage = ""
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if dataManager.workoutPrograms.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.clipboard")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Programs Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Create your first workout program to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        NavigationLink(destination: ProgramsView()) {
                            Text("Create Program")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                } else {
                    List(dataManager.workoutPrograms, id: \.id) { program in
                        Button(action: {
                            do {
                                let _ = try dataManager.startWorkout(program: program)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                                showingErrorAlert = true
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(program.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("\(program.exercises.count) exercises")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "play.fill")
                                    .foregroundColor(.accentColor)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Choose Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: WorkoutSession.self, ExerciseDefinition.self, WorkoutSet.self, CompletedExercise.self)
    let dataManager = DataManager(modelContext: container.mainContext)
    
    return ActiveWorkoutView()
        .environmentObject(dataManager)
        .modelContainer(container)
}