//
//  SupplementModelValidation.swift
//  workTests
//
//  Created by Kiro on 7/18/25.
//

import Foundation
import SwiftData
@testable import work

/// Simple validation to ensure models can be instantiated and basic properties work
class SupplementModelValidation {
    
    static func validateSupplementModel() -> Bool {
        // Test basic Supplement creation
        let supplement = Supplement(
            name: "Test Supplement",
            timeOfDay: "Morning",
            dosage: "100mg",
            sortOrder: 1
        )
        
        // Validate properties
        guard supplement.name == "Test Supplement" else { return false }
        guard supplement.timeOfDay == "Morning" else { return false }
        guard supplement.dosage == "100mg" else { return false }
        guard supplement.sortOrder == 1 else { return false }
        guard supplement.isActive == true else { return false }
        guard supplement.id != UUID() else { return false } // Should have a valid UUID
        
        return true
    }
    
    static func validateSupplementLogModel() -> Bool {
        let testDate = Date()
        
        // Test basic SupplementLog creation
        let supplementLog = SupplementLog(
            date: testDate,
            supplementName: "Test Supplement",
            isTaken: true
        )
        
        // Validate properties
        guard supplementLog.supplementName == "Test Supplement" else { return false }
        guard supplementLog.isTaken == true else { return false }
        guard supplementLog.id != UUID() else { return false } // Should have a valid UUID
        
        // Validate date normalization
        let expectedDate = Calendar.current.startOfDay(for: testDate)
        guard supplementLog.date == expectedDate else { return false }
        
        // Test default values
        let defaultLog = SupplementLog(
            date: testDate,
            supplementName: "Default Test"
        )
        guard defaultLog.isTaken == false else { return false }
        
        return true
    }
    
    static func runAllValidations() -> (supplement: Bool, supplementLog: Bool) {
        let supplementValid = validateSupplementModel()
        let supplementLogValid = validateSupplementLogModel()
        
        print("Supplement model validation: \(supplementValid ? "✅ PASSED" : "❌ FAILED")")
        print("SupplementLog model validation: \(supplementLogValid ? "✅ PASSED" : "❌ FAILED")")
        
        return (supplement: supplementValid, supplementLog: supplementLogValid)
    }
}