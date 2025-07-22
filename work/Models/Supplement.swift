//
//  Supplement.swift
//  work
//
//  Created by Kiro on 7/18/25.
//

import Foundation
import SwiftData

@Model
final class Supplement {
    var id: UUID
    var name: String
    var timeOfDay: String // "Morning" or "Evening"
    var dosage: String
    var isActive: Bool
    var sortOrder: Int
    
    init(name: String, timeOfDay: String, dosage: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.timeOfDay = timeOfDay
        self.dosage = dosage
        self.isActive = true
        self.sortOrder = sortOrder
    }
}