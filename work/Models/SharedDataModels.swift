//
//  SharedDataModels.swift
//  work
//
//  Created by Kiro on 12/19/24.
//

import Foundation
import HealthKit

// MARK: - Health Data Models

struct DailyMetrics {
    let date: Date
    let hrv: Double?
    let rhr: Double?
    let respiratoryRate: Double?
    let walkingHeartRate: Double?
    let oxygenSaturation: Double?
    let sleepDuration: TimeInterval?
    let deepSleep: TimeInterval?
    let remSleep: TimeInterval?
    let bedtime: Date?
    let wakeTime: Date?
}

struct EnhancedHRVData {
    let sdnn: Double
    let rmssd: Double?
    let heartRateSamples: [HKQuantitySample]
    let calculatedMetrics: AdvancedHRVMetrics
    let hasBeatToBeatData: Bool
    let stressLevel: Double
}

struct AdvancedHRVMetrics {
    let meanRR: Double
    let sdnn: Double
    let rmssd: Double
    let pnn50: Double
    let triangularIndex: Double
    let stressIndex: Double
    let autonomicBalance: Double
    let recoveryScore: Double
    let autonomicBalanceScore: Double
}

// MARK: - Sleep Score Error Types are defined in SleepScoreCalculator.swift

// MARK: - Sleep Session Helper

struct SleepSession {
    let startTime: Date
    let endTime: Date
    let samples: [HKCategorySample]
    
    var totalDuration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var timeAsleep: TimeInterval {
        samples.filter { sample in
            let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            return value == .asleepUnspecified || value == .asleepDeep || 
                   value == .asleepREM || value == .asleepCore
        }.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
    }
}