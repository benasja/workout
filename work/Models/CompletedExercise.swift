//
//  CompletedExercise.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import Foundation
import SwiftData

@Model
final class CompletedExercise {
    var id: UUID
    var notes: String?
    var targetSets: Int?
    var targetReps: String?
    var warmupSets: Int?
    
    @Relationship(inverse: \WorkoutSession.completedExercises) var workoutSession: WorkoutSession?
    @Relationship var exercise: ExerciseDefinition?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.completedExercise) var sets: [WorkoutSet] = []
    
    init(exercise: ExerciseDefinition, notes: String? = nil, targetSets: Int = 3, targetReps: String = "8-12", warmupSets: Int = 0) {
        self.id = UUID()
        self.exercise = exercise
        self.notes = notes
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.warmupSets = warmupSets
    }
}

// Extension for computed properties to avoid SwiftData conflicts
extension CompletedExercise {
    var totalVolume: Double {
        sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
    
    var bestSet: WorkoutSet? {
        sets.max { $0.e1RM < $1.e1RM }
    }
    
    var setCount: Int {
        sets.count
    }
} 
