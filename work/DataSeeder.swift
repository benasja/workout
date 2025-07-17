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
            // Warm-up
            ExerciseDefinition(
                name: "Jumping Jacks",
                instructions: "Stand upright with your legs together, arms at your sides. Jump up, spreading your legs shoulder-width apart and raising your arms overhead. Return to start and repeat.",
                primaryMuscleGroup: "Full Body",
                secondaryMuscleGroups: ["Legs", "Shoulders", "Cardio"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Bodyweight Squats",
                instructions: "Stand with feet shoulder-width apart. Lower your body by bending your knees and hips, keeping your chest up. Return to standing.",
                primaryMuscleGroup: "Legs",
                secondaryMuscleGroups: ["Glutes", "Core"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Arm Circles & Leg Swings",
                instructions: "For arm circles: extend arms to sides and make small to large circles. For leg swings: swing each leg forward/back and side-to-side.",
                primaryMuscleGroup: "Shoulders",
                secondaryMuscleGroups: ["Legs", "Mobility"],
                equipment: "Bodyweight"
            ),

            // A
            ExerciseDefinition(
                name: "Goblet Squat with Triceps Extensions",
                instructions: "Hold a dumbbell at your chest for a squat, then perform a triceps extension at the top of each rep.",
                primaryMuscleGroup: "Legs",
                secondaryMuscleGroups: ["Triceps", "Glutes", "Core"],
                equipment: "Dumbbell"
            ),
            ExerciseDefinition(
                name: "Deficit Push Ups with Bent Over DB Rows",
                instructions: "Perform push-ups with hands elevated, then immediately do bent over dumbbell rows.",
                primaryMuscleGroup: "Chest",
                secondaryMuscleGroups: ["Back", "Triceps", "Shoulders"],
                equipment: "Dumbbell"
            ),
            ExerciseDefinition(
                name: "Shrugs",
                instructions: "Hold dumbbells or a barbell at your sides. Lift your shoulders straight up toward your ears, hold briefly, then lower back down.",
                primaryMuscleGroup: "Shoulders",
                secondaryMuscleGroups: ["Traps"],
                equipment: "Dumbbell"
            ),
            ExerciseDefinition(
                name: "Plank",
                instructions: "Hold a push-up position with your body in a straight line from head to heels. Keep your core tight and breathe steadily.",
                primaryMuscleGroup: "Core",
                secondaryMuscleGroups: ["Shoulders"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Leg Raises",
                instructions: "Lie on your back, legs straight. Lift your legs up to 90 degrees, then lower them slowly without touching the ground.",
                primaryMuscleGroup: "Core",
                secondaryMuscleGroups: ["Hip Flexors"],
                equipment: "Bodyweight"
            ),

            // B
            ExerciseDefinition(
                name: "Dumbbell Romanian Deadlifts",
                instructions: "Hold dumbbells in front of your thighs. Hinge at your hips to lower the weights down your legs, keeping your back straight.",
                primaryMuscleGroup: "Legs",
                secondaryMuscleGroups: ["Back", "Glutes", "Hamstrings"],
                equipment: "Dumbbell"
            ),
            ExerciseDefinition(
                name: "Push-ups",
                instructions: "Start in a plank position with hands slightly wider than shoulders. Lower your body until your chest nearly touches the ground, then push back up.",
                primaryMuscleGroup: "Chest",
                secondaryMuscleGroups: ["Triceps", "Shoulders", "Core"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Dumbbell Bicep Curls",
                instructions: "Hold dumbbells at your sides, palms facing forward. Curl the weights up to your shoulders, then lower back down.",
                primaryMuscleGroup: "Biceps",
                secondaryMuscleGroups: ["Forearms"],
                equipment: "Dumbbell"
            ),
            ExerciseDefinition(
                name: "Dumbbell Shoulder Press",
                instructions: "Sit or stand with dumbbells at shoulder height. Press the weights overhead until arms are fully extended, then lower back down.",
                primaryMuscleGroup: "Shoulders",
                secondaryMuscleGroups: ["Triceps"],
                equipment: "Dumbbell"
            ),

            // C
            ExerciseDefinition(
                name: "Dumbbell Lunges with Band Pull-Aparts",
                instructions: "Hold dumbbells at your sides and perform lunges. Between sets, use a resistance band to do pull-aparts for upper back activation.",
                primaryMuscleGroup: "Legs",
                secondaryMuscleGroups: ["Back", "Glutes", "Shoulders"],
                equipment: "Dumbbell"
            ),
            ExerciseDefinition(
                name: "Single-Arm Dumbbell Rows with Glute Bridges",
                instructions: "Perform single-arm rows with a dumbbell, then superset with glute bridges for lower body activation.",
                primaryMuscleGroup: "Back",
                secondaryMuscleGroups: ["Glutes", "Core"],
                equipment: "Dumbbell"
            ),
            ExerciseDefinition(
                name: "Lateral Raises with Dumbbell Bicep Curls",
                instructions: "Perform lateral raises for shoulders, then immediately do bicep curls with dumbbells.",
                primaryMuscleGroup: "Shoulders",
                secondaryMuscleGroups: ["Biceps"],
                equipment: "Dumbbell"
            ),

            // Cooldown
            ExerciseDefinition(
                name: "Hip Flexor Lunge",
                instructions: "Step one foot forward into a lunge, keeping your back leg straight and stretching the hip flexor.",
                primaryMuscleGroup: "Legs",
                secondaryMuscleGroups: ["Hip Flexors"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Doorway Chest Stretch",
                instructions: "Stand in a doorway, place your arms on the frame, and gently lean forward to stretch your chest.",
                primaryMuscleGroup: "Chest",
                secondaryMuscleGroups: ["Shoulders"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Hamstring Stretch",
                instructions: "Sit on the ground with one leg extended. Reach toward your toes to stretch your hamstring.",
                primaryMuscleGroup: "Legs",
                secondaryMuscleGroups: ["Hamstrings"],
                equipment: "Bodyweight"
            ),

            // Core finisher
            ExerciseDefinition(
                name: "Leg Raises (Core Finisher)",
                instructions: "Lie on your back, legs straight. Lift your legs up to 90 degrees, then lower them slowly without touching the ground.",
                primaryMuscleGroup: "Core",
                secondaryMuscleGroups: ["Hip Flexors"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Dumbbell Woodchoppers",
                instructions: "Hold a dumbbell with both hands. Rotate your torso to bring the weight from high to low across your body, engaging your core.",
                primaryMuscleGroup: "Core",
                secondaryMuscleGroups: ["Obliques", "Shoulders"],
                equipment: "Dumbbell"
            ),
            ExerciseDefinition(
                name: "Side Plank Twists",
                instructions: "Start in a side plank. Rotate your torso and reach your top arm under your body, then return to start.",
                primaryMuscleGroup: "Core",
                secondaryMuscleGroups: ["Obliques", "Shoulders"],
                equipment: "Bodyweight"
            ),
            
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
            ),
            
            // Additional Shoulder Exercises
            ExerciseDefinition(
                name: "Shrugs",
                instructions: "Hold dumbbells or a barbell at your sides. Lift your shoulders straight up toward your ears, hold briefly, then lower back down.",
                primaryMuscleGroup: "Shoulders",
                secondaryMuscleGroups: ["Traps"],
                equipment: "Dumbbell"
            ),
            ExerciseDefinition(
                name: "Upright Rows",
                instructions: "Hold a barbell with a narrow grip. Pull the bar up along your body to chest level, keeping elbows higher than wrists.",
                primaryMuscleGroup: "Shoulders",
                secondaryMuscleGroups: ["Traps", "Biceps"],
                equipment: "Barbell"
            ),
            ExerciseDefinition(
                name: "Arnold Press",
                instructions: "Start with dumbbells at shoulder level, palms facing you. Press up while rotating palms forward, then reverse the motion.",
                primaryMuscleGroup: "Shoulders",
                secondaryMuscleGroups: ["Triceps"],
                equipment: "Dumbbell"
            ),
            
            // Additional Core Exercises
            ExerciseDefinition(
                name: "Leg Raises",
                instructions: "Lie on your back with hands at your sides. Keep legs straight and lift them up to 90 degrees, then lower back down slowly.",
                primaryMuscleGroup: "Core",
                secondaryMuscleGroups: ["Hip Flexors"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Hanging Leg Raises",
                instructions: "Hang from a pull-up bar. Keep legs straight and lift them up to 90 degrees, then lower back down with control.",
                primaryMuscleGroup: "Core",
                secondaryMuscleGroups: ["Hip Flexors", "Forearms"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Mountain Climbers",
                instructions: "Start in a plank position. Alternate bringing knees to chest in a running motion while maintaining plank position.",
                primaryMuscleGroup: "Core",
                secondaryMuscleGroups: ["Shoulders", "Legs"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Dead Bug",
                instructions: "Lie on your back with arms up and knees bent at 90 degrees. Lower opposite arm and leg, then return to start.",
                primaryMuscleGroup: "Core",
                secondaryMuscleGroups: [],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Bird Dog",
                instructions: "Start on hands and knees. Extend opposite arm and leg, hold, then return to start. Alternate sides.",
                primaryMuscleGroup: "Core",
                secondaryMuscleGroups: ["Back", "Glutes"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Side Plank",
                instructions: "Lie on your side, prop yourself up on your elbow. Keep body straight from head to feet, hold position.",
                primaryMuscleGroup: "Core",
                secondaryMuscleGroups: ["Shoulders"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Bicycle Crunches",
                instructions: "Lie on your back, hands behind head. Bring opposite elbow to knee in a cycling motion.",
                primaryMuscleGroup: "Core",
                secondaryMuscleGroups: [],
                equipment: "Bodyweight"
            ),
            
            // Additional Leg Exercises
            ExerciseDefinition(
                name: "Bulgarian Split Squats",
                instructions: "Stand 2 feet in front of a bench, place rear foot on bench. Lower into a lunge position, then push back up.",
                primaryMuscleGroup: "Legs",
                secondaryMuscleGroups: ["Glutes", "Core"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Walking Lunges",
                instructions: "Step forward into a lunge, then bring rear foot forward into the next lunge. Continue walking forward.",
                primaryMuscleGroup: "Legs",
                secondaryMuscleGroups: ["Glutes", "Core"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Jump Squats",
                instructions: "Perform a squat, then explode up into a jump. Land softly and immediately go into the next squat.",
                primaryMuscleGroup: "Legs",
                secondaryMuscleGroups: ["Glutes", "Core"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Single Leg Deadlift",
                instructions: "Stand on one leg, hinge at hip to lower torso while lifting rear leg. Return to standing position.",
                primaryMuscleGroup: "Legs",
                secondaryMuscleGroups: ["Glutes", "Core", "Back"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Wall Sit",
                instructions: "Lean back against a wall with feet shoulder-width apart. Slide down until thighs are parallel to floor, hold position.",
                primaryMuscleGroup: "Legs",
                secondaryMuscleGroups: ["Glutes"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Step Ups",
                instructions: "Step up onto a bench or platform with one foot, then step down. Alternate legs or complete sets on each leg.",
                primaryMuscleGroup: "Legs",
                secondaryMuscleGroups: ["Glutes", "Core"],
                equipment: "Bodyweight"
            ),
            
            // Additional Back Exercises
            ExerciseDefinition(
                name: "T-Bar Rows",
                instructions: "Straddle a T-bar, bend at waist. Pull the bar up to your chest, squeezing shoulder blades together.",
                primaryMuscleGroup: "Back",
                secondaryMuscleGroups: ["Biceps"],
                equipment: "Barbell"
            ),
            ExerciseDefinition(
                name: "Seated Cable Rows",
                instructions: "Sit at cable machine, pull handle to your torso while keeping back straight and squeezing shoulder blades.",
                primaryMuscleGroup: "Back",
                secondaryMuscleGroups: ["Biceps"],
                equipment: "Cable"
            ),
            ExerciseDefinition(
                name: "Reverse Flyes",
                instructions: "Bend forward with dumbbells, arms slightly bent. Lift weights out to sides, squeezing shoulder blades.",
                primaryMuscleGroup: "Back",
                secondaryMuscleGroups: ["Shoulders"],
                equipment: "Dumbbell"
            ),
            ExerciseDefinition(
                name: "Superman",
                instructions: "Lie face down, extend arms forward. Lift chest and legs off ground simultaneously, hold, then lower.",
                primaryMuscleGroup: "Back",
                secondaryMuscleGroups: ["Glutes", "Core"],
                equipment: "Bodyweight"
            ),
            
            // Additional Chest Exercises
            ExerciseDefinition(
                name: "Decline Bench Press",
                instructions: "Lie on a decline bench with feet secured. Press barbell from chest to full arm extension.",
                primaryMuscleGroup: "Chest",
                secondaryMuscleGroups: ["Triceps", "Shoulders"],
                equipment: "Barbell"
            ),
            ExerciseDefinition(
                name: "Chest Dips",
                instructions: "Support yourself on parallel bars, lean forward slightly. Lower body by bending elbows, then push back up.",
                primaryMuscleGroup: "Chest",
                secondaryMuscleGroups: ["Triceps", "Shoulders"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Cable Crossovers",
                instructions: "Stand between cable machines, pull handles down and across your body in an arc motion.",
                primaryMuscleGroup: "Chest",
                secondaryMuscleGroups: ["Shoulders"],
                equipment: "Cable"
            ),
            ExerciseDefinition(
                name: "Diamond Push-Ups",
                instructions: "Perform push-ups with hands close together forming a diamond shape with thumbs and index fingers.",
                primaryMuscleGroup: "Triceps",
                secondaryMuscleGroups: ["Chest", "Shoulders"],
                equipment: "Bodyweight"
            ),
            
            // Additional Arm Exercises
            ExerciseDefinition(
                name: "Concentration Curls",
                instructions: "Sit on bench, rest elbow on inner thigh. Curl dumbbell up while keeping upper arm stationary.",
                primaryMuscleGroup: "Biceps",
                secondaryMuscleGroups: ["Forearms"],
                equipment: "Dumbbell"
            ),
            ExerciseDefinition(
                name: "Cable Curls",
                instructions: "Stand at cable machine with straight bar attachment. Curl the bar up while keeping elbows at sides.",
                primaryMuscleGroup: "Biceps",
                secondaryMuscleGroups: ["Forearms"],
                equipment: "Cable"
            ),
            ExerciseDefinition(
                name: "Overhead Tricep Extension",
                instructions: "Hold dumbbell overhead with both hands. Lower weight behind head by bending elbows, then extend back up.",
                primaryMuscleGroup: "Triceps",
                secondaryMuscleGroups: [],
                equipment: "Dumbbell"
            ),
            ExerciseDefinition(
                name: "Close Grip Bench Press",
                instructions: "Lie on bench with hands closer than shoulder width. Press barbell focusing on tricep engagement.",
                primaryMuscleGroup: "Triceps",
                secondaryMuscleGroups: ["Chest", "Shoulders"],
                equipment: "Barbell"
            ),
            
            // Functional/Athletic Exercises
            ExerciseDefinition(
                name: "Turkish Get-Up",
                instructions: "Lie down holding weight overhead. Stand up while keeping weight overhead, then reverse the movement.",
                primaryMuscleGroup: "Core",
                secondaryMuscleGroups: ["Shoulders", "Legs"],
                equipment: "Kettlebell"
            ),
            ExerciseDefinition(
                name: "Farmer's Walk",
                instructions: "Hold heavy weights at your sides and walk forward maintaining good posture and core engagement.",
                primaryMuscleGroup: "Core",
                secondaryMuscleGroups: ["Forearms", "Traps", "Legs"],
                equipment: "Dumbbell"
            ),
            ExerciseDefinition(
                name: "Box Jumps",
                instructions: "Stand in front of a box. Jump up onto the box, land softly, then step or jump back down.",
                primaryMuscleGroup: "Legs",
                secondaryMuscleGroups: ["Glutes", "Core"],
                equipment: "Bodyweight"
            ),
            ExerciseDefinition(
                name: "Battle Ropes",
                instructions: "Hold rope ends, create waves by alternating arm movements. Maintain athletic stance throughout.",
                primaryMuscleGroup: "Core",
                secondaryMuscleGroups: ["Shoulders", "Arms"],
                equipment: "Other"
            ),
            ExerciseDefinition(
                name: "Medicine Ball Slams",
                instructions: "Hold medicine ball overhead, slam it down with full force while engaging core. Pick up and repeat.",
                primaryMuscleGroup: "Core",
                secondaryMuscleGroups: ["Shoulders", "Back"],
                equipment: "Medicine Ball"
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