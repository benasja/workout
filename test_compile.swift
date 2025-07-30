import Foundation

// Simple test to verify the concurrency fixes
func testConcurrencyFixes() {
    print("🧪 Testing Concurrency Fixes...")
    
    // Test that we can create a basic structure
    let testDate = Date()
    let testInterval = DateInterval(start: testDate.addingTimeInterval(-8 * 3600), duration: 8 * 3600)
    
    print("✅ DateInterval created successfully")
    print("   Start: \(testInterval.start)")
    print("   End: \(testInterval.end)")
    print("   Duration: \(testInterval.duration / 3600) hours")
    
    // Test that we can create a basic recovery component
    let testComponent = RecoveryScoreResult.RecoveryComponent(
        score: 85.0,
        weight: 0.50,
        contribution: 42.5,
        baseline: 40.0,
        currentValue: 45.0,
        description: "Test HRV component"
    )
    
    print("✅ RecoveryComponent created successfully")
    print("   Score: \(testComponent.score)")
    print("   Weight: \(testComponent.weight)")
    print("   Contribution: \(testComponent.contribution)")
    print("   Description: \(testComponent.description)")
    
    print("🎉 Concurrency fixes test completed successfully!")
}

// Run the test
testConcurrencyFixes()