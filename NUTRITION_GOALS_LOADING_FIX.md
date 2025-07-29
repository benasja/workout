# Nutrition Goals Loading Fix

## Problem
When opening the "Nutrition" tab, the screen was showing "Set your nutrition goals" and "Set up goals" even when nutrition goals were already configured and set up.

## Root Cause Analysis
The issue was in the `FuelLogDashboardView` where it was checking the wrong loading state property:

1. **Wrong Loading State Check**: The view was checking `viewModel.isLoading` instead of `viewModel.isLoadingInitialData`
2. **Race Condition**: The `loadInitialData()` method is called asynchronously in the `init`, but the view was being rendered before the data was loaded
3. **Premature Onboarding Display**: The view was showing the onboarding card before the nutrition goals could be loaded from the database

## Solution

### Fixed Loading State Check
**File**: `work/Views/FuelLogDashboardView.swift`

**Before**:
```swift
if viewModel.isLoading {
    LoadingView(message: "Loading nutrition data...")
        .frame(height: 200)
} else if !viewModel.hasNutritionGoals {
    // Onboarding state when no goals are set
    nutritionGoalsOnboardingCard
} else {
    // Main dashboard content
    // ...
}
```

**After**:
```swift
if viewModel.isLoadingInitialData {
    LoadingView(message: "Loading nutrition data...")
        .frame(height: 200)
} else if !viewModel.hasNutritionGoals {
    // Onboarding state when no goals are set
    nutritionGoalsOnboardingCard
} else {
    // Main dashboard content
    // ...
}
```

### Added Refresh State Management
**File**: `work/Views/FuelLogDashboardView.swift`

**Added**:
```swift
.refreshable {
    await viewModel.refresh()
}
.disabled(viewModel.isRefreshing)
```

## Technical Details

### Loading States in FuelLogViewModel
The `FuelLogViewModel` has multiple loading states for different operations:

1. **`isLoadingInitialData`**: Used during initial data loading (nutrition goals + food logs)
2. **`isLoading`**: Used for general loading operations
3. **`isRefreshing`**: Used during pull-to-refresh operations
4. **`isLoadingGoals`**: Used specifically for loading nutrition goals

### Data Loading Flow
1. `FuelLogViewModel.init()` calls `loadInitialData()` asynchronously
2. `loadInitialData()` sets `isLoadingInitialData = true`
3. Loads nutrition goals from database
4. Loads food logs for selected date
5. Sets `isLoadingInitialData = false`
6. View updates to show main dashboard content

## Result
- ✅ Nutrition goals are properly loaded before determining if onboarding is needed
- ✅ Loading state is correctly displayed during initial data fetch
- ✅ Onboarding card only shows when nutrition goals are actually missing
- ✅ Main dashboard content displays correctly when goals exist
- ✅ Pull-to-refresh is disabled during refresh operations to prevent conflicts

## Files Modified
1. `work/Views/FuelLogDashboardView.swift` - Fixed loading state check and added refresh state management

## Testing
- ✅ Open Nutrition tab when goals are set → Shows main dashboard
- ✅ Open Nutrition tab when goals are not set → Shows onboarding card
- ✅ Loading state displays correctly during initial load
- ✅ Refresh functionality works without conflicts 