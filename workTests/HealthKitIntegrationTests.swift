import XCTest
import HealthKit
@testable import work

/// Integration tests for HealthKit operations in Fuel Log
final class HealthKitIntegrationTests: XCTestCase {
    
    var healthKitManager: FuelLogHealthKitManager!
    var mockHealthStore: MockHKHealthStore!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Skip tests if HealthKit is not available
        guard HKHealthStore.isHealthDataAvailable() else {
            throw XCTSkip("HealthKit is not available on this device")
        }
        
        mockHealthStore = MockHKHealthStore()
        healthKitManager = FuelLogHealthKitManager()
        
        // Inject mock health store for testing
        healthKitManager.healthStore = mockHealthStore
    }
    
    override func tearDown() async throws {
        healthKitManager = nil
        mockHealthStore = nil
        try await super.tearDown()
    }
    
    // MARK: - Authorization Tests
    
    func testRequestAuthorization_Success() async throws {
        // Given
        mockHealthStore.authorizationResult = .sharingAuthorized
        
        // When
        let result = try await healthKitManager.requestAuthorization()
        
        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(mockHealthStore.requestAuthorizationCalled)
        
        // Verify correct types were requested
        let expectedReadTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .height)!,
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
            HKObjectType.characteristicType(forIdentifier: .biologicalSex)!
        ]
        
        let expectedWriteTypes: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
            HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
            HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
            HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!
        ]
        
        XCTAssertEqual(mockHealthStore.requestedReadTypes, expectedReadTypes)
        XCTAssertEqual(mockHealthStore.requestedWriteTypes, expectedWriteTypes)
    }
    
    func testRequestAuthorization_Denied() async throws {
        // Given
        mockHealthStore.authorizationResult = .sharingDenied
        
        // When
        let result = try await healthKitManager.requestAuthorization()
        
        // Then
        XCTAssertFalse(result)
        XCTAssertTrue(mockHealthStore.requestAuthorizationCalled)
    }
    
    func testRequestAuthorization_Error() async throws {
        // Given
        mockHealthStore.shouldThrowError = true
        mockHealthStore.errorToThrow = HKError(.errorAuthorizationDenied)
        
        // When & Then
        do {
            _ = try await healthKitManager.requestAuthorization()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is HKError)
        }
    }
    
    // MARK: - Physical Data Fetching Tests
    
    func testFetchUserPhysicalData_Success() async throws {
        // Given
        let mockWeight = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 75.0)
        let mockHeight = HKQuantity(unit: .meterUnit(with: .centi), doubleValue: 175.0)
        let mockBirthDate = Calendar.current.date(byAdding: .year, value: -30, to: Date())!
        let mockSex = HKBiologicalSex.male
        
        mockHealthStore.mockWeight = mockWeight
        mockHealthStore.mockHeight = mockHeight
        mockHealthStore.mockBirthDate = mockBirthDate
        mockHealthStore.mockBiologicalSex = HKBiologicalSexObject(biologicalSex: mockSex)
        
        // When
        let physicalData = try await healthKitManager.fetchUserPhysicalData()
        
        // Then
        XCTAssertEqual(physicalData.weight, 75.0, accuracy: 0.1)
        XCTAssertEqual(physicalData.height, 175.0, accuracy: 0.1)
        XCTAssertEqual(physicalData.age, 30)
        XCTAssertEqual(physicalData.biologicalSex, "male")
        XCTAssertNotNil(physicalData.bmr)
        XCTAssertNotNil(physicalData.tdee)
        
        // Verify BMR calculation
        let expectedBMR = healthKitManager.calculateBMR(
            weight: 75.0,
            height: 175.0,
            age: 30,
            sex: mockSex
        )
        XCTAssertEqual(physicalData.bmr, expectedBMR, accuracy: 1.0)
    }
    
    func testFetchUserPhysicalData_PartialData() async throws {
        // Given - only weight available
        let mockWeight = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 70.0)
        mockHealthStore.mockWeight = mockWeight
        mockHealthStore.mockHeight = nil
        mockHealthStore.mockBirthDate = nil
        mockHealthStore.mockBiologicalSex = nil
        
        // When
        let physicalData = try await healthKitManager.fetchUserPhysicalData()
        
        // Then
        XCTAssertEqual(physicalData.weight, 70.0, accuracy: 0.1)
        XCTAssertNil(physicalData.height)
        XCTAssertNil(physicalData.age)
        XCTAssertNil(physicalData.biologicalSex)
        XCTAssertNil(physicalData.bmr) // Can't calculate without all data
        XCTAssertNil(physicalData.tdee)
    }
    
    func testFetchUserPhysicalData_NoData() async throws {
        // Given - no data available
        mockHealthStore.mockWeight = nil
        mockHealthStore.mockHeight = nil
        mockHealthStore.mockBirthDate = nil
        mockHealthStore.mockBiologicalSex = nil
        
        // When
        let physicalData = try await healthKitManager.fetchUserPhysicalData()
        
        // Then
        XCTAssertNil(physicalData.weight)
        XCTAssertNil(physicalData.height)
        XCTAssertNil(physicalData.age)
        XCTAssertNil(physicalData.biologicalSex)
        XCTAssertNil(physicalData.bmr)
        XCTAssertNil(physicalData.tdee)
    }
    
    func testFetchUserPhysicalData_Error() async throws {
        // Given
        mockHealthStore.shouldThrowError = true
        mockHealthStore.errorToThrow = HKError(.errorDataUnavailable)
        
        // When & Then
        do {
            _ = try await healthKitManager.fetchUserPhysicalData()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is HKError)
        }
    }
    
    // MARK: - BMR Calculation Tests
    
    func testCalculateBMR_Male() {
        // Given
        let weight = 75.0 // kg
        let height = 175.0 // cm
        let age = 30
        let sex = HKBiologicalSex.male
        
        // When
        let bmr = healthKitManager.calculateBMR(weight: weight, height: height, age: age, sex: sex)
        
        // Then
        // Mifflin-St Jeor formula for men: BMR = 10 * weight + 6.25 * height - 5 * age + 5
        let expectedBMR = 10 * weight + 6.25 * height - 5 * Double(age) + 5
        XCTAssertEqual(bmr, expectedBMR, accuracy: 0.1)
    }
    
    func testCalculateBMR_Female() {
        // Given
        let weight = 65.0 // kg
        let height = 165.0 // cm
        let age = 25
        let sex = HKBiologicalSex.female
        
        // When
        let bmr = healthKitManager.calculateBMR(weight: weight, height: height, age: age, sex: sex)
        
        // Then
        // Mifflin-St Jeor formula for women: BMR = 10 * weight + 6.25 * height - 5 * age - 161
        let expectedBMR = 10 * weight + 6.25 * height - 5 * Double(age) - 161
        XCTAssertEqual(bmr, expectedBMR, accuracy: 0.1)
    }
    
    func testCalculateBMR_Other() {
        // Given
        let weight = 70.0 // kg
        let height = 170.0 // cm
        let age = 35
        let sex = HKBiologicalSex.other
        
        // When
        let bmr = healthKitManager.calculateBMR(weight: weight, height: height, age: age, sex: sex)
        
        // Then
        // Should use male formula as default for 'other'
        let expectedBMR = 10 * weight + 6.25 * height - 5 * Double(age) + 5
        XCTAssertEqual(bmr, expectedBMR, accuracy: 0.1)
    }
    
    // MARK: - Nutrition Data Writing Tests
    
    func testWriteNutritionData_Success() async throws {
        // Given
        let foodLog = MockDataGenerator.shared.createMockFoodLog(
            name: "Test Food",
            calories: 300,
            protein: 25,
            carbohydrates: 35,
            fat: 12,
            timestamp: Date()
        )
        
        mockHealthStore.shouldThrowError = false
        
        // When
        try await healthKitManager.writeNutritionData(foodLog)
        
        // Then
        XCTAssertTrue(mockHealthStore.saveCalled)
        XCTAssertEqual(mockHealthStore.savedSamples.count, 4) // calories, protein, carbs, fat
        
        // Verify sample types and values
        let caloriesSample = mockHealthStore.savedSamples.first { sample in
            sample.sampleType == HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)
        } as? HKQuantitySample
        
        XCTAssertNotNil(caloriesSample)
        XCTAssertEqual(caloriesSample?.quantity.doubleValue(for: .kilocalorie()), 300, accuracy: 0.1)
        
        let proteinSample = mockHealthStore.savedSamples.first { sample in
            sample.sampleType == HKObjectType.quantityType(forIdentifier: .dietaryProtein)
        } as? HKQuantitySample
        
        XCTAssertNotNil(proteinSample)
        XCTAssertEqual(proteinSample?.quantity.doubleValue(for: .gram()), 25, accuracy: 0.1)
    }
    
    func testWriteNutritionData_Error() async throws {
        // Given
        let foodLog = MockDataGenerator.shared.createMockFoodLog()
        mockHealthStore.shouldThrowError = true
        mockHealthStore.errorToThrow = HKError(.errorAuthorizationDenied)
        
        // When & Then
        do {
            try await healthKitManager.writeNutritionData(foodLog)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is HKError)
        }
    }
    
    func testWriteNutritionData_AuthorizationDenied() async throws {
        // Given
        let foodLog = MockDataGenerator.shared.createMockFoodLog()
        mockHealthStore.authorizationStatus = .sharingDenied
        
        // When & Then
        do {
            try await healthKitManager.writeNutritionData(foodLog)
            XCTFail("Expected FuelLogError.healthKitAuthorizationDenied to be thrown")
        } catch FuelLogError.healthKitAuthorizationDenied {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Authorization Status Tests
    
    func testCheckAuthorizationStatus_Authorized() {
        // Given
        mockHealthStore.authorizationStatus = .sharingAuthorized
        
        // When
        let isAuthorized = healthKitManager.checkAuthorizationStatus()
        
        // Then
        XCTAssertTrue(isAuthorized)
    }
    
    func testCheckAuthorizationStatus_Denied() {
        // Given
        mockHealthStore.authorizationStatus = .sharingDenied
        
        // When
        let isAuthorized = healthKitManager.checkAuthorizationStatus()
        
        // Then
        XCTAssertFalse(isAuthorized)
    }
    
    func testCheckAuthorizationStatus_NotDetermined() {
        // Given
        mockHealthStore.authorizationStatus = .notDetermined
        
        // When
        let isAuthorized = healthKitManager.checkAuthorizationStatus()
        
        // Then
        XCTAssertFalse(isAuthorized)
    }
    
    // MARK: - Integration with Repository Tests
    
    func testFullIntegrationFlow() async throws {
        // Given
        let repository = FuelLogRepository(modelContext: createInMemoryModelContext())
        let viewModel = FuelLogViewModel(repository: repository, healthKitManager: healthKitManager)
        
        // Mock successful authorization
        mockHealthStore.authorizationResult = .sharingAuthorized
        mockHealthStore.mockWeight = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 75.0)
        mockHealthStore.mockHeight = HKQuantity(unit: .meterUnit(with: .centi), doubleValue: 175.0)
        mockHealthStore.mockBirthDate = Calendar.current.date(byAdding: .year, value: -30, to: Date())!
        mockHealthStore.mockBiologicalSex = HKBiologicalSexObject(biologicalSex: .male)
        
        // When - complete onboarding flow
        let authResult = try await healthKitManager.requestAuthorization()
        XCTAssertTrue(authResult)
        
        let physicalData = try await healthKitManager.fetchUserPhysicalData()
        XCTAssertNotNil(physicalData.weight)
        
        // Create nutrition goals based on physical data
        let goals = NutritionGoals(
            dailyCalories: physicalData.tdee ?? 2000,
            dailyProtein: 150,
            dailyCarbohydrates: 250,
            dailyFat: 67,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            bmr: physicalData.bmr ?? 1600,
            tdee: physicalData.tdee ?? 2000,
            weight: physicalData.weight,
            height: physicalData.height,
            age: physicalData.age,
            biologicalSex: physicalData.biologicalSex
        )
        
        try await repository.saveNutritionGoals(goals)
        
        // Log food and verify HealthKit integration
        let foodLog = MockDataGenerator.shared.createMockFoodLog()
        try await repository.saveFoodLog(foodLog)
        
        // Verify HealthKit data was written
        XCTAssertTrue(mockHealthStore.saveCalled)
        XCTAssertGreaterThan(mockHealthStore.savedSamples.count, 0)
    }
    
    // MARK: - Error Recovery Tests
    
    func testErrorRecovery_HealthKitUnavailable() async throws {
        // Given
        mockHealthStore.shouldThrowError = true
        mockHealthStore.errorToThrow = HKError(.errorHealthDataUnavailable)
        
        let repository = FuelLogRepository(modelContext: createInMemoryModelContext())
        let viewModel = FuelLogViewModel(repository: repository, healthKitManager: healthKitManager)
        
        // When - try to log food despite HealthKit error
        let foodLog = MockDataGenerator.shared.createMockFoodLog()
        
        // Should not throw error - should gracefully handle HealthKit failure
        await viewModel.logFood(foodLog)
        
        // Then - food should still be logged locally
        let savedLogs = try await repository.fetchFoodLogs(for: Date())
        XCTAssertEqual(savedLogs.count, 1)
        XCTAssertEqual(savedLogs.first?.name, foodLog.name)
    }
    
    // MARK: - Performance Tests
    
    func testHealthKitOperationPerformance() throws {
        measure {
            let expectation = XCTestExpectation(description: "HealthKit operation")
            
            Task {
                do {
                    _ = try await healthKitManager.requestAuthorization()
                    expectation.fulfill()
                } catch {
                    XCTFail("HealthKit operation failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testBulkNutritionDataWriting() throws {
        // Given
        let foodLogs = MockDataGenerator.shared.createMockFoodLogs(count: 10)
        mockHealthStore.shouldThrowError = false
        
        measure {
            let expectation = XCTestExpectation(description: "Bulk nutrition writing")
            
            Task {
                do {
                    for foodLog in foodLogs {
                        try await healthKitManager.writeNutritionData(foodLog)
                    }
                    expectation.fulfill()
                } catch {
                    XCTFail("Bulk writing failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createInMemoryModelContext() -> ModelContext {
        do {
            let schema = Schema([FoodLog.self, CustomFood.self, NutritionGoals.self])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return ModelContext(modelContainer)
        } catch {
            fatalError("Failed to create in-memory model context: \(error)")
        }
    }
}

// MARK: - Mock HKHealthStore

class MockHKHealthStore: HKHealthStore {
    
    var shouldThrowError = false
    var errorToThrow: Error = HKError(.errorDataUnavailable)
    
    var authorizationResult: HKAuthorizationStatus = .sharingAuthorized
    var authorizationStatus: HKAuthorizationStatus = .sharingAuthorized
    
    var requestAuthorizationCalled = false
    var requestedReadTypes: Set<HKObjectType>?
    var requestedWriteTypes: Set<HKSampleType>?
    
    var saveCalled = false
    var savedSamples: [HKSample] = []
    
    // Mock data
    var mockWeight: HKQuantity?
    var mockHeight: HKQuantity?
    var mockBirthDate: Date?
    var mockBiologicalSex: HKBiologicalSexObject?
    
    override func requestAuthorization(toShare typesToShare: Set<HKSampleType>?, read typesToRead: Set<HKObjectType>?) async throws {
        requestAuthorizationCalled = true
        requestedReadTypes = typesToRead
        requestedWriteTypes = typesToShare
        
        if shouldThrowError {
            throw errorToThrow
        }
    }
    
    override func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        return authorizationStatus
    }
    
    override func save(_ object: HKObject) async throws {
        saveCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if let sample = object as? HKSample {
            savedSamples.append(sample)
        }
    }
    
    override func save(_ objects: [HKObject]) async throws {
        saveCalled = true
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        for object in objects {
            if let sample = object as? HKSample {
                savedSamples.append(sample)
            }
        }
    }
    
    // Mock quantity sample fetching
    func mockExecuteQuery<T: HKQuery>(_ query: T) async throws -> [HKSample] {
        if shouldThrowError {
            throw errorToThrow
        }
        
        var samples: [HKSample] = []
        
        if let quantityQuery = query as? HKSampleQuery {
            let sampleType = quantityQuery.sampleType
            
            if sampleType == HKObjectType.quantityType(forIdentifier: .bodyMass), let weight = mockWeight {
                let sample = HKQuantitySample(
                    type: sampleType as! HKQuantityType,
                    quantity: weight,
                    start: Date(),
                    end: Date()
                )
                samples.append(sample)
            } else if sampleType == HKObjectType.quantityType(forIdentifier: .height), let height = mockHeight {
                let sample = HKQuantitySample(
                    type: sampleType as! HKQuantityType,
                    quantity: height,
                    start: Date(),
                    end: Date()
                )
                samples.append(sample)
            }
        }
        
        return samples
    }
    
    // Mock characteristic data
    override func dateOfBirthComponents() throws -> DateComponents? {
        if shouldThrowError {
            throw errorToThrow
        }
        
        guard let birthDate = mockBirthDate else { return nil }
        return Calendar.current.dateComponents([.year, .month, .day], from: birthDate)
    }
    
    override func biologicalSex() throws -> HKBiologicalSexObject {
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockBiologicalSex ?? HKBiologicalSexObject(biologicalSex: .notSet)
    }
}

// MARK: - HKBiologicalSexObject Extension

extension HKBiologicalSexObject {
    convenience init(biologicalSex: HKBiologicalSex) {
        // This is a simplified mock - in real implementation, this would be handled differently
        self.init()
        // Set the biological sex value through private API or reflection if needed for testing
    }
}