# RHR Data Availability Issue - Debugging

## 🔍 **Problem Identified**

The recovery score is frequently showing "RHR data unavailable" because:

1. **Apple Health RHR Data Structure**: Apple Health typically provides RHR data as daily averages, not as time-specific readings during sleep sessions
2. **Sleep Session Mismatch**: The recovery score tries to fetch RHR data specifically during the detected sleep session, but RHR data may not be available for that exact time window
3. **No Fallback Mechanism**: Previously, if no RHR data was found during the sleep session, the system would fail completely

## 🛠️ **Solution Implemented**

### 1. **Enhanced RHR Fetching with Fallback**

**File**: `work/HealthKitManager.swift`

**Changes**:
- Added debugging to understand when and why RHR data is missing
- Implemented fallback mechanism to fetch daily RHR if sleep session RHR is unavailable
- Added detailed logging to track the data fetching process

**Before**:
```swift
guard !values.isEmpty else {
    completion(nil)
    return
}
```

**After**:
```swift
if values.isEmpty {
    print("⚠️ RHR: No RHR data found during sleep session")
    
    // Fallback: Try to get RHR for the entire day
    self.fetchRHRForDay(containing: interval.start) { fallbackRHR in
        if let fallbackRHR = fallbackRHR {
            print("✅ RHR: Using daily RHR as fallback: \(fallbackRHR) BPM")
            completion(fallbackRHR)
        } else {
            print("❌ RHR: No RHR data available for day either")
            completion(nil)
        }
    }
    return
}
```

### 2. **Added Fallback Method**

**New Method**: `fetchRHRForDay(containing:completion:)`

```swift
private func fetchRHRForDay(containing date: Date, completion: @escaping (Double?) -> Void) {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: date)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
    
    // Fetch RHR for the entire day as fallback
    let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
    // ... query implementation
}
```

### 3. **Enhanced Sleep Session Detection Debugging**

**File**: `work/HealthKitManager.swift`

**Added debugging to `fetchMainSleepSession`**:
- Logs the time window being searched
- Shows number of sleep samples found
- Reports sleep session creation and duration
- Helps identify if sleep detection is working correctly

### 4. **RHR Component Calculation Debugging**

**File**: `work/RecoveryScoreCalculator.swift`

**Added debugging to `calculateRHRComponent`**:
- Logs current RHR and baseline RHR values
- Shows when data is missing vs when calculation proceeds
- Reports final score calculation

## 📊 **Debugging Output Examples**

### **Successful RHR Detection**:
```
🔍 Sleep Session Detection: Looking for sleep between 12:00 PM and 12:00 PM
✅ Sleep: Found 15 sleep samples
✅ Sleep: Created 2 sleep sessions
✅ Sleep: Main session found: 11:30 PM - 6:30 AM (duration: 7.0h)
⚠️ RHR: No RHR data found during sleep session (11:30 PM - 6:30 AM)
✅ RHR: Using daily RHR as fallback: 58 BPM
🔍 RHR Component Calculation:
  - Current RHR: 58.0
  - Baseline RHR: 62.0
✅ RHR Component: Valid data - calculating score
✅ RHR Component: Score calculated: 82/100
```

### **Failed RHR Detection**:
```
🔍 Sleep Session Detection: Looking for sleep between 12:00 PM and 12:00 PM
✅ Sleep: Found 8 sleep samples
✅ Sleep: Created 1 sleep sessions
✅ Sleep: Main session found: 12:30 AM - 5:45 AM (duration: 5.3h)
⚠️ RHR: No RHR data found during sleep session (12:30 AM - 5:45 AM)
❌ RHR: No RHR data available for day either
🔍 RHR Component Calculation:
  - Current RHR: nil
  - Baseline RHR: 62.0
❌ RHR Component: Missing data - returning neutral score
```

## 🎯 **Expected Improvements**

### 1. **Better Data Availability**
- ✅ Fallback to daily RHR when sleep session RHR is unavailable
- ✅ More reliable RHR data for recovery score calculation
- ✅ Reduced "RHR data unavailable" messages

### 2. **Debugging Capabilities**
- ✅ Clear visibility into why RHR data is missing
- ✅ Understanding of sleep session detection accuracy
- ✅ Ability to identify data source issues

### 3. **User Experience**
- ✅ More consistent recovery scores
- ✅ Better understanding of data availability
- ✅ Reduced frustration from missing data

## 🔧 **Common Causes of RHR Unavailability**

### 1. **Apple Health Data Structure**
- RHR is typically calculated as a daily average
- May not have granular time-based RHR data during sleep
- Depends on device capabilities and settings

### 2. **Sleep Session Timing**
- Sleep session detection may not align with RHR data availability
- Different devices may provide RHR data at different times
- Sleep tracking accuracy affects data window alignment

### 3. **HealthKit Permissions**
- RHR data requires specific HealthKit permissions
- User may not have granted access to RHR data
- Device may not support RHR tracking

## 🚀 **Next Steps**

1. **Test the Fallback Mechanism**: Run the app and check if RHR data is now more consistently available
2. **Monitor Debug Output**: Use the console logs to understand data patterns
3. **User Education**: Consider adding UI to explain when fallback data is being used
4. **Further Optimization**: If needed, implement additional fallback strategies

## 📱 **Testing Instructions**

1. **Run the app** and navigate to the Recovery tab
2. **Check console output** for RHR debugging messages
3. **Look for patterns** in when RHR data is available vs unavailable
4. **Verify fallback behavior** when sleep session RHR is missing

The debugging output will help identify the root cause and ensure the fallback mechanism is working correctly. 