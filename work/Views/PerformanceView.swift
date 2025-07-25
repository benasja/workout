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
    @State private var showingHealthKitAlert = false
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Dynamic Personalized Greeting (NEW)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(personalizedGreeting)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text(motivationalSubtext)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.top)
                    
                    // Date Slider (KEPT)
                    DateSliderView(selectedDate: $dateModel.selectedDate)
                    
                    // Daily Readiness Card (Always visible with loading/placeholder states)
                    NavigationLink(destination: DailyReadinessDetailView()
                        .environmentObject(dateModel)
                        .environmentObject(tabSelectionModel)) {
                        DailyReadinessCard(
                            recoveryScore: recoveryScore,
                            sleepScore: sleepScore,
                            recoverySubtitle: recoverySubtitle,
                            sleepSubtitle: sleepSubtitle,
                            isLoading: isLoading
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Quick Actions (ALWAYS VISIBLE - REFINED)
                    QuickActionsView()
                    
                    // Show error message if any, but don't hide the UI
                    if let error = errorMessage {
                        Text("⚠️ \(error)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                            .background(AppColors.secondaryBackground)
                            .cornerRadius(8)
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
    
    // MARK: - Dynamic Greeting Logic
    
    private var personalizedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let calendar = Calendar.current
        
        // Check if viewing today
        if calendar.isDateInToday(dateModel.selectedDate) {
            switch hour {
            case 5..<12:
                return "Good morning"
            case 12..<17:
                return "Good afternoon"
            case 17..<22:
                return "Good evening"
            default:
                return "Ready to conquer?"
            }
        } else if calendar.isDateInYesterday(dateModel.selectedDate) {
            return "Yesterday's recap"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: dateModel.selectedDate)
        }
    }
    
    private var motivationalSubtext: String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(dateModel.selectedDate) {
            let avgScore = ((recoveryScore ?? 0) + (sleepScore ?? 0)) / 2
            switch avgScore {
            case 85...:
                return "You're primed for peak performance!"
            case 70..<85:
                return "Let's make today count."
            case 55..<70:
                return "Take it steady today."
            default:
                return "Focus on recovery and rest."
            }
        } else if calendar.isDateInYesterday(dateModel.selectedDate) {
            return "How did your body respond?"
        } else {
            return "Review your health data"
        }
    }
    
    private var recoverySubtitle: String {
        if isLoading {
            return "Loading..."
        }
        guard let score = recoveryScore else { return "Data unavailable" }
        switch score {
        case 85...: return "Primed for peak performance"
        case 70..<85: return "Good recovery state"
        case 55..<70: return "Moderate recovery"
        default: return "Focus on recovery"
        }
    }
    
    private var sleepSubtitle: String {
        if isLoading {
            return "Loading..."
        }
        guard let score = sleepScore else { return "Data unavailable" }
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
            // Still show UI with placeholder scores
            recoveryScore = nil
            sleepScore = nil
            return
        }
        
        Task {
            // Use the most appropriate date for data fetching
            let dataDate = getMostRecentDataDate()
            
            // Fetch scores concurrently with graceful fallbacks
            async let recoveryResult = fetchRecoveryScoreWithFallback(for: dataDate)
            async let sleepResult = fetchSleepScoreWithFallback(for: dataDate)
            
            let (recovery, sleep) = await (recoveryResult, sleepResult)
            
            await MainActor.run {
                self.recoveryScore = recovery
                self.sleepScore = sleep
                self.isLoading = false
                self.errorMessage = nil
            }
        }
    }
    
    // Get the most appropriate date for fetching health data
    private func getMostRecentDataDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        
        // If it's after midnight but before 8 AM, and we're viewing "today",
        // use yesterday's date to get the most recent completed sleep data
        if calendar.isDateInToday(dateModel.selectedDate) && currentHour < 8 {
            return calendar.date(byAdding: .day, value: -1, to: dateModel.selectedDate) ?? dateModel.selectedDate
        }
        
        return dateModel.selectedDate
    }
    
    // Fetch recovery score with graceful fallback
    private func fetchRecoveryScoreWithFallback(for date: Date) async -> Int? {
        do {
            let result = try await RecoveryScoreCalculator.shared.calculateRecoveryScore(for: date)
            return result.finalScore
        } catch {
            print("⚠️ Recovery score calculation failed: \(error)")
            return nil // Return nil instead of crashing
        }
    }
    
    // Fetch sleep score with graceful fallback
    private func fetchSleepScoreWithFallback(for date: Date) async -> Int? {
        do {
            let result = try await SleepScoreCalculator.shared.calculateSleepScore(for: date)
            return result.finalScore
        } catch {
            print("⚠️ Sleep score calculation failed: \(error)")
            return nil // Return nil instead of crashing
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
    
    private func scoreColor(for score: Int?) -> Color {
        guard let score = score else { return AppColors.textSecondary }
        switch score {
        case 85...: return AppColors.success
        case 70..<85: return AppColors.primary
        case 55..<70: return AppColors.warning
        default: return AppColors.error
        }
    }
}

// Helper function for dynamic color-coding
func colorFor(score: Int) -> Color {
    switch score {
    case 90...100:
        return AppColors.success // Elite
    case 80...89:
        return AppColors.primary // Excellent
    case 70...79:
        return AppColors.secondary // Good
    case 60...69:
        return AppColors.warning // Needs Attention
    case 50...59:
        return AppColors.accent // Fair
    default:
        return AppColors.error // Poor
    }
}

// MARK: - Daily Readiness Card (NEW)

struct DailyReadinessCard: View {
    let recoveryScore: Int?
    let sleepScore: Int?
    let recoverySubtitle: String
    let sleepSubtitle: String
    let isLoading: Bool
    @EnvironmentObject var tabSelectionModel: TabSelectionModel
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                tabSelectionModel.selection = 1 // Recovery tab
            }) {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .font(.title3)
                            .foregroundColor(colorFor(score: recoveryScore ?? 0))
                        Text("Recovery")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(height: 36)
                    } else if let score = recoveryScore {
                        Text("\(score)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(colorFor(score: score))
                    } else {
                        Text("—")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Text(recoverySubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
            .buttonStyle(PlainButtonStyle())
            .background(Color.clear)
            
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 1, height: 80)
            
            Button(action: {
                tabSelectionModel.selection = 2 // Sleep tab
            }) {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "bed.double.fill")
                            .font(.title3)
                            .foregroundColor(colorFor(score: sleepScore ?? 0))
                        Text("Sleep")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(height: 36)
                    } else if let score = sleepScore {
                        Text("\(score)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(colorFor(score: score))
                    } else {
                        Text("—")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Text(sleepSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
            .buttonStyle(PlainButtonStyle())
            .background(Color.clear)
        }
        .background(
            LinearGradient(
                colors: [AppColors.secondaryBackground, AppColors.tertiaryBackground.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
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

// MARK: - Daily Readiness Detail View (NEW)

struct DailyReadinessDetailView: View {
    @EnvironmentObject var dateModel: PerformanceDateModel
    @EnvironmentObject var tabSelectionModel: TabSelectionModel
    @State private var selectedTab: DetailTab = .recovery
    
    enum DetailTab: String, CaseIterable {
        case recovery = "Recovery"
        case sleep = "Sleep"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Tab Picker
            HStack(spacing: 0) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: tab == .recovery ? "heart.fill" : "bed.double.fill")
                                    .font(.headline)
                                Text(tab.rawValue)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(selectedTab == tab ? AppColors.primary : .secondary)
                            
                            Rectangle()
                                .fill(selectedTab == tab ? AppColors.primary : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .background(AppColors.background)
            
            // Content
            TabView(selection: $selectedTab) {
                RecoveryDetailView()
                    .environmentObject(dateModel)
                    .environmentObject(tabSelectionModel)
                    .tag(DetailTab.recovery)
                
                SleepDetailView()
                    .environmentObject(dateModel)
                    .environmentObject(tabSelectionModel)
                    .tag(DetailTab.sleep)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("Daily Readiness")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Refined Quick Actions (KEPT)

struct QuickActionsView: View {
    @EnvironmentObject var tabSelectionModel: TabSelectionModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                NavigationLink(destination: JournalView()) {
                    QuickActionCard(
                        title: "Journal",
                        icon: "book.closed.fill",
                        color: .blue
                    )
                }
                .buttonStyle(PlainButtonStyle())
                NavigationLink(destination: WeightTrackerView()) {
                    QuickActionCard(
                        title: "Weight",
                        icon: "scalemass",
                        color: .green
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            HStack(spacing: 16) {
                NavigationLink(destination: SupplementsView()) {
                    QuickActionCard(
                        title: "Vitamins",
                        icon: "pills.fill",
                        color: AppColors.accent
                    )
                }
                .buttonStyle(PlainButtonStyle())
                NavigationLink(destination: HydrationView()) {
                    QuickActionCard(
                        title: "Hydration",
                        icon: "drop.fill",
                        color: AppColors.primary
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

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(AppColors.secondaryBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PerformanceView()
            .environmentObject(PerformanceDateModel())
            .environmentObject(TabSelectionModel())
    }
} 
