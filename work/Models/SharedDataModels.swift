//
//  SharedDataModels.swift
//  work
//
//  Created by Kiro on 12/19/24.
//

import Foundation
import HealthKit
import SwiftUI

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

// MARK: - Weight Data Models

struct WeightData {
    let date: Date
    let weight: Double // in kg
    let source: String
}

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

// MARK: - JournalTag (shared)
enum JournalTag: String, CaseIterable, Hashable {
    case coffee = "coffee"
    case alcohol = "alcohol"
    case caffeine = "caffeine"
    case lateEating = "late_eating"
    case stress = "stress"
    case exercise = "exercise"
    case meditation = "meditation"
    case goodSleep = "good_sleep"
    case poorSleep = "poor_sleep"
    case illness = "illness"
    case travel = "travel"
    case work = "work"
    case social = "social"
    case supplements = "supplements"
    case hydration = "hydration"
    case mood = "mood"
    case energy = "energy"
    case focus = "focus"
    case recovery = "recovery"
    
    var displayName: String {
        switch self {
        case .coffee: return "Coffee"
        case .alcohol: return "Alcohol"
        case .caffeine: return "Late Caffeine"
        case .lateEating: return "Late Eating"
        case .stress: return "High Stress"
        case .exercise: return "Exercise"
        case .meditation: return "Meditation"
        case .goodSleep: return "Good Sleep"
        case .poorSleep: return "Poor Sleep"
        case .illness: return "Illness"
        case .travel: return "Travel"
        case .work: return "Work Stress"
        case .social: return "Social"
        case .supplements: return "Supplements"
        case .hydration: return "Good Hydration"
        case .mood: return "Good Mood"
        case .energy: return "High Energy"
        case .focus: return "Good Focus"
        case .recovery: return "Recovery Day"
        }
    }
    var icon: String {
        switch self {
        case .coffee: return "cup.and.saucer.fill"
        case .alcohol: return "wineglass"
        case .caffeine: return "cup.and.saucer"
        case .lateEating: return "clock.badge.exclamationmark"
        case .stress: return "exclamationmark.triangle"
        case .exercise: return "figure.run"
        case .meditation: return "leaf"
        case .goodSleep: return "bed.double"
        case .poorSleep: return "bed.double.fill"
        case .illness: return "thermometer"
        case .travel: return "airplane"
        case .work: return "briefcase"
        case .social: return "person.2"
        case .supplements: return "pills.fill"
        case .hydration: return "drop.fill"
        case .mood: return "face.smiling"
        case .energy: return "bolt.fill"
        case .focus: return "target"
        case .recovery: return "heart.fill"
        }
    }
    var color: Color {
        switch self {
        case .coffee: return .brown
        case .alcohol: return .red
        case .caffeine: return .orange
        case .lateEating: return .orange
        case .stress: return .red
        case .exercise: return .green
        case .meditation: return .mint
        case .goodSleep: return .blue
        case .poorSleep: return .purple
        case .illness: return .red
        case .travel: return .cyan
        case .work: return .gray
        case .social: return .pink
        case .supplements: return .blue
        case .hydration: return .cyan
        case .mood: return .yellow
        case .energy: return .orange
        case .focus: return .indigo
        case .recovery: return .green
        }
    }
}