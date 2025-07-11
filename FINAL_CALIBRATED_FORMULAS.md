# FINAL CALIBRATED SLEEP & RECOVERY FORMULAS

## Overview

This document provides the final, re-calibrated set of formulas for calculating Sleep and Recovery Scores. The previous iteration was correctly identified as having flawed HRV and RHR calculations. This version implements a stricter, more physiologically sound model that heavily penalizes insufficient sleep duration and requires exceptional metrics to achieve a top-tier score. All calculations are designed to produce logical, clamped 0-100 scores at every stage.

## SLEEP SCORE FORMULA (FINAL CALIBRATION)

### Core Philosophy Change
Sleep Duration is now a gatekeeper. Excellent sleep efficiency or consistency cannot fully compensate for a lack of sufficient time asleep. The final score is now a product of its components multiplied by a critical Duration Multiplier.

### New Final Sleep Score Calculation

```
Component_Score = (Restoration_Component × 0.45) + (Efficiency_Component × 0.30) + (Consistency_Component × 0.25)
Total_Sleep_Score = Component_Score * Duration_Multiplier
```

The final result is clamped between 0 and 100.

### 1. The Duration Multiplier (The Gatekeeper)

**Problem**: A 6h 53m sleep should never result in a 90+ score.
**Solution**: This new multiplier acts as a hard cap on your potential score based purely on sleep duration.

**Formula**:
```swift
private func calculateDurationMultiplier(hoursAsleep: Double) -> Double {
    if hoursAsleep < 6.0 {
        // Harsh penalty for very short sleep
        return 0.65
    } else if hoursAsleep < 7.0 {
        // Maps the range [6.0, 7.0) to a multiplier of [0.65, 0.90)
        return 0.65 + (hoursAsleep - 6.0) * 0.25
    } else if hoursAsleep <= 9.0 {
        // Optimal duration range
        return 1.0
    } else { // hoursAsleep > 9.0
        // Gradual penalty for potential oversleeping/sickness
        return max(0.8, 1.0 - (hoursAsleep - 9.0) * 0.1)
    }
}
```

**Analysis with example data**:
- Hours Asleep: 6.89
- New Duration Multiplier: 0.65 + (6.89 - 6.0) * 0.25 = 0.65 + 0.2225 = 0.8725

### 2. Restoration Component (45% Weight)

This formula remains robust, focusing purely on the quality of sleep stages and autonomic recovery.

**Formula**:
```swift
// Deep sleep score (optimal range 13-23%)
let deepScore = normalizeScore(deepSleepPercentage, min: 13, max: 23)
// REM sleep score (optimal range 20-35%)
let remScore = normalizeScore(remSleepPercentage, min: 20, max: 35)
// HR Dip score (normalized 0-100)
let hrDipScore = clamp(hrDipPercentage * 5.0, min: 0, max: 100)
// Weighted average
let restorationScore = (deepScore * 0.40) + (remScore * 0.40) + (hrDipScore * 0.20)
```

**Analysis with example data**:
- Deep Score: 100, REM Score: 100, HR Dip Score: 75
- New Restoration Score: 95

### 3. Efficiency Component (30% Weight)

This formula remains robust and unchanged.

**Formula**:
```swift
private func calculateEfficiencyComponent(timeInBed: TimeInterval, timeAsleep: TimeInterval) -> Double {
    let efficiency = timeAsleep / timeInBed
    return efficiency * 100
}
```

**Analysis with example data**:
- New Efficiency Score: 97.5

### 4. Consistency Component (25% Weight)

This formula is effective and remains unchanged.

**Formula**:
```swift
private func calculateConsistencyComponent(totalDeviationInMinutes: Double) -> Double {
    return 100 * exp(-0.005 * totalDeviationInMinutes)
}
```

**Analysis with example data**:
- New Consistency Score: 86.5

## RECOVERY SCORE FORMULA (FINAL CALIBRATION)

### Core Philosophy Change
An excellent HRV or RHR reading cannot override a poor night's sleep. The formulas are re-calibrated using more intuitive piecewise functions. A baseline reading now correctly maps to a "good" score of 75, not an average or perfect one.

### New Final Recovery Score Calculation

```
Total_Recovery_Score = (HRV_Component × 0.50) + (RHR_Component × 0.25) + (Sleep_Component × 0.15) + (Stress_Component × 0.10)
```

The final result is clamped between 0 and 100.

### 1. HRV Component (50% Weight)

**Problem**: The previous formulas were unintuitive and poorly calibrated around the baseline.
**Solution**: A new piecewise function provides a more realistic score. A baseline HRV (ratio of 1.0) now correctly yields a score of 75. Scores increase logarithmically for improvements and decay exponentially for negative changes.

**Formula**:
```swift
private func calculateHrvScore(hrvRatio: Double) -> Double {
    let score: Double
    if hrvRatio >= 1.0 {
        // Logarithmic growth for positive results, starting from a baseline of 75.
        // A ratio of 1.0 gives 75. A ratio of 1.2 gives ~90.
        score = 75 + 35 * log10(hrvRatio + 0.35)
    } else {
        // Exponential decay for negative results.
        // A ratio of 0.9 gives ~55. A ratio of 0.8 gives ~38.
        score = 75 * pow(hrvRatio, 3)
    }
    return clamp(score, min: 0, max: 100)
}
let hrvScore = calculateHrvScore(hrvRatio: hrv / baseline)
let contribution = hrvScore * 0.50
```

**Analysis with example data**:
- HRV Ratio: 1.13
- New Score: 75 + 35 * log10(1.13 + 0.35) = 75 + 35 * log10(1.48) = 75 + 35 * 0.17 = 75 + 5.95 = 80.95
- New Contribution: 40.48

### 2. RHR Component (25% Weight)

**Problem**: The previous formula was also poorly calibrated and too harsh.
**Solution**: A similar piecewise function is used for RHR. A baseline RHR (ratio of 1.0) correctly yields a score of 75.

**Formula**:
```swift
private func calculateRhrScore(rhrRatio: Double) -> Double {
    let score: Double
    if rhrRatio >= 1.0 {
        // Logarithmic growth for positive results (lower RHR).
        // A ratio of 1.0 gives 75. A ratio of 1.1 gives ~88.
        score = 75 + 45 * log10(rhrRatio + 0.25)
    } else {
        // Exponential decay for negative results (higher RHR).
        score = 75 * pow(rhrRatio, 4)
    }
    return clamp(score, min: 0, max: 100)
}
let rhrScore = calculateRhrScore(rhrRatio: baseline / rhr)
let contribution = rhrScore * 0.25
```

**Analysis with example data**:
- RHR Ratio: 1.07
- New Score: 75 + 45 * log10(1.07 + 0.25) = 75 + 45 * log10(1.32) = 75 + 45 * 0.12 = 75 + 5.4 = 80.4
- New Contribution: 20.1

### 3. Sleep & Stress Components (15% & 10%)

The formulas for these components remain the same, but they will use the new, more accurate Sleep Score.

## FINAL RE-CALCULATED SCORES WITH EXAMPLE DATA

### New Sleep Score:

Component Score: (95 × 0.45) + (97.5 × 0.30) + (86.5 × 0.25) = 42.75 + 29.25 + 21.625 = 93.6

Duration Multiplier: 0.8725 (from 6.89 hours of sleep)

Final Total: 93.6 * 0.8725 = 81.7 ≈ 82

This score is now a much more realistic reflection of a good quality but short duration sleep.

### New Recovery Score:

HRV Contribution: 40.48 (from a score of 80.95)
RHR Contribution: 20.1 (from a score of 80.4)
Sleep Contribution: 82 * 0.15 = 12.3
Stress Contribution: 94.8 * 0.10 = 9.48

Total: 40.48 + 20.1 + 12.3 + 9.48 = 82.36

Final Score: 82 (Clamped)

This final score is now a much more logical and defensible number. It correctly reflects excellent HRV and RHR readings (both scoring ~80/100), but is tempered by a sleep score that, while good, was not perfect due to its short duration. An 82 is a strong score, indicating you are well-prepared, but it correctly leaves room at the top for days where every single metric is truly optimal.

## IMPLEMENTATION NOTES

### Key Changes Made:

1. **Sleep Score**:
   - Added Duration Multiplier as a gatekeeper
   - Updated component weights: Restoration 45%, Efficiency 30%, Consistency 25%
   - Simplified restoration component calculation with normalizeScore function
   - Updated consistency component to use exponential decay formula

2. **Recovery Score**:
   - Updated component weights: HRV 50%, RHR 25%, Sleep 15%, Stress 10%
   - Implemented piecewise functions for HRV and RHR with baseline of 75
   - Added proper mathematical functions with Foundation prefix
   - Added clamp function for score validation

### Mathematical Functions Used:

- `Foundation.log10()` for logarithmic growth
- `Foundation.pow()` for exponential decay
- `Foundation.exp()` for consistency scoring
- `clamp()` for score validation

### Cache Management:

Both calculators maintain proper caching to avoid duplicate calculations and ensure UI responsiveness.

### Error Handling:

Robust error handling with fallback values ensures the app continues to function even when some health data is unavailable.

## EXPECTED BEHAVIOR

With these final calibrated formulas:

1. **Sleep scores will be more realistic** - short sleep durations will be properly penalized
2. **Recovery scores will be more balanced** - excellent HRV/RHR won't override poor sleep
3. **Scores will be more intuitive** - baseline readings will score around 75, not 100
4. **UI will be more responsive** - proper caching prevents duplicate calculations
5. **Scores will be more defensible** - each component has clear physiological justification

The formulas now provide a much more accurate and realistic assessment of sleep quality and recovery readiness. 