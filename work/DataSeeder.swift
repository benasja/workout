//
//  DataSeeder.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import Foundation
import SwiftData

class DataSeeder {
    static func seedExerciseLibrary(modelContext: ModelContext) {
        // Check if exercises already exist
        let descriptor = FetchDescriptor<ExerciseDefinition>()
        let existingExercises = try? modelContext.fetch(descriptor)
        
        if let existingExercises = existingExercises, !existingExercises.isEmpty {
            return // Already seeded
        }
        
        let exercises = [
            // Chest Exercises
            ExerciseDefinition(
                name: "Bench Press",
                instructions: "Lie on a flat bench with your feet flat on the ground. Grip the barbell slightly wider than shoulder width. Lower the bar to your chest, then press it back up to the starting position.",
                primaryMuscleGroup: "Chest",
                secondaryMuscleGroups: ["Triceps", "Shoulders"],
                equipment: "Barbell"
            ),
            ExerciseDefinition(
                name: "Incline Bench Press",
                instructions: "Lie on an inclined bench (30-45 degrees). Grip the barbell and perform the same pressing motion as flat bench press.",
                primaryMuscleGroup: "Chest",
                secondaryMuscleGroups: ["Triceps", "Shoulders"],
                equipment: "Barbell"
            ),
            ExerciseDefinition(
                name: "Dumbbell Flyes",
                instructions: "Lie on a flat bench with dumbbells held above your chest. Lower the weights in an arc motion, keeping a slight bend in your elbows.",
                primaryMuscleGroup: "Chest",
                secondaryMuscleGroups: ["Shoulders"],
                equipment: "Dumbbell"
            ),
            ExerciseDefinition(
                name: "Push-Ups",
                instructions: "Start in a plank position with hands slightly wider than shoulders. Lower your body until your chest nearly touches the ground, then push back up.",
                primaryMuscleGroup: "Chest",
                secondaryMuscleGroups: ["Triceps", "Shoulders", "Core"],
                equipment: "Bodyweight"
            ),
            
            // Back Exercises
            ExerciseDefinition(
                name: "Deadlift",
                instructions: "Stand with feet hip-width apart, barbell on the ground. Bend at hips and knees to grip the bar. Keep your back straight and lift the bar by extending your hips and knees.",
                primaryMuscleGroup: "Back",
                secondaryMuscleGroups: ["Legs", "Core"],
                equipment: "Barbell"
            ),
            ExerciseDefinition(
                name: "Pull-Ups",
                instructions: "Hang from a pull-up bar with hands slightly wider than shoulders. Pull your body up until your chin is above the bar, then lower back down.",
                primaryMuscleGroup: "Back",
                secondaryMuscleGroups: ["Biceps", "Shoulders"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Barbell Rows",
                instructions: "Bend at the waist with a barbell in front of you. Pull the bar up to your lower chest, keeping your elbows close to your body.",
                primaryMuscleGroup: "Back",
                secondaryMuscleGroups: ["Biceps"],
                equipment: "Barbell"
            ),
            ExerciseDefinition(
                name: "Lat Pulldowns",
                instructions: "Sit at a lat pulldown machine. Grip the bar and pull it down to your upper chest, keeping your chest up and shoulders back.",
                primaryMuscleGroup: "Back",
                secondaryMuscleGroups: ["Biceps"],
                equipment: "Machine"
            ),
            
            // Shoulder Exercises
            ExerciseDefinition(
                name: "Overhead Press",
                instructions: "Stand with barbell at shoulder level. Press the bar overhead while keeping your core tight and avoiding excessive back arch.",
                primaryMuscleGroup: "Shoulders",
                secondaryMuscleGroups: ["Triceps"],
                equipment: "Barbell"
            ),
            ExerciseDefinition(
                name: "Dumbbell Lateral Raises",
                instructions: "Stand with dumbbells at your sides. Raise the weights out to the sides until they reach shoulder level, then lower back down.",
                primaryMuscleGroup: "Shoulders",
                secondaryMuscleGroups: [],
                equipment: "Dumbbell"
            ),
            ExerciseDefinition(
                name: "Face Pulls",
                instructions: "Attach a rope to a cable machine at face level. Pull the rope toward your face, separating your hands as you pull.",
                primaryMuscleGroup: "Shoulders",
                secondaryMuscleGroups: ["Back"],
                equipment: "Cable"
            ),
            
            // Biceps Exercises
            ExerciseDefinition(
                name: "Barbell Curls",
                instructions: "Stand with a barbell in front of you. Curl the bar up toward your shoulders, keeping your elbows at your sides.",
                primaryMuscleGroup: "Biceps",
                secondaryMuscleGroups: ["Forearms"],
                equipment: "Barbell"
            ),
            ExerciseDefinition(
                name: "Dumbbell Hammer Curls",
                instructions: "Hold dumbbells with palms facing each other. Curl the weights up while maintaining the neutral grip position.",
                primaryMuscleGroup: "Biceps",
                secondaryMuscleGroups: ["Forearms"],
                equipment: "Dumbbell"
            ),
            ExerciseDefinition(
                name: "Preacher Curls",
                instructions: "Sit at a preacher curl bench. Rest your arms on the pad and curl the weight up, focusing on the biceps contraction.",
                primaryMuscleGroup: "Biceps",
                secondaryMuscleGroups: ["Forearms"],
                equipment: "Machine"
            ),
            
            // Triceps Exercises
            ExerciseDefinition(
                name: "Tricep Dips",
                instructions: "Support yourself on parallel bars. Lower your body by bending your elbows, then push back up to the starting position.",
                primaryMuscleGroup: "Triceps",
                secondaryMuscleGroups: ["Chest", "Shoulders"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Skull Crushers",
                instructions: "Lie on a bench with a barbell or dumbbells. Lower the weight behind your head, then extend your arms to press the weight back up.",
                primaryMuscleGroup: "Triceps",
                secondaryMuscleGroups: [],
                equipment: "Barbell"
            ),
            ExerciseDefinition(
                name: "Cable Tricep Extensions",
                instructions: "Attach a rope to a high cable. Pull the rope down and extend your arms, keeping your elbows at your sides.",
                primaryMuscleGroup: "Triceps",
                secondaryMuscleGroups: [],
                equipment: "Cable"
            ),
            
            // Leg Exercises
            ExerciseDefinition(
                name: "Squat",
                instructions: "Stand with feet shoulder-width apart, barbell on your upper back. Squat down by bending your knees and hips, keeping your chest up.",
                primaryMuscleGroup: "Legs",
                secondaryMuscleGroups: ["Core"],
                equipment: "Barbell"
            ),
            ExerciseDefinition(
                name: "Romanian Deadlift",
                instructions: "Hold a barbell in front of your thighs. Hinge at your hips to lower the bar down your legs, keeping your back straight.",
                primaryMuscleGroup: "Legs",
                secondaryMuscleGroups: ["Back", "Core"],
                equipment: "Barbell"
            ),
            ExerciseDefinition(
                name: "Leg Press",
                instructions: "Sit in a leg press machine. Place your feet on the platform and press the weight away by extending your knees and hips.",
                primaryMuscleGroup: "Legs",
                secondaryMuscleGroups: [],
                equipment: "Machine"
            ),
            ExerciseDefinition(
                name: "Lunges",
                instructions: "Step forward with one leg and lower your body until both knees are bent at 90 degrees. Push back to the starting position.",
                primaryMuscleGroup: "Legs",
                secondaryMuscleGroups: ["Core"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Calf Raises",
                instructions: "Stand on the edge of a step or platform. Raise your heels up as high as possible, then lower them below the step level.",
                primaryMuscleGroup: "Calves",
                secondaryMuscleGroups: [],
                equipment: "Bodyweight"
            ),
            
            // Core Exercises
            ExerciseDefinition(
                name: "Plank",
                instructions: "Hold a push-up position with your body in a straight line from head to heels. Keep your core tight and breathe steadily.",
                primaryMuscleGroup: "Core",
                secondaryMuscleGroups: ["Shoulders"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Crunches",
                instructions: "Lie on your back with knees bent. Lift your shoulders off the ground by contracting your abs, then lower back down.",
                primaryMuscleGroup: "Core",
                secondaryMuscleGroups: [],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Russian Twists",
                instructions: "Sit on the ground with knees bent and feet off the floor. Hold a weight and rotate your torso from side to side.",
                primaryMuscleGroup: "Core",
                secondaryMuscleGroups: [],
                equipment: "Dumbbell"
            ),
            
            // Additional Compound Movements
            ExerciseDefinition(
                name: "Clean and Press",
                instructions: "Start with barbell on the ground. Explosively pull the bar up and catch it at shoulder level, then press it overhead.",
                primaryMuscleGroup: "Shoulders",
                secondaryMuscleGroups: ["Legs", "Back"],
                equipment: "Barbell"
            ),
            ExerciseDefinition(
                name: "Kettlebell Swings",
                instructions: "Stand with feet shoulder-width apart, kettlebell between your legs. Swing the kettlebell forward and up using hip power.",
                primaryMuscleGroup: "Legs",
                secondaryMuscleGroups: ["Core", "Shoulders"],
                equipment: "Kettlebell"
            ),
            ExerciseDefinition(
                name: "Burpees",
                instructions: "Start standing, drop into a squat position, kick feet back into a plank, do a push-up, jump feet back to squat, and jump up.",
                primaryMuscleGroup: "Core",
                secondaryMuscleGroups: ["Legs", "Chest"],
                equipment: "Bodyweight"
            )
        ]
        
        for exercise in exercises {
            modelContext.insert(exercise)
        }
        
        try? modelContext.save()
    }
    
    static func seedSamplePrograms(modelContext: ModelContext) {
        // Check if programs already exist
        let descriptor = FetchDescriptor<Program>()
        let existingPrograms = try? modelContext.fetch(descriptor)
        
        if let existingPrograms = existingPrograms, !existingPrograms.isEmpty {
            return // Already seeded
        }
        
        // Get exercises for the program
        let exerciseDescriptor = FetchDescriptor<ExerciseDefinition>()
        let exercises = try? modelContext.fetch(exerciseDescriptor)
        
        guard let exercises = exercises else { return }
        
        // Create a Push/Pull/Legs program
        let pushPullLegs = Program(
            name: "Push/Pull/Legs",
            description: "A classic 6-day split focusing on compound movements and progressive overload.",
            weeks: 8
        )
        
        // Push Day
        let pushDay = ProgramDay(dayName: "Push Day")
        let pushExercises = [
            findExercise("Bench Press", in: exercises),
            findExercise("Overhead Press", in: exercises),
            findExercise("Incline Bench Press", in: exercises),
            findExercise("Dumbbell Lateral Raises", in: exercises),
            findExercise("Skull Crushers", in: exercises),
            findExercise("Cable Tricep Extensions", in: exercises)
        ].compactMap { $0 }
        
        for exercise in pushExercises {
            let programExercise = ProgramExercise(
                exercise: exercise,
                targetSets: 3,
                targetReps: "8-12",
                progressionRule: .doubleProgression,
                warmupSets: 0
            )
            pushDay.exercises.append(programExercise)
        }
        
        // Pull Day
        let pullDay = ProgramDay(dayName: "Pull Day")
        let pullExercises = [
            findExercise("Deadlift", in: exercises),
            findExercise("Pull-Ups", in: exercises),
            findExercise("Barbell Rows", in: exercises),
            findExercise("Lat Pulldowns", in: exercises),
            findExercise("Face Pulls", in: exercises),
            findExercise("Barbell Curls", in: exercises)
        ].compactMap { $0 }
        
        for exercise in pullExercises {
            let programExercise = ProgramExercise(
                exercise: exercise,
                targetSets: 3,
                targetReps: "8-12",
                progressionRule: .doubleProgression,
                warmupSets: 0
            )
            pullDay.exercises.append(programExercise)
        }
        
        // Legs Day
        let legsDay = ProgramDay(dayName: "Legs Day")
        let legsExercises = [
            findExercise("Squat", in: exercises),
            findExercise("Romanian Deadlift", in: exercises),
            findExercise("Leg Press", in: exercises),
            findExercise("Lunges", in: exercises),
            findExercise("Calf Raises", in: exercises)
        ].compactMap { $0 }
        
        for exercise in legsExercises {
            let programExercise = ProgramExercise(
                exercise: exercise,
                targetSets: 3,
                targetReps: "8-12",
                progressionRule: .doubleProgression,
                warmupSets: 0
            )
            legsDay.exercises.append(programExercise)
        }
        
        pushPullLegs.days = [pushDay, pullDay, legsDay]
        modelContext.insert(pushPullLegs)
        
        try? modelContext.save()
    }
    
    private static func findExercise(_ name: String, in exercises: [ExerciseDefinition]) -> ExerciseDefinition? {
        return exercises.first { $0.name == name }
    }
    
    static func seedDemoPushPullLegs(modelContext: ModelContext) {
        // Create exercises
        let benchPress = ExerciseDefinition(name: "Bench Press", instructions: "Lie on a bench and press the barbell.", primaryMuscleGroup: MuscleGroup.chest.rawValue, equipment: Equipment.barbell.rawValue)
        let overheadPress = ExerciseDefinition(name: "Overhead Press", instructions: "Press the barbell overhead.", primaryMuscleGroup: MuscleGroup.shoulders.rawValue, equipment: Equipment.barbell.rawValue)
        let tricepsPushdown = ExerciseDefinition(name: "Triceps Pushdown", instructions: "Push the cable down.", primaryMuscleGroup: MuscleGroup.triceps.rawValue, equipment: Equipment.cable.rawValue)
        let barbellRow = ExerciseDefinition(name: "Barbell Row", instructions: "Row the barbell to your torso.", primaryMuscleGroup: MuscleGroup.back.rawValue, equipment: Equipment.barbell.rawValue)
        let latPulldown = ExerciseDefinition(name: "Lat Pulldown", instructions: "Pull the bar to your chest.", primaryMuscleGroup: MuscleGroup.back.rawValue, equipment: Equipment.cable.rawValue)
        let bicepsCurl = ExerciseDefinition(name: "Biceps Curl", instructions: "Curl the dumbbells.", primaryMuscleGroup: MuscleGroup.biceps.rawValue, equipment: Equipment.dumbbell.rawValue)
        let squat = ExerciseDefinition(name: "Squat", instructions: "Squat with the barbell.", primaryMuscleGroup: MuscleGroup.legs.rawValue, equipment: Equipment.barbell.rawValue)
        let legPress = ExerciseDefinition(name: "Leg Press", instructions: "Press with your legs.", primaryMuscleGroup: MuscleGroup.legs.rawValue, equipment: Equipment.machine.rawValue)
        let calfRaise = ExerciseDefinition(name: "Calf Raise", instructions: "Raise your heels.", primaryMuscleGroup: MuscleGroup.calves.rawValue, equipment: Equipment.machine.rawValue)
        
        [benchPress, overheadPress, tricepsPushdown, barbellRow, latPulldown, bicepsCurl, squat, legPress, calfRaise].forEach { modelContext.insert($0) }
        
        // Create program days
        let pushDay = ProgramDay(dayName: "Push")
        pushDay.exercises = [
            ProgramExercise(exercise: benchPress, targetSets: 3, targetReps: "8-12", progressionRule: .linearWeight, warmupSets: 1),
            ProgramExercise(exercise: overheadPress, targetSets: 3, targetReps: "8-12", progressionRule: .linearWeight, warmupSets: 1),
            ProgramExercise(exercise: tricepsPushdown, targetSets: 3, targetReps: "10-15", progressionRule: .doubleProgression, warmupSets: 0)
        ]
        let pullDay = ProgramDay(dayName: "Pull")
        pullDay.exercises = [
            ProgramExercise(exercise: barbellRow, targetSets: 3, targetReps: "8-12", progressionRule: .linearWeight, warmupSets: 1),
            ProgramExercise(exercise: latPulldown, targetSets: 3, targetReps: "8-12", progressionRule: .doubleProgression, warmupSets: 1),
            ProgramExercise(exercise: bicepsCurl, targetSets: 3, targetReps: "10-15", progressionRule: .doubleProgression, warmupSets: 0)
        ]
        let legsDay = ProgramDay(dayName: "Legs")
        legsDay.exercises = [
            ProgramExercise(exercise: squat, targetSets: 3, targetReps: "8-12", progressionRule: .linearWeight, warmupSets: 1),
            ProgramExercise(exercise: legPress, targetSets: 3, targetReps: "10-15", progressionRule: .doubleProgression, warmupSets: 1),
            ProgramExercise(exercise: calfRaise, targetSets: 3, targetReps: "12-20", progressionRule: .doubleProgression, warmupSets: 0)
        ]
        
        // Create programs
        let pushProgram = Program(name: "Push Day", description: "Chest, shoulders, triceps.", weeks: 4)
        pushProgram.days = [pushDay]
        let pullProgram = Program(name: "Pull Day", description: "Back, biceps.", weeks: 4)
        pullProgram.days = [pullDay]
        let legsProgram = Program(name: "Legs Day", description: "Legs and calves.", weeks: 4)
        legsProgram.days = [legsDay]
        [pushProgram, pullProgram, legsProgram].forEach { modelContext.insert($0) }
        
        // Create 12 historical workout sessions for each program
        let calendar = Calendar.current
        let baseDate = calendar.startOfDay(for: Date())
        let sessionCount = 12
        for (i, program) in [pushProgram, pullProgram, legsProgram].enumerated() {
            for j in 0..<sessionCount {
                // Guarantee unique, non-overlapping days for each program
                let dayOffset = -(j + i * sessionCount)
                let date = calendar.date(byAdding: .day, value: dayOffset, to: baseDate) ?? baseDate
                let sessionDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
                let session = WorkoutSession(date: sessionDate, programName: program.name)
                session.isCompleted = true
                for programExercise in program.days.first?.exercises ?? [] {
                    if let exercise = programExercise.exercise {
                        print("Seeding session for \(program.name) - \(exercise.name) on \(sessionDate)")
                        let completedExercise = CompletedExercise(exercise: exercise, targetSets: programExercise.targetSets, targetReps: programExercise.targetReps, warmupSets: programExercise.warmupSets)
                        completedExercise.workoutSession = session
                        session.completedExercises.append(completedExercise)
                        modelContext.insert(completedExercise)
                        for setIndex in 0..<3 {
                            // Wavy pattern: up, down, plateau, jump, dip
                            let baseWeight = 40 + Double(i*10) + Double(setIndex*5)
                            let wave = sin(Double(j) / 2.0) * 5 // sine wave for up/down
                            let plateau = (j % 6 == 0) ? 0 : Double(j) * 0.8
                            let jump = (j % 7 == 3) ? Double.random(in: 3...7) : 0
                            let dip = (j % 8 == 5) ? -Double.random(in: 2...5) : 0
                            let noise = Double.random(in: -1.0...1.0)
                            let weight = baseWeight + plateau + wave + jump + dip + noise
                            let reps = 8 + setIndex + (j % 4) + Int.random(in: -1...1)
                            let set = WorkoutSet(weight: weight, reps: reps, date: sessionDate)
                            set.completedExercise = completedExercise
                            modelContext.insert(set)
                        }
                    }
                }
                modelContext.insert(session)
            }
        }
        try? modelContext.save()
    }
    
    static func seedJournalData(context: ModelContext) {
        let calendar = Calendar.current
        let today = Date()
        
        // Create sample journal entries for the last 30 days with realistic patterns
        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            
            // Create realistic patterns
            let isWeekend = calendar.component(.weekday, from: date) == 1 || calendar.component(.weekday, from: date) == 7
            let _ = calendar.component(.weekday, from: date)
            
            // Alcohol consumption (more likely on weekends)
            let consumedAlcohol = isWeekend && Int.random(in: 1...3) == 1
            
            // Late caffeine (more likely on weekdays)
            let caffeineAfter2PM = !isWeekend && Int.random(in: 1...4) == 1
            
            // Late meals (random)
            let ateLate = Int.random(in: 1...5) == 1
            
            // High stress (more likely on weekdays)
            let highStressDay = !isWeekend && Int.random(in: 1...3) == 1
            
            // Supplements (random but consistent)
            let tookMagnesium = Int.random(in: 1...2) == 1
            let tookAshwagandha = Int.random(in: 1...3) == 1
            
            // Generate health metrics based on lifestyle factors
            var recoveryScore: Int?
            var sleepScore: Int?
            var hrv: Double?
            var rhr: Double?
            
            // Base values
            var baseRecovery = 75
            var baseSleep = 80
            var baseHRV = 35.0
            var baseRHR = 65.0
            
            // Adjust based on lifestyle factors
            if consumedAlcohol {
                baseRecovery -= 15
                baseSleep -= 10
                baseHRV -= 8
                baseRHR += 5
            }
            
            if caffeineAfter2PM {
                baseSleep -= 8
                baseHRV -= 3
            }
            
            if ateLate {
                baseSleep -= 5
                baseHRV -= 2
            }
            
            if highStressDay {
                baseRecovery -= 10
                baseHRV -= 5
                baseRHR += 3
            }
            
            if tookMagnesium {
                baseSleep += 5
                baseHRV += 2
            }
            
            if tookAshwagandha {
                baseRecovery += 3
                baseHRV += 1
                baseRHR -= 1
            }
            
            // Add some natural variation
            recoveryScore = max(30, min(100, baseRecovery + Int.random(in: -10...10)))
            sleepScore = max(40, min(100, baseSleep + Int.random(in: -8...8)))
            hrv = max(15.0, min(60.0, baseHRV + Double.random(in: -5...5)))
            rhr = max(50.0, min(85.0, baseRHR + Double.random(in: -3...3)))
            
            // Create journal entry
            let journal = DailyJournal(
                date: date,
                consumedAlcohol: consumedAlcohol,
                caffeineAfter2PM: caffeineAfter2PM,
                ateLate: ateLate,
                highStressDay: highStressDay,
                tookMagnesium: tookMagnesium,
                tookAshwagandha: tookAshwagandha,
                notes: generateNotes(
                    consumedAlcohol: consumedAlcohol,
                    caffeineAfter2PM: caffeineAfter2PM,
                    ateLate: ateLate,
                    highStressDay: highStressDay,
                    tookMagnesium: tookMagnesium,
                    tookAshwagandha: tookAshwagandha
                )
            )
            
            // Set health metrics
            journal.recoveryScore = recoveryScore
            journal.sleepScore = sleepScore
            journal.hrv = hrv
            journal.rhr = rhr
            
            context.insert(journal)
        }
        
        try? context.save()
        print("Seeded \(30) journal entries")
    }
    
    private static func generateNotes(
        consumedAlcohol: Bool,
        caffeineAfter2PM: Bool,
        ateLate: Bool,
        highStressDay: Bool,
        tookMagnesium: Bool,
        tookAshwagandha: Bool
    ) -> String? {
        var notes: [String] = []
        
        if consumedAlcohol {
            notes.append("Had a drink with dinner")
        }
        
        if caffeineAfter2PM {
            notes.append("Coffee in the afternoon")
        }
        
        if ateLate {
            notes.append("Late dinner")
        }
        
        if highStressDay {
            notes.append("Busy day at work")
        }
        
        if tookMagnesium {
            notes.append("Took magnesium before bed")
        }
        
        if tookAshwagandha {
            notes.append("Ashwagandha supplement")
        }
        
        return notes.isEmpty ? nil : notes.joined(separator: ". ")
    }
} 