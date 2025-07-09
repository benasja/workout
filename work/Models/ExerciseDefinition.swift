//
//  ExerciseDefinition.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import Foundation
import SwiftData

@Model
final class ExerciseDefinition {
    var id: UUID
    var name: String
    var instructions: String
    var videoURL: String?
    var primaryMuscleGroup: String
    var secondaryMuscleGroups: [String]
    var equipment: String
    var userCreated: Bool
    
    init(id: UUID = UUID(), name: String, instructions: String, videoURL: String? = nil, primaryMuscleGroup: String, secondaryMuscleGroups: [String] = [], equipment: String, userCreated: Bool = false) {
        self.id = id
        self.name = name
        self.instructions = instructions
        self.videoURL = videoURL
        self.primaryMuscleGroup = primaryMuscleGroup
        self.secondaryMuscleGroups = secondaryMuscleGroups
        self.equipment = equipment
        self.userCreated = userCreated
    }
}

enum MuscleGroup: String, CaseIterable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case legs = "Legs"
    case core = "Core"
    case calves = "Calves"
    case forearms = "Forearms"
    case glutes = "Glutes"
    case hamstrings = "Hamstrings"
    case quadriceps = "Quadriceps"
}

enum Equipment: String, CaseIterable {
    case barbell = "Barbell"
    case dumbbell = "Dumbbell"
    case machine = "Machine"
    case cable = "Cable"
    case bodyweight = "Bodyweight"
    case kettlebell = "Kettlebell"
    case resistanceBand = "Resistance Band"
    case smithMachine = "Smith Machine"
} 