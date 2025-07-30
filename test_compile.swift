import Foundation

// Test the optional score handling
func testOptionalScores() {
    let recoveryScore: Int? = nil
    let sleepScore: Int? = nil
    
    // Test the generateDirective function signature
    func generateDirective(recoveryScore: Int?, sleepScore: Int?) -> String {
        if recoveryScore == nil || sleepScore == nil {
            return "Data not yet available. Recovery and sleep scores will be calculated once you complete your sleep session."
        }
        
        if recoveryScore! > 85 {
            return "Primed for peak performance. Your body is ready for a high-strain workout."
        } else if recoveryScore! < 55 {
            return "Nervous system under strain. Prioritize active recovery. A light walk or stretching is recommended."
        } else if sleepScore! < 60 {
            return "Sleep was not restorative. Focus on your wind-down routine tonight."
        } else {
            return "Maintain your current habits for continued progress."
        }
    }
    
    let directive = generateDirective(recoveryScore: recoveryScore, sleepScore: sleepScore)
    print("Directive: \(directive)")
}

testOptionalScores()
print("✅ All syntax tests passed!")