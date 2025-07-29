import XCTest
@testable import work

@MainActor
final class IngredientPickerViewModelTests: XCTestCase {
    
    var viewModel: IngredientPickerViewModel!
    var mockRepository: MockFuelLogRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockFuelLogRepository()
        viewModel = IngredientPickerViewModel(repository: mockRepository)
    }
    
    override func tearDown() {
        viewModel = nil
        mockRepository = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertEqual(viewModel.selectedSource, .custom)
        XCTAssertTrue(viewModel.searchResults.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.showingError)
        XCTAssertFalse(viewModel.showingCustomFoodCreation)
        XCTAssertFalse(viewModel.showingPortionAdjustment)
        XCTAssertNil(viewModel.selectedFood)
    }
    
    // MARK: - Load Custom Foods Tests
    
    func testLoadCustomFoodsSuccess() async {
        let customFood1 = CustomFood(
            name: "Chicken Breast",
            caloriesPerServing: 165,
            proteinPerServing: 31,
            carbohydratesPerServing: 0,
            fatPerServing: 3.6
        )
        
        let customFood2 = CustomFood(
            name: "Brown Rice",
            caloriesPerServing: 130,
            proteinPerServing: 2.7,
            carbohydratesPerServing: 28,
            fatPerServing: 0.3
        )
        
        mockRepository.mockCustomFoods = [customFood1, customFood2]
        
        await viewModel.loadCustomFoods()
        
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.searchResults.count, 2)
        XCTAssertEqual(viewModel.searchResults[0].name, "Chicken Breast")
        XCTAssertEqual(viewModel.searchResults[1].name, "Brown Rice")
    }
    
    func testLoadCustomFoodsError() async {
        mockRepository.shouldThrowError = true
        
        await viewModel.loadCustomFoods()
        
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.showingError)
        XCTAssertTrue(viewModel.searchResults.isEmpty)
    }
    
    // MARK: - Search Tests
    
    func testPerformSearchWithEmptyQuery() async {
        let customFood = CustomFood(
            name: "Test Food",
            caloriesPerServing: 100,
            proteinPerServing: 10,
            carbohydratesPerServing: 15,
            fatPerServing: 5
        )
        
        mockRepository.mockCustomFoods = [customFood]
        viewModel.searchText = ""
        
        await viewModel.performSearch()
        
        XCTAssertEqual(viewModel.searchResults.count, 1)
        XCTAssertEqual(viewModel.searchResults[0].name, "Test Food")
    }
    
    func testPerformSearchWithQuery() async {
        let customFood1 = CustomFood(
            name: "Chicken Breast",
            caloriesPerServing: 165,
            proteinPerServing: 31,
            carbohydratesPerServing: 0,
            fatPerServing: 3.6
        )
        
        let customFood2 = CustomFood(
            name: "Brown Rice",
            caloriesPerServing: 130,
            proteinPerServing: 2.7,
            carbohydratesPerServing: 28,
            fatPerServing: 0.3
        )
        
        mockRepository.mockCustomFoods = [customFood1, customFood2]
        viewModel.searchText = "chicken"
        
        await viewModel.performSearch()
        
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.searchResults.count, 1)
        XCTAssertEqual(viewModel.searchResults[0].name, "Chicken Breast")
    }
    
    func testPerformSearchError() async {
        mockRepository.shouldThrowError = true
        viewModel.searchText = "test"
        
        await viewModel.performSearch()
        
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.showingError)
        XCTAssertTrue(viewModel.searchResults.isEmpty)
    }
    
    // MARK: - Food Selection Tests
    
    func testSelectFood() {
        let result = IngredientSearchResult(
            name: "Test Food",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5
        )
        
        viewModel.selectFood(result)
        
        XCTAssertEqual(viewModel.selectedFood?.name, "Test Food")
        XCTAssertTrue(viewModel.showingPortionAdjustment)
    }
}

// MARK: - IngredientSearchResult Tests

final class IngredientSearchResultTests: XCTestCase {
    
    func testInitFromCustomFood() {
        let customFood = CustomFood(
            name: "Test Food",
            caloriesPerServing: 100,
            proteinPerServing: 10,
            carbohydratesPerServing: 15,
            fatPerServing: 5,
            servingSize: 2.0,
            servingUnit: "pieces"
        )
        
        let result = IngredientSearchResult(from: customFood)
        
        XCTAssertEqual(result.id, customFood.id)
        XCTAssertEqual(result.name, "Test Food")
        XCTAssertEqual(result.calories, 100)
        XCTAssertEqual(result.protein, 10)
        XCTAssertEqual(result.carbohydrates, 15)
        XCTAssertEqual(result.fat, 5)
        XCTAssertEqual(result.servingSize, 2.0)
        XCTAssertEqual(result.servingUnit, "pieces")
        XCTAssertEqual(result.source, .custom)
        XCTAssertNotNil(result.customFood)
    }
    
    func testInitFromDatabase() {
        let result = IngredientSearchResult(
            name: "Database Food",
            calories: 200,
            protein: 20,
            carbohydrates: 30,
            fat: 10,
            servingSize: 100,
            servingUnit: "g"
        )
        
        XCTAssertEqual(result.name, "Database Food")
        XCTAssertEqual(result.calories, 200)
        XCTAssertEqual(result.protein, 20)
        XCTAssertEqual(result.carbohydrates, 30)
        XCTAssertEqual(result.fat, 10)
        XCTAssertEqual(result.servingSize, 100)
        XCTAssertEqual(result.servingUnit, "g")
        XCTAssertEqual(result.source, .database)
        XCTAssertNil(result.customFood)
    }
    
    func testServingInfoFormatting() {
        let result1 = IngredientSearchResult(
            name: "Test",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            servingSize: 1.0,
            servingUnit: "serving"
        )
        
        XCTAssertEqual(result1.servingInfo, "per serving")
        
        let result2 = IngredientSearchResult(
            name: "Test",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            servingSize: 100,
            servingUnit: "g"
        )
        
        XCTAssertEqual(result2.servingInfo, "per 100.0 g")
    }
}

// MARK: - PortionAdjustmentView Tests

final class PortionAdjustmentTests: XCTestCase {
    
    func testNutritionCalculations() {
        let food = IngredientSearchResult(
            name: "Test Food",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5,
            servingSize: 100,
            servingUnit: "g"
        )
        
        // Test with 200g (double the serving size)
        let quantity = 200.0
        let multiplier = quantity / food.servingSize // 2.0
        
        let expectedCalories = food.calories * multiplier // 200
        let expectedProtein = food.protein * multiplier // 20
        let expectedCarbs = food.carbohydrates * multiplier // 30
        let expectedFat = food.fat * multiplier // 10
        
        XCTAssertEqual(expectedCalories, 200, accuracy: 0.1)
        XCTAssertEqual(expectedProtein, 20, accuracy: 0.1)
        XCTAssertEqual(expectedCarbs, 30, accuracy: 0.1)
        XCTAssertEqual(expectedFat, 10, accuracy: 0.1)
    }
    
    func testIngredientCreation() {
        let food = IngredientSearchResult(
            name: "Chicken Breast",
            calories: 165,
            protein: 31,
            carbohydrates: 0,
            fat: 3.6,
            servingSize: 100,
            servingUnit: "g"
        )
        
        let quantity = 150.0
        let unit = "g"
        let multiplier = quantity / food.servingSize
        
        let ingredient = CustomFoodIngredient(
            name: food.name,
            quantity: quantity,
            unit: unit,
            calories: food.calories * multiplier,
            protein: food.protein * multiplier,
            carbohydrates: food.carbohydrates * multiplier,
            fat: food.fat * multiplier
        )
        
        XCTAssertEqual(ingredient.name, "Chicken Breast")
        XCTAssertEqual(ingredient.quantity, 150)
        XCTAssertEqual(ingredient.unit, "g")
        XCTAssertEqual(ingredient.calories, 247.5, accuracy: 0.1)
        XCTAssertEqual(ingredient.protein, 46.5, accuracy: 0.1)
        XCTAssertEqual(ingredient.carbohydrates, 0, accuracy: 0.1)
        XCTAssertEqual(ingredient.fat, 5.4, accuracy: 0.1)
    }
}

// MARK: - Integration Tests

@MainActor
final class CustomFoodIntegrationTests: XCTestCase {
    
    var repository: MockFuelLogRepository!
    var customFoodViewModel: CustomFoodCreationViewModel!
    var ingredientPickerViewModel: IngredientPickerViewModel!
    
    override func setUp() {
        super.setUp()
        repository = MockFuelLogRepository()
        customFoodViewModel = CustomFoodCreationViewModel(repository: repository)
        ingredientPickerViewModel = IngredientPickerViewModel(repository: repository)
    }
    
    override func tearDown() {
        repository = nil
        customFoodViewModel = nil
        ingredientPickerViewModel = nil
        super.tearDown()
    }
    
    func testCreateAndSearchCustomFood() async {
        // Create a custom food
        customFoodViewModel.name = "My Custom Food"
        customFoodViewModel.calories = 150
        customFoodViewModel.protein = 12
        customFoodViewModel.carbohydrates = 20
        customFoodViewModel.fat = 6
        
        await customFoodViewModel.saveCustomFood()
        
        XCTAssertEqual(repository.mockCustomFoods.count, 1)
        
        // Load custom foods in ingredient picker
        await ingredientPickerViewModel.loadCustomFoods()
        
        XCTAssertEqual(ingredientPickerViewModel.searchResults.count, 1)
        XCTAssertEqual(ingredientPickerViewModel.searchResults[0].name, "My Custom Food")
        
        // Search for the custom food
        ingredientPickerViewModel.searchText = "custom"
        await ingredientPickerViewModel.performSearch()
        
        XCTAssertEqual(ingredientPickerViewModel.searchResults.count, 1)
        XCTAssertEqual(ingredientPickerViewModel.searchResults[0].name, "My Custom Food")
    }
    
    func testCreateCompositeFood() async {
        // First create some base custom foods
        let baseFood1 = CustomFood(
            name: "Ingredient 1",
            caloriesPerServing: 100,
            proteinPerServing: 10,
            carbohydratesPerServing: 15,
            fatPerServing: 5
        )
        
        let baseFood2 = CustomFood(
            name: "Ingredient 2",
            caloriesPerServing: 200,
            proteinPerServing: 20,
            carbohydratesPerServing: 30,
            fatPerServing: 10
        )
        
        repository.mockCustomFoods = [baseFood1, baseFood2]
        
        // Create a composite food
        customFoodViewModel.name = "My Recipe"
        customFoodViewModel.isComposite = true
        
        let ingredient1 = CustomFoodIngredient(
            name: "Ingredient 1",
            quantity: 1,
            unit: "serving",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5
        )
        
        let ingredient2 = CustomFoodIngredient(
            name: "Ingredient 2",
            quantity: 0.5,
            unit: "serving",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5
        )
        
        customFoodViewModel.addIngredient(ingredient1)
        customFoodViewModel.addIngredient(ingredient2)
        
        await customFoodViewModel.saveCustomFood()
        
        XCTAssertEqual(repository.mockCustomFoods.count, 3) // 2 base + 1 composite
        
        let compositeFood = repository.mockCustomFoods.last!
        XCTAssertEqual(compositeFood.name, "My Recipe")
        XCTAssertTrue(compositeFood.isComposite)
        XCTAssertEqual(compositeFood.ingredients.count, 2)
        XCTAssertEqual(compositeFood.caloriesPerServing, 200) // 100 + 100
        XCTAssertEqual(compositeFood.proteinPerServing, 20) // 10 + 10
    }
}