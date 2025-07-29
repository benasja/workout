import XCTest
@testable import work

@MainActor
final class CustomFoodCreationTests: XCTestCase {
    
    var viewModel: CustomFoodCreationViewModel!
    var mockRepository: MockFuelLogRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockFuelLogRepository()
        viewModel = CustomFoodCreationViewModel(repository: mockRepository)
    }
    
    override func tearDown() {
        viewModel = nil
        mockRepository = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertEqual(viewModel.name, "")
        XCTAssertEqual(viewModel.calories, 0.0)
        XCTAssertEqual(viewModel.protein, 0.0)
        XCTAssertEqual(viewModel.carbohydrates, 0.0)
        XCTAssertEqual(viewModel.fat, 0.0)
        XCTAssertEqual(viewModel.servingSize, 1.0)
        XCTAssertEqual(viewModel.servingUnit, "serving")
        XCTAssertFalse(viewModel.isComposite)
        XCTAssertTrue(viewModel.ingredients.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.showingError)
        XCTAssertFalse(viewModel.shouldDismiss)
    }
    
    func testInitializationWithExistingFood() {
        let existingFood = CustomFood(
            name: "Test Food",
            caloriesPerServing: 100,
            proteinPerServing: 10,
            carbohydratesPerServing: 15,
            fatPerServing: 5,
            servingSize: 2.0,
            servingUnit: "pieces"
        )
        
        let editViewModel = CustomFoodCreationViewModel(repository: mockRepository, existingFood: existingFood)
        
        XCTAssertEqual(editViewModel.name, "Test Food")
        XCTAssertEqual(editViewModel.calories, 100)
        XCTAssertEqual(editViewModel.protein, 10)
        XCTAssertEqual(editViewModel.carbohydrates, 15)
        XCTAssertEqual(editViewModel.fat, 5)
        XCTAssertEqual(editViewModel.servingSize, 2.0)
        XCTAssertEqual(editViewModel.servingUnit, "pieces")
        XCTAssertFalse(editViewModel.isComposite)
    }
    
    // MARK: - Validation Tests
    
    func testValidationEmptyName() {
        viewModel.name = ""
        viewModel.calories = 100
        viewModel.protein = 10
        viewModel.carbohydrates = 15
        viewModel.fat = 5
        
        XCTAssertFalse(viewModel.isValid)
        XCTAssertTrue(viewModel.validationMessages.contains("Food name is required"))
    }
    
    func testValidationLongName() {
        viewModel.name = String(repeating: "a", count: 101)
        viewModel.calories = 100
        viewModel.protein = 10
        viewModel.carbohydrates = 15
        viewModel.fat = 5
        
        XCTAssertFalse(viewModel.isValid)
        XCTAssertTrue(viewModel.validationMessages.contains("Food name must be 100 characters or less"))
    }
    
    func testValidationNegativeCalories() {
        viewModel.name = "Test Food"
        viewModel.calories = -10
        viewModel.protein = 10
        viewModel.carbohydrates = 15
        viewModel.fat = 5
        
        XCTAssertFalse(viewModel.isValid)
        XCTAssertTrue(viewModel.validationMessages.contains("Calories cannot be negative"))
    }
    
    func testValidationNegativeProtein() {
        viewModel.name = "Test Food"
        viewModel.calories = 100
        viewModel.protein = -5
        viewModel.carbohydrates = 15
        viewModel.fat = 5
        
        XCTAssertFalse(viewModel.isValid)
        XCTAssertTrue(viewModel.validationMessages.contains("Protein cannot be negative"))
    }
    
    func testValidationNegativeCarbohydrates() {
        viewModel.name = "Test Food"
        viewModel.calories = 100
        viewModel.protein = 10
        viewModel.carbohydrates = -5
        viewModel.fat = 5
        
        XCTAssertFalse(viewModel.isValid)
        XCTAssertTrue(viewModel.validationMessages.contains("Carbohydrates cannot be negative"))
    }
    
    func testValidationNegativeFat() {
        viewModel.name = "Test Food"
        viewModel.calories = 100
        viewModel.protein = 10
        viewModel.carbohydrates = 15
        viewModel.fat = -2
        
        XCTAssertFalse(viewModel.isValid)
        XCTAssertTrue(viewModel.validationMessages.contains("Fat cannot be negative"))
    }
    
    func testValidationUnreasonablyHighValues() {
        viewModel.name = "Test Food"
        viewModel.calories = 15000
        viewModel.protein = 1500
        viewModel.carbohydrates = 1500
        viewModel.fat = 1500
        
        XCTAssertFalse(viewModel.isValid)
        XCTAssertTrue(viewModel.validationMessages.contains("Calories seem unreasonably high (>10,000)"))
        XCTAssertTrue(viewModel.validationMessages.contains("Protein seems unreasonably high (>1,000g)"))
        XCTAssertTrue(viewModel.validationMessages.contains("Carbohydrates seem unreasonably high (>1,000g)"))
        XCTAssertTrue(viewModel.validationMessages.contains("Fat seems unreasonably high (>1,000g)"))
    }
    
    func testValidationMacroConsistency() {
        viewModel.name = "Test Food"
        viewModel.calories = 100
        viewModel.protein = 25 // 100 kcal
        viewModel.carbohydrates = 25 // 100 kcal
        viewModel.fat = 11 // 99 kcal
        // Total macro calories: 299, stated calories: 100 - huge difference
        
        XCTAssertFalse(viewModel.isValid)
        XCTAssertTrue(viewModel.validationMessages.contains { $0.contains("Macro calories") && $0.contains("don't match stated calories") })
    }
    
    func testValidationZeroServingSize() {
        viewModel.name = "Test Food"
        viewModel.calories = 100
        viewModel.protein = 10
        viewModel.carbohydrates = 15
        viewModel.fat = 5
        viewModel.servingSize = 0
        
        XCTAssertFalse(viewModel.isValid)
        XCTAssertTrue(viewModel.validationMessages.contains("Serving size must be greater than 0"))
    }
    
    func testValidationEmptyServingUnit() {
        viewModel.name = "Test Food"
        viewModel.calories = 100
        viewModel.protein = 10
        viewModel.carbohydrates = 15
        viewModel.fat = 5
        viewModel.servingUnit = ""
        
        XCTAssertFalse(viewModel.isValid)
        XCTAssertTrue(viewModel.validationMessages.contains("Serving unit is required"))
    }
    
    func testValidationCompositeWithoutIngredients() {
        viewModel.name = "Test Meal"
        viewModel.isComposite = true
        
        XCTAssertFalse(viewModel.isValid)
        XCTAssertTrue(viewModel.validationMessages.contains("Composite meals must have at least one ingredient"))
    }
    
    func testValidationValidSimpleFood() {
        viewModel.name = "Test Food"
        viewModel.calories = 100
        viewModel.protein = 10
        viewModel.carbohydrates = 15
        viewModel.fat = 5
        viewModel.servingSize = 1.0
        viewModel.servingUnit = "serving"
        
        XCTAssertTrue(viewModel.isValid)
        XCTAssertTrue(viewModel.validationMessages.isEmpty)
    }
    
    // MARK: - Composite Meal Tests
    
    func testCalculatedNutritionForComposite() {
        viewModel.isComposite = true
        
        let ingredient1 = CustomFoodIngredient(
            name: "Chicken",
            quantity: 100,
            unit: "g",
            calories: 165,
            protein: 31,
            carbohydrates: 0,
            fat: 3.6
        )
        
        let ingredient2 = CustomFoodIngredient(
            name: "Rice",
            quantity: 50,
            unit: "g",
            calories: 130,
            protein: 2.7,
            carbohydrates: 28,
            fat: 0.3
        )
        
        viewModel.addIngredient(ingredient1)
        viewModel.addIngredient(ingredient2)
        
        XCTAssertEqual(viewModel.calculatedCalories, 295, accuracy: 0.1)
        XCTAssertEqual(viewModel.calculatedProtein, 33.7, accuracy: 0.1)
        XCTAssertEqual(viewModel.calculatedCarbohydrates, 28, accuracy: 0.1)
        XCTAssertEqual(viewModel.calculatedFat, 3.9, accuracy: 0.1)
    }
    
    func testAddIngredient() {
        let ingredient = CustomFoodIngredient(
            name: "Test Ingredient",
            quantity: 100,
            unit: "g",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5
        )
        
        XCTAssertTrue(viewModel.ingredients.isEmpty)
        viewModel.addIngredient(ingredient)
        XCTAssertEqual(viewModel.ingredients.count, 1)
        XCTAssertEqual(viewModel.ingredients.first?.name, "Test Ingredient")
    }
    
    func testRemoveIngredient() {
        let ingredient1 = CustomFoodIngredient(
            name: "Ingredient 1",
            quantity: 100,
            unit: "g",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5
        )
        
        let ingredient2 = CustomFoodIngredient(
            name: "Ingredient 2",
            quantity: 50,
            unit: "g",
            calories: 50,
            protein: 5,
            carbohydrates: 7,
            fat: 2
        )
        
        viewModel.addIngredient(ingredient1)
        viewModel.addIngredient(ingredient2)
        XCTAssertEqual(viewModel.ingredients.count, 2)
        
        viewModel.removeIngredient(ingredient1)
        XCTAssertEqual(viewModel.ingredients.count, 1)
        XCTAssertEqual(viewModel.ingredients.first?.name, "Ingredient 2")
    }
    
    // MARK: - Save Tests
    
    func testSaveNewCustomFood() async {
        viewModel.name = "Test Food"
        viewModel.calories = 100
        viewModel.protein = 10
        viewModel.carbohydrates = 15
        viewModel.fat = 5
        viewModel.servingSize = 1.0
        viewModel.servingUnit = "serving"
        
        await viewModel.saveCustomFood()
        
        XCTAssertEqual(mockRepository.mockCustomFoods.count, 1)
        let savedFood = mockRepository.mockCustomFoods.first!
        XCTAssertEqual(savedFood.name, "Test Food")
        XCTAssertEqual(savedFood.caloriesPerServing, 100)
        XCTAssertEqual(savedFood.proteinPerServing, 10)
        XCTAssertEqual(savedFood.carbohydratesPerServing, 15)
        XCTAssertEqual(savedFood.fatPerServing, 5)
        XCTAssertEqual(savedFood.servingSize, 1.0)
        XCTAssertEqual(savedFood.servingUnit, "serving")
        XCTAssertFalse(savedFood.isComposite)
        XCTAssertTrue(viewModel.shouldDismiss)
    }
    
    func testSaveCompositeFood() async {
        viewModel.name = "Test Meal"
        viewModel.isComposite = true
        
        let ingredient = CustomFoodIngredient(
            name: "Test Ingredient",
            quantity: 100,
            unit: "g",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5
        )
        
        viewModel.addIngredient(ingredient)
        
        await viewModel.saveCustomFood()
        
        XCTAssertEqual(mockRepository.mockCustomFoods.count, 1)
        let savedFood = mockRepository.mockCustomFoods.first!
        XCTAssertEqual(savedFood.name, "Test Meal")
        XCTAssertEqual(savedFood.caloriesPerServing, 100)
        XCTAssertEqual(savedFood.proteinPerServing, 10)
        XCTAssertEqual(savedFood.carbohydratesPerServing, 15)
        XCTAssertEqual(savedFood.fatPerServing, 5)
        XCTAssertTrue(savedFood.isComposite)
        XCTAssertEqual(savedFood.ingredients.count, 1)
        XCTAssertTrue(viewModel.shouldDismiss)
    }
    
    func testSaveInvalidFood() async {
        viewModel.name = "" // Invalid name
        viewModel.calories = 100
        
        await viewModel.saveCustomFood()
        
        XCTAssertEqual(mockRepository.mockCustomFoods.count, 0)
        XCTAssertTrue(viewModel.showingError)
        XCTAssertFalse(viewModel.shouldDismiss)
    }
    
    func testSaveWithRepositoryError() async {
        viewModel.name = "Test Food"
        viewModel.calories = 100
        viewModel.protein = 10
        viewModel.carbohydrates = 15
        viewModel.fat = 5
        
        mockRepository.shouldThrowError = true
        
        await viewModel.saveCustomFood()
        
        XCTAssertTrue(viewModel.showingError)
        XCTAssertFalse(viewModel.shouldDismiss)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testUpdateExistingFood() async {
        let existingFood = CustomFood(
            name: "Original Food",
            caloriesPerServing: 50,
            proteinPerServing: 5,
            carbohydratesPerServing: 10,
            fatPerServing: 2
        )
        
        let editViewModel = CustomFoodCreationViewModel(repository: mockRepository, existingFood: existingFood)
        editViewModel.name = "Updated Food"
        editViewModel.calories = 100
        editViewModel.protein = 10
        editViewModel.carbohydrates = 15
        editViewModel.fat = 5
        
        await editViewModel.saveCustomFood()
        
        XCTAssertEqual(existingFood.name, "Updated Food")
        XCTAssertEqual(existingFood.caloriesPerServing, 100)
        XCTAssertEqual(existingFood.proteinPerServing, 10)
        XCTAssertEqual(existingFood.carbohydratesPerServing, 15)
        XCTAssertEqual(existingFood.fatPerServing, 5)
        XCTAssertTrue(editViewModel.shouldDismiss)
    }
}

// MARK: - CustomFoodIngredient Tests

final class CustomFoodIngredientTests: XCTestCase {
    
    func testIngredientInitialization() {
        let ingredient = CustomFoodIngredient(
            name: "Test Ingredient",
            quantity: 100,
            unit: "g",
            calories: 165,
            protein: 31,
            carbohydrates: 0,
            fat: 3.6
        )
        
        XCTAssertEqual(ingredient.name, "Test Ingredient")
        XCTAssertEqual(ingredient.quantity, 100)
        XCTAssertEqual(ingredient.unit, "g")
        XCTAssertEqual(ingredient.calories, 165)
        XCTAssertEqual(ingredient.protein, 31)
        XCTAssertEqual(ingredient.carbohydrates, 0)
        XCTAssertEqual(ingredient.fat, 3.6)
    }
    
    func testFormattedQuantityWholeNumber() {
        let ingredient = CustomFoodIngredient(
            name: "Test",
            quantity: 100,
            unit: "g",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5
        )
        
        XCTAssertEqual(ingredient.formattedQuantity, "100 g")
    }
    
    func testFormattedQuantityDecimal() {
        let ingredient = CustomFoodIngredient(
            name: "Test",
            quantity: 100.5,
            unit: "g",
            calories: 100,
            protein: 10,
            carbohydrates: 15,
            fat: 5
        )
        
        XCTAssertEqual(ingredient.formattedQuantity, "100.5 g")
    }
}

// MARK: - Mock Repository Extension

extension MockFuelLogRepository {
    // Add any additional methods needed for custom food testing
}