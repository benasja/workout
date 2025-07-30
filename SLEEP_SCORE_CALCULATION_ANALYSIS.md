# Sleep Score Calculation - Complete System Analysis

## 🔍 **Current Sleep Score Implementation (V3.0)**

The sleep score system uses **Performance Sleep Score V3.0** as the primary calculation engine, with a separate component description system for the UI breakdown.

## 📊 **1. Final Score Calculation (V3.0)**

### **Master Formula:**
```
Final Sleep Score = Duration Points + Deep Sleep Points + REM Points + Efficiency Points + Consistency Points
```
**Range**: 0-100 (sum is capped at 100, theoretical maximum is 100)

### **Component Point Allocation:**
- **Duration**: 0-30 points (30% weight)
- **Deep Sleep**: 0-25 points (25% weight)  
- **REM Sleep**: 0-20 points (20% weight)
- **Efficiency**: 0-15 points (15% weight)
- **Consistency**: 0-10 points (10% weight)
- **Total Available**: 100 points exactly

## 🎯 **2. Individual Component Calculations**

### **Duration Component (0-30 points)**
**Input**: Time asleep in seconds
**Formula**: Discrete point allocation based on sleep duration

```swift
private func getDurationPoints(for timeAsleepInSeconds: Double) -> Int {
    let minutes = timeAsleepInSeconds / 60
    switch minutes {
    case let m where m > 480: return 30     // 8+ hours
    case 470...480: return 29               // 7h 50m - 8h
    case 460..<470: return 28               // 7h 40m - 7h 50m
    case 450..<460: return 27               // 7h 30m - 7h 40m
    case 440..<450: return 26               // 7h 20m - 7h 30m
    case 430..<440: return 25               // 7h 10m - 7h 20m
    case 420..<430: return 25               // 7h - 7h 10m
    case 410..<420: return 24               // 6h 50m - 7h
    case 400..<410: return 22               // 6h 40m - 6h 50m
    case 390..<400: return 20               // 6h 30m - 6h 40m
    case 380..<390: return 18               // 6h 20m - 6h 30m
    case 370..<380: return 16               // 6h 10m - 6h 20m
    case 360..<370: return 15               // 6h - 6h 10m
    case 330..<360: return 10               // 5h 30m - 6h
    case 300..<330: return 5                // 5h - 5h 30m
    default: return 0                       // < 5h
    }
}
```

**Optimal Range**: 7-8+ hours (25-30 points)
**Scoring Strategy**: Steep penalties below 6h, gentle penalties 6-7h, optimal plateau 7-8h+

### **Deep Sleep Component (0-25 points)**
**Input**: Deep sleep duration in seconds
**Formula**: Discrete point allocation based on deep sleep amount

```swift
private func getDeepSleepPoints(for deepSleepInSeconds: Double) -> Int {
    let minutes = deepSleepInSeconds / 60
    switch minutes {
    case let m where m >= 105: return 25    // 1h 45m+
    case 90..<105: return 22                // 1h 30m - 1h 45m
    case 75..<90: return 18                 // 1h 15m - 1h 30m
    case 60..<75: return 14                 // 1h - 1h 15m
    case 45..<60: return 8                  // 45m - 1h
    default: return 0                       // < 45m
    }
}
```

**Optimal Range**: 1h 45m+ (25 points)
**Scoring Strategy**: Significant credit for 1h+, maximum credit for 1h 45m+

### **REM Sleep Component (0-20 points)**
**Input**: REM sleep duration in seconds
**Formula**: Discrete point allocation with proportional scoring for low values

```swift
private func getREMPoints(for remSleepInSeconds: Double) -> Int {
    let minutes = remSleepInSeconds / 60
    switch minutes {
    case let m where m >= 120: return 20    // 2h+ (maximum)
    case 105..<120: return 18               // 1h 45m - 2h
    case 90..<105: return 16                // 1h 30m - 1h 45m
    case 75..<90: return 13                 // 1h 15m - 1h 30m
    case 60..<75: return 10                 // 1h - 1h 15m
    case 0..<60: return Int((minutes / 60.0) * 5.0)  // Proportional up to 5
    default: return 0
    }
}
```

**Optimal Range**: 1h 45m+ (18-20 points)
**Scoring Strategy**: Proportional scoring below 1h, discrete tiers above 1h

### **Efficiency Component (0-15 points)**
**Input**: Time asleep and time in bed
**Formula**: Sleep efficiency percentage-based discrete allocation

```swift
private func getEfficiencyPoints(timeAsleep: Double, timeInBed: Double) -> Int {
    guard timeInBed > 0 else { return 0 }
    let efficiency = (timeAsleep / timeInBed) * 100
    switch efficiency {
    case let e where e >= 95: return 15     // 95%+
    case 92.5..<95: return 12               // 92.5-95%
    case 90..<92.5: return 10               // 90-92.5%
    case 85..<90: return 5                  // 85-90%
    default: return 0                       // < 85%
    }
}
```

**Calculation**: `Efficiency = (Time Asleep ÷ Time in Bed) × 100`
**Optimal Range**: 95%+ (15 points)
**Scoring Strategy**: High threshold requirements, steep drop-offs below 90%

### **Consistency Component (0-10 points)**
**Input**: Actual bedtime and target bedtime (from 14-day baseline)
**Formula**: Time deviation-based discrete allocation

```swift
private func getOnsetConsistencyPoints(actualBedtime: Date, targetBedtime: Date) -> Int {
    // Extract hour/minute components only
    let calendar = Calendar.current
    let componentsActual = calendar.dateComponents([.hour, .minute], from: actualBedtime)
    let componentsTarget = calendar.dateComponents([.hour, .minute], from: targetBedtime)
    
    // Calculate time difference
    let diff = abs(actualDate.timeIntervalSince(targetDate))
    switch diff {
    case 0..<(15*60): return 10             // < 15 minutes
    case (15*60)..<(30*60): return 7        // 15-30 minutes
    case (30*60)..<(45*60): return 4        // 30-45 minutes
    default: return 0                       // > 45 minutes
    }
}
```

**Optimal Range**: < 15 minutes deviation (10 points)
**Scoring Strategy**: High precision required, rapid point loss with deviation

## 🔄 **3. Data Fetching and Processing**

### **Data Sources:**
1. **HealthKit Sleep Analysis** (`HKCategoryType.sleepAnalysis`)
2. **HealthKit Heart Rate** (sleeping heart rate)
3. **DynamicBaselineEngine** (14-day averages for consistency)

### **Sleep Data Fetching Process:**

```swift
private func fetchDetailedSleepData(for date: Date) async throws -> SleepData {
    // 1. Define sleep window: Previous day noon to current day noon
    let startOfWindow = calendar.date(byAdding: .hour, value: 12, to: previousDay)
    let endOfWindow = calendar.date(byAdding: .hour, value: 12, to: currentDay)
    
    // 2. Query HealthKit for sleep samples
    let sleepPredicate = HKQuery.predicateForSamples(
        withStart: startOfWindow, 
        end: endOfWindow, 
        options: .strictEndDate
    )
    
    // 3. Extract sleep stages and timing
    // - timeInBed: Total time from bedtime to wake time
    // - timeAsleep: Sum of all sleep stages (excludes awake time)
    // - deepSleepDuration: Sum of HKCategoryValueSleepAnalysis.deepSleep
    // - remSleepDuration: Sum of HKCategoryValueSleepAnalysis.REM
    // - bedtime: Start time of first sleep sample
    // - wakeTime: End time of last sleep sample
}
```

### **Heart Rate Data Fetching:**
```swift
private func fetchHeartRateData(for sleepSession: DateInterval) async -> Double? {
    // Query heart rate samples during sleep session
    // Calculate average heart rate during sleep
    // Used for heart rate dip calculation in restoration quality
}
```

### **Baseline Data:**
```swift
// From DynamicBaselineEngine.shared
let baselineBedtime = baselineEngine.bedtime14  // 14-day average bedtime
let baselineWakeTime = baselineEngine.wake14    // 14-day average wake time
```

## 📱 **4. UI Component Breakdown**

The UI shows 4 components with proportional scores (0-100 display):

### **Component Mapping:**
```swift
// In HealthStatsViewModel
sleepComponents = [
    ComponentData(
        name: "Sleep Duration",
        score: (durationPoints / 30.0) * 100,    // Convert 27/30 → 90/100
        maxScore: 100,
        description: "Sleep Duration: 7h 34m (optimal range 7h 30m - 8h 30m). Score: 27/30 (30% of total)."
    ),
    ComponentData(
        name: "Restoration Quality", 
        score: restorationScore,                  // Already 0-100 range
        maxScore: 100,
        description: "Combined deep sleep, REM sleep, and heart rate recovery scoring"
    ),
    ComponentData(
        name: "Sleep Efficiency",
        score: (efficiencyPoints / 15.0) * 100,  // Convert 12/15 → 80/100
        maxScore: 100,
        description: "Sleep Efficiency: 85.4% (good). Score: 12/15 (15% of total)."
    ),
    ComponentData(
        name: "Sleep Consistency",
        score: (consistencyPoints / 10.0) * 100, // Convert 7/10 → 70/100
        maxScore: 100,
        description: "Bedtime deviation: 23 minutes from your 14-day average. Score: 7/10 (10% of total)."
    )
]
```

## 🔬 **5. Restoration Quality (Separate Algorithm)**

**Note**: Restoration Quality uses a different algorithm than the V3.0 REM/Deep components and is used only for UI descriptions.

### **Formula:**
```
Restoration Score = (Deep Sleep Score × 0.40) + (REM Sleep Score × 0.40) + (Heart Rate Dip Score × 0.20)
```

### **Deep Sleep Scoring:**
```swift
// Optimal range: 13-23% of total sleep time
if percentage >= 0.13 && percentage <= 0.23 {
    return 100.0
} else if percentage >= 0.10 {
    // Forgiving curve for 10-13%
    let ratio = percentage / 0.13
    return 60 + (ratio * 40)  // Maps 10% → 91, 12% → 97
} else {
    // Steep penalty below 10%
    return (percentage / 0.10) * 60
}
```

### **REM Sleep Scoring:**
```swift
// Optimal range: 20-25% of total sleep time
if percentage >= 0.20 && percentage <= 0.25 {
    return 100.0
} else if percentage < 0.20 {
    return (percentage / 0.20) * 100
} else {
    // Above 25%
    let excess = percentage - 0.25
    let maxExcess = 0.35 - 0.25
    return (1.0 - (excess / maxExcess)) * 100
}
```

### **Heart Rate Dip Scoring:**
```swift
// Formula: 1 - (Average_Sleeping_HR / Daily_RHR)
let hrDip = 1.0 - (averageHeartRate / dailyRestingHeartRate)

if hrDip >= 0.15 {
    return 100.0      // Excellent (15%+ dip)
} else if hrDip >= 0.10 {
    return 80.0 + (hrDip - 0.10) * 400.0  // Good (10-15% dip)
} else if hrDip >= 0.05 {
    return 60.0 + (hrDip - 0.05) * 400.0  // Fair (5-10% dip)
} else if hrDip >= 0.0 {
    return 60.0 * (hrDip / 0.05)  // Poor (0-5% dip)
} else {
    return 0.0        // Negative dip (HR increased during sleep)
}
```

## 📊 **6. Example Score Calculation**

### **Input Data:**
- Sleep Duration: 7h 34m (454 minutes)
- Deep Sleep: 1h 12m (72 minutes)
- REM Sleep: 1h 48m (108 minutes)
- Time in Bed: 8h 15m (495 minutes)
- Bedtime Deviation: 23 minutes from baseline

### **V3.0 Point Calculation:**
```
Duration Points: 454 minutes → 27/30 points
Deep Sleep Points: 72 minutes → 14/25 points  
REM Sleep Points: 108 minutes → 18/20 points
Efficiency Points: (454/495) × 100 = 91.7% → 10/15 points
Consistency Points: 23 minutes deviation → 7/10 points

Final Score = 27 + 14 + 18 + 10 + 7 = 76/100
```

### **UI Display Conversion:**
```
Sleep Duration: (27/30) × 100 = 90/100
Restoration Quality: 82/100 (from separate algorithm)
Sleep Efficiency: (10/15) × 100 = 67/100  
Sleep Consistency: (7/10) × 100 = 70/100
```

## ⚠️ **7. System Architecture Notes**

### **Dual Scoring System:**
The app maintains two parallel scoring systems:
1. **V3.0 Performance Score**: Determines the final score (76/100)
2. **Restoration Quality Algorithm**: Provides detailed UI descriptions

### **Data Flow:**
```
HealthKit → SleepScoreCalculator → HealthStatsViewModel → SleepDetailView
```

### **Caching:**
- Sleep scores are cached by date to avoid recalculation
- Cache key format: "sleep_score_yyyy-MM-dd"

### **Error Handling:**
- Missing heart rate data: Uses neutral score (75.0)
- Missing baseline data: Uses neutral score (75.0)
- Authorization failures: Throws SleepScoreError

## 🎯 **8. Scoring Philosophy**

### **Component Priorities:**
1. **Duration (30%)**: Foundation - adequate sleep time required
2. **Restoration (25% in UI, split in V3.0)**: Quality over quantity
3. **Efficiency (15%)**: Sleep maintenance ability
4. **Consistency (10%)**: Circadian rhythm alignment

### **Scoring Strategy:**
- **High precision required**: Most categories require near-optimal performance for maximum points
- **Steep penalties**: Significant point loss for suboptimal values
- **Realistic thresholds**: Based on sleep medicine research ranges
- **Forgiving deep sleep**: More lenient for values just below optimal

This comprehensive system provides users with both an overall sleep score and detailed component breakdowns to understand their sleep quality and identify areas for improvement. 