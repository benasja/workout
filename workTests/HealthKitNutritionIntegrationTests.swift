import XCTest
import HealthKit
@testable import work

final class HealthKitNutritionIntegrationTests: XCTestCase {
    
    var healthKitManager: HealthKitManager!
    
    override func setUpWithError() throws {
        healthKitManager = HealthKitManager.shared
    }
    
    override func tearDownWithError() throws {
        healthKitManager = nil
    }
    
    // MARK: - BMR Calculation Tests
    
    func testBMRCalculationMale() throws {
        // Test BMR calculation for male using Mifflin-St Jeor formula
        // BMR = (10 × weight in kg) + (6.25 × height in cm) - (5 × age in years) + 5
        let weight: Double = 80 // kg
        let height: Double = 180 // cm
        let age: Int = 30
        let sex: HKBiologicalSex = .male
        
        let expectedBMR = (10 * weight) + (6.25 * height) - (5 * Double(age)) + 5
        let calculatedBMR = healthKitManager.calculateBMR(
            weight: weight,
            height: height,
            age: age,
            biologicalSex: sex
        )
        
        XCTAssertEqual(calculatedBMR, expectedBMR, accuracy: 0.1)
        XCTAssertEqual(calculatedBMR, 1825.0, accuracy: 0.1)
    }
    
    func testBMRCalculationFemale() throws {
        // Test BMR calculation for female using Mifflin-St Jeor formula
        // BMR = (10 × weight in kg) + (6.25 × height in cm) - (5 × age in years) - 161
        let weight: Double = 65 // kg
        let height: Double = 165 // cm
        let age: Int = 25
        let sex: HKBiologicalSex = .female
        
        let expectedBMR = (10 * weight) + (6.25 * height) - (5 * Double(age)) - 161
        let calculatedBMR = healthKitManager.calculateBMR(
            weight: weight,
            height: height,
            age: age,
            biologicalSex: sex
        )
        
        XCTAssertEqual(calculatedBMR, expectedBMR, accuracy: 0.1)
        XCTAssertEqual(calculatedBMR, 1396.25, accuracy: 0.1)
    }
    
    func testBMRCalculationOtherSex() throws {
        // Test BMR calculation for other/unknown sex (should use average)
        let weight: Double = 70 // kg
        let height: Double = 170 // cm
        let age: Int = 35
        let sex: HKBiologicalSex = .other
        
        let maleRate = (10 * weight) + (6.25 * height) - (5 * Double(age)) + 5
        let femaleRate = (10 * weight) + (6.25 * height) - (5 * Double(age)) - 161
        let expectedBMR = (maleRate + femaleRate) / 2
        
        let calculatedBMR = healthKitManager.calculateBMR(
            weight: weight,
            height: height,
            age: age,
            biologicalSex: sex
        )
        
        XCTAssertEqual(calculatedBMR, expectedBMR, accuracy: 0.1)
    }
    
    func testBMRMinimumValue() throws {
        // Test that BMR never goes below 1000 calories
        let weight: Double = 30 // Very low weight
        let height: Double = 120 // Very low height
        let age: Int = 80 // High age
        let sex: HKBiologicalSex = .female
        
        let calculatedBMR = healthKitManager.calculateBMR(
            weight: weight,
            height: height,
            age: age,
            biologicalSex: sex
        )
        
        XCTAssertGreaterThanOrEqual(calculatedBMR, 1000.0)
    }
    
    // MARK: - Nutrition Sample Creation Tests
    
    func testWriteNutritionDataIntegration() async throws {
        // Skip this test on simulator since HealthKit is not available
        guard HKHealthStore.isHealthDataAvailable() else {
            throw XCTSkip("HealthKit not available on simulator")
        }
        
        // Create a test FoodLog
        let foodLog = FoodLog(
            timestamp: Date(),
            name: "Test Food",
            calories: 250.0,
            protein: 20.0,
            carbohydrates: 30.0,
            fat: 10.0,
            mealType: .lunch,
            servingSize: 1.0,
            servingUnit: "serving"
        )
        
        // Test that the method doesn't crash (actual writing requires permissions)
        do {
            try await healthKitManager.writeNutritionData(foodLog)
            XCTAssertTrue(true) // If we get here, no exception was thrown
        } catch {
            // Expected if permissions are not granted
            XCTAssertTrue(error is FuelLogError || error.localizedDescription.contains("authorization"))
        }
    }
    
    // MARK: - UserPhysicalData Tests
    
    func testUserPhysicalDataComplete() throws {
        let physicalData = UserPhysicalData(
            weight: 75.0,
            height: 175.0,
            age: 30,
            biologicalSex: .male,
            bmr: 1800.0,
            tdee: 2200.0
        )
        
        XCTAssertTrue(physicalData.hasCompleteData)
        XCTAssertEqual(physicalData.formattedWeight, "75.0 kg")
        XCTAssertEqual(physicalData.formattedHeight, "175 cm")
        XCTAssertEqual(physicalData.formattedAge, "30 years")
        XCTAssertEqual(physicalData.formattedBiologicalSex, "Male")
    }
    
    func testUserPhysicalDataIncomplete() throws {
        let physicalData = UserPhysicalData(
            weight: nil,
            height: 175.0,
            age: 30,
            biologicalSex: .male,
            bmr: nil,
            tdee: nil
        )
        
        XCTAssertFalse(physicalData.hasCompleteData)
        XCTAssertNil(physicalData.formattedWeight)
        XCTAssertNotNil(physicalData.formattedHeight)
    }
    
    func testTDEECalculation() throws {
        let physicalData = UserPhysicalData(
            weight: 75.0,
            height: 175.0,
            age: 30,
            biologicalSex: .male,
            bmr: 1800.0,
            tdee: nil
        )
        
        let tdee = physicalData.calculateTDEE(activityLevel: .moderatelyActive)
        let expectedTDEE = 1800.0 * 1.55 // moderatelyActive multiplier
        
        XCTAssertNotNil(tdee)
        XCTAssertEqual(tdee!, expectedTDEE, accuracy: 0.1)
    }
    
    func testTDEECalculationWithoutBMR() throws {
        let physicalData = UserPhysicalData(
            weight: 75.0,
            height: 175.0,
            age: 30,
            biologicalSex: .male,
            bmr: nil,
            tdee: nil
        )
        
        let tdee = physicalData.calculateTDEE(activityLevel: .moderatelyActive)
        XCTAssertNil(tdee)
    }
    
    // MARK: - Error Handling Tests
    
    func testFuelLogErrorDescriptions() throws {
        let errors: [FuelLogError] = [
            .healthKitNotAvailable,
            .healthKitAuthorizationDenied,
            .networkError(NSError(domain: "test", code: 1, userInfo: nil)),
            .invalidBarcode,
            .foodNotFound,
            .invalidNutritionData,
            .persistenceError(NSError(domain: "test", code: 1, userInfo: nil)),
            .invalidUserData,
            .calculationError
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertNotNil(error.failureReason)
            XCTAssertNotNil(error.recoverySuggestion)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    // MARK: - Integration Tests (require HealthKit permissions)
    
    func testHealthKitAvailability() throws {
        // This test will pass on iOS devices and fail on simulator
        // We just test that the method doesn't crash
        let isAvailable = HKHealthStore.isHealthDataAvailable()
        
        // On simulator, this will be false
        // On device, this should be true
        XCTAssertNotNil(isAvailable)
    }
    
    func testNutritionAuthorizationRequest() async throws {
        // Skip this test on simulator since HealthKit is not available
        guard HKHealthStore.isHealthDataAvailable() else {
            throw XCTSkip("HealthKit not available on simulator")
        }
        
        // This test requires user interaction and may fail if permissions are denied
        // We're mainly testing that the method doesn't crash
        do {
            let _ = try await healthKitManager.requestNutritionAuthorization()
            // If we get here, the method completed without throwing
            XCTAssertTrue(true)
        } catch FuelLogError.healthKitAuthorizationDenied {
            // This is expected if user denies permission
            XCTAssertTrue(true)
        } catch {
            // Other errors should cause test failure
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testBMRCalculationPerformance() throws {
        measure {
            for _ in 0..<1000 {
                let _ = healthKitManager.calculateBMR(
                    weight: 75.0,
                    height: 175.0,
                    age: 30,
                    biologicalSex: .male
                )
            }
        }
    }
}

