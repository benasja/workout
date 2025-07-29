import XCTest
@testable import work

/// Basic compilation test for FuelLogViewModel
@MainActor
final class FuelLogViewModelBasicTests: XCTestCase {
    
    func testViewModelInitialization() {
        // Given
        let mockRepository = MockBasicRepository()
        
        // When
        let viewModel = FuelLogViewModel(repository: mockRepository)
        
        // Then
        XCTAssertNotNil(viewModel)
        XCTAssertEqual(viewModel.todaysFoodLogs.count, 0)
        XCTAssertNil(viewModel.nutritionGoals)
    }
}

// MARK: - Basic Mock Repository

class MockBasicRepository: FuelLogRepositoryProtocol {
    nonisolated func fetchFoodLogs(for date: Date) async throws -> [FoodLog] { return [] }
    nonisolated func saveFoodLog(_ foodLog: FoodLog) async throws { }
    nonisolated func updateFoodLog(_ foodLog: FoodLog) async throws { }
    nonisolated func deleteFoodLog(_ foodLog: FoodLog) async throws { }
    nonisolated func fetchFoodLogsByDateRange(from startDate: Date, to endDate: Date) async throws -> [FoodLog] { return [] }
    nonisolated func fetchCustomFoods() async throws -> [CustomFood] { return [] }
    nonisolated func fetchCustomFood(by id: UUID) async throws -> CustomFood? { return nil }
    nonisolated func saveCustomFood(_ customFood: CustomFood) async throws { }
    nonisolated func updateCustomFood(_ customFood: CustomFood) async throws { }
    nonisolated func deleteCustomFood(_ customFood: CustomFood) async throws { }
    nonisolated func searchCustomFoods(query: String) async throws -> [CustomFood] { return [] }
    nonisolated func fetchNutritionGoals() async throws -> NutritionGoals? { return nil }
    nonisolated func fetchNutritionGoals(for userId: String) async throws -> NutritionGoals? { return nil }
    nonisolated func saveNutritionGoals(_ goals: NutritionGoals) async throws { }
    nonisolated func updateNutritionGoals(_ goals: NutritionGoals) async throws { }
    nonisolated func deleteNutritionGoals(_ goals: NutritionGoals) async throws { }
}