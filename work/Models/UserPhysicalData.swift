import Foundation
import HealthKit

/// Structure containing user physical data from HealthKit for nutrition calculations
struct UserPhysicalData {
    let weight: Double? // kg
    let height: Double? // cm
    let age: Int?
    let biologicalSex: HKBiologicalSex?
    let bmr: Double?
    let tdee: Double?
    
    /// Indicates if all required data is available for BMR calculation
    var hasCompleteData: Bool {
        return weight != nil && height != nil && age != nil && biologicalSex != nil
    }
    
    /// Calculates TDEE from BMR and activity level
    func calculateTDEE(activityLevel: ActivityLevel) -> Double? {
        guard let bmr = bmr else { return nil }
        return bmr * activityLevel.multiplier
    }
    
    /// Returns formatted weight string
    var formattedWeight: String? {
        guard let weight = weight else { return nil }
        return String(format: "%.1f kg", weight)
    }
    
    /// Returns formatted height string
    var formattedHeight: String? {
        guard let height = height else { return nil }
        return String(format: "%.0f cm", height)
    }
    
    /// Returns formatted age string
    var formattedAge: String? {
        guard let age = age else { return nil }
        return "\(age) years"
    }
    
    /// Returns formatted biological sex string
    var formattedBiologicalSex: String? {
        guard let sex = biologicalSex else { return nil }
        switch sex {
        case .male:
            return "Male"
        case .female:
            return "Female"
        case .other:
            return "Other"
        default:
            return "Not specified"
        }
    }
}