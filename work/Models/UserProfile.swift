//
//  UserProfile.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    var name: String
    var height: Double // in cm
    var unitRawValue: String
    var experienceLevelRawValue: String
    var goals: [String]
    
    init(name: String = "", height: Double = 0, unit: WeightUnit = .kg, experienceLevel: ExperienceLevel = .beginner, goals: [String] = []) {
        self.name = name
        self.height = height
        self.unitRawValue = unit.rawValue
        self.experienceLevelRawValue = experienceLevel.rawValue
        self.goals = goals
    }
    
    var unit: WeightUnit {
        get { WeightUnit(rawValue: unitRawValue) ?? .kg }
        set { unitRawValue = newValue.rawValue }
    }
    
    var experienceLevel: ExperienceLevel {
        get { ExperienceLevel(rawValue: experienceLevelRawValue) ?? .beginner }
        set { experienceLevelRawValue = newValue.rawValue }
    }
    
    // Computed property to get current weight from weight tracker
    var currentWeight: Double {
        // This will be calculated from WeightEntry queries
        0.0 // Placeholder - will be implemented in views
    }
}

enum WeightUnit: String, CaseIterable, Codable {
    case kg = "kg"
}

enum ExperienceLevel: String, CaseIterable, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
} 