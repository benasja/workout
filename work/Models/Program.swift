//
//  Program.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import Foundation
import SwiftData

@Model
final class Program {
    var name: String
    var programDescription: String
    var weeks: Int
    var isActive: Bool
    
    var days: [ProgramDay] = []
    
    init(name: String, description: String, weeks: Int, isActive: Bool = false) {
        self.name = name
        self.programDescription = description
        self.weeks = weeks
        self.isActive = isActive
    }
}

@Model
final class ProgramDay {
    var dayName: String
    
    var program: Program?
    var exercises: [ProgramExercise] = []
    
    init(dayName: String) {
        self.dayName = dayName
    }
}

@Model
final class ProgramExercise {
    var targetSets: Int
    var targetReps: String
    var progressionRule: ProgressionRule
    var warmupSets: Int
    
    var programDay: ProgramDay?
    var exercise: ExerciseDefinition?
    
    init(exercise: ExerciseDefinition, targetSets: Int, targetReps: String, progressionRule: ProgressionRule, warmupSets: Int = 0) {
        self.exercise = exercise
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.progressionRule = progressionRule
        self.warmupSets = warmupSets
    }
}

enum ProgressionRule: String, CaseIterable, Codable {
    case linearWeight = "Linear Weight"
    case doubleProgression = "Double Progression"
    case percentageBased = "Percentage Based"
    case rpeBased = "RPE Based"
    
    var displayName: String {
        return self.rawValue
    }
} 