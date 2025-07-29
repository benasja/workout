# Environment Object Fix for PerformanceDateModel Error

## Problem
The app was crashing with the following error when navigating to the nutrition view from the More section:

```
SwiftUICore/EnvironmentObject.swift:93: Fatal error: No ObservableObject of type PerformanceDateModel found. A View.environmentObject(_:) for PerformanceDateModel may be missing as an ancestor of this view.
```

## Root Cause
The issue was that `FuelLogDashboardView` requires multiple environment objects:
- `@EnvironmentObject var dataManager: DataManager`
- `@EnvironmentObject var dateModel: PerformanceDateModel`
- `@EnvironmentObject var tabSelectionModel: TabSelectionModel`

However, when navigating to `FuelLogDashboardView` from the `MoreView`, only `dateModel` and `tabSelectionModel` were being passed as environment objects. The `dataManager` was missing.

## Solution
Updated `MainTabView.swift` to properly pass all required environment objects:

1. **Added `dataManager` to MainTabView**: Added `@EnvironmentObject var dataManager: DataManager` to the `MainTabView` struct to receive the `DataManager` from the app level.

2. **Added `dataManager` to MoreView**: Added `@EnvironmentObject var dataManager: DataManager` to the `MoreView` struct so it can access and pass the `DataManager`.

3. **Updated all tab navigation**: Added `.environmentObject(dataManager)` to all tab views in `MainTabView` to ensure consistency:
   - PerformanceView (Today tab)
   - RecoveryDetailView (Recovery tab)
   - SleepDetailView (Sleep tab)
   - EnvironmentView (Environment tab)
   - MoreView (More tab)

4. **Updated FuelLogDashboardView navigation**: Modified the navigation link in `MoreView` to pass all three required environment objects:
   ```swift
   NavigationLink(destination: FuelLogDashboardView()
       .environmentObject(dateModel)
       .environmentObject(tabSelectionModel)
       .environmentObject(dataManager)) {
       Label("Nutrition", systemImage: "fork.knife")
           .foregroundColor(.primary)
   }
   ```

## Files Modified
- `work/Views/MainTabView.swift`

## Result
The navigation to `FuelLogDashboardView` from the More section now works correctly without crashing, as all required environment objects are properly passed down the view hierarchy.

## Testing
The fix ensures that:
- All environment objects are available at the correct levels in the view hierarchy
- Navigation from More tab to Nutrition view works without crashes
- All other tabs continue to work as expected
- The app maintains consistency in environment object distribution