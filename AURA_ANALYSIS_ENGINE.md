# Aura Analysis Engine

## Overview

The Aura Analysis Engine is a comprehensive health data analysis system that provides deep insights into recovery readiness and sleep quality. It implements advanced algorithms that combine multiple health metrics to generate actionable insights for optimal performance.

## Core Components

### 1. Recovery Score Algorithm

The Recovery Score is a weighted composite algorithm that quantifies the body's readiness for training stress. It combines four key components:

#### Algorithm Formula
```
Total_Recovery_Score = (HRV_Component * 0.50) + (RHR_Component * 0.25) + (Sleep_Component * 0.15) + (Systemic_Stress_Component * 0.10)
```

#### Component Details

**HRV Component (50% Weight) - The Core of Readiness**
- **Calculation**: Compare today's overnight HRV to 60-day rolling average baseline
- **Formula**: `HRV_Ratio = Today_HRV / Baseline_HRV_60_Day`
- **Scoring**: `HRV_Score = 100 * (1 + log10(HRV_Ratio))` (logarithmic scaling)
- **Range**: Clamped between 0 and 120
- **Logic**: Heavily penalizes drops below baseline, rewards improvements

**RHR Component (25% Weight) - Cardiovascular Load**
- **Calculation**: Compare today's RHR to 60-day baseline (lower is better)
- **Formula**: `RHR_Ratio = Baseline_RHR_60_Day / Today_RHR`
- **Scoring**: `RHR_Score = 100 * RHR_Ratio`
- **Range**: Clamped between 50 and 120
- **Logic**: Lower RHR indicates better recovery state

**Sleep Component (15% Weight) - The Foundation of Recovery**
- **Calculation**: Direct use of the comprehensive Sleep Score from previous night
- **Logic**: Sleep quality directly impacts recovery readiness

**Systemic Stress Component (10% Weight) - Sickness & Strain Indicators**
- **Walking Heart Rate Deviation**: Proxy for wrist temperature changes
- **Respiratory Rate Deviation**: Indicator of respiratory stress
- **Oxygen Saturation**: Below 95% triggers penalty
- **Logic**: Detects underlying stress or illness that may not be apparent

### 2. Enhanced HealthKit Integration

#### Continuous Data Synchronization
- **On-Demand Fetching**: `fetchData(for date: Date)` retrieves all metrics for a specific date
- **Background Refresh**: Automatic data updates when app becomes active
- **Real-time Updates**: Fresh data on every view appearance

#### Required HealthKit Data Types
```swift
let readTypes: Set<HKObjectType> = [
    .heartRateVariabilitySDNN,      // HRV measurements
    .restingHeartRate,              // Resting heart rate
    .sleepAnalysis,                 // Sleep stages and duration
    .respiratoryRate,               // Breathing rate
    .walkingHeartRateAverage,       // Walking heart rate (temp proxy)
    .oxygenSaturation,              // Blood oxygen levels
    .activeEnergyBurned,            // Activity metrics
    .workoutType()                  // Exercise sessions
]
```

### 3. Dynamic Baseline Engine

#### Baseline Types
- **60-day Baselines**: Long-term trends for HRV and RHR
- **14-day Baselines**: Short-term trends for walking HR and respiratory rate
- **Sleep Baselines**: Average bedtime, wake time, and duration

#### Smart Baseline Calculation
- **Time-of-Day Averaging**: Bedtime and wake times calculated as average time of day
- **Rolling Windows**: Continuous updates as new data becomes available
- **Persistence**: Baselines stored in UserDefaults for app restarts

### 4. Interactive UI Components

#### DateSliderView
- **30-day Range**: Horizontal scrolling through the last 30 days
- **Today Indicator**: Visual marker for current date
- **Smooth Navigation**: Tap any date to load historical data
- **Auto-scroll**: Automatically centers on selected date

#### SleepDetailView
- **Main Score Card**: Large display of sleep score with circular progress
- **Timeline Card**: Visual representation of time in bed vs. time asleep
- **Sleep Stages Card**: Bar chart showing deep, REM, and core sleep distribution
- **Efficiency Card**: Time to fall asleep and sleep efficiency metrics

#### RecoveryDetailView
- **Main Score Card**: Recovery score with component breakdown
- **HRV Card**: Current vs. baseline comparison with visual chart
- **RHR Card**: Resting heart rate analysis with trend visualization
- **Systemic Stress Card**: Stress indicators with severity levels

## Implementation Details

### File Structure
```
work/
├── RecoveryScoreCalculator.swift      # Core recovery algorithm
├── HealthKitManager.swift             # Enhanced data fetching
├── DynamicBaselineEngine.swift        # Baseline calculations
├── Views/
│   ├── DateSliderView.swift           # Reusable date selector
│   ├── SleepDetailView.swift          # Detailed sleep analysis
│   ├── RecoveryDetailView.swift       # Detailed recovery analysis
│   ├── RecoveryView.swift             # Recovery tab placeholder
│   └── PerformanceDashboardView.swift # Updated with navigation
```

### Key Classes

#### RecoveryScoreCalculator
- **Singleton Pattern**: Shared instance for app-wide access
- **Async Operations**: Non-blocking calculations
- **Error Handling**: Graceful fallbacks for missing data
- **Debug Logging**: Comprehensive console output for troubleshooting

#### HealthKitManager
- **Batch Operations**: Efficient data fetching for date ranges
- **Background Support**: Ready for background app refresh
- **Permission Management**: Comprehensive HealthKit authorization
- **Data Validation**: Ensures data quality before processing

### Navigation Flow
1. **Performance Tab**: Main dashboard with tappable score cards
2. **Recovery Card Tap**: Navigate to RecoveryDetailView
3. **Sleep Card Tap**: Navigate to SleepDetailView
4. **Date Selection**: Use DateSliderView to explore historical data
5. **Back Navigation**: Return to main dashboard

## Usage Examples

### Calculating Recovery Score
```swift
let calculator = RecoveryScoreCalculator.shared
let result = try await calculator.calculateRecoveryScore(for: Date())
print("Recovery Score: \(result.finalScore)")
print("Directive: \(result.directive)")
```

### Fetching Health Data
```swift
let healthKit = HealthKitManager.shared
healthKit.fetchData(for: Date()) { metrics in
    if let metrics = metrics {
        print("HRV: \(metrics.hrv ?? 0)")
        print("RHR: \(metrics.rhr ?? 0)")
    }
}
```

### Using Date Slider
```swift
DateSliderView(selectedDate: $selectedDate) { date in
    // Load data for selected date
    loadData(for: date)
}
```

## Performance Considerations

### Data Efficiency
- **Lazy Loading**: Data fetched only when needed
- **Caching**: Baselines persisted to avoid recalculation
- **Batch Operations**: Multiple metrics fetched in parallel
- **Memory Management**: Large datasets processed incrementally

### UI Responsiveness
- **Async Operations**: All heavy calculations run in background
- **Loading States**: Clear feedback during data fetching
- **Error Handling**: Graceful degradation when data unavailable
- **Smooth Animations**: Fluid transitions between states

## Debugging and Monitoring

### Console Output
The system provides comprehensive logging:
```
🔄 Calculating Recovery Score for 2025-01-15
✅ Recovery Score calculated: 78
   HRV: 85.2 (weight: 50%)
   RHR: 72.1 (weight: 25%)
   Sleep: 82.0 (weight: 15%)
   Stress: 95.0 (weight: 10%)
```

### Baseline Monitoring
```
💾 Baseline data persisted:
   HRV 60-day: 35.2
   RHR 60-day: 65.1
   Walking HR 14-day: 72.3
   Respiratory Rate 14-day: 14.2
```

## Future Enhancements

### Planned Features
1. **Machine Learning Integration**: Predictive recovery modeling
2. **Custom Baselines**: User-defined baseline periods
3. **Export Functionality**: Data export for external analysis
4. **Notifications**: Recovery alerts and recommendations
5. **Social Features**: Comparison with similar users

### Algorithm Improvements
1. **Seasonal Adjustments**: Account for seasonal variations
2. **Training Load Integration**: Factor in recent exercise intensity
3. **Nutrition Impact**: Consider dietary factors
4. **Stress Metrics**: Additional stress indicators

## Troubleshooting

### Common Issues

**No Data Available**
- Check HealthKit permissions
- Ensure device has collected sufficient data
- Verify baseline calibration status

**Incorrect Scores**
- Review baseline calculations
- Check for data quality issues
- Validate algorithm parameters

**Performance Issues**
- Monitor memory usage
- Check for excessive API calls
- Verify async operation completion

### Debug Commands
```swift
// Reset all baselines
DynamicBaselineEngine.shared.resetBaselines()

// Force baseline recalculation
DynamicBaselineEngine.shared.updateAndStoreBaselines { }

// Check HealthKit authorization
HealthKitManager.shared.requestAuthorization { success in
    print("Authorization: \(success)")
}
```

## Conclusion

The Aura Analysis Engine provides a sophisticated, user-friendly system for understanding and optimizing recovery. By combining multiple health metrics with intelligent algorithms, it delivers actionable insights that help users make informed decisions about their training and recovery strategies.

The modular architecture ensures easy maintenance and future enhancements, while the comprehensive error handling and debugging capabilities make it robust and reliable for production use. 