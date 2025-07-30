# Overnight Recovery Score Implementation

## Overview

This document describes the implementation of a proper Recovery Score system that captures overnight physiological data as a static snapshot, following industry best practices used by companies like Whoop and Oura.

## Problem Solved

**Previous Issue**: The recovery score was calculated using data fetched throughout the day, creating a "Live Status" monitor that would change based on daily activities (e.g., stressful meetings affecting HRV).

**Solution**: Implement a true Recovery Score that:
1. Uses only overnight data from the sleep session
2. Calculates once in the morning and remains static throughout the day
3. Provides a stable baseline for daily planning

## Key Changes

### 1. HealthKitManager Enhancements

Added new methods to fetch data within specific date intervals:

```swift
// Fetch the main sleep session for a given wake date
func fetchMainSleepSession(for wakeDate: Date, completion: @escaping (DateInterval?) -> Void)

// Fetch health data within specific intervals (for overnight analysis)
func fetchHRVForInterval(_ interval: DateInterval, completion: @escaping (Double?) -> Void)
func fetchRHRForInterval(_ interval: DateInterval, completion: @escaping (Double?) -> Void)
func fetchWalkingHeartRateForInterval(_ interval: DateInterval, completion: @escaping (Double?) -> Void)
func fetchRespiratoryRateForInterval(_ interval: DateInterval, completion: @escaping (Double?) -> Void)
func fetchOxygenSaturationForInterval(_ interval: DateInterval, completion: @escaping (Double?) -> Void)
```

### 2. Persistent Storage System

Created a new `RecoveryScore` model with comprehensive data storage:

```swift
@Model
final class RecoveryScore {
    var id: UUID
    var date: Date
    var score: Int
    var calculatedAt: Date
    var sleepSessionStart: Date
    var sleepSessionEnd: Date
    
    // Component scores and raw metrics
    var hrvScore: Double
    var rhrScore: Double
    var sleepScore: Double
    var stressScore: Double
    
    // Raw metrics and baseline values
    var hrvValue: Double?
    var rhrValue: Double?
    var sleepScoreValue: Int?
    var walkingHRValue: Double?
    var respiratoryRateValue: Double?
    var oxygenSaturationValue: Double?
    
    // Baseline values at time of calculation
    var baselineHRV: Double?
    var baselineRHR: Double?
    var baselineWalkingHR: Double?
    var baselineRespiratoryRate: Double?
    var baselineOxygenSaturation: Double?
    
    // Descriptions and directives
    var directive: String
    var hrvDescription: String
    var rhrDescription: String
    var sleepDescription: String
    var stressDescription: String
}
```

### 3. RecoveryScoreCalculator Rewrite

Completely rewrote the calculator to implement the overnight approach:

#### Key Features:
- **Sleep Session Detection**: Finds the main sleep session for the wake date
- **Overnight Data Only**: Fetches HRV, RHR, and stress metrics only during sleep
- **Persistent Storage**: Stores calculated scores permanently
- **Static Results**: Once calculated, scores don't change throughout the day

#### Algorithm Flow:
1. Check if a stored recovery score exists for the date
2. If exists, return the stored score
3. If not, find the main sleep session for the wake date
4. Fetch all health data during the sleep session only
5. Calculate components using the FINAL CALIBRATED algorithm
6. Store the result permanently
7. Return the calculated score

### 4. Updated ViewModels

Modified `HealthStatsViewModel` and `PerformanceDashboardView` to use the new system:

```swift
// The new RecoveryScoreCalculator will automatically check for stored scores first
// and only calculate new ones if none exist for that date
let recoveryResult = try await RecoveryScoreCalculator.shared.calculateRecoveryScore(for: Date())
```

## Data Flow

### Morning Calculation (First App Launch):
1. App detects no stored recovery score for today
2. Finds last night's sleep session (e.g., 11 PM - 6 AM)
3. Fetches HRV, RHR, and stress metrics during that window only
4. Calculates recovery score using overnight data
5. Stores result permanently

### Throughout the Day:
1. App requests recovery score for today
2. Finds stored score from morning calculation
3. Returns static score without recalculation

## Benefits

### 1. True Recovery Assessment
- Measures actual overnight recovery, not daily stress
- Uses lowest RHR during sleep (best recovery state)
- Analyzes HRV during sleep (autonomic recovery)

### 2. Stable Planning Tool
- Score remains constant throughout the day
- Provides reliable baseline for training decisions
- Aligns with industry best practices

### 3. Improved Accuracy
- Eliminates confounding factors from daily activities
- Focuses on physiological recovery markers
- Uses personal baselines for stress assessment

## Technical Implementation

### Sleep Session Detection
```swift
// Fetch sleep samples that end between previous day noon and this day noon
let startOfWindow = calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: wakeDate)!))!
let endOfWindow = calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: wakeDate))!
```

### Overnight Data Fetching
```swift
// Fetch HRV during sleep session only
HealthKitManager.shared.fetchHRVForInterval(sleepSession) { value in
    hrv = value
}

// Fetch RHR during sleep session only (lowest value during sleep)
HealthKitManager.shared.fetchRHRForInterval(sleepSession) { value in
    rhr = value
}
```

### Persistent Storage
```swift
// Store the result permanently so it doesn't change throughout the day
let recoveryScore = RecoveryScore(...)
scoreStore.saveRecoveryScore(recoveryScore)
```

## Usage Example

```swift
// This will return a stored score if it exists, or calculate a new one using overnight data
let recoveryResult = try await RecoveryScoreCalculator.shared.calculateRecoveryScore(for: Date())

print("Recovery Score: \(recoveryResult.finalScore)")
print("Directive: \(recoveryResult.directive)")
print("Sleep Session: \(recoveryResult.sleepSessionStart) to \(recoveryResult.sleepSessionEnd)")
```

## Migration Notes

- Existing recovery score calculations will continue to work
- New overnight system will be used for future calculations
- Stored scores are permanent and don't expire
- Clear cache functionality available for testing

## Testing

The implementation includes comprehensive error handling and fallback mechanisms:

- Graceful handling of missing sleep data
- Fallback to daily data if overnight data unavailable
- Proper error propagation and logging
- Cache validation and integrity checks

## Future Enhancements

1. **Beat-to-Beat Analysis**: Enhanced HRV analysis using beat-to-beat data
2. **Sleep Stage Integration**: Weight different sleep stages in recovery calculation
3. **Trend Analysis**: Historical recovery score trends and patterns
4. **Personalization**: User-specific recovery score calibration
5. **Notifications**: Morning recovery score notifications with recommendations 