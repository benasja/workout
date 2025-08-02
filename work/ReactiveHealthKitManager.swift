//
//  ReactiveHealthKitManager.swift
//  work
//
//  Created by Kiro on HealthKit Observer Implementation.
//

import Foundation
import HealthKit
import Combine

/// Enhanced HealthKit manager that implements reactive recalculation using HKObserverQuery
/// This fixes the critical race condition where recovery scores are calculated before Apple Watch data syncs
@MainActor
final class ReactiveHealthKitManager: ObservableObject {
    static let shared = ReactiveHealthKitManager()
    
    // MARK: - Published Properties
    @Published var isObservingHealthData = false
    @Published var lastDataUpdateTime: Date?
    @Published var pendingRecalculations: Set<Date> = []
    
    // MARK: - Dependencies
    private let healthStore = HKHealthStore()
    private let recoveryCalculator = RecoveryScoreCalculator.shared
    private let healthStatsViewModel: HealthStatsViewModel?
    
    // MARK: - Observer Queries
    private var hrvObserverQuery: HKObserverQuery?
    private var rhrObserverQuery: HKObserverQuery?
    private var activeObserverQueries: [HKObserverQuery] = []
    
    // MARK: - State Management
    private var isInitialized = false
    private var observerQueryCompletionHandlers: [String: () -> Void] = [:]
    
    private init() {
        self.healthStatsViewModel = nil // Will be set via dependency injection
    }
    
    // MARK: - Initialization
    
    /// Initializes the reactive HealthKit system with observer queries
    /// Call this after HealthKit authorization is granted
    func initializeReactiveSystem() async {
        guard !isInitialized else {
            // print("🔄 ReactiveHealthKitManager already initialized")
            return
        }
        
        // print("🚀 Initializing ReactiveHealthKitManager...")
        
        // Ensure HealthKit is authorized
        guard await ensureHealthKitAuthorization() else {
            // print("❌ HealthKit authorization failed - cannot initialize reactive system")
            return
        }
        
        // Set up observer queries for critical data types
        await setupObserverQueries()
        
        isInitialized = true
        isObservingHealthData = true
        
        // print("✅ ReactiveHealthKitManager initialized successfully")
    }
    
    /// Ensures HealthKit authorization is granted
    private func ensureHealthKitAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            HealthKitManager.shared.requestAuthorization { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    // MARK: - Observer Query Setup
    
    /// Sets up HKObserverQuery for HRV and RHR data types
    private func setupObserverQueries() async {
        // print("🔍 Setting up observer queries for HRV and RHR...")
        
        // Set up HRV observer
        await setupHRVObserver()
        
        // Set up RHR observer
        await setupRHRObserver()
        
        // print("✅ Observer queries set up successfully")
    }
    
    /// Sets up observer query for Heart Rate Variability (SDNN)
    private func setupHRVObserver() async {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            // print("❌ HRV type not available")
            return
        }
        
        let query = HKObserverQuery(sampleType: hrvType, predicate: nil) { [weak self] query, completionHandler, error in
            Task { @MainActor in
                if error != nil {
                    // print("❌ HRV Observer Query error: \(error.localizedDescription)")
                    completionHandler()
                    return
                }
                
                // print("🔔 HRV data updated - triggering reactive recalculation")
                await self?.handleHealthDataUpdate(for: .heartRateVariabilitySDNN)
                completionHandler()
            }
        }
        
        hrvObserverQuery = query
        activeObserverQueries.append(query)
        healthStore.execute(query)
        
        // print("✅ HRV observer query started")
    }
    
    /// Sets up observer query for Resting Heart Rate
    private func setupRHRObserver() async {
        guard let rhrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            // print("❌ RHR type not available")
            return
        }
        
        let query = HKObserverQuery(sampleType: rhrType, predicate: nil) { [weak self] query, completionHandler, error in
            Task { @MainActor in
                if error != nil {
                    // print("❌ RHR Observer Query error: \(error.localizedDescription)")
                    completionHandler()
                    return
                }
                
                // print("🔔 RHR data updated - triggering reactive recalculation")
                await self?.handleHealthDataUpdate(for: .restingHeartRate)
                completionHandler()
            }
        }
        
        rhrObserverQuery = query
        activeObserverQueries.append(query)
        healthStore.execute(query)
        
        // print("✅ RHR observer query started")
    }
    
    // MARK: - Reactive Recalculation Logic
    
    /// Handles health data updates by triggering recalculation for affected dates
    private func handleHealthDataUpdate(for dataType: HKQuantityTypeIdentifier) async {
        lastDataUpdateTime = Date()
        
        // print("🔄 Processing health data update for \(dataType.rawValue)")
        
        // Determine which dates need recalculation
        let datesToRecalculate = await determineDatesForRecalculation(dataType: dataType)
        
        // Add to pending recalculations
        for date in datesToRecalculate {
            pendingRecalculations.insert(date)
        }
        
        // Trigger recalculation for each affected date
        for date in datesToRecalculate {
            await performReactiveRecalculation(for: date, triggeredBy: dataType)
        }
        
        // Clear pending recalculations
        for date in datesToRecalculate {
            pendingRecalculations.remove(date)
        }
    }
    
    /// Determines which dates need recalculation based on the updated data type
    private func determineDatesForRecalculation(dataType: HKQuantityTypeIdentifier) async -> [Date] {
        let calendar = Calendar.current
        var datesToRecalculate: [Date] = []
        
        // Check today and yesterday (in case of late sync from previous day)
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        
        // Always include today
        datesToRecalculate.append(today)
        
        // Include yesterday if it might be affected by late sync
        if await shouldRecalculateDate(yesterday, for: dataType) {
            datesToRecalculate.append(yesterday)
        }
        
        // print("📅 Dates requiring recalculation: \(datesToRecalculate.map { calendar.dateComponents([.month, .day], from: $0) })")
        
        return datesToRecalculate
    }
    
    /// Checks if a specific date should be recalculated based on data availability
    private func shouldRecalculateDate(_ date: Date, for dataType: HKQuantityTypeIdentifier) async -> Bool {
        // Check if we have a stored recovery score for this date
        let scoreStore = ScoreHistoryStore.shared
        let hasStoredScore = scoreStore.hasRecoveryScore(for: date)
        
        if !hasStoredScore {
            // No stored score, so recalculation is needed
            return true
        }
        
        // Check if the new data would significantly change the score
        return await hasSignificantDataChange(for: date, dataType: dataType)
    }
    
    /// Checks if there's significant new data that would change the recovery score
    private func hasSignificantDataChange(for date: Date, dataType: HKQuantityTypeIdentifier) async -> Bool {
        // For now, assume any new data is significant
        // In a more sophisticated implementation, we could compare the new data
        // with what was used in the previous calculation
        return true
    }
    
    /// Performs the actual recalculation for a specific date
    private func performReactiveRecalculation(for date: Date, triggeredBy dataType: HKQuantityTypeIdentifier) async {
        // print("🔄 Starting reactive recalculation for \(date) triggered by \(dataType.rawValue)")
        
        do {
            // Clear any existing cached score for this date
            let scoreStore = ScoreHistoryStore.shared
            scoreStore.deleteRecoveryScore(for: date)
            
            // Recalculate the recovery score with fresh data
            let newRecoveryResult = try await recoveryCalculator.calculateRecoveryScore(for: date)
            
            // print("✅ Reactive recalculation completed for \(date)")
            // print("   New Recovery Score: \(newRecoveryResult.finalScore)")
            // print("   HRV Component: \(String(format: "%.1f", newRecoveryResult.hrvComponent.score))")
            // print("   RHR Component: \(String(format: "%.1f", newRecoveryResult.rhrComponent.score))")
            
            // Notify the UI to update if this is today's data
            if Calendar.current.isDate(date, inSameDayAs: Date()) {
                await notifyUIOfScoreUpdate(newRecoveryResult)
            }
            
        } catch {
            // print("❌ Reactive recalculation failed for \(date): \(error.localizedDescription)")
        }
    }
    
    /// Notifies the UI that a score has been updated
    private func notifyUIOfScoreUpdate(_ newResult: RecoveryScoreResult) async {
        // Trigger a refresh of the HealthStatsViewModel if available
        // This will cause the UI to update with the new score
        if let viewModel = HealthStatsViewModel.shared {
            await viewModel.refresh()
        }
        
        // Post a notification for other parts of the app that might be interested
        NotificationCenter.default.post(
            name: .recoveryScoreUpdated,
            object: nil,
            userInfo: ["newScore": newResult.finalScore, "date": newResult.date]
        )
        
        // print("📱 UI notified of score update: \(newResult.finalScore)")
    }
    
    // MARK: - Manual Recalculation
    
    /// Manually triggers a recalculation for a specific date (useful for testing)
    func manuallyTriggerRecalculation(for date: Date) async {
        // print("🔧 Manual recalculation triggered for \(date)")
        
        pendingRecalculations.insert(date)
        await performReactiveRecalculation(for: date, triggeredBy: .heartRateVariabilitySDNN)
        pendingRecalculations.remove(date)
    }
    
    // MARK: - Observer Query Management
    
    /// Stops all observer queries (call when app is backgrounded or terminated)
    func stopObserverQueries() {
        // print("🛑 Stopping observer queries...")
        
        for query in activeObserverQueries {
            healthStore.stop(query)
        }
        
        activeObserverQueries.removeAll()
        hrvObserverQuery = nil
        rhrObserverQuery = nil
        isObservingHealthData = false
        
        // print("✅ Observer queries stopped")
    }
    
    /// Restarts observer queries (call when app returns to foreground)
    func restartObserverQueries() async {
        guard isInitialized else {
            await initializeReactiveSystem()
            return
        }
        
        // print("🔄 Restarting observer queries...")
        
        stopObserverQueries()
        await setupObserverQueries()
        isObservingHealthData = true
        
        // print("✅ Observer queries restarted")
    }
    
    // MARK: - Background Processing
    
    /// Enables background delivery for critical health data types
    func enableBackgroundDelivery() {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
              let rhrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            // print("❌ Cannot enable background delivery - types not available")
            return
        }
        
        // Enable background delivery for HRV
        healthStore.enableBackgroundDelivery(for: hrvType, frequency: .immediate) { success, _ in
            if success {
                // print("✅ HRV background delivery enabled")
            } else {
                // print("❌ Failed to enable HRV background delivery")
            }
        }
        
        // Enable background delivery for RHR
        healthStore.enableBackgroundDelivery(for: rhrType, frequency: .immediate) { success, _ in
            if success {
                // print("✅ RHR background delivery enabled")
            } else {
                // print("❌ Failed to enable RHR background delivery")
            }
        }
    }
    
    /// Disables background delivery (call when no longer needed)
    func disableBackgroundDelivery() {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
              let rhrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            return
        }
        
        healthStore.disableBackgroundDelivery(for: hrvType) { success, _ in
            if success {
                // print("✅ HRV background delivery disabled")
            }
        }
        
        healthStore.disableBackgroundDelivery(for: rhrType) { success, _ in
            if success {
                // print("✅ RHR background delivery disabled")
            }
        }
    }
    
    // MARK: - Status and Debugging
    
    /// Returns the current status of the reactive system
    var systemStatus: ReactiveSystemStatus {
        ReactiveSystemStatus(
            isInitialized: isInitialized,
            isObserving: isObservingHealthData,
            activeObserverCount: activeObserverQueries.count,
            pendingRecalculations: Array(pendingRecalculations),
            lastUpdateTime: lastDataUpdateTime
        )
    }
    
    /// Checks if we have sufficient data for today's recovery score
    /// This helps determine if we should continue showing monitoring status
    func hasCompleteDataForToday() async -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        
        // Check if we have a recovery score for today
        let scoreStore = ScoreHistoryStore.shared
        guard let todayScore = scoreStore.getRecoveryScore(for: today) else {
            return false // No score means incomplete data
        }
        
        // Check if the score has both HRV and RHR data
        let hasHRV = todayScore.hrvValue != nil && todayScore.hrvValue! > 0
        let hasRHR = todayScore.rhrValue != nil && todayScore.rhrValue! > 0
        
        return hasHRV && hasRHR
    }
    
    /// Prints detailed status information for debugging
    func printSystemStatus() {
        let status = systemStatus
        print("🔍 ReactiveHealthKitManager Status:")
        print("   Initialized: \(status.isInitialized)")
        print("   Observing: \(status.isObserving)")
        print("   Active Observers: \(status.activeObserverCount)")
        print("   Pending Recalculations: \(status.pendingRecalculations.count)")
        print("   Last Update: \(status.lastUpdateTime?.description ?? "Never")")
    }
}

// MARK: - Supporting Types

struct ReactiveSystemStatus {
    let isInitialized: Bool
    let isObserving: Bool
    let activeObserverCount: Int
    let pendingRecalculations: [Date]
    let lastUpdateTime: Date?
}

// MARK: - Notification Names

extension Notification.Name {
    static let recoveryScoreUpdated = Notification.Name("recoveryScoreUpdated")
    static let healthDataSyncCompleted = Notification.Name("healthDataSyncCompleted")
}

// MARK: - HealthStatsViewModel Extension

extension HealthStatsViewModel {
    /// Singleton access for ReactiveHealthKitManager
    static weak var shared: HealthStatsViewModel?
    
    /// Sets up the shared instance (call from your main view model initialization)
    func setupAsSharedInstance() {
        HealthStatsViewModel.shared = self
    }
}