# Nutrition Goals Race Condition Fix

## Problem
The nutrition tab was showing "Set your nutrition goals" even though nutrition goals existed in the database. Debug logs showed:
- ✅ Nutrition goals were being fetched successfully (2 goals found)
- ✅ Goals had valid data (Calories: 2203.2, Protein: 137.7)
- ❌ View was still showing onboarding screen

## Root Cause Analysis
The issue was a **race condition** in the view rendering:
1. **Async Data Loading**: `loadInitialData()` is called asynchronously in the ViewModel's `init`
2. **Premature View Rendering**: The view was being rendered before the async data loading completed
3. **Timing Issue**: `isLoadingInitialData` was `false` but `nutritionGoals` was still `nil` during the brief window between initialization and data loading completion

## Solution

### 1. Added Initial Data Loading Tracking
**File**: `work/ViewModels/FuelLogViewModel.swift`
- Added `@Published var hasLoadedInitialData: Bool = false`
- Set to `true` when `loadInitialData()` completes successfully

### 2. Enhanced View Loading State Check
**File**: `work/Views/FuelLogDashboardView.swift`
- Changed condition from: `viewModel.isLoadingInitialData`
- To: `viewModel.isLoadingInitialData || !viewModel.hasLoadedInitialData`
- This ensures the loading state is shown until initial data is fully loaded

### 3. Added Debug Logging
**File**: `work/ViewModels/FuelLogViewModel.swift`
- Added logging to `hasNutritionGoals` computed property to track when it's called
- Helps identify timing issues in future debugging

## Technical Details

### Before Fix
```swift
if viewModel.isLoadingInitialData {
    LoadingView(message: "Loading nutrition data...")
} else if !viewModel.hasNutritionGoals {
    nutritionGoalsOnboardingCard  // ❌ Shown prematurely
}
```

### After Fix
```swift
if viewModel.isLoadingInitialData || !viewModel.hasLoadedInitialData {
    LoadingView(message: "Loading nutrition data...")  // ✅ Proper loading state
} else if !viewModel.hasNutritionGoals {
    nutritionGoalsOnboardingCard  // ✅ Only shown when truly no goals exist
}
```

## Result
- ✅ Nutrition goals are properly detected after loading
- ✅ Onboarding screen only appears when no goals actually exist
- ✅ Loading state properly handles async data loading
- ✅ Race condition eliminated

## Testing
The fix ensures that:
1. Loading state is shown during initial data fetch
2. View waits for data to be fully loaded before making UI decisions
3. Nutrition goals are properly recognized when they exist in the database
4. Onboarding screen only appears when nutrition goals are truly missing 