import SwiftUI
import SwiftData

class PerformanceDateModel: ObservableObject {
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())
}

struct PerformanceView: View {
    @EnvironmentObject var dateModel: PerformanceDateModel
    @EnvironmentObject var tabSelectionModel: TabSelectionModel
    @State private var recoveryScore: Int? = nil
    @State private var sleepScore: Int? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var loadingWorkItem: DispatchWorkItem? = nil
    @State private var healthMetrics: HealthMetrics? = nil
    @State private var showingHealthKitAlert = false
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header with date
                    VStack(spacing: 8) {
                        Text(headerTitle)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(dateSubtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Date Slider
                    DateSliderView(selectedDate: $dateModel.selectedDate)
                    
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else {
                        // Main Score Cards
                        HStack(spacing: 16) {
                            NavigationLink(destination: RecoveryDetailView().environmentObject(dateModel)) {
                                ModernScoreCard(
                                    title: "Recovery",
                                    score: recoveryScore,
                                    color: scoreColor(for: recoveryScore),
                                    icon: "heart.fill",
                                    subtitle: recoverySubtitle
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            NavigationLink(destination: SleepDetailView().environmentObject(dateModel)) {
                                ModernScoreCard(
                                    title: "Sleep",
                                    score: sleepScore,
                                    color: scoreColor(for: sleepScore),
                                    icon: "bed.double.fill",
                                    subtitle: sleepSubtitle
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Health Metrics Grid
                        if let metrics = healthMetrics {
                            HealthMetricsGrid(metrics: metrics)
                        }
                        
                        // Quick Actions
                        QuickActionsView()
                        
                        // Journal Summary
                        JournalSummaryView(selectedDate: dateModel.selectedDate)
                        
                        // Today's Insights
                        if let recovery = recoveryScore, let sleep = sleepScore {
                            TodaysInsightsView(recoveryScore: recovery, sleepScore: sleep)
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                await refreshData()
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            fetchScores()
            
            // Sync latest sleep data to server when opening Today view
            Task {
                await HealthKitManager.shared.checkAndSyncSleepDataIfNeeded()
            }
        }
        .onChange(of: dateModel.selectedDate) { _, _ in
            fetchScores()
        }
        .alert("HealthKit Access Required", isPresented: $showingHealthKitAlert) {
            Button("Grant Access") {
                requestHealthKitAccess()
            }
            Button("Skip", role: .cancel) { }
        } message: {
            Text("To show your personalized health data, please grant access to HealthKit.")
        }
    }
    
    // MARK: - Computed Properties
    
    private var headerTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(dateModel.selectedDate) {
            return "Today"
        } else if calendar.isDateInYesterday(dateModel.selectedDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: dateModel.selectedDate)
        }
    }
    
    private var dateSubtitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: dateModel.selectedDate)
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
    
    // MARK: - Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColors.primary)
            
            Text("Loading your health data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 120)
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
                fetchScores()
            }
            .primaryButton()
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Methods
    
    private func fetchScores() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        loadingWorkItem?.cancel()
        
        // Check HealthKit authorization first
        if !HealthKitManager.shared.checkAuthorizationStatus() {
            showingHealthKitAlert = true
            isLoading = false
            return
        }
        
        Task {
            do {
                // Fetch scores concurrently
                async let recoveryResult = RecoveryScoreCalculator.shared.calculateRecoveryScore(for: dateModel.selectedDate)
                async let sleepResult = SleepScoreCalculator.shared.calculateSleepScore(for: dateModel.selectedDate)
                async let healthData = fetchHealthMetrics()
                
                let (recovery, sleep, metrics) = try await (recoveryResult, sleepResult, healthData)
                
                await MainActor.run {
                    self.recoveryScore = recovery.finalScore
                    self.sleepScore = sleep.finalScore
                    self.healthMetrics = metrics
                    self.isLoading = false
                    self.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Failed to load health data. Please check your HealthKit permissions."
                }
            }
        }
    }
    
    private func refreshData() async {
        await MainActor.run {
            fetchScores()
        }
    }
    
    private func requestHealthKitAccess() {
        HealthKitManager.shared.requestAuthorization { success in
            DispatchQueue.main.async {
                if success {
                    self.fetchScores()
                }
            }
        }
    }
    
    private func fetchHealthMetrics() async -> HealthMetrics {
        return await withCheckedContinuation { continuation in
            let group = DispatchGroup()
            var hrv: Double?
            var rhr: Double?
            var walkingHR: Double?
            var respiratoryRate: Double?
            
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
            
            group.notify(queue: .main) {
                let metrics = HealthMetrics(
                    hrv: hrv,
                    rhr: rhr,
                    walkingHeartRate: walkingHR,
                    respiratoryRate: respiratoryRate
                )
                continuation.resume(returning: metrics)
            }
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
}

// MARK: - Supporting Views and Models

struct HealthMetrics {
    let hrv: Double?
    let rhr: Double?
    let walkingHeartRate: Double?
    let respiratoryRate: Double?
}

struct ModernScoreCard: View {
    let title: String
    let score: Int?
    let color: Color
    let icon: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
                
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct HealthMetricsGrid: View {
    let metrics: HealthMetrics
    
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
                MetricCard(
                    title: "HRV",
                    value: metrics.hrv,
                    unit: "ms",
                    icon: "waveform.path.ecg",
                    color: .green
                )
                
                MetricCard(
                    title: "RHR",
                    value: metrics.rhr,
                    unit: "bpm",
                    icon: "heart.fill",
                    color: .red
                )
                
                MetricCard(
                    title: "Walking HR",
                    value: metrics.walkingHeartRate,
                    unit: "bpm",
                    icon: "figure.walk",
                    color: .blue
                )
                
                MetricCard(
                    title: "Resp Rate",
                    value: metrics.respiratoryRate,
                    unit: "rpm",
                    icon: "lungs.fill",
                    color: .purple
                )
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: Double?
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                if let value = value {
                    Text("\(String(format: "%.0f", value))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                } else {
                    Text("--")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
                
                Text("\(title) (\(unit))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(AppColors.secondaryBackground)
        .cornerRadius(12)
    }
}

struct QuickActionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                NavigationLink(destination: WorkoutLibraryView()) {
                    QuickActionCard(
                        title: "Start Workout",
                        icon: "dumbbell.fill",
                        color: .orange
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
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
            }
        }
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(12)
    }
}

struct TodaysInsightsView: View {
    let recoveryScore: Int
    let sleepScore: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Insights")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                InsightRow(
                    icon: "lightbulb.fill",
                    text: generateInsight(),
                    color: .orange
                )
                
                InsightRow(
                    icon: "target",
                    text: generateRecommendation(),
                    color: .blue
                )
            }
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(16)
    }
    
    private func generateInsight() -> String {
        let avgScore = (recoveryScore + sleepScore) / 2
        
        switch avgScore {
        case 85...:
            return "You're in excellent shape today! Perfect time for high-intensity training."
        case 70..<85:
            return "Good balance between recovery and sleep. Maintain your current routine."
        case 55..<70:
            return "Moderate readiness. Consider lighter activities or active recovery."
        default:
            return "Your body needs more rest. Focus on recovery and sleep optimization."
        }
    }
    
    private func generateRecommendation() -> String {
        if recoveryScore < sleepScore - 10 {
            return "Your recovery is lagging behind sleep quality. Consider stress management."
        } else if sleepScore < recoveryScore - 10 {
            return "Sleep quality could be improved. Review your bedtime routine."
        } else if recoveryScore > 80 && sleepScore > 80 {
            return "Great day for challenging workouts or important activities!"
        } else {
            return "Focus on consistent sleep and recovery habits for better scores."
        }
    }
}

struct InsightRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 16)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

struct JournalSummaryView: View {
    let selectedDate: Date
    @Query private var journalEntries: [DailyJournal]
    
    init(selectedDate: Date) {
        self.selectedDate = selectedDate
        self._journalEntries = Query(sort: \DailyJournal.date, order: .reverse)
    }
    
    private var currentEntry: DailyJournal? {
        let calendar = Calendar.current
        return journalEntries.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
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

// Define JournalTag here for the summary view
// enum JournalTag: String, CaseIterable, Hashable {
//     case coffee = "coffee"
//     case alcohol = "alcohol"
//     case caffeine = "caffeine"
//     case lateEating = "late_eating"
//     case stress = "stress"
//     case exercise = "exercise"
//     case meditation = "meditation"
//     case goodSleep = "good_sleep"
//     case poorSleep = "poor_sleep"
//     case illness = "illness"
//     case travel = "travel"
//     case work = "work"
//     case social = "social"
//     case supplements = "supplements"
//     case hydration = "hydration"
//     case mood = "mood"
//     case energy = "energy"
//     case focus = "focus"
//     case recovery = "recovery"
//     
//     var displayName: String {
//         switch self {
//         case .coffee: return "Coffee"
//         case .alcohol: return "Alcohol"
//         case .caffeine: return "Late Caffeine"
//         case .lateEating: return "Late Eating"
//         case .stress: return "High Stress"
//         case .exercise: return "Exercise"
//         case .meditation: return "Meditation"
//         case .goodSleep: return "Good Sleep"
//         case .poorSleep: return "Poor Sleep"
//         case .illness: return "Illness"
//         case .travel: return "Travel"
//         case .work: return "Work Stress"
//         case .social: return "Social"
//         case .supplements: return "Supplements"
//         case .hydration: return "Good Hydration"
//         case .mood: return "Good Mood"
//         case .energy: return "High Energy"
//         case .focus: return "Good Focus"
//         case .recovery: return "Recovery Day"
//         }
//     }
//     
//     var icon: String {
//         switch self {
//         case .coffee: return "cup.and.saucer.fill"
//         case .alcohol: return "wineglass"
//         case .caffeine: return "cup.and.saucer"
//         case .lateEating: return "clock.badge.exclamationmark"
//         case .stress: return "exclamationmark.triangle"
//         case .exercise: return "figure.run"
//         case .meditation: return "leaf"
//         case .goodSleep: return "bed.double"
//         case .poorSleep: return "bed.double.fill"
//         case .illness: return "thermometer"
//         case .travel: return "airplane"
//         case .work: return "briefcase"
//         case .social: return "person.2"
//         case .supplements: return "pills.fill"
//         case .hydration: return "drop.fill"
//         case .mood: return "face.smiling"
//         case .energy: return "bolt.fill"
//         case .focus: return "target"
//         case .recovery: return "heart.fill"
//         }
//     }
//     
//     var color: Color {
//         switch self {
//         case .coffee: return .brown
//         case .alcohol: return .red
//         case .caffeine: return .orange
//         case .lateEating: return .orange
//         case .stress: return .red
//         case .exercise: return .green
//         case .meditation: return .mint
//         case .goodSleep: return .blue
//         case .poorSleep: return .purple
//         case .illness: return .red
//         case .travel: return .cyan
//         case .work: return .gray
//         case .social: return .pink
//         case .supplements: return .blue
//         case .hydration: return .cyan
//         case .mood: return .yellow
//         case .energy: return .orange
//         case .focus: return .indigo
//         case .recovery: return .green
//         }
//     }
// }

struct ScoreGaugeView: View {
    let title: String
    let score: Int?
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 16)
                    .frame(width: 120, height: 120)
                if let score = score {
                    Text("\(score)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: color))
                        .frame(width: 48, height: 48)
                }
            }
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(20)
    }
} 
