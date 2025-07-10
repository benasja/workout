# Sleep Score Algorithm Documentation

## Overview

The Sleep Score Algorithm is a world-class, multi-component assessment system that provides a highly accurate, physiologically-grounded evaluation of a night's restorative quality. The algorithm processes raw Apple HealthKit data to produce a single, actionable score from 0-100.

## Core Philosophy

The score quantifies true restoration. It is not enough to be asleep; the body must be recovering efficiently. The algorithm is sensitive to:
- Sleep quality and efficiency
- Autonomic nervous system recovery
- Circadian rhythm stability
- Physiological markers of restoration

## Required HealthKit Data Inputs

The algorithm processes the following data types for a given night:

1. **HKCategoryTypeIdentifierSleepAnalysis**: Determines time in bed, time asleep, and duration spent in each sleep stage (Deep, REM, Core/Light)
2. **HKQuantityTypeIdentifierHeartRate**: Calculates average heart rate during sleep
3. **HKQuantityTypeIdentifierRestingHeartRate**: Fetches daily resting heart rate as baseline
4. **HKQuantityTypeIdentifierRespiratoryRate**: Average breathing rate during sleep (future enhancement)

## Algorithm Structure

The final Total_Sleep_Score is the sum of three weighted components:

```
Total_Sleep_Score = (Efficiency_Component × 0.35) + (Quality_Component × 0.45) + (Timing_Component × 0.20)
```

### 1. Efficiency & Duration Component (35% Weight)

Measures how well you used your time in bed.

#### Sub-component A: Sleep Efficiency (50% of this component)
- **Calculation**: `Sleep_Efficiency = (Time_Asleep_in_Seconds / Time_in_Bed_in_Seconds)`
- **Scoring**: `Efficiency_Score = Sleep_Efficiency × 100`
- **Impact**: Directly penalizes restlessness and time spent awake in bed

#### Sub-component B: Sleep Duration (50% of this component)
- **Calculation**: Uses a Gaussian (bell curve) model with peak at 8 hours
- **Formula**: `Duration_Score = 100 × exp(-0.5 × pow(Deviation / 1.5, 2))`
- **Impact**: Penalizes both significant under-sleeping and over-sleeping

**Final Component Score**: `Efficiency_Component = (Efficiency_Score × 0.5) + (Duration_Score × 0.5)`

### 2. Restorative Quality Component (45% Weight)

The most heavily weighted component, measuring deep physiological recovery.

#### Sub-component A: Deep Sleep (40% of this component)
- **Calculation**: `Deep_Sleep_Percentage = (Time_in_Deep_Sleep / Time_Asleep) × 100`
- **Scoring**: Scored against ideal physiological range of 13-23%
- **Formula**: `Deep_Score = normalize(Deep_Sleep_Percentage, min=13, max=23)`

#### Sub-component B: REM Sleep (30% of this component)
- **Calculation**: `REM_Sleep_Percentage = (Time_in_REM_Sleep / Time_Asleep) × 100`
- **Scoring**: Scored against ideal range of 20-25%
- **Formula**: `REM_Score = normalize(REM_Sleep_Percentage, min=20, max=25)`

#### Sub-component C: Sleeping Heart Rate Dip (30% of this component)
- **Calculation**: `HR_Dip_Percentage = 1 - (Average_Sleeping_HR / Daily_RHR)`
- **Scoring**: `HR_Dip_Score = HR_Dip_Percentage × 100 × 5` (clamped at 100)
- **Impact**: Larger dip indicates better autonomic recovery

**Final Component Score**: `Quality_Component = (Deep_Score × 0.4) + (REM_Score × 0.3) + (HR_Dip_Score × 0.3)`

### 3. Timing & Consistency Component (20% Weight)

Rewards stable circadian rhythm, crucial for hormonal regulation.

#### Calculation
- **Bedtime_Deviation_Minutes**: `abs(Today_Bedtime - Baseline_Bedtime_14_Day)`
- **Wakeup_Deviation_Minutes**: `abs(Today_Wakeup - Baseline_Wakeup_14_Day)`
- **Total_Deviation**: `Bedtime_Deviation_Minutes + Wakeup_Deviation_Minutes`

#### Scoring
- **Formula**: `Timing_Score = max(0, 100 - (Total_Deviation / 1.8))`
- **Impact**: Perfect score for 0 deviation, 0 score for 3+ hours deviation

**Final Component Score**: `Timing_Component = Timing_Score`

## Implementation Details

### Key Classes

1. **SleepScoreCalculator**: Main calculator class with static shared instance
2. **SleepScoreResult**: Result structure containing final score and components
3. **SleepScoreDetails**: Detailed metrics and calculations
4. **SleepScoreError**: Error handling for various failure scenarios

### Data Flow

1. **Data Fetching**: Concurrent fetching of sleep, heart rate, and baseline data
2. **Component Calculation**: Parallel calculation of all three components
3. **Score Aggregation**: Weighted combination of components
4. **Key Findings Generation**: Contextual insights based on component scores

### Error Handling

The algorithm gracefully handles missing data:
- Missing heart rate data: Neutral score (50) for HR dip component
- Missing baseline data: Neutral score (50) for timing component
- Missing sleep data: Returns appropriate error

## Usage Examples

### Basic Usage
```swift
let sleepScore = try await SleepScoreCalculator.shared.calculateSleepScore(for: Date())
print("Sleep Score: \(sleepScore.finalScore)")
print("Key Findings: \(sleepScore.keyFindings)")
```

### Detailed Analysis
```swift
let sleepScore = try await SleepScoreCalculator.shared.calculateSleepScore(for: Date())
print("Efficiency Component: \(sleepScore.efficiencyComponent)")
print("Quality Component: \(sleepScore.qualityComponent)")
print("Timing Component: \(sleepScore.timingComponent)")
```

### Historical Data
```swift
let detailedScores = await HealthKitManager.shared.getDetailedSleepScores(
    from: startDate, 
    to: endDate
)
```

## UI Integration

### DetailedSleepScoreView
A comprehensive view that displays:
- Main score with color-coded assessment
- Component breakdown with progress bars
- Key findings and insights
- Detailed metrics grid
- Sleep schedule information

### Integration Points
- **TodayView**: Tap sleep card to show detailed analysis
- **PerformanceDashboardView**: Uses new algorithm for daily scores
- **SleepAnalysisView**: Historical trend analysis
- **JournalView**: Sleep score display in journal entries

## Testing

The algorithm includes comprehensive test cases:
- **Optimal Sleep**: 8 hours, good efficiency, optimal sleep stages
- **Poor Sleep**: 6 hours, low efficiency, poor sleep stages
- **Moderate Sleep**: 7.2 hours, moderate efficiency, suboptimal stages

Expected score ranges:
- Optimal: 80-100
- Good: 60-79
- Fair: 40-59
- Poor: 0-39

## Performance Considerations

- **Async Operations**: All HealthKit queries are asynchronous
- **Concurrent Fetching**: Data is fetched in parallel for optimal performance
- **Caching**: Baseline data is cached in DynamicBaselineEngine
- **Error Recovery**: Graceful fallback to simple calculations if detailed data unavailable

## Future Enhancements

1. **Respiratory Rate Integration**: Add breathing rate analysis
2. **Sleep Onset Latency**: Time to fall asleep analysis
3. **Wake After Sleep Onset**: Number and duration of awakenings
4. **Sleep Cycle Analysis**: Pattern recognition for sleep cycles
5. **Environmental Factors**: Temperature, noise, light exposure
6. **Lifestyle Correlation**: Exercise, nutrition, stress impact

## Scientific Basis

The algorithm is based on established sleep science:
- **Sleep Efficiency**: Standard metric in sleep medicine
- **Sleep Stage Percentages**: Based on AASM guidelines
- **Heart Rate Variability**: Autonomic nervous system recovery indicator
- **Circadian Rhythm**: Importance of consistent sleep timing
- **Gaussian Duration Model**: Reflects natural sleep duration distribution

## Conclusion

This sleep score algorithm provides a comprehensive, scientifically-grounded assessment of sleep quality that goes beyond simple duration metrics. It considers multiple physiological factors to give users actionable insights into their sleep health and recovery patterns. 