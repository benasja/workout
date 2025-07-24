//
//  WorkoutProgram.swift
//  work
//
//  Created by Kiro on 7/24/25.
//

import Foundation
import SwiftData

@Model
final class WorkoutProgram {
    var id: UUID
    var name: String
    @Relationship var exercises: [ExerciseDefinition] = []
    
    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}