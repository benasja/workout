import SwiftUI
import SwiftData
import HealthKit
import Charts
// Add this import for shared components
import Foundation

struct EnhancedPerformanceView: View {
    @EnvironmentObject var dateModel: PerformanceDateModel
    @EnvironmentObject var tabSelectionModel: TabSelectionModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyJournal.date, order: .reverse) private var journalEntries: [DailyJournal]
    
    @State private var recoveryScore: Int? = nil
    @State private var sleepScore: Int? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var healthMetrics: EnhancedHealthMetrics? = nil
    @State private var showingHealthKitAlert = false
    @State private var personalizedTips: [PersonalizedTip] = []
    @State private var weeklyTrends: WeeklyTrends? = nil
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Enhanced Header with Personalized Greeting
                    enhancedHeaderView
                    
                    // Date Slider with Week View
                    EnhancedDateSliderView(selectedDate: $dateModel.selectedDate)
                    
                    if isLoading {
                        enhancedLoadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else {
                        // Main Score Cards with Trends
                        enhancedScoreCardsView
                        
                        // Weekly Trends Summary
                        if let trends = weeklyTrends {
                            WeeklyTrendsCard(trends: trends)
                        }
                        
                        // Enhanced Health Metrics Grid
                        if let metrics = healthMetrics {
                            EnhancedHealthMetricsGrid(metrics: metrics)
                        }
                        
                        // Personalized Tips & Insights
                        if !personalizedTips.isEmpty {
                            PersonalizedTipsView(tips: personalizedTips)
                        }
                        
                        // Quick Actions with Smart Suggestions
                        EnhancedQuickActionsView()
                            .environmentObject(tabSelectionModel)
                        
                        // Journal Summary with AI Insights
                        EnhancedJournalSummaryView(
                            selectedDate: dateModel.selectedDate,
                            entries: journalEntries
                        )
                        
                        // Today's Comprehensive Insights
                        if let recovery = recoveryScore, let sleep = sleepScore {
                            ComprehensiveInsightsView(
                                recoveryScore: recovery,
                                sleepScore: sleep,
                                healthMetrics: healthMetrics,
                                journalEntry: currentJournalEntry
                            )
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                await refreshAllData()
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            fetchAllData()
        }
        .onChange(of: dateModel.selectedDate) { _, _ in
            fetchAllData()
        }
        .alert("HealthKit Access Required", isPresented: $showingHealthKitAlert) {
            Button("Grant Access") {
                requestHealthKitAccess()
            }
            Button("Skip", role: .cancel) { }
        } message: {
            Text("To show your personalized health data and insights, please grant access to HealthKit.")
        }
    }
    
    // MARK: - Enhanced Views
    
    private var enhancedHeaderView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(personalizedGreeting)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(enhancedDateSubtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Weather Integration (placeholder)
                WeatherWidget()
            }
            
            // Readiness Summary
            if let recovery = recoveryScore, let sleep = sleepScore {
                ReadinessSummaryCard(recoveryScore: recovery, sleepScore: sleep)
            }
        }
        .padding(.top)
    }
    
    private var enhancedLoadingView: some View {
        VStack(spacing: 20) {
            // Animated loading indicator
            ZStack {
                Circle()
                    .stroke(AppColors.primary.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(AppColors.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isLoading)
            }
            
            VStack(spacing: 8) {
                Text("Analyzing your health data...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Calculating personalized insights and recommendations")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(height: 200)
    }
    
    private var enhancedScoreCardsView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                NavigationLink(destination: RecoveryDetailView().environmentObject(dateModel)) {
                    EnhancedScoreCard(
                        title: "Recovery",
                        score: recoveryScore,
                        color: scoreColor(for: recoveryScore),
                        icon: "heart.fill",
                        subtitle: recoverySubtitle,
                        trend: getRecoveryTrend(),
                        recommendation: getRecoveryRecommendation()
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: SleepDetailView().environmentObject(dateModel)) {
                    EnhancedScoreCard(
                        title: "Sleep",
                        score: sleepScore,
                        color: scoreColor(for: sleepScore),
                        icon: "bed.double.fill",
                        subtitle: sleepSubtitle,
                        trend: getSleepTrend(),
                        recommendation: getSleepRecommendation()
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Additional metrics row
            HStack(spacing: 16) {
                if let hrv = healthMetrics?.hrv {
                    MetricMiniCard(
                        title: "HRV",
                        value: "\(Int(hrv))",
                        unit: "ms",
                        color: .green,
                        trend: getHRVTrend()
                    )
                }
                
                if let rhr = healthMetrics?.rhr {
                    MetricMiniCard(
                        title: "RHR",
                        value: "\(Int(rhr))",
                        unit: "bpm",
                        color: .red,
                        trend: getRHRTrend()
                    )
                }
                
                if let steps = healthMetrics?.steps {
                    MetricMiniCard(
                        title: "Steps",
                        value: "\(Int(steps))",
                        unit: "",
                        color: .blue,
                        trend: getStepsTrend()
                    )
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var personalizedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let calendar = Calendar.current
        
        if calendar.isDateInToday(dateModel.selectedDate) {
            switch hour {
            case 5..<12: return "Good Morning"
            case 12..<17: return "Good Afternoon"
            case 17..<22: return "Good Evening"
            default: return "Good Night"
            }
        } else if calendar.isDateInYesterday(dateModel.selectedDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: dateModel.selectedDate)
        }
    }
    
    private var enhancedDateSubtitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        let dateString = formatter.string(from: dateModel.selectedDate)
        
        if Calendar.current.isDateInToday(dateModel.selectedDate) {
            return "\(dateString) • Today"
        } else {
            return dateString
        }
    }
    
    private var currentJournalEntry: DailyJournal? {
        let calendar = Calendar.current
        return journalEntries.first { calendar.isDate($0.date, inSameDayAs: dateModel.selectedDate) }
    }
    
    private var recoverySubtitle: String {
        guard let score = recoveryScore else { return "Loading..." }
        switch score {
        case 85...: return "Primed for peak performance"
        case 70..<85: return "Good recovery state"
        case 55..<70: return "Moderate recovery"
        default: return "Focus on recovery"
        }
    }
    
    private var sleepSubtitle: String {
        guard let score = sleepScore else { return "Loading..." }
        switch score {
        case 85...: return "Excellent sleep quality"
        case 70..<85: return "Good sleep quality"
        case 50..<70: return "Fair sleep quality"
        default: return "Poor sleep quality"
        }
    }
    
    // MARK: - Methods
    
    private func fetchAllData() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Check HealthKit authorization first
        if !HealthKitManager.shared.checkAuthorizationStatus() {
            showingHealthKitAlert = true
            isLoading = false
            return
        }
        
        Task {
            do {
                // Fetch all data concurrently
                async let recoveryResult = RecoveryScoreCalculator.shared.calculateRecoveryScore(for: dateModel.selectedDate)
                async let sleepResult = SleepScoreCalculator.shared.calculateSleepScore(for: dateModel.selectedDate)
                async let healthData = fetchEnhancedHealthMetrics()
                async let tipsData = generatePersonalizedTips()
                async let trendsData = fetchWeeklyTrends()
                
                let (recovery, sleep, metrics, tips, trends) = try await (recoveryResult, sleepResult, healthData, tipsData, trendsData)
                
                await MainActor.run {
                    self.recoveryScore = recovery.finalScore
                    self.sleepScore = sleep.finalScore
                    self.healthMetrics = metrics
                    self.personalizedTips = tips
                    self.weeklyTrends = trends
                    self.isLoading = false
                    self.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Failed to load health data. Please check your HealthKit permissions and try again."
                }
            }
        }
    }
    
    private func refreshAllData() async {
        await MainActor.run {
            fetchAllData()
        }
    }
    
    private func requestHealthKitAccess() {
        HealthKitManager.shared.requestAuthorization { success in
            DispatchQueue.main.async {
                if success {
                    self.fetchAllData()
                }
            }
        }
    }
    
    private func fetchEnhancedHealthMetrics() async -> EnhancedHealthMetrics {
        return await withCheckedContinuation { continuation in
            let group = DispatchGroup()
            var hrv: Double?
            var rhr: Double?
            var walkingHR: Double?
            var respiratoryRate: Double?
            var oxygenSaturation: Double?
            var steps: Double?
            var activeEnergy: Double?
            let vo2Max: Double? = nil
            
            // Fetch all metrics
            group.enter()
            HealthKitManager.shared.fetchHRV(for: dateModel.selectedDate) { value in
                hrv = value
                group.leave()
            }
            
            group.enter()
            HealthKitManager.shared.fetchRHR(for: dateModel.selectedDate) { value in
                rhr = value
                group.leave()
            }
            
            group.enter()
            HealthKitManager.shared.fetchWalkingHeartRate(for: dateModel.selectedDate) { value in
                walkingHR = value
                group.leave()
            }
            
            group.enter()
            HealthKitManager.shared.fetchRespiratoryRate(for: dateModel.selectedDate) { value in
                respiratoryRate = value
                group.leave()
            }
            
            group.enter()
            HealthKitManager.shared.fetchOxygenSaturation(for: dateModel.selectedDate) { value in
                oxygenSaturation = value
                group.leave()
            }
            
            // Fetch steps for today
            group.enter()
            fetchStepsForDate(dateModel.selectedDate) { value in
                steps = value
                group.leave()
            }
            
            // Fetch active energy
            group.enter()
            HealthKitManager.shared.fetchLatestActiveEnergy { value in
                activeEnergy = value
                group.leave()
            }
            
            group.notify(queue: .main) {
                let metrics = EnhancedHealthMetrics(
                    hrv: hrv,
                    rhr: rhr,
                    walkingHeartRate: walkingHR,
                    respiratoryRate: respiratoryRate,
                    oxygenSaturation: oxygenSaturation,
                    steps: steps,
                    activeEnergy: activeEnergy,
                    vo2Max: vo2Max
                )
                continuation.resume(returning: metrics)
            }
        }
    }
    
    private func fetchStepsForDate(_ date: Date, completion: @escaping (Double?) -> Void) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(nil)
            return
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
            completion(steps)
        }
        
        HealthKitManager.shared.execute(query)
    }
    
    private func generatePersonalizedTips() async -> [PersonalizedTip] {
        // Generate tips based on current data and patterns
        var tips: [PersonalizedTip] = []
        
        // Recovery-based tips
        if let recovery = recoveryScore {
            if recovery < 60 {
                tips.append(PersonalizedTip(
                    title: "Focus on Recovery",
                    description: "Your recovery score is low. Consider taking a rest day or doing light activity.",
                    icon: "heart.fill",
                    color: .red,
                    priority: .high
                ))
            }
        }
        
        // Sleep-based tips
        if let sleep = sleepScore {
            if sleep < 70 {
                tips.append(PersonalizedTip(
                    title: "Improve Sleep Quality",
                    description: "Try going to bed 30 minutes earlier tonight for better recovery.",
                    icon: "bed.double.fill",
                    color: .blue,
                    priority: .medium
                ))
            }
        }
        
        // Journal-based tips
        if let entry = currentJournalEntry {
            if entry.consumedAlcohol {
                tips.append(PersonalizedTip(
                    title: "Hydration Focus",
                    description: "You had alcohol yesterday. Extra hydration will help your recovery.",
                    icon: "drop.fill",
                    color: .cyan,
                    priority: .medium
                ))
            }
            
            if entry.highStressDay {
                tips.append(PersonalizedTip(
                    title: "Stress Management",
                    description: "Try 10 minutes of meditation or deep breathing to manage stress.",
                    icon: "leaf.fill",
                    color: .green,
                    priority: .high
                ))
            }
        }
        
        return tips
    }
    
    private func fetchWeeklyTrends() async -> WeeklyTrends {
        // Calculate trends for the past week
        let _ = Calendar.current
        let _ = dateModel.selectedDate
        // This would fetch actual data - for now returning sample data
        return WeeklyTrends(
            recoveryTrend: 2.5,
            sleepTrend: -1.2,
            hrvTrend: 3.1,
            rhrTrend: -0.8,
            stepsTrend: 15.2
        )
    }
    
    // MARK: - Trend Helpers
    
    private func getRecoveryTrend() -> TrendDirection {
        // Calculate based on recent data
        return .up
    }
    
    private func getSleepTrend() -> TrendDirection {
        return .stable
    }
    
    private func getHRVTrend() -> TrendDirection {
        return .up
    }
    
    private func getRHRTrend() -> TrendDirection {
        return .down
    }
    
    private func getStepsTrend() -> TrendDirection {
        return .up
    }
    
    private func getRecoveryRecommendation() -> String {
        guard let score = recoveryScore else { return "" }
        switch score {
        case 85...: return "Perfect for high-intensity training"
        case 70..<85: return "Good for moderate training"
        case 55..<70: return "Consider light activity"
        default: return "Focus on rest and recovery"
        }
    }
    
    private func getSleepRecommendation() -> String {
        guard let score = sleepScore else { return "" }
        switch score {
        case 85...: return "Excellent sleep foundation"
        case 70..<85: return "Good sleep quality"
        case 50..<70: return "Room for improvement"
        default: return "Prioritize sleep hygiene"
        }
    }
    
    private func scoreColor(for score: Int?) -> Color {
        guard let score = score else { return .gray }
        switch score {
        case 85...: return .green
        case 70..<85: return .blue
        case 55..<70: return .orange
        default: return .red
        }
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Unable to load data")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                fetchAllData()
            }
            .primaryButton()
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(16)
    }
}

// MARK: - Supporting Models and Views

struct EnhancedHealthMetrics {
    let hrv: Double?
    let rhr: Double?
    let walkingHeartRate: Double?
    let respiratoryRate: Double?
    let oxygenSaturation: Double?
    let steps: Double?
    let activeEnergy: Double?
    let vo2Max: Double?
}

struct PersonalizedTip: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color: Color
    let priority: Priority
    
    enum Priority {
        case high, medium, low
    }
}

struct WeeklyTrends {
    let recoveryTrend: Double // percentage change
    let sleepTrend: Double
    let hrvTrend: Double
    let rhrTrend: Double
    let stepsTrend: Double
}

enum TrendDirection {
    case up, down, stable
    
    var icon: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .stable: return "minus"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return AppColors.success
        case .down: return AppColors.error
        case .stable: return AppColors.textSecondary
        }
    }
}

// MARK: - Enhanced Components

struct EnhancedScoreCard: View {
    let title: String
    let score: Int?
    let color: Color
    let icon: String
    let subtitle: String
    let trend: TrendDirection
    let recommendation: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with trend
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: trend.icon)
                        .font(.caption)
                        .foregroundColor(trend.color)
                    
                    if let score = score {
                        Text("\(score)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(color)
                    } else {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(color)
                    }
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                if !recommendation.isEmpty {
                    Text(recommendation)
                        .font(.caption2)
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct MetricMiniCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let trend: TrendDirection
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: trend.icon)
                    .font(.caption2)
                    .foregroundColor(trend.color)
            }
            
            HStack(alignment: .bottom, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(AppColors.secondaryBackground)
        .cornerRadius(12)
    }
}

struct WeatherWidget: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.max.fill")
                .font(.title2)
                .foregroundColor(.orange)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("22°")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Sunny")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(AppColors.secondaryBackground)
        .cornerRadius(12)
    }
}

struct ReadinessSummaryCard: View {
    let recoveryScore: Int
    let sleepScore: Int
    
    private var overallReadiness: Int {
        (recoveryScore + sleepScore) / 2
    }
    
    private var readinessColor: Color {
        switch overallReadiness {
        case 85...: return .green
        case 70..<85: return .blue
        case 55..<70: return .orange
        default: return .red
        }
    }
    
    private var readinessText: String {
        switch overallReadiness {
        case 85...: return "Excellent Readiness"
        case 70..<85: return "Good Readiness"
        case 55..<70: return "Moderate Readiness"
        default: return "Low Readiness"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Readiness score circle
            ZStack {
                Circle()
                    .stroke(readinessColor.opacity(0.2), lineWidth: 8)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: Double(overallReadiness) / 100)
                    .stroke(readinessColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                Text("\(overallReadiness)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(readinessColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(readinessText)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Based on recovery and sleep scores")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(16)
    }
}

// Placeholder views for new components
struct EnhancedDateSliderView: View {
    @Binding var selectedDate: Date
    
    var body: some View {
        DateSliderView(selectedDate: $selectedDate)
    }
}

struct WeeklyTrendsCard: View {
    let trends: WeeklyTrends
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Trends")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Trends grid would go here
            Text("Trends visualization coming soon")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(16)
    }
}

struct EnhancedHealthMetricsGrid: View {
    let metrics: EnhancedHealthMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Metrics")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                if let hrv = metrics.hrv {
                    MetricCard(
                        title: "HRV",
                        value: hrv,
                        unit: "ms",
                        icon: "waveform.path.ecg",
                        color: .green
                    )
                }
                
                if let rhr = metrics.rhr {
                    MetricCard(
                        title: "RHR",
                        value: rhr,
                        unit: "bpm",
                        icon: "heart.fill",
                        color: .red
                    )
                }
                
                if let walkingHR = metrics.walkingHeartRate {
                    MetricCard(
                        title: "Walking HR",
                        value: walkingHR,
                        unit: "bpm",
                        icon: "figure.walk",
                        color: .blue
                    )
                }
                
                if let respiratoryRate = metrics.respiratoryRate {
                    MetricCard(
                        title: "Resp Rate",
                        value: respiratoryRate,
                        unit: "rpm",
                        icon: "lungs.fill",
                        color: .purple
                    )
                }
                
                if let steps = metrics.steps {
                    MetricCard(
                        title: "Steps",
                        value: steps,
                        unit: "",
                        icon: "figure.walk",
                        color: .blue
                    )
                }
                
                if let activeEnergy = metrics.activeEnergy {
                    MetricCard(
                        title: "Active Cal",
                        value: activeEnergy,
                        unit: "kcal",
                        icon: "flame.fill",
                        color: .orange
                    )
                }
            }
        }
    }
}

struct PersonalizedTipsView: View {
    let tips: [PersonalizedTip]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personalized Tips")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            ForEach(tips) { tip in
                HStack(spacing: 12) {
                    Image(systemName: tip.icon)
                        .font(.title2)
                        .foregroundColor(tip.color)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tip.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(tip.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(tip.color.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
}

struct EnhancedQuickActionsView: View {
    @EnvironmentObject var tabSelectionModel: TabSelectionModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                
                NavigationLink(destination: JournalView()) {
                    QuickActionCard(
                        title: "Add Journal",
                        icon: "book.closed.fill",
                        color: .blue
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: WeightTrackerView()) {
                    QuickActionCard(
                        title: "Log Weight",
                        icon: "scalemass",
                        color: .green
                    )
                }
                .buttonStyle(PlainButtonStyle())
                Button(action: {
                    tabSelectionModel.selection = 5 // Switch to More tab
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Optionally, you could set a flag in tabSelectionModel to scroll to the Workout section if needed
                    }
                }) {
                    QuickActionCard(
                        title: "Workout",
                        icon: "dumbbell.fill",
                        color: .orange
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct EnhancedJournalSummaryView: View {
    let selectedDate: Date
    let entries: [DailyJournal]
    
    private var currentEntry: DailyJournal? {
        let calendar = Calendar.current
        return entries.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "book.closed.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("Journal Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
                NavigationLink(destination: JournalView()) {
                    Text("View All")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.08))
                        .cornerRadius(8)
                }
            }
            
            if let entry = currentEntry {
                VStack(alignment: .leading, spacing: 14) {
                    // Tags Summary
                    if !entry.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Today's Tags:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                                ForEach(entry.tags.prefix(6), id: \.self) { tagName in
                                    HStack(spacing: 4) {
                                        if let tag = getJournalTag(for: tagName) {
                                            Image(systemName: tag.icon)
                                                .font(.caption2)
                                                .foregroundColor(tag.color)
                                            Text(tag.displayName)
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                        } else {
                                            Text(tagName)
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(tagBackground(for: tagName))
                                    .cornerRadius(10)
                                }
                            }
                            if entry.tags.count > 6 {
                                Text("+ \(entry.tags.count - 6) more")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Notes Preview
                    if let notes = entry.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Text(notes)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(3)
                                .padding(10)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Text("No journal entry for this day")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    NavigationLink(destination: JournalView()) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add Entry")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
    
    private func getJournalTag(for tagName: String) -> JournalTag? {
        return JournalTag.allCases.first { $0.displayName == tagName }
    }
    
    private func tagBackground(for tagName: String) -> Color {
        if let tag = getJournalTag(for: tagName) {
            return tag.color.opacity(0.13)
        }
        return Color(.systemGray5)
    }
}

struct ComprehensiveInsightsView: View {
    let recoveryScore: Int
    let sleepScore: Int
    let healthMetrics: EnhancedHealthMetrics?
    let journalEntry: DailyJournal?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Insights")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                InsightRow(
                    icon: "lightbulb.fill",
                    text: generateComprehensiveInsight(),
                    color: .orange
                )
                
                InsightRow(
                    icon: "target",
                    text: generateSmartRecommendation(),
                    color: .blue
                )
                
                if let entry = journalEntry {
                    InsightRow(
                        icon: "brain.head.profile",
                        text: generateJournalInsight(from: entry),
                        color: .purple
                    )
                }
            }
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(16)
    }
    
    private func generateComprehensiveInsight() -> String {
        let avgScore = (recoveryScore + sleepScore) / 2
        
        // Factor in HRV if available
        var insight = ""
        if let hrv = healthMetrics?.hrv {
            if hrv > 50 {
                insight += "Your HRV is excellent (\(Int(hrv))ms). "
            } else if hrv < 30 {
                insight += "Your HRV is low (\(Int(hrv))ms), indicating stress. "
            }
        }
        
        switch avgScore {
        case 85...:
            insight += "You're in peak condition today! Perfect time for challenging workouts or important tasks."
        case 70..<85:
            insight += "Good balance between recovery and sleep. Your body is ready for moderate to high intensity activities."
        case 55..<70:
            insight += "Moderate readiness. Consider lighter activities or focus on skill-based training."
        default:
            insight += "Your body needs more rest. Prioritize recovery activities and stress management."
        }
        
        return insight
    }
    
    private func generateSmartRecommendation() -> String {
        var recommendations: [String] = []
        
        // Recovery-based recommendations
        if recoveryScore < sleepScore - 15 {
            recommendations.append("Your recovery is lagging behind sleep quality - consider stress management techniques")
        } else if sleepScore < recoveryScore - 15 {
            recommendations.append("Sleep quality could be improved - review your bedtime routine and sleep environment")
        }
        
        // HRV-based recommendations
        if let hrv = healthMetrics?.hrv, hrv < 30 {
            recommendations.append("Low HRV suggests high stress - try meditation or breathing exercises")
        }
        
        // Steps-based recommendations
        if let steps = healthMetrics?.steps, steps < 8000 {
            recommendations.append("Aim for more daily movement - even a 10-minute walk can help")
        }
        
        if recommendations.isEmpty {
            if recoveryScore > 80 && sleepScore > 80 {
                return "Excellent day for challenging workouts or tackling important goals!"
            } else {
                return "Focus on maintaining consistent sleep and recovery habits for optimal performance."
            }
        }
        
        return recommendations.first ?? "Keep up your healthy habits!"
    }
    
    private func generateJournalInsight(from entry: DailyJournal) -> String {
        var insights: [String] = []
        
        if entry.consumedAlcohol {
            insights.append("Alcohol consumption may impact tonight's sleep quality and tomorrow's recovery")
        }
        
        if entry.highStressDay {
            insights.append("High stress can affect HRV and recovery - consider relaxation techniques")
        }
        
        if entry.tookMagnesium {
            insights.append("Magnesium supplementation may improve sleep quality and muscle recovery")
        }
        
        if entry.ateLate {
            insights.append("Late eating can disrupt sleep - try to finish meals 3 hours before bed")
        }
        
        return insights.first ?? "Your lifestyle choices today will influence tomorrow's readiness."
    }
}
