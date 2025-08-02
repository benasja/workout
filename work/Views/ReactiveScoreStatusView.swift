//
//  ReactiveScoreStatusView.swift
//  work
//
//  Created by Kiro on Reactive Score Status UI.
//

import SwiftUI

/// UI component that shows the status of reactive score calculation
/// Displays when scores are being recalculated due to new HealthKit data
struct ReactiveScoreStatusView: View {
    @StateObject private var reactiveManager = ReactiveHealthKitManager.shared
    @State private var showingDetails = false
    @State private var hasCompleteData = false
    
    var body: some View {
        VStack(spacing: 8) {
            if !reactiveManager.pendingRecalculations.isEmpty {
                // Active recalculation indicator
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Updating Recovery Score")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("New health data detected")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { showingDetails.toggle() }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(AppColors.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.primary.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.primary.opacity(0.3), lineWidth: 1)
                        )
                )
                .transition(.scale.combined(with: .opacity))
                
            } else if reactiveManager.isObservingHealthData && shouldShowMonitoringStatus && !hasCompleteData {
                // Monitoring status indicator (only show if recently updated or data might be incomplete)
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppColors.success)
                        .frame(width: 6, height: 6)
                    
                    Text(monitoringStatusText)
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Spacer()
                    
                    if let lastUpdate = reactiveManager.lastDataUpdateTime {
                        Text("Last update: \(formatLastUpdateTime(lastUpdate))")
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.success.opacity(0.05))
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: reactiveManager.pendingRecalculations.isEmpty)
        .sheet(isPresented: $showingDetails) {
            ReactiveSystemDetailsView()
        }
        .task {
            // Check if we have complete data when the view appears
            hasCompleteData = await reactiveManager.hasCompleteDataForToday()
        }
        .onChange(of: reactiveManager.lastDataUpdateTime) { _, _ in
            // Recheck data completeness when new data arrives
            Task {
                hasCompleteData = await reactiveManager.hasCompleteDataForToday()
            }
        }
    }
    
    /// Determines if we should show the monitoring status
    private var shouldShowMonitoringStatus: Bool {
        // Show monitoring status if:
        // 1. Data was updated recently (within last 30 minutes)
        // 2. It's early in the day (before 10 AM) when Watch sync is most likely
        // 3. We're in debug mode
        
        if let lastUpdate = reactiveManager.lastDataUpdateTime {
            let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)
            if timeSinceUpdate < 1800 { // 30 minutes
                return true
            }
        }
        
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 10 { // Before 10 AM
            return true
        }
        
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    /// Dynamic monitoring status text based on context
    private var monitoringStatusText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        if let lastUpdate = reactiveManager.lastDataUpdateTime {
            let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)
            if timeSinceUpdate < 300 { // 5 minutes
                return hasCompleteData ? "Score updated with complete data" : "Score updated, monitoring for more data"
            }
        }
        
        if hasCompleteData {
            return "Ready - monitoring for new data"
        } else if hour < 10 {
            return "Waiting for Apple Watch sync"
        } else {
            return "Monitoring for health data updates"
        }
    }
    
    private func formatLastUpdateTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// Detailed view showing reactive system status and information
struct ReactiveSystemDetailsView: View {
    @StateObject private var reactiveManager = ReactiveHealthKitManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reactive Score System")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Your recovery score automatically updates when new health data syncs from your Apple Watch.")
                            .font(.body)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    // System Status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("System Status")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        
                        StatusRow(
                            title: "Health Data Monitoring",
                            status: reactiveManager.isObservingHealthData ? "Active" : "Inactive",
                            isPositive: reactiveManager.isObservingHealthData
                        )
                        
                        StatusRow(
                            title: "Observer Queries",
                            status: "\(reactiveManager.systemStatus.activeObserverCount) active",
                            isPositive: reactiveManager.systemStatus.activeObserverCount > 0
                        )
                        
                        if !reactiveManager.pendingRecalculations.isEmpty {
                            StatusRow(
                                title: "Pending Updates",
                                status: "\(reactiveManager.pendingRecalculations.count) dates",
                                isPositive: false
                            )
                        }
                        
                        if let lastUpdate = reactiveManager.lastDataUpdateTime {
                            StatusRow(
                                title: "Last Data Update",
                                status: formatDetailedTime(lastUpdate),
                                isPositive: true
                            )
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.secondaryBackground)
                    )
                    
                    // How It Works
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How It Works")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ReactiveFeatureRow(
                                icon: "heart.fill",
                                title: "Continuous Monitoring",
                                description: "Watches for new HRV and RHR data from HealthKit"
                            )
                            
                            ReactiveFeatureRow(
                                icon: "arrow.clockwise",
                                title: "Automatic Recalculation",
                                description: "Updates your recovery score when new data arrives"
                            )
                            
                            ReactiveFeatureRow(
                                icon: "clock.fill",
                                title: "Real-time Updates",
                                description: "No need to restart the app or manually refresh"
                            )
                            
                            ReactiveFeatureRow(
                                icon: "battery.25",
                                title: "Battery Efficient",
                                description: "Uses Apple's optimized background delivery system"
                            )
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.secondaryBackground)
                    )
                    
                    // Debug Actions (only in debug builds)
                    #if DEBUG
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Debug Actions")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Button(action: {
                            Task {
                                await reactiveManager.manuallyTriggerRecalculation(for: Date())
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Trigger Manual Recalculation")
                            }
                            .foregroundColor(AppColors.primary)
                        }
                        
                        Button(action: {
                            reactiveManager.printSystemStatus()
                        }) {
                            HStack {
                                Image(systemName: "doc.text")
                                Text("Print System Status to Console")
                            }
                            .foregroundColor(AppColors.secondary)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.warning.opacity(0.1))
                    )
                    #endif
                }
                .padding(20)
            }
            .navigationTitle("Reactive System")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDetailedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct StatusRow: View {
    let title: String
    let status: String
    let isPositive: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(isPositive ? AppColors.success : AppColors.warning)
                    .frame(width: 6, height: 6)
                
                Text(status)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
            }
        }
    }
}

struct ReactiveFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppColors.primary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ReactiveScoreStatusView()
}