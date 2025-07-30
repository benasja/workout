# HRV Consistency and Time Format Fixes

## ✅ **Issues Fixed**

Successfully resolved two critical data consistency and formatting issues:

1. **HRV Data Inconsistency**: Fixed mismatch between "How It Was Calculated" and biomarker card values
2. **Time Formatting**: Changed sleep time display from decimal hours (1.6h) to proper hh:mm format (1h 35min)

## 🔧 **Problem Analysis**

### **Issue 1: HRV Data Inconsistency**

**Problem**: Users were seeing different HRV values in different parts of the app:
- "How It Was Calculated" section: Shows HRV value from recovery score calculation (overnight data)
- Biomarker cards at bottom: Shows HRV value from daily trend data

**Root Cause**: Two different data sources were being used:
1. **Recovery Score Calculation**: Uses overnight HRV data from sleep session (via `RecoveryScoreCalculator`)
2. **Biomarker Trends**: Uses daily HRV data (via `HealthStatsViewModel.fetchHRVForDate`)

**Impact**: Confusing user experience with inconsistent data display

### **Issue 2: Time Formatting**

**Problem**: Sleep times were displayed as decimal hours (e.g., "1.6h") instead of proper time format (e.g., "1h 35min")

**Root Cause**: `BiomarkerTrendCard` was using `String(format: "%.1f", value)` for all values, including time

**Impact**: Poor user experience with non-intuitive time display

## 🛠️ **Solutions Implemented**

### **Fix 1: HRV Data Consistency**

**Location**: `work/Views/RecoveryDetailView.swift`

**Before**:
```swift
if let hrvData = biomarkerTrends["hrv"] {
    BiomarkerTrendCard(
        title: "Resting HRV",
        value: hrvData.currentValue,  // Daily HRV data
        unit: hrvData.unit,
        percentageChange: hrvData.percentageChange,
        trendData: hrvData.trend,
        color: hrvData.color
    )
}
```

**After**:
```swift
// Use HRV data from recovery score calculation for consistency
if let recoveryResult = healthStats.recoveryResult,
   let hrvValue = recoveryResult.hrvComponent.currentValue {
    BiomarkerTrendCard(
        title: "Resting HRV",
        value: hrvValue,  // Overnight HRV data (same as recovery score)
        unit: "ms",
        percentageChange: biomarkerTrends["hrv"]?.percentageChange,
        trendData: biomarkerTrends["hrv"]?.trend ?? [],
        color: .green
    )
}
```

**Also Fixed RHR Consistency**:
```swift
// Use RHR data from recovery score calculation for consistency
if let recoveryResult = healthStats.recoveryResult,
   let rhrValue = recoveryResult.rhrComponent.currentValue {
    BiomarkerTrendCard(
        title: "Resting HR",
        value: rhrValue,  // Overnight RHR data (same as recovery score)
        unit: "bpm",
        percentageChange: biomarkerTrends["rhr"]?.percentageChange,
        trendData: biomarkerTrends["rhr"]?.trend ?? [],
        color: .blue
    )
}
```

### **Fix 2: Time Formatting**

**Location**: `work/Views/SharedComponents.swift`

**Before**:
```swift
HStack(alignment: .bottom, spacing: 4) {
    Text(String(format: "%.1f", value))  // Always decimal format
        .font(.title2)
        .fontWeight(.bold)
        .foregroundColor(.primary)
    
    Text(unit)
        .font(.caption)
        .foregroundColor(.secondary)
}
```

**After**:
```swift
HStack(alignment: .bottom, spacing: 4) {
    if unit == "h" {
        // Format time as hh:mm instead of decimal hours
        let timeInterval = value * 3600
        Text(timeInterval.formattedAsHoursAndMinutes())
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.primary)
        
        Text("")
            .font(.caption)
            .foregroundColor(.secondary)
    } else {
        Text(String(format: "%.1f", value))
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.primary)
        
        Text(unit)
            .font(.caption)
            .foregroundColor(.secondary)
    }
}
```

## 📱 **Impact on UI**

### **Recovery Tab**

**Before**:
- "How It Was Calculated": "HRV vs 40 ms baseline: your HRV of 54 ms is +35% above baseline"
- Biomarker Card: "Resting HRV 56.4ms"

**After**:
- "How It Was Calculated": "HRV vs 40 ms baseline: your HRV of 54 ms is +35% above baseline"
- Biomarker Card: "Resting HRV 54ms" ✅ **Consistent!**

### **Sleep Tab**

**Before**:
- Time in Bed: "1.6h"
- Time Asleep: "1.4h"
- REM Sleep: "0.3h"
- Deep Sleep: "0.2h"

**After**:
- Time in Bed: "1h 36min" ✅ **Proper format!**
- Time Asleep: "1h 24min" ✅ **Proper format!**
- REM Sleep: "18min" ✅ **Proper format!**
- Deep Sleep: "12min" ✅ **Proper format!**

## 🎯 **Benefits**

### 1. **Data Consistency**
- ✅ HRV values now match between recovery score calculation and biomarker cards
- ✅ RHR values now match between recovery score calculation and biomarker cards
- ✅ Single source of truth for overnight recovery metrics

### 2. **Better User Experience**
- ✅ No more confusion about different HRV values
- ✅ Intuitive time display in hh:mm format
- ✅ Consistent data presentation across the app

### 3. **Improved Readability**
- ✅ Sleep times are now easy to read and understand
- ✅ No more decimal hour confusion
- ✅ Clear distinction between hours and minutes

### 4. **Technical Integrity**
- ✅ Biomarker cards now use the same overnight data as recovery score
- ✅ Proper time formatting for all time-based metrics
- ✅ Maintained trend data functionality

## 🔍 **Technical Details**

### **Data Flow Consistency**

**Recovery Score Calculation**:
1. Fetches overnight HRV/RHR data from sleep session
2. Calculates recovery score using this data
3. Stores results in `RecoveryScoreResult`

**Biomarker Cards** (Now Fixed):
1. Uses same overnight HRV/RHR data from `RecoveryScoreResult`
2. Displays consistent values with recovery score calculation
3. Still shows trend data from daily measurements for context

### **Time Formatting Logic**

**For Time Units (unit == "h")**:
1. Converts decimal hours to seconds: `value * 3600`
2. Uses `formattedAsHoursAndMinutes()` extension
3. Displays as "1h 35min" format

**For Other Units**:
1. Uses decimal formatting: `String(format: "%.1f", value)`
2. Shows unit label normally

## 🚀 **Result**

Users now see:
- ✅ **Consistent HRV values** across all parts of the recovery tab
- ✅ **Consistent RHR values** across all parts of the recovery tab
- ✅ **Properly formatted sleep times** in hh:mm format
- ✅ **Clear, intuitive data presentation** without confusion

The app now provides a cohesive and user-friendly experience with consistent data display and proper time formatting. 