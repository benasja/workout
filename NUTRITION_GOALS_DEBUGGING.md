# Nutrition Goals Debugging

## Problem
The nutrition tab is still showing "Set your nutrition goals" even when goals should be configured. The onboarding screen appears every time the nutrition view is opened.

## Root Cause Investigation
The issue appears to be that no nutrition goals exist in the database, causing the `hasNutritionGoals` property to always return `false`.

## Debugging Approach

### 1. Added Debug Logging
**Files Modified**:
- `work/ViewModels/FuelLogViewModel.swift` - Added logging to `loadNutritionGoals()`
- `work/Repositories/FuelLogRepository.swift` - Added logging to `fetchNutritionGoals()`
- `work/Views/FuelLogDashboardView.swift` - Added logging to view state decisions

### 2. Debug Logs Added
```swift
// FuelLogViewModel
print("🔍 FuelLogViewModel: Loaded nutrition goals: \(nutritionGoals != nil ? "Found" : "Not found")")
if let goals = nutritionGoals {
    print("🔍 FuelLogViewModel: Goals - Calories: \(goals.dailyCalories), Protein: \(goals.dailyProtein)")
}

// FuelLogRepository
print("🔍 FuelLogRepository: Fetched \(goals.count) nutrition goals from database")
if let firstGoal = goals.first {
    print("🔍 FuelLogRepository: First goal - Calories: \(firstGoal.dailyCalories), Protein: \(firstGoal.dailyProtein)")
}

// FuelLogDashboardView
print("🔍 FuelLogDashboardView: Showing onboarding card - hasNutritionGoals: \(viewModel.hasNutritionGoals)")
print("🔍 FuelLogDashboardView: Showing main dashboard - hasNutritionGoals: \(viewModel.hasNutritionGoals)")
```

### 3. Temporary Test Data Creation
**File**: `work/Views/FuelLogDashboardView.swift`

Added temporary code to create test nutrition goals if none exist:
```swift
.onAppear {
    // Temporary debug: Create test nutrition goals if none exist
    Task {
        if let viewModel = viewModel {
            let repository = FuelLogRepository(modelContext: dataManager.modelContext)
            let existingGoals = try? await repository.fetchNutritionGoals()
            if existingGoals == nil {
                print("🔧 Creating test nutrition goals for debugging...")
                let testGoals = NutritionGoals(
                    dailyCalories: 2000,
                    dailyProtein: 150,
                    dailyCarbohydrates: 200,
                    dailyFat: 67,
                    activityLevel: .moderatelyActive,
                    goal: .maintain,
                    bmr: 1600,
                    tdee: 2000
                )
                try? await repository.saveNutritionGoals(testGoals)
                print("🔧 Test nutrition goals created successfully")
                
                // Reload data to pick up the new goals
                await viewModel.loadInitialData()
            }
        }
    }
}
```

## Expected Debug Output
When the nutrition view is opened, the console should show:

1. **If no goals exist**:
   ```
   🔍 FuelLogRepository: Fetched 0 nutrition goals from database
   🔍 FuelLogViewModel: Loaded nutrition goals: Not found
   🔧 Creating test nutrition goals for debugging...
   🔧 Test nutrition goals created successfully
   🔍 FuelLogRepository: Fetched 1 nutrition goals from database
   🔍 FuelLogRepository: First goal - Calories: 2000.0, Protein: 150.0
   🔍 FuelLogViewModel: Loaded nutrition goals: Found
   🔍 FuelLogViewModel: Goals - Calories: 2000.0, Protein: 150.0
   🔍 FuelLogDashboardView: Showing main dashboard - hasNutritionGoals: true
   ```

2. **If goals already exist**:
   ```
   🔍 FuelLogRepository: Fetched 1 nutrition goals from database
   🔍 FuelLogRepository: First goal - Calories: 2000.0, Protein: 150.0
   🔍 FuelLogViewModel: Loaded nutrition goals: Found
   🔍 FuelLogViewModel: Goals - Calories: 2000.0, Protein: 150.0
   🔍 FuelLogDashboardView: Showing main dashboard - hasNutritionGoals: true
   ```

## Next Steps
1. Run the app and check the console output
2. If test goals are created successfully, the main dashboard should appear
3. Remove the temporary test data creation code once the issue is confirmed
4. Investigate why nutrition goals weren't being created through the normal onboarding flow

## Files Modified
1. `work/ViewModels/FuelLogViewModel.swift` - Added debug logging
2. `work/Repositories/FuelLogRepository.swift` - Added debug logging  
3. `work/Views/FuelLogDashboardView.swift` - Added debug logging and temporary test data creation 