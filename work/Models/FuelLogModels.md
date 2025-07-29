# Fuel Log Data Models

This document provides an overview of the SwiftData models created for the Fuel Log feature.

## Core Models

### FoodLog
Represents a single food entry in the user's daily log.

**Key Properties:**
- `id`: Unique identifier
- `timestamp`: When the food was logged
- `name`: Display name of the food
- `calories`, `protein`, `carbohydrates`, `fat`: Nutritional values
- `mealType`: Breakfast, lunch, dinner, or snacks
- `servingSize` & `servingUnit`: Portion information
- `barcode`: Optional barcode for scanned items
- `customFoodId`: Optional reference to custom food

**Computed Properties:**
- `totalMacroCalories`: Calculated calories from macros (4-4-9 rule)
- `hasValidMacros`: Validates macro calories align with stated calories
- `isQuickAdd`: Identifies quick-add entries
- `formattedServing`: Human-readable serving size

### CustomFood
Represents user-created food items and composite meals.

**Key Properties:**
- `id`: Unique identifier
- `name`: User-defined food name
- `caloriesPerServing`, `proteinPerServing`, etc.: Nutritional values per serving
- `servingSize` & `servingUnit`: Default serving information
- `isComposite`: Whether this is a multi-ingredient meal
- `ingredientsData`: Encoded ingredient list for composite meals

**Computed Properties:**
- `totalMacroCalories`: Calculated calories from macros
- `hasValidMacros`: Validates nutritional consistency
- `hasValidNutrition`: Ensures all values are non-negative
- `hasValidName`: Validates name is present and reasonable
- `isValid`: Overall validation check
- `ingredients`: Decoded ingredient list

### NutritionGoals
Represents user's daily nutritional targets and preferences.

**Key Properties:**
- `id`: Unique identifier
- `userId`: For future multi-user support
- `dailyCalories`, `dailyProtein`, etc.: Daily targets
- `activityLevel`: User's activity level (sedentary to extremely active)
- `goal`: Cut, maintain, or bulk
- `bmr` & `tdee`: Calculated metabolic rates
- `weight`, `height`, `age`, `biologicalSex`: HealthKit-derived data

**Computed Properties:**
- `totalMacroCalories`: Calculated calories from macro targets
- `hasValidMacros`: Validates macro distribution
- `proteinPercentage`, `carbohydratesPercentage`, `fatPercentage`: Macro ratios
- `needsUpdate`: Whether goals are stale (>30 days old)

**Static Methods:**
- `calculateBMR()`: Mifflin-St Jeor formula implementation
- `calculateTDEE()`: TDEE calculation from BMR and activity level

## Supporting Types

### MealType Enum
- `breakfast`, `lunch`, `dinner`, `snacks`
- Includes display names, icons, and sort order

### ActivityLevel Enum
- `sedentary` through `extremelyActive`
- Includes multipliers for TDEE calculation

### NutritionGoal Enum
- `cut`, `maintain`, `bulk`
- Includes calorie adjustments and descriptions

### CustomFoodIngredient Struct
- Represents individual ingredients in composite meals
- Codable for persistence in CustomFood model

### DailyNutritionTotals Struct
- Helper for calculating daily nutrition totals
- Includes progress tracking and meal-type grouping
- Not persisted - calculated from FoodLog entries

## Data Relationships

- FoodLog entries can reference CustomFood via `customFoodId`
- CustomFood can contain multiple CustomFoodIngredient items
- NutritionGoals are user-scoped (single active goals per user)
- All models include proper validation and computed properties

## Integration

Models are integrated into the existing SwiftData container in `workApp.swift` and accessible through extended `DataManager` methods.

Unit tests are provided in `NutritionModelsTests.swift` and integration tests in `FuelLogDataIntegrationTests.swift`.