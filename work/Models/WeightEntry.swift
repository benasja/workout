//
//  WeightEntry.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import Foundation
import SwiftData

@Model
final class WeightEntry: ObservableObject, Identifiable {
    var id: UUID
    var date: Date
    var weight: Double
    var notes: String?
    
    init(date: Date = Date(), weight: Double, notes: String? = nil) {
        self.id = UUID()
        self.date = date
        self.weight = weight
        self.notes = notes
    }
} 