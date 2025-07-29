//
//  FuelLogHealthKitManagerProtocol.swift
//  work
//
//  Created by Kiro on 7/29/25.
//

import Foundation
import HealthKit

/// Protocol defining the interface for HealthKit integration in the Fuel Log feature
protocol FuelLogHealthKitManagerProtocol {
    /// Requests authorization for HealthKit data access
    func requestAuthorization() async throws -> Bool
    
    /// Fetches user's physical data from HealthKit
    func fetchUserPhysicalData() async throws -> UserPhysicalData
    
    /// Writes nutrition data to HealthKit
    func writeNutritionData(_ foodLog: FoodLog) async throws
    
    /// Calculates BMR using the Mifflin-St Jeor equation
    func calculateBMR(weight: Double, height: Double, age: Int, sex: HKBiologicalSex) -> Double
}