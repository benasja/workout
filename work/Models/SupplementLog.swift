//
//  SupplementLog.swift
//  work
//
//  Created by Kiro on 7/18/25.
//

import Foundation
import SwiftData

@Model
final class SupplementLog: ObservableObject, Identifiable {
    var id: UUID
    var date: Date
    var supplementName: String
    var isTaken: Bool
    var timestamp: Date
    
    init(date: Date, supplementName: String, isTaken: Bool = false) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.supplementName = supplementName
        self.isTaken = isTaken
        self.timestamp = Date()
    }
}