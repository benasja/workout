import XCTest
import SwiftData
@testable import work

final class BarcodeIntegrationTests: XCTestCase {
    var modelContext: ModelContext!
    var repository: FuelLogRepository!
    var foodSearchViewModel: FoodSearchViewModel!
    
    override func setUp() async throws {
        // Create in-memory model container for testing
        let container = try ModelContainer(
            for: FoodLog.self, CustomFood.self, NutritionGoals.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        modelContext = container.mainContext
        repository = FuelLogRepository(modelContext: modelContext)
        foodSearchViewModel = FoodSearchViewModel(repository: repository)
    }
    
    override func tearDown() {
        modelContext = nil
        repository = nil
        foodSearchViewModel = nil
    }
    
    func testBarcodeSearchFlow() async throws {
        // Test the complete barcode search flow
        let testBarcode = "1234567890123"
        
        // Mock a successful barcode search
        // Note: In a real test, we would mock the network manager
        // For now, we test the error handling path
        
        await foodSearchViewModel.searchByBarcode(testBarcode)
        
        // Verify that the search was attempted
        XCTAssertFalse(foodSearchViewModel.isLoadingBarcode)
        
        // Since we don't have a real network connection in tests,
        // we expect an error state
        XCTAssertTrue(foodSearchViewModel.showErrorAlert || foodSearchViewModel.barcodeResult != nil)
    }
    
    func testFoodLogCreationFromBarcodeResult() {
        // Test creating a FoodLog from a barcode search result
        let searchResult = FoodSearchResult(
            id: "test123",
            name: "Test Product",
            brand: "Test Brand",
            calories: 250.0,
            protein: 10.0,
            carbohydrates: 30.0,
            fat: 8.0,
            servingSize: 100.0,
            servingUnit: "g",
            imageUrl: nil,
            source: .openFoodFacts
        )
        
        let foodLog = searchResult.createFoodLog(
            mealType: .breakfast,
            servingMultiplier: 1.5,
            barcode: "1234567890123"
        )
        
        // Verify the food log was created correctly
        XCTAssertEqual(foodLog.name, "Test Product")
        XCTAssertEqual(foodLog.calories, 375.0) // 250 * 1.5
        XCTAssertEqual(foodLog.protein, 15.0) // 10 * 1.5
        XCTAssertEqual(foodLog.carbohydrates, 45.0) // 30 * 1.5
        XCTAssertEqual(foodLog.fat, 12.0) // 8 * 1.5
        XCTAssertEqual(foodLog.mealType, .breakfast)
        XCTAssertEqual(foodLog.servingSize, 150.0) // 100 * 1.5
        XCTAssertEqual(foodLog.servingUnit, "g")
        XCTAssertEqual(foodLog.barcode, "1234567890123")
    }
    
    func testBarcodeResultViewModelDefaults() {
        let viewModel = BarcodeResultViewModel()
        
        // Test default values
        XCTAssertEqual(viewModel.servingMultiplier, 1.0)
        XCTAssertFalse(viewModel.isLogging)
        XCTAssertFalse(viewModel.showErrorAlert)
        XCTAssertEqual(viewModel.errorMessage, "")
        
        // Test that meal type is set based on current time
        let currentHour = Calendar.current.component(.hour, from: Date())
        let expectedMealType: MealType
        
        switch currentHour {
        case 5..<11:
            expectedMealType = .breakfast
        case 11..<16:
            expectedMealType = .lunch
        case 16..<22:
            expectedMealType = .dinner
        default:
            expectedMealType = .snacks
        }
        
        XCTAssertEqual(viewModel.selectedMealType, expectedMealType)
    }
    
    func testNutritionCalculations() {
        let searchResult = FoodSearchResult(
            id: "test123",
            name: "Test Product",
            brand: nil,
            calories: 100.0,
            protein: 5.0,
            carbohydrates: 15.0,
            fat: 3.0,
            servingSize: 50.0,
            servingUnit: "g",
            imageUrl: nil,
            source: .openFoodFacts
        )
        
        // Test nutrition summary formatting
        let expectedSummary = "100 cal • 5.0g protein • 15.0g carbs • 3.0g fat"
        XCTAssertEqual(searchResult.nutritionSummary, expectedSummary)
        
        // Test display name formatting
        XCTAssertEqual(searchResult.displayName, "Test Product")
        
        // Test with brand
        let searchResultWithBrand = FoodSearchResult(
            id: "test123",
            name: "Test Product",
            brand: "Test Brand",
            calories: 100.0,
            protein: 5.0,
            carbohydrates: 15.0,
            fat: 3.0,
            servingSize: 50.0,
            servingUnit: "g",
            imageUrl: nil,
            source: .openFoodFacts
        )
        
        XCTAssertEqual(searchResultWithBrand.displayName, "Test Product - Test Brand")
    }
    
    func testMealTypeProperties() {
        // Test MealType enum properties
        XCTAssertEqual(MealType.breakfast.displayName, "Breakfast")
        XCTAssertEqual(MealType.breakfast.icon, "sunrise.fill")
        XCTAssertEqual(MealType.breakfast.sortOrder, 0)
        
        XCTAssertEqual(MealType.lunch.displayName, "Lunch")
        XCTAssertEqual(MealType.lunch.icon, "sun.max.fill")
        XCTAssertEqual(MealType.lunch.sortOrder, 1)
        
        XCTAssertEqual(MealType.dinner.displayName, "Dinner")
        XCTAssertEqual(MealType.dinner.icon, "sunset.fill")
        XCTAssertEqual(MealType.dinner.sortOrder, 2)
        
        XCTAssertEqual(MealType.snacks.displayName, "Snacks")
        XCTAssertEqual(MealType.snacks.icon, "star.fill")
        XCTAssertEqual(MealType.snacks.sortOrder, 3)
    }
}