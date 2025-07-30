# Recovery Tab Midnight Crash Fix

## Problem Description

After 00:00 (midnight), the recovery tab would crash the app when users tried to view today's recovery data. This happened because:

1. **No Sleep Session Available**: After midnight, there hasn't been any sleep session for the current day yet
2. **RecoveryScoreCalculator Throws Error**: When no sleep session is found, the calculator throws `RecoveryScoreError.noSleepSessionFound`
3. **Poor Error Handling**: The `HealthStatsViewModel` and `RecoveryDetailView` didn't properly handle this error case
4. **App Crashes**: The unhandled error caused the app to crash instead of showing a graceful message

## Root Cause Analysis

The issue was in the data flow:

```
RecoveryDetailView → HealthStatsViewModel.loadData() → RecoveryScoreCalculator.calculateRecoveryScore() → HealthKitManager.fetchMainSleepSession()
```

When `fetchMainSleepSession()` returns `nil` (no sleep session found), the `RecoveryScoreCalculator` throws an error, but the `HealthStatsViewModel` didn't handle this gracefully.

## Solution Implemented

### 1. Enhanced HealthStatsViewModel Error Handling

**File**: `work/HealthStatsViewModel.swift`

- **Added Midnight Check**: Before attempting to load data, check if it's today and before 8 AM
- **Graceful Error Messages**: Set appropriate error messages instead of crashing
- **Specific Error Handling**: Handle `RecoveryScoreError.noSleepSessionFound` specifically

```swift
// Check if it's today and before 8 AM - recovery data won't be available yet
let calendar = Calendar.current
let now = Date()
let currentHour = calendar.component(.hour, from: now)

if calendar.isDateInToday(date) && currentHour < 8 {
    await MainActor.run {
        self.isLoading = false
        self.errorMessage = "Recovery data is not yet available for today. It will be calculated once you have completed your sleep session."
        // Clear any existing data to show the error state
        self.recoveryResult = nil
        self.sleepResult = nil
        self.recoveryComponents = []
        self.sleepComponents = []
        self.biomarkerTrends = [:]
    }
    return
}
```

### 2. Updated RecoveryDetailView Error Display

**File**: `work/Views/RecoveryDetailView.swift`

- **Better Error UI**: Changed from warning triangle to moon icon for sleep-related issues
- **User-Friendly Messages**: Show "Recovery Data Not Yet Available" instead of "Unable to load recovery data"
- **Additional Context**: Added explanatory text about when data will be available

```swift
private func errorOverlay(_ error: String) -> some View {
    VStack(spacing: 16) {
        Image(systemName: "moon.zzz")
            .font(.system(size: 40))
            .foregroundColor(.blue)
        
        Text("Recovery Data Not Yet Available")
            .font(.headline)
            .fontWeight(.semibold)
        
        Text(error)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        
        if error.contains("not yet available") {
            Text("Your recovery score will be calculated once you complete your sleep session and wake up.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        
        Button("Try Again") {
            Task {
                await healthStats.refresh()
            }
        }
        .buttonStyle(.borderedProminent)
    }
    .padding()
    .background(AppColors.secondaryBackground)
    .cornerRadius(16)
}
```

### 3. Updated PerformanceDashboardView for Nil Scores

**File**: `work/Views/PerformanceDashboardView.swift`

- **Optional Score Types**: Changed `recoveryScore` and `sleepScore` from `Int` to `Int?`
- **Nil Score Handling**: Updated `CircularScoreGauge` to show "—" when score is nil
- **Updated Directives**: Modified `generateDirective` to handle nil scores gracefully

```swift
struct CircularScoreGauge: View {
    let score: Int?
    let label: String
    let gradient: Gradient
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 18)
            if let score = score {
                Circle()
                    .trim(from: 0, to: CGFloat(score)/100)
                    .stroke(AngularGradient(gradient: gradient, center: .center), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            VStack {
                if let score = score {
                    Text("\(score)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                } else {
                    Text("—")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Text(label)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 140, height: 140)
    }
}
```

## Benefits of the Fix

### 1. **No More Crashes**
- App gracefully handles the case when recovery data is not available
- Users see informative messages instead of crashes

### 2. **Better User Experience**
- Clear messaging about when data will be available
- Consistent with sleep tab behavior (shows "information not yet available")
- Maintains app functionality even when data is missing

### 3. **Consistent Data Display**
- Shows "—" for scores when not available (matches user expectation)
- Proper error states with retry functionality
- Maintains UI consistency across the app

### 4. **Future-Proof**
- Handles edge cases properly
- Easy to extend for other time-based data availability issues
- Robust error handling pattern

## Testing

The fix has been tested to ensure:

1. **Syntax Correctness**: All Swift code compiles without errors
2. **Logic Validation**: Error handling works as expected
3. **UI Consistency**: Error messages are user-friendly and informative

## User Impact

- **Before**: App crashes when viewing recovery tab after midnight
- **After**: App shows "Recovery Data Not Yet Available" with explanation
- **Behavior**: Consistent with sleep tab's "information not yet available" message

The fix ensures that users can safely navigate to the recovery tab at any time without experiencing crashes, while providing clear information about when recovery data will become available. 