//
//  WorkoutSet.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import Foundation
import SwiftData

@Model
final class WorkoutSet {
    var weight: Double
    var reps: Int
    var rpe: Int?
    var notes: String?
    var date: Date
    
    // Reference to the completed exercise
    @Relationship var completedExercise: CompletedExercise?
    
    init(weight: Double, reps: Int, rpe: Int? = nil, notes: String? = nil, date: Date = Date(), completedExercise: CompletedExercise? = nil) {
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.notes = notes
        self.date = date
        self.completedExercise = completedExercise
    }
}

// Extension for computed properties to avoid SwiftData conflicts
extension WorkoutSet {
    var estimatedOneRepMax: Double {
        // Epley formula: 1RM = weight × (1 + reps/30)
        return weight * (1 + Double(reps) / 30.0)
    }
} 