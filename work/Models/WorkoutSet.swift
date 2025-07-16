//
//  WorkoutSet.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class WorkoutSet {
    var weight: Double
    var reps: Int
    var rpe: Int?
    var notes: String?
    var date: Date
    var setType: SetType
    var isCompleted: Bool
    var restTime: TimeInterval?
    
    // Reference to the completed exercise
    @Relationship var completedExercise: CompletedExercise?
    
    init(weight: Double, reps: Int, rpe: Int? = nil, notes: String? = nil, date: Date = Date(), setType: SetType = .working, isCompleted: Bool = false, restTime: TimeInterval? = nil, completedExercise: CompletedExercise? = nil) {
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.notes = notes
        self.date = date
        self.setType = setType
        self.isCompleted = isCompleted
        self.restTime = restTime
        self.completedExercise = completedExercise
    }
}

enum SetType: String, CaseIterable, Codable {
    case warmup = "Warmup"
    case working = "Working"
    case dropset = "Drop Set"
    case failure = "Failure"
    case backoff = "Back-off"
    
    var displayName: String {
        return self.rawValue
    }
    
    var color: Color {
        switch self {
        case .warmup:
            return .orange
        case .working:
            return .blue
        case .dropset:
            return .purple
        case .failure:
            return .red
        case .backoff:
            return .green
        }
    }
    
    var icon: String {
        switch self {
        case .warmup:
            return "flame"
        case .working:
            return "dumbbell"
        case .dropset:
            return "arrow.down.circle"
        case .failure:
            return "exclamationmark.triangle"
        case .backoff:
            return "arrow.backward.circle"
        }
    }
}

// Extension for computed properties to avoid SwiftData conflicts
extension WorkoutSet {
    var estimatedOneRepMax: Double {
        // Epley formula: 1RM = weight × (1 + reps/30)
        return weight * (1 + Double(reps) / 30.0)
    }
} 