//
//  HealthStatsViewModel.swift
//  work
//
//  Created by Assistant on architectural refactor.
//

import SwiftUI
import Foundation
import Combine

/// Centralized data hub serving as the single source of truth for all health data and scoring.
/// This ObservableObject eliminates score inconsistencies by providing unified data access for all views.
@MainActor
final class HealthStatsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    // Core Health Data
    @Published var currentDate: Date = Date()
    @Published var rawHealthData: DailyMetrics?
    @Published var baselineMetrics: BaselineMetrics?
    
    // Calculated Scores
    @Published var recoveryResult: RecoveryScoreResult?
    @Published var sleepResult: SleepScoreResult?
    
    // Component Breakdowns for UI
    @Published var recoveryComponents: [ComponentData] = []
    @Published var sleepComponents: [ComponentData] = []
    @Published var biomarkerTrends: [String: BiomarkerTrendData] = [:]
    
    // Loading States
    @Published var isLoading = false
    @Published var isCalculatingBaseline = false
    @Published var errorMessage: String?
    
    // Historical Data for Trends
    @Published var sevenDayTrends: [String: [Double]] = [:]
    @Published var thirtyDayTrends: [String: [Double]] = [:]
    
    // MARK: - Dependencies
    
    private let baselineEngine = DynamicBaselineEngine.shared
    private let healthKitManager = HealthKitManager.shared
    private let recoveryCalculator = RecoveryScoreCalculator.shared
    private let sleepCalculator = SleepScoreCalculator.shared
    
    // MARK: - Cache Management
    
    private var dataCache: [String: CachedHealthData] = [:]
    private let cacheExpiryMinutes = 5 // Data expires after 5 minutes
    
    // MARK: - Initialization
    
    init() {
        // Load today's data by default
        Task {
            await loadData(for: Date())
        }
    }
    
    // MARK: - Primary Data Loading Function
    
    /// Loads all health data, calculates scores, and publishes results for the given date.
    /// This is the central function that should be called by all views instead of individual data fetching.
    /// - Parameter date: The date to load data for
    func loadData(for date: Date) async {
        // Check cache first
        let cacheKey = cacheKey(for: date)
        if let cachedData = dataCache[cacheKey], !cachedData.isExpired {
            await publishCachedData(cachedData)
            return
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.currentDate = date
        }
        
        // Step 1: Fetch raw health data
        let rawData = await fetchRawHealthData(for: date)
        
        // Step 2: Calculate historical baseline for this date
        let baseline = await calculateHistoricalBaseline(for: date)
        
        // Step 3: Calculate scores using the unified data and baseline
        let (recovery, sleep) = await calculateScores(for: date, rawData: rawData, baseline: baseline)
        
        // Step 4: Generate component breakdowns and trends
        let components = generateComponentBreakdowns(recovery: recovery, sleep: sleep)
        let trends = await generateBiomarkerTrends(for: date)
        let historicalTrends = await generateHistoricalTrends(for: date)
        
        // Step 5: Cache the results
        let cachedData = CachedHealthData(
            date: date,
            rawData: rawData,
            baseline: baseline,
            recovery: recovery,
            sleep: sleep,
            components: components,
            trends: trends,
            historicalTrends: historicalTrends,
            timestamp: Date()
        )
        dataCache[cacheKey] = cachedData
        
        // Step 6: Publish all results
        await publishData(cachedData)
    }
    
    // MARK: - Data Fetching
    
    private func fetchRawHealthData(for date: Date) async -> DailyMetrics? {
        return await withCheckedContinuation { continuation in
            healthKitManager.fetchData(for: date) { metrics in
                continuation.resume(returning: metrics)
            }
        }
    }
    
    private func calculateHistoricalBaseline(for date: Date) async -> BaselineMetrics {
        await MainActor.run {
            self.isCalculatingBaseline = true
        }
        
        // Use the new historical baselining engine
        let baseline = await baselineEngine.calculateBaseline(for: date, days: 60)
        
        await MainActor.run {
            self.isCalculatingBaseline = false
        }
        
        return baseline
    }
    
    private func calculateScores(for date: Date, rawData: DailyMetrics?, baseline: BaselineMetrics) async -> (RecoveryScoreResult?, SleepScoreResult?) {
        async let recovery = calculateRecoveryScore(for: date)
        async let sleep = calculateSleepScore(for: date)
        
        return await (recovery, sleep)
    }
    
    private func calculateRecoveryScore(for date: Date) async -> RecoveryScoreResult? {
        do {
            return try await recoveryCalculator.calculateRecoveryScore(for: date)
        } catch {
            print("⚠️ Failed to calculate recovery score: \(error)")
            return nil
        }
    }
    
    private func calculateSleepScore(for date: Date) async -> SleepScoreResult? {
        do {
            return try await sleepCalculator.calculateSleepScore(for: date)
        } catch {
            print("⚠️ Failed to calculate sleep score: \(error)")
            return nil
        }
    }
    
    // MARK: - Component Generation
    
    private func generateComponentBreakdowns(recovery: RecoveryScoreResult?, sleep: SleepScoreResult?) -> ComponentBreakdowns {
        var recoveryComponents: [ComponentData] = []
        var sleepComponents: [ComponentData] = []
        
        // Recovery Components
        if let recovery = recovery {
            recoveryComponents = [
                ComponentData(
                    name: "HRV Recovery",
                    score: recovery.hrvComponent.score,
                    maxScore: 50,
                    description: recovery.hrvComponent.description,
                    color: AppColors.success
                ),
                ComponentData(
                    name: "RHR Recovery", 
                    score: recovery.rhrComponent.score,
                    maxScore: 25,
                    description: recovery.rhrComponent.description,
                    color: AppColors.primary
                ),
                ComponentData(
                    name: "Sleep Quality",
                    score: recovery.sleepComponent.score,
                    maxScore: 15,
                    description: recovery.sleepComponent.description,
                    color: AppColors.accent
                ),
                ComponentData(
                    name: "Stress Indicators",
                    score: recovery.stressComponent.score,
                    maxScore: 10,
                    description: recovery.stressComponent.description,
                    color: AppColors.warning
                )
            ]
        }
        
        // Sleep Components
        if let sleep = sleep {
            sleepComponents = [
                ComponentData(
                    name: "Sleep Duration",
                    score: Double(sleep.finalScore) * 0.3, // Approximate duration contribution
                    maxScore: 25,
                    description: "Sleep duration: \(sleep.timeAsleep.formattedAsHoursAndMinutes())",
                    color: AppColors.primary
                ),
                ComponentData(
                    name: "Sleep Efficiency",
                    score: sleep.efficiencyComponent,
                    maxScore: 25,
                    description: "Sleep efficiency: \(String(format: "%.1f", sleep.sleepEfficiency * 100))%",
                    color: AppColors.success
                ),
                ComponentData(
                    name: "Deep Sleep",
                    score: Double(sleep.finalScore) * 0.2, // Approximate deep sleep contribution
                    maxScore: 25,
                    description: "Deep sleep: \(sleep.deepSleep.formattedAsHoursAndMinutes())",
                    color: AppColors.primary
                ),
                ComponentData(
                    name: "REM Sleep",
                    score: Double(sleep.finalScore) * 0.2, // Approximate REM contribution
                    maxScore: 25,
                    description: "REM sleep: \(sleep.remSleep.formattedAsHoursAndMinutes())",
                    color: AppColors.accent
                ),
                ComponentData(
                    name: "Sleep Quality",
                    score: sleep.qualityComponent,
                    maxScore: 25,
                    description: "Overall restoration quality",
                    color: AppColors.warning
                ),
                ComponentData(
                    name: "Sleep Timing",
                    score: sleep.timingComponent,
                    maxScore: 25,
                    description: "Bedtime consistency",
                    color: AppColors.error
                )
            ]
        }
        
        return ComponentBreakdowns(recovery: recoveryComponents, sleep: sleepComponents)
    }
    
    private func generateBiomarkerTrends(for date: Date) async -> [String: BiomarkerTrendData] {
        var trends: [String: BiomarkerTrendData] = [:]
        let calendar = Calendar.current
        
        // --- Recovery Trends (existing) ---
        // HRV Trend
        var hrvTrend: [Double] = []
        for i in 0..<7 {
            if let trendDate = calendar.date(byAdding: .day, value: -i, to: date) {
                let hrv = await fetchHRVForDate(trendDate)
                if let hrv = hrv {
                    hrvTrend.insert(hrv, at: 0)
                }
            }
        }
        if !hrvTrend.isEmpty {
            trends["hrv"] = BiomarkerTrendData(
                currentValue: hrvTrend.last ?? 0,
                unit: "ms",
                trend: hrvTrend,
                percentageChange: calculatePercentageChange(current: hrvTrend.last, previous: hrvTrend.dropLast().last),
                color: .green
            )
        }
        // RHR Trend
        var rhrTrend: [Double] = []
        for i in 0..<7 {
            if let trendDate = calendar.date(byAdding: .day, value: -i, to: date) {
                let rhr = await fetchRHRForDate(trendDate)
                if let rhr = rhr {
                    rhrTrend.insert(rhr, at: 0)
                }
            }
        }
        if !rhrTrend.isEmpty {
            trends["rhr"] = BiomarkerTrendData(
                currentValue: rhrTrend.last ?? 0,
                unit: "bpm",
                trend: rhrTrend,
                percentageChange: calculatePercentageChange(current: rhrTrend.last, previous: rhrTrend.dropLast().last),
                color: .blue
            )
        }
        
        // --- Sleep Trends (NEW) ---
        var timeInBedTrend: [Double] = []
        var timeAsleepTrend: [Double] = []
        var remSleepTrend: [Double] = []
        var deepSleepTrend: [Double] = []
        var efficiencyTrend: [Double] = []
        var fallAsleepTrend: [Double] = []
        for i in 0..<7 {
            if let trendDate = calendar.date(byAdding: .day, value: -i, to: date) {
                if let sleepScore = try? await SleepScoreCalculator.shared.calculateSleepScore(for: trendDate) {
                    timeInBedTrend.insert(sleepScore.timeInBed / 3600, at: 0)
                    timeAsleepTrend.insert(sleepScore.timeAsleep / 3600, at: 0)
                    remSleepTrend.insert(sleepScore.remSleep / 3600, at: 0)
                    deepSleepTrend.insert(sleepScore.deepSleep / 3600, at: 0)
                    efficiencyTrend.insert(sleepScore.sleepEfficiency * 100, at: 0)
                    fallAsleepTrend.insert(sleepScore.timeToFallAsleep, at: 0)
                } else {
                    // Insert 0 for missing data
                    timeInBedTrend.insert(0, at: 0)
                    timeAsleepTrend.insert(0, at: 0)
                    remSleepTrend.insert(0, at: 0)
                    deepSleepTrend.insert(0, at: 0)
                    efficiencyTrend.insert(0, at: 0)
                    fallAsleepTrend.insert(0, at: 0)
                }
            }
        }
        // Add to trends dictionary for each sleep metric, with up/down trend arrows (percentageChange)
        if !timeInBedTrend.isEmpty {
            trends["timeInBed"] = BiomarkerTrendData(
                currentValue: timeInBedTrend.last ?? 0,
                unit: "h",
                trend: timeInBedTrend,
                percentageChange: calculatePercentageChange(current: timeInBedTrend.last, previous: timeInBedTrend.dropLast().last),
                color: .blue
            )
        }
        if !timeAsleepTrend.isEmpty {
            trends["timeAsleep"] = BiomarkerTrendData(
                currentValue: timeAsleepTrend.last ?? 0,
                unit: "h",
                trend: timeAsleepTrend,
                percentageChange: calculatePercentageChange(current: timeAsleepTrend.last, previous: timeAsleepTrend.dropLast().last),
                color: .green
            )
        }
        if !remSleepTrend.isEmpty {
            trends["remSleep"] = BiomarkerTrendData(
                currentValue: remSleepTrend.last ?? 0,
                unit: "h",
                trend: remSleepTrend,
                percentageChange: calculatePercentageChange(current: remSleepTrend.last, previous: remSleepTrend.dropLast().last),
                color: .purple
            )
        }
        if !deepSleepTrend.isEmpty {
            trends["deepSleep"] = BiomarkerTrendData(
                currentValue: deepSleepTrend.last ?? 0,
                unit: "h",
                trend: deepSleepTrend,
                percentageChange: calculatePercentageChange(current: deepSleepTrend.last, previous: deepSleepTrend.dropLast().last),
                color: .indigo
            )
        }
        if !efficiencyTrend.isEmpty {
            trends["efficiency"] = BiomarkerTrendData(
                currentValue: efficiencyTrend.last ?? 0,
                unit: "%",
                trend: efficiencyTrend,
                percentageChange: calculatePercentageChange(current: efficiencyTrend.last, previous: efficiencyTrend.dropLast().last),
                color: .orange
            )
        }
        if !fallAsleepTrend.isEmpty {
            trends["fallAsleep"] = BiomarkerTrendData(
                currentValue: fallAsleepTrend.last ?? 0,
                unit: "min",
                trend: fallAsleepTrend,
                percentageChange: calculatePercentageChange(current: fallAsleepTrend.last, previous: fallAsleepTrend.dropLast().last),
                color: .red
            )
        }
        return trends
    }
    
    private func generateHistoricalTrends(for date: Date) async -> HistoricalTrends {
        // This would be implemented to fetch 7-day and 30-day historical data
        // For now, return empty trends
        return HistoricalTrends(sevenDay: [:], thirtyDay: [:])
    }
    
    // MARK: - Helper Methods
    
    private func fetchHRVForDate(_ date: Date) async -> Double? {
        return await withCheckedContinuation { continuation in
            healthKitManager.fetchHRV(for: date) { hrv in
                continuation.resume(returning: hrv)
            }
        }
    }
    
    private func fetchRHRForDate(_ date: Date) async -> Double? {
        return await withCheckedContinuation { continuation in
            healthKitManager.fetchRHR(for: date) { rhr in
                continuation.resume(returning: rhr)
            }
        }
    }
    
    private func calculatePercentageChange(current: Double?, previous: Double?) -> Double? {
        guard let current = current, let previous = previous, previous != 0 else { return nil }
        return ((current - previous) / previous) * 100
    }
    
    // MARK: - Score Calculation Helpers (from Sleep Detail View)
    
    private func calculateDurationScore(from result: SleepScoreResult) -> Double {
        let hoursAsleep = result.timeAsleep / 3600
        let optimal = 8.0
        let deviation = abs(hoursAsleep - optimal)
        return 100 * Foundation.exp(-0.5 * Foundation.pow(deviation / 1.5, 2))
    }
    
    private func calculateDeepSleepScore(from result: SleepScoreResult) -> Double {
        let deepPercentage = result.deepSleepPercentage * 100
        return normalizeScore(deepPercentage, min: 13, maxValue: 23)
    }
    
    private func calculateREMSleepScore(from result: SleepScoreResult) -> Double {
        let remMinutes = result.remSleep / 60
        if remMinutes >= 120 {
            return 100
        }
        let remPercentage = result.remSleepPercentage * 100
        return normalizeScore(remPercentage, min: 20, maxValue: 25)
    }
    
    private func calculateOnsetScore(from result: SleepScoreResult) -> Double {
        let fallAsleepTime = result.timeToFallAsleep
        if fallAsleepTime <= 10 {
            return 100
        } else if fallAsleepTime <= 60 {
            let normalizedTime = (fallAsleepTime - 10) / 50.0
            return 100 * Foundation.exp(-2.0 * normalizedTime)
        } else {
            return max(0, 100 * Foundation.exp(-2.0 * (60 - 10) / 50.0) - (fallAsleepTime - 60) * 0.5)
        }
    }
    
    private func normalizeScore(_ value: Double, min: Double, maxValue: Double) -> Double {
        if value < min {
            return 60 * (value / min) * (value / min)
        }
        if value > maxValue {
            let excess = value - maxValue
            let penalty = excess * 3.0
            return max(60, 100 - penalty)
        }
        let optimal = (min + maxValue) / 2
        let deviation = abs(value - optimal)
        let maxDeviation = (maxValue - min) / 2
        let normalizedDeviation = deviation / maxDeviation
        return 100 - (normalizedDeviation * normalizedDeviation * 40)
    }
    
    // MARK: - Cache Management
    
    private func cacheKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func publishCachedData(_ cachedData: CachedHealthData) async {
        await publishData(cachedData)
    }
    
    private func publishData(_ cachedData: CachedHealthData) async {
        await MainActor.run {
            self.currentDate = cachedData.date
            self.rawHealthData = cachedData.rawData
            self.baselineMetrics = cachedData.baseline
            self.recoveryResult = cachedData.recovery
            self.sleepResult = cachedData.sleep
            self.recoveryComponents = cachedData.components.recovery
            self.sleepComponents = cachedData.components.sleep
            self.biomarkerTrends = cachedData.trends
            self.sevenDayTrends = cachedData.historicalTrends.sevenDay
            self.thirtyDayTrends = cachedData.historicalTrends.thirtyDay
            self.isLoading = false
            self.isCalculatingBaseline = false
        }
    }
    
    // MARK: - Public Interface Methods
    
    /// Refreshes data for the current date
    func refresh() async {
        // Clear cache for current date and reload
        let key = cacheKey(for: currentDate)
        dataCache.removeValue(forKey: key)
        await loadData(for: currentDate)
    }
    
    /// Clears all cached data
    func clearCache() {
        dataCache.removeAll()
        sleepCalculator.clearCache()
        print("🗑️ HealthStatsViewModel: All caches cleared")
    }
    
    /// Gets biomarker trend data for Sleep tab BiomarkerTrendCards
    func getSleepBiomarkerTrends() -> [String: BiomarkerTrendData] {
        guard let sleep = sleepResult else { return [:] }
        
        var sleepTrends: [String: BiomarkerTrendData] = [:]
        
        // Time in Bed - using new formatting
        sleepTrends["timeInBed"] = BiomarkerTrendData(
            currentValue: sleep.timeInBed / 3600,
            unit: "h",
            trend: biomarkerTrends["timeInBed"]?.trend ?? [],
            percentageChange: nil,
            color: .blue
        )
        
        // Time Asleep - using new formatting  
        sleepTrends["timeAsleep"] = BiomarkerTrendData(
            currentValue: sleep.timeAsleep / 3600,
            unit: "h",
            trend: biomarkerTrends["timeAsleep"]?.trend ?? [],
            percentageChange: nil,
            color: .green
        )
        
        // Time in REM - using new formatting
        sleepTrends["remSleep"] = BiomarkerTrendData(
            currentValue: sleep.remSleep / 3600,
            unit: "h",
            trend: biomarkerTrends["remSleep"]?.trend ?? [],
            percentageChange: nil,
            color: .purple
        )
        
        // Time in Deep - using new formatting
        sleepTrends["deepSleep"] = BiomarkerTrendData(
            currentValue: sleep.deepSleep / 3600,
            unit: "h",
            trend: biomarkerTrends["deepSleep"]?.trend ?? [],
            percentageChange: nil,
            color: .indigo
        )
        
        // Sleep Efficiency
        sleepTrends["efficiency"] = BiomarkerTrendData(
            currentValue: sleep.sleepEfficiency * 100,
            unit: "%",
            trend: biomarkerTrends["efficiency"]?.trend ?? [],
            percentageChange: nil,
            color: .orange
        )
        
        // Time to Fall Asleep
        sleepTrends["fallAsleep"] = BiomarkerTrendData(
            currentValue: sleep.timeToFallAsleep,
            unit: "min",
            trend: biomarkerTrends["fallAsleep"]?.trend ?? [],
            percentageChange: nil,
            color: .red
        )
        
        return sleepTrends
    }
}

// MARK: - Supporting Data Structures

struct ComponentData: Identifiable {
    let id = UUID()
    let name: String
    let score: Double
    let maxScore: Double
    let description: String
    let color: Color
}

struct ComponentBreakdowns {
    let recovery: [ComponentData]
    let sleep: [ComponentData]
}

struct BiomarkerTrendData {
    let currentValue: Double
    let unit: String
    let trend: [Double]
    let percentageChange: Double?
    let color: Color
}

struct HistoricalTrends {
    let sevenDay: [String: [Double]]
    let thirtyDay: [String: [Double]]
}

private struct CachedHealthData {
    let date: Date
    let rawData: DailyMetrics?
    let baseline: BaselineMetrics
    let recovery: RecoveryScoreResult?
    let sleep: SleepScoreResult?
    let components: ComponentBreakdowns
    let trends: [String: BiomarkerTrendData]
    let historicalTrends: HistoricalTrends
    let timestamp: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 300 // 5 minutes
    }
} 