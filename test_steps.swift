#!/usr/bin/env swift

import Foundation
import HealthKit

// Test script to verify Steps functionality
print("🧪 Testing Steps functionality...")

// Check if HealthKit is available
guard HKHealthStore.isHealthDataAvailable() else {
    print("❌ HealthKit is not available on this device")
    exit(1)
}

let healthStore = HKHealthStore()

// Check if step count type is available
guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
    print("❌ Step count type is not available")
    exit(1)
}

print("✅ HealthKit and step count type are available")

// Check authorization status
let authStatus = healthStore.authorizationStatus(for: stepType)
print("🔍 Step count authorization status: \(authStatus.rawValue)")

switch authStatus {
case .notDetermined:
    print("⚠️ Authorization not determined - user needs to grant permission")
case .sharingDenied:
    print("❌ Authorization denied - user needs to enable in Settings")
case .sharingAuthorized:
    print("✅ Authorization granted - step data should be accessible")
@unknown default:
    print("❓ Unknown authorization status")
}

print("🏁 Steps test completed")