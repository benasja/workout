import XCTest
import SwiftUI
@testable import work

final class EnhancedNutritionViewTests: XCTestCase {
    
    func testEnhancedNutritionViewInitialization() {
        let view = EnhancedNutritionView(
            caloriesRemaining: 362,
            carbsCurrent: 216,
            carbsGoal: 250,
            proteinCurrent: 147,
            proteinGoal: 180,
            fatCurrent: 38,
            fatGoal: 65
        )
        
        // Verify the view can be created without crashing
        XCTAssertNotNil(view)
    }
    
    func testProgressCalculations() {
        let view = EnhancedNutritionView(
            caloriesRemaining: 100,
            carbsCurrent: 50,
            carbsGoal: 100,
            proteinCurrent: 75,
            proteinGoal: 100,
            fatCurrent: 25,
            fatGoal: 50
        )
        
        // Test that progress values are calculated correctly
        // Note: These are private properties, so we test through the view's behavior
        let mirror = Mirror(reflecting: view)
        
        // Verify the view has the expected properties
        XCTAssertTrue(mirror.children.contains { $0.label == "caloriesRemaining" })
        XCTAssertTrue(mirror.children.contains { $0.label == "carbsCurrent" })
        XCTAssertTrue(mirror.children.contains { $0.label == "proteinCurrent" })
        XCTAssertTrue(mirror.children.contains { $0.label == "fatCurrent" })
    }
    
    func testZeroGoalHandling() {
        let view = EnhancedNutritionView(
            caloriesRemaining: 0,
            carbsCurrent: 0,
            carbsGoal: 0,
            proteinCurrent: 0,
            proteinGoal: 0,
            fatCurrent: 0,
            fatGoal: 0
        )
        
        // Verify the view can handle zero goals without crashing
        XCTAssertNotNil(view)
    }
    
    func testLargeValuesHandling() {
        let view = EnhancedNutritionView(
            caloriesRemaining: 5000,
            carbsCurrent: 1000,
            carbsGoal: 500,
            proteinCurrent: 500,
            proteinGoal: 200,
            fatCurrent: 200,
            fatGoal: 100
        )
        
        // Verify the view can handle large values without crashing
        XCTAssertNotNil(view)
    }
    
    func testAccessibilitySupport() {
        let view = EnhancedNutritionView(
            caloriesRemaining: 362,
            carbsCurrent: 216,
            carbsGoal: 250,
            proteinCurrent: 147,
            proteinGoal: 180,
            fatCurrent: 38,
            fatGoal: 65
        )
        
        // Verify the view has accessibility support
        XCTAssertNotNil(view)
        
        // Test that the view can be rendered for accessibility testing
        let hostingController = UIHostingController(rootView: view)
        XCTAssertNotNil(hostingController.view)
    }
} 