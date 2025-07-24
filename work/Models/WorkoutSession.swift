//
//  WorkoutSession.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var id: UUID
    var date: Date
    var endDate: Date?
    var duration: TimeInterval
    var notes: String?
    var programName: String?
    var isCompleted: Bool
    
    @Relationship(deleteRule: .cascade) var completedExercises: [CompletedExercise] = []
    @Relationship(deleteRule: .cascade) var sets: [WorkoutSet] = []
    
    init(date: Date = Date(), duration: TimeInterval = 0, notes: String? = nil, programName: String? = nil) {
        self.id = UUID()
        self.date = date
        self.endDate = nil
        self.duration = duration
        self.notes = notes
        self.programName = programName
        self.isCompleted = false
    }
}

// Extension for computed properties to avoid SwiftData conflicts
extension WorkoutSession {
    var totalVolume: Double {
        completedExercises.reduce(0) { $0 + $1.totalVolume }
    }
    
    var setCount: Int {
        // This will be calculated from WorkoutSet queries
        0 // Placeholder
    }
} 