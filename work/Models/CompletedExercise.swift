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
        // This will be calculated from WorkoutSet queries in views
        // For now return 0, but views will calculate it properly
        0.0
    }
    
    var bestSet: WorkoutSet? {
        // This will be calculated from WorkoutSet queries in views
        nil
    }
} 