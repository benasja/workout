# Sleep and Recovery Score Formulas

## Overview
This document contains all the formulas used for calculating Sleep Scores and Recovery Scores in the app.

---

## RECOVERY SCORE FORMULA

### Final Recovery Score Calculation
```
Total_Recovery_Score = (HRV_Component × 0.35) + (RHR_Component × 0.20) + (Sleep_Component × 0.35) + (Stress_Component × 0.10)
```

### 1. HRV Component (35% Weight)

**Current Formula:**
```swift
// Calculate the ratio of today's HRV to 60-day baseline
let hrvRatio = hrv / baseline

// Apply logarithmic scoring
let hrvScoreRaw = 100 * (0.5 + 0.5 * log10(hrvRatio))

// Clamp the score between 0 and 100
let clampedScore = clamp(hrvScoreRaw, min: 0, max: 100)
let contribution = clampedScore * 0.35
```

**Example with your data:**
- Your HRV: 70ms
- Baseline HRV: 61.7ms
- Ratio: 70/61.7 = 1.13
- Score: 100 * (0.5 + 0.5 * log10(1.13)) = 100 * (0.5 + 0.5 * 0.053) = 100 * 0.5265 = 52.65
- Final: 52.65/100

### 2. RHR Component (20% Weight)

**Current Formula:**
```swift
// Calculate the ratio of baseline RHR to today's RHR (lower RHR is better)
let rhrRatio = baseline / rhr

// Scoring logic
let rhrScoreRaw: Double
if rhrRatio >= 1.05 {
    // RHR is significantly below baseline (excellent)
    rhrScoreRaw = 100 * (0.9 + 0.1 * rhrRatio)
} else if rhrRatio >= 1.0 {
    // RHR is at or slightly below baseline (good)
    rhrScoreRaw = 100 * (0.7 + 0.3 * rhrRatio)
} else {
    // RHR is above baseline (bad) - exponential penalty
    let deviation = 1.0 - rhrRatio
    rhrScoreRaw = 100 * exp(-3.0 * deviation)
}

let clampedScore = clamp(rhrScoreRaw, min: 0, max: 100)
let contribution = clampedScore * 0.20
```

**Example with your data:**
- Your RHR: 56 BPM
- Baseline RHR: 60.1 BPM
- Ratio: 60.1/56 = 1.07
- Since 1.07 >= 1.05: Score = 100 * (0.9 + 0.1 * 1.07) = 100 * 1.007 = 100.7
- Final: 100/100 (clamped)

### 3. Sleep Component (35% Weight)

**Current Formula:**
```swift
// Uses the final score from Sleep Score algorithm
let contribution = Double(sleepScore) * 0.35
```

**Example with your data:**
- Sleep Score: 71/100
- Contribution: 71 * 0.35 = 24.85

### 4. Stress Component (10% Weight)

**Current Formula:**
```swift
// Calculate deviations from baseline for:
// - Respiratory Rate
// - Oxygen Saturation  
// - Walking Heart Rate

// For each metric:
let deviation = abs((current - baseline) / baseline) * 100

// Apply weights:
// Respiratory Rate: deviation * 1.5
// Oxygen Saturation: deviation * 2.0
// Walking HR: deviation * 1.2

// Calculate weighted average deviation
let averageDeviation = deviations.reduce(0, +) / Double(deviations.count)

// Stress scoring:
let stressScore: Double
if averageDeviation <= 5.0 {
    stressScore = 100 - (averageDeviation * 2.0)
} else if averageDeviation <= 15.0 {
    stressScore = 90 - ((averageDeviation - 5.0) * 3.0)
} else {
    let excessDeviation = averageDeviation - 15.0
    stressScore = max(0, 75 - (excessDeviation * excessDeviation * 0.5))
}

let contribution = stressScore * 0.10
```

**Example with your data:**
- Stress Score: 94.8/100
- Contribution: 94.8 * 0.10 = 9.48

---

## SLEEP SCORE FORMULA

### Final Sleep Score Calculation
```
Total_Sleep_Score = (Restoration_Component × 0.50) + (Efficiency_Component × 0.30) + (Consistency_Component × 0.20)
```

### 1. Restoration Component (50% Weight)

**Current Formula:**
```swift
private func calculateRestorationComponent(
    timeAsleep: TimeInterval,
    deepSleepDuration: TimeInterval,
    remSleepDuration: TimeInterval,
    averageHeartRate: Double,
    dailyRestingHeartRate: Double,
    enhancedHRV: EnhancedHRVData?
) -> Double {
    let hoursAsleep = timeAsleep / 3600
    let deepPercentage = deepSleepDuration / timeAsleep
    let remPercentage = remSleepDuration / timeAsleep
    
    // Duration score
    let optimal = 8.0
    let deviation = abs(hoursAsleep - optimal)
    let durationScore = 100 * exp(-0.5 * pow(deviation / 1.5, 2))
    
    // Deep sleep score
    let deepScore = normalizeScore(deepPercentage * 100, min: 13, max: 23)
    
    // REM sleep score  
    let remScore = normalizeScore(remPercentage * 100, min: 20, max: 25)
    
    // Heart rate dip score
    let hrDipScore = calculateOnsetScore(from: result) // This seems wrong - should be HR dip calculation
    
    // Weighted average
    let restorationScore = (durationScore * 0.30) + (deepScore * 0.25) + (remScore * 0.25) + (hrDipScore * 0.20)
    
    return restorationScore
}
```

**Normalize Score Function:**
```swift
private func normalizeScore(_ value: Double, min: Double, maxValue: Double) -> Double {
    if value < min {
        // Smooth curve for values below minimum
        return 60 * (value / min) * (value / min)
    }
    if value > maxValue {
        // Smooth curve for values above maximum
        let excess = value - maxValue
        let penalty = excess * 3.0
        return max(60, 100 - penalty)
    }
    // Smooth curve within optimal range
    let optimal = (min + maxValue) / 2
    let deviation = abs(value - optimal)
    let maxDeviation = (maxValue - min) / 2
    let normalizedDeviation = deviation / maxDeviation
    return 100 - (normalizedDeviation * normalizedDeviation * 40)
}
```

**Example with your data:**
- Time Asleep: 6.89 hours
- Deep Sleep: 14.4% (0.99 hours)
- REM Sleep: 34.6% (2.38 hours)
- Duration Score: 100 * exp(-0.5 * pow((6.89-8.0)/1.5, 2)) = 100 * exp(-0.5 * 0.55) = 100 * 0.76 = 76
- Deep Score: normalizeScore(14.4, min: 13, max: 23) = 100 (within optimal range)
- REM Score: normalizeScore(34.6, min: 20, max: 25) = 4.17 (above optimal range, penalized)
- Restoration Score: (76 * 0.30) + (100 * 0.25) + (4.17 * 0.25) + (HR dip score * 0.20) = 45.34

### 2. Efficiency Component (30% Weight)

**Current Formula:**
```swift
private func calculateEfficiencyComponent(timeInBed: TimeInterval, timeAsleep: TimeInterval) -> Double {
    let efficiency = timeAsleep / timeInBed
    return efficiency * 100 // Direct percentage
}
```

**Example with your data:**
- Time in Bed: 7.07 hours
- Time Asleep: 6.89 hours
- Efficiency: 6.89/7.07 = 97.5%
- Score: 97.5/100

### 3. Consistency Component (20% Weight)

**Current Formula:**
```swift
private func calculateConsistencyComponent(
    bedtime: Date?,
    wakeTime: Date?,
    baselineBedtime: Date?,
    baselineWakeTime: Date?
) -> Double {
    guard let bedtime = bedtime, let wakeTime = wakeTime,
          let baselineBedtime = baselineBedtime, let baselineWakeTime = baselineWakeTime else {
        return 70 // Default score if no baseline data
    }
    
    let calendar = Calendar.current
    
    // Calculate bedtime deviation
    let bedtimeDeviation = abs(bedtime.timeIntervalSince(baselineBedtime)) / 60 // in minutes
    let wakeDeviation = abs(wakeTime.timeIntervalSince(baselineWakeTime)) / 60 // in minutes
    
    let totalDeviation = bedtimeDeviation + wakeDeviation
    
    // Consistency scoring
    if totalDeviation <= 15 {
        return 100 // Excellent consistency
    } else if totalDeviation <= 30 {
        return 90 // Very good consistency
    } else if totalDeviation <= 45 {
        return 80 // Good consistency
    } else if totalDeviation <= 60 {
        return 70 // Fair consistency
    } else if totalDeviation <= 90 {
        return 60 // Poor consistency
    } else {
        return max(0, 60 - (totalDeviation - 90) * 0.5) // Very poor consistency
    }
}
```

**Example with your data:**
- Bedtime: 22:17
- Baseline Bedtime: 22:05
- Deviation: 12.8 minutes
- Score: 92.9/100

---

## YOUR CURRENT DATA ANALYSIS

### Sleep Data (2025-07-09 night):
- Time in Bed: 7.07 hours
- Time Asleep: 6.89 hours
- Sleep Efficiency: 97.5%
- Deep Sleep: 0.99 hours (14.4%)
- REM Sleep: 2.38 hours (34.6%)
- Bedtime: 22:17
- Wake Time: 05:21
- Baseline Bedtime: 22:05
- Baseline Wake: 05:06

### Recovery Data (2025-07-10):
- HRV: 70.4ms (baseline: 61.7ms)
- RHR: 56 BPM (baseline: 60.1 BPM)
- Sleep Score: 71/100
- Stress Score: 94.8/100

### Current Scores:
- **Sleep Score**: 71/100
  - Restoration: 45.34/100
  - Efficiency: 97.5/100
  - Consistency: 92.9/100
  - Total: (45.34×0.50) + (97.5×0.30) + (92.9×0.20) = 22.67 + 29.25 + 18.58 = 70.5 ≈ 71

- **Recovery Score**: 98/100
  - HRV: 52.65/100 (contribution: 18.43)
  - RHR: 100/100 (contribution: 20.0)
  - Sleep: 71/100 (contribution: 24.85)
  - Stress: 94.8/100 (contribution: 9.48)
  - Total: 18.43 + 20.0 + 24.85 + 9.48 = 72.76 ≈ 73 (but showing 98 - there's a bug!)

---

## ISSUES IDENTIFIED

1. **Recovery Score Bug**: The calculation shows 72.76 but displays 98 - there's a calculation error somewhere
2. **RHR Too Generous**: RHR of 56 vs 60.1 baseline shouldn't get 100/100
3. **HRV Too Low**: HRV of 70.4 vs 61.7 baseline should score higher than 52.65
4. **Sleep Score Too Low**: Good sleep data (97.5% efficiency, good consistency) should score higher than 71
5. **REM Sleep Penalty Too Harsh**: 34.6% REM is being heavily penalized when it's actually good

---

## RECOMMENDED FIXES

1. **Fix Recovery Score Calculation Bug**
2. **Make RHR scoring stricter** - only 10%+ below baseline gets 100
3. **Make HRV scoring more generous** - 15% above baseline should get 85+
4. **Relax REM sleep scoring** - 20-35% should be considered good
5. **Increase sleep efficiency weight** - 97.5% efficiency should contribute more to final score 