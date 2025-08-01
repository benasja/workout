import SwiftUI
import SwiftData
import VisionKit

#if canImport(UIKit)
import UIKit
#endif

/// Main dashboard view for the Fuel Log feature, providing comprehensive nutrition tracking interface
struct FuelLogDashboardView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var dateModel: PerformanceDateModel
    @EnvironmentObject var tabSelectionModel: TabSelectionModel
    @State private var viewModel: FuelLogViewModel?
    @State private var showingFoodSearch = false
    @State private var selectedMealTypeForSearch: MealType = .breakfast
    @State private var showingBarcodeScan = false
    @State private var showingQuickAdd = false
    @State private var showingQuickEdit = false
    @State private var editingFoodLog: FoodLog?
    @State private var showingGoalsSetup = false
    @State private var showingPersonalLibrary = false
    @State private var showingDailyLogging = false
    @State private var isInitialized = false
    @State private var showingBarcodeResult = false
    @State private var barcodeResult: FoodSearchResult?
    @State private var scannedBarcode: String?
    @State private var foodSearchViewModel: FoodSearchViewModel?
    
    var body: some View {
        NavigationView {
            Group {
                if let viewModel = viewModel {
                    // CRITICAL FIX: Wrap in ObservableView to properly observe @Published properties
                    ObservableViewModelWrapper(viewModel: viewModel) { observedViewModel in
                        mainContentView(observedViewModel: observedViewModel)
                    }
                } else {
                    LoadingView(message: "Initializing...")
                }
            }
        }
        .onAppear {
            if !isInitialized {
                // Initialize viewModel with the dataManager's modelContext
                let repository = FuelLogRepository(modelContext: dataManager.modelContext)
                viewModel = FuelLogViewModel(repository: repository, healthKitManager: nil)
                
                // Initialize foodSearchViewModel
                foodSearchViewModel = FoodSearchViewModel(repository: repository)
                
                // Sync selected date with the global date model
                viewModel?.selectedDate = dateModel.selectedDate
                
                // Load initial data including nutrition goals
                Task {
                    await viewModel?.loadInitialData()
                }
                
                isInitialized = true
            }
            

        }
        .sheet(isPresented: $showingGoalsSetup) {
            if let repository = viewModel?.repository as? FuelLogRepository {
                FuelLogOnboardingView(repository: repository)
            }
        }
        .sheet(isPresented: $showingFoodSearch) {
            if let repository = viewModel?.repository {
                FoodSearchView(repository: repository, selectedDate: viewModel?.selectedDate ?? Date(), defaultMealType: selectedMealTypeForSearch, nutritionGoals: viewModel?.nutritionGoals) { foodLog in
                    Task {
                        await viewModel?.logFood(foodLog)
                    }
                }
            }
        }
        // Barcode scanning is temporarily disabled
        // .sheet(isPresented: $showingBarcodeScan) {
        //     if let viewModel = viewModel {
        //         BarcodeScannerView { barcode in
        //             Task {
        //                 await handleBarcodeScanned(barcode, viewModel: viewModel)
        //             }
        //         }
        //     }
        // }
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddView(selectedDate: viewModel?.selectedDate ?? Date()) { foodLog in
                Task {
                    await viewModel?.logFood(foodLog)
                }
            }
        }
        .sheet(isPresented: $showingPersonalLibrary) {
            if let repository = viewModel?.repository {
                PersonalFoodLibraryView(repository: repository) { foodLog in
                    Task {
                        await viewModel?.logFood(foodLog)
                    }
                }
            }
        }
        .sheet(isPresented: $showingDailyLogging) {
            if let repository = viewModel?.repository {
                DailyLoggingView(
                    repository: repository,
                    selectedDate: viewModel?.selectedDate ?? Date()
                ) { foodLog in
                    Task {
                        await viewModel?.logFood(foodLog)
                    }
                }
            }
        }
        .sheet(isPresented: $showingQuickEdit) {
            if let editingFoodLog = editingFoodLog {
                if editingFoodLog.isQuickAdd {
                    QuickEditView(foodLog: editingFoodLog) { updatedFoodLog in
                        Task {
                            await viewModel?.updateFoodLog(editingFoodLog, with: updatedFoodLog)
                        }
                    }
                } else {
                    if editingFoodLog.name.isEmpty {
                        // Fallback for invalid food log
                        VStack {
                            Text("Invalid Food Item")
                                .font(.title2)
                                .padding()
                            Button("Close") {
                                showingQuickEdit = false
                            }
                        }
                    } else {
                        if let viewModel = viewModel {
                            FoodEditView(
                                foodLog: editingFoodLog,
                                nutritionGoals: viewModel.nutritionGoals
                            ) { updatedFoodLog in
                                Task {
                                    await viewModel.updateFoodLog(editingFoodLog, with: updatedFoodLog)
                                }
                            }
                        } else {
                            // Fallback if viewModel is not ready
                            VStack {
                                Text("Loading...")
                                    .font(.title2)
                                    .padding()
                                Button("Close") {
                                    showingQuickEdit = false
                                }
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: showingQuickEdit) { _, isShowing in
            if !isShowing {
                editingFoodLog = nil
            }
        }
        // Barcode result sheet is disabled since barcode scanning is disabled
        // .sheet(isPresented: $showingBarcodeResult) {
        //     if let result = barcodeResult, let barcode = scannedBarcode, let viewModel = viewModel {
        //         BarcodeResultView(
        //             foodResult: result,
        //             barcode: barcode
        //         ) { foodLog in
        //             Task {
        //                 await viewModel.logFood(foodLog)
        //             }
        //         }
        //     }
        // }
    }
    
    // MARK: - Main Content View
    
    @ViewBuilder
    private func mainContentView(observedViewModel: FuelLogViewModel) -> some View {
        // Debug logging to track UI re-renders
        // let _ = print("🖥️ FuelLogDashboardView: Rendering main content with \(viewModel.todaysFoodLogs.count) food logs")
        ScrollView {
            LazyVStack(spacing: AppSpacing.lg) {
                // Date Navigation Header
                dateNavigationHeader(observedViewModel: observedViewModel)
                
                Group {
                    if observedViewModel.isLoadingInitialData {
                        LoadingView(message: "Loading nutrition data...")
                            .frame(height: 200)
                    } else if observedViewModel.nutritionGoals == nil && !observedViewModel.isLoadingGoals {
                        // Onboarding state when no goals are set
                        nutritionGoalsOnboardingCard
                    } else if observedViewModel.nutritionGoals != nil {
                        // Main dashboard content
                        VStack(spacing: AppSpacing.lg) {
                            // Enhanced Nutrition View
                            EnhancedNutritionView(
                                caloriesRemaining: Int(observedViewModel.remainingNutrition.totalCalories),
                                carbsCurrent: observedViewModel.dailyTotals.totalCarbohydrates,
                                carbsGoal: observedViewModel.nutritionGoals?.dailyCarbohydrates ?? 0,
                                proteinCurrent: observedViewModel.dailyTotals.totalProtein,
                                proteinGoal: observedViewModel.nutritionGoals?.dailyProtein ?? 0,
                                fatCurrent: observedViewModel.dailyTotals.totalFat,
                                fatGoal: observedViewModel.nutritionGoals?.dailyFat ?? 0
                            )
                            
                            // Quick Action Buttons
                            quickActionButtons(observedViewModel: observedViewModel)
                            
                            // Food Log by Meal Type
                            foodLogSection(observedViewModel: observedViewModel)
                        }
                    } else {
                        // Loading goals state
                        LoadingView(message: "Loading nutrition goals...")
                            .frame(height: 200)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .navigationTitle("Nutrition")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if observedViewModel.nutritionGoals != nil {
                    Button(action: {
                        showingGoalsSetup = true
                    }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .refreshable {
            await observedViewModel.refresh()
        }
        .disabled(observedViewModel.isRefreshing)
        .alert("Error", isPresented: .constant(observedViewModel.errorMessage != nil)) {
            Button("OK") {
                observedViewModel.clearError()
            }
        } message: {
            Text(observedViewModel.errorMessage ?? "An unknown error occurred")
        }
        .onChange(of: dateModel.selectedDate) { _, newDate in
            observedViewModel.selectedDate = newDate
        }
    }
    
    // MARK: - Date Navigation Header
    
    private func dateNavigationHeader(observedViewModel: FuelLogViewModel) -> some View {
        HStack {
            Button(action: {
                observedViewModel.navigateToPreviousDay()
                dateModel.selectedDate = observedViewModel.selectedDate
                AccessibilityUtils.selectionFeedback()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(AppColors.primary)
            }
            .iconButton()
            .actionButtonAccessibility(
                label: "Previous day",
                hint: "Navigate to previous day's nutrition data"
            )
            .accessibilityIdentifier(AccessibilityIdentifiers.previousDayButton)
            
            Spacer()
            
            VStack(spacing: AppSpacing.xs) {
                Text(dateFormatter.string(from: observedViewModel.selectedDate))
                    .font(AppTypography.headline)
                    .foregroundColor(AccessibilityUtils.contrastAwareText())
                    .dynamicTypeSize(maxSize: .accessibility2)
                
                if observedViewModel.isSelectedDateToday {
                    Text("Today")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.primary)
                        .dynamicTypeSize(maxSize: .accessibility2)
                } else {
                    Text(relativeDateFormatter.string(for: observedViewModel.selectedDate) ?? "")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .dynamicTypeSize(maxSize: .accessibility2)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Selected date: \(dateFormatter.string(from: observedViewModel.selectedDate))")
            .accessibilityIdentifier(AccessibilityIdentifiers.dateDisplay)
            
            Spacer()
            
            Button(action: {
                observedViewModel.navigateToNextDay()
                dateModel.selectedDate = observedViewModel.selectedDate
                AccessibilityUtils.selectionFeedback()
            }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(AppColors.primary)
            }
            .iconButton()
            .disabled(Calendar.current.isDateInToday(observedViewModel.selectedDate))
            .actionButtonAccessibility(
                label: "Next day",
                hint: "Navigate to next day's nutrition data"
            )
            .accessibilityIdentifier(AccessibilityIdentifiers.nextDayButton)
        }
        .padding(.horizontal, AppSpacing.md)
    }
    
    // MARK: - Nutrition Goals Onboarding
    
    private var nutritionGoalsOnboardingCard: some View {
        ModernCard {
            VStack(spacing: AppSpacing.lg) {
                Image(systemName: "target")
                    .font(.system(size: 60))
                    .foregroundColor(AppColors.primary)
                
                VStack(spacing: AppSpacing.sm) {
                    Text("Set Your Nutrition Goals")
                        .font(AppTypography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Get started by setting up your daily calorie and macronutrient targets based on your goals and activity level.")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                Button("Set Up Goals") {
                    showingGoalsSetup = true
                }
                .primaryButton()
            }
            .padding(AppSpacing.lg)
        }
    }
    
    // MARK: - Calorie Progress Section
    
    private var calorieProgressSection: some View {
        ModernCard {
            VStack(spacing: AccessibilityUtils.scaledSpacing(AppSpacing.lg)) {
                HStack {
                    Text("Daily Calories")
                        .font(AppTypography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(AccessibilityUtils.contrastAwareText())
                        .dynamicTypeSize(maxSize: .accessibility2)
                    
                    Spacer()
                    
                    if let goals = viewModel?.nutritionGoals {
                        Text("\(Int(viewModel?.dailyTotals.totalCalories ?? 0)) / \(Int(goals.dailyCalories))")
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .dynamicTypeSize(maxSize: .accessibility2)
                    }
                }
                
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(
                            AccessibilityUtils.contrastAwareColor(
                                normal: AppColors.primary.opacity(0.2),
                                highContrast: AppColors.primary.opacity(0.5)
                            ), 
                            lineWidth: 12
                        )
                        .frame(width: 200, height: 200)
                    
                    // Progress circle with enhanced animations
                    Circle()
                        .trim(from: 0, to: min(viewModel?.nutritionProgress.caloriesProgress ?? 0, 1.0))
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AccessibilityUtils.contrastAwareColor(
                                        normal: AppColors.primary,
                                        highContrast: Color.blue
                                    ),
                                    AccessibilityUtils.contrastAwareColor(
                                        normal: AppColors.secondary,
                                        highContrast: Color.cyan
                                    )
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8, dampingFraction: 0.8, blendDuration: 0.2), value: viewModel?.nutritionProgress.caloriesProgress ?? 0)
                        .scaleEffect(viewModel?.isGoalCompleted(for: .calories) == true ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel?.isGoalCompleted(for: .calories) == true)
                    
                    // Goal completion celebration effect
                    if viewModel?.isGoalCompleted(for: .calories) == true {
                        Circle()
                            .stroke(AppColors.primary.opacity(0.3), lineWidth: 2)
                            .frame(width: 220, height: 220)
                            .scaleEffect(1.2)
                            .opacity(0.5)
                            .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel?.isGoalCompleted(for: .calories) == true)
                    }
                    
                    // Center content
                    VStack(spacing: AppSpacing.xs) {
                        Text("\(Int(viewModel?.remainingNutrition.totalCalories ?? 0))")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(AccessibilityUtils.contrastAwareText())
                            .dynamicTypeSize(maxSize: .accessibility1)
                        
                        Text("kcal remaining")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .dynamicTypeSize(maxSize: .accessibility2)
                    }
                }
                
                // Progress percentage
                if viewModel?.nutritionGoals != nil {
                    let percentage = min((viewModel?.nutritionProgress.caloriesProgress ?? 0) * 100, 100)
                    Text("\(Int(percentage))% of daily goal")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .dynamicTypeSize(maxSize: .accessibility2)
                }
            }
            .padding(AppSpacing.lg)
        }
        .nutritionProgressAccessibility(
            nutrient: "Calories",
            current: viewModel?.dailyTotals.totalCalories ?? 0,
            goal: viewModel?.nutritionGoals?.dailyCalories ?? 0,
            unit: "calories"
        )
        .accessibilityIdentifier(AccessibilityIdentifiers.calorieProgress)
        .onChange(of: viewModel?.isGoalCompleted(for: .calories) ?? false) { _, isCompleted in
            if isCompleted {
                AccessibilityUtils.announceGoalCompletion(for: "Calorie")
            }
        }
    }
    
    // MARK: - Macro Progress Section
    
    private var macroProgressSection: some View {
        ModernCard {
            VStack(spacing: AppSpacing.lg) {
                Text("Macronutrients")
                    .font(AppTypography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: AppSpacing.md) {
                    MacroProgressBar(
                        nutrient: .protein,
                        current: viewModel?.dailyTotals.totalProtein ?? 0,
                        goal: viewModel?.nutritionGoals?.dailyProtein ?? 0,
                        progress: viewModel?.nutritionProgress.proteinProgress ?? 0,
                        color: AppColors.accent
                    )
                    
                    MacroProgressBar(
                        nutrient: .carbohydrates,
                        current: viewModel?.dailyTotals.totalCarbohydrates ?? 0,
                        goal: viewModel?.nutritionGoals?.dailyCarbohydrates ?? 0,
                        progress: viewModel?.nutritionProgress.carbohydratesProgress ?? 0,
                        color: AppColors.secondary
                    )
                    
                    MacroProgressBar(
                        nutrient: .fat,
                        current: viewModel?.dailyTotals.totalFat ?? 0,
                        goal: viewModel?.nutritionGoals?.dailyFat ?? 0,
                        progress: viewModel?.nutritionProgress.fatProgress ?? 0,
                        color: AppColors.warning
                    )
                }
            }
            .padding(AppSpacing.lg)
        }
    }
    
    // MARK: - Quick Action Buttons
    
    private func quickActionButtons(observedViewModel: FuelLogViewModel) -> some View {
        VStack(spacing: AppSpacing.md) {
            // Primary action buttons
            HStack(spacing: AccessibilityUtils.scaledSpacing(AppSpacing.md)) {
                Button(action: { 
                    // Default to breakfast for general search button
                    selectedMealTypeForSearch = .breakfast
                    showingFoodSearch = true
                    AccessibilityUtils.selectionFeedback()
                }) {
                    VStack(spacing: AppSpacing.xs) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .scaleEffect(showingFoodSearch ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showingFoodSearch)
                        Text("Search")
                            .font(AppTypography.caption)
                            .dynamicTypeSize(maxSize: .accessibility2)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(AccessibilityUtils.scaledSpacing(AppSpacing.lg))
                    .background(
                        AccessibilityUtils.contrastAwareColor(
                            normal: AppColors.secondary,
                            highContrast: Color.green
                        )
                    )
                    .cornerRadius(AppCornerRadius.md)
                    .scaleEffect(showingFoodSearch ? 0.95 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.8), value: showingFoodSearch)
                }
                .actionButtonAccessibility(
                    label: "Search foods",
                    hint: AccessibilityUtils.searchFoodHint
                )
                .accessibilityIdentifier(AccessibilityIdentifiers.searchFoodButton)
                .keyboardNavigationSupport()
                
                Button(action: { 
                    showingPersonalLibrary = true
                    AccessibilityUtils.selectionFeedback()
                }) {
                    VStack(spacing: AppSpacing.xs) {
                        Image(systemName: "heart.text.square")
                            .font(.title2)
                            .scaleEffect(showingPersonalLibrary ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showingPersonalLibrary)
                        Text("My Foods")
                            .font(AppTypography.caption)
                            .dynamicTypeSize(maxSize: .accessibility2)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(AccessibilityUtils.scaledSpacing(AppSpacing.lg))
                    .background(
                        AccessibilityUtils.contrastAwareColor(
                            normal: AppColors.accent,
                            highContrast: Color.orange
                        )
                    )
                    .cornerRadius(AppCornerRadius.md)
                    .scaleEffect(showingPersonalLibrary ? 0.95 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.8), value: showingPersonalLibrary)
                }
                .actionButtonAccessibility(
                    label: "My food library",
                    hint: "Access your personal food library and meals"
                )
                .accessibilityIdentifier("personal_library_button")
                .keyboardNavigationSupport()
            }
            
            // Secondary action buttons
            HStack(spacing: AccessibilityUtils.scaledSpacing(AppSpacing.md)) {
                Button(action: { 
                    showingQuickAdd = true
                    AccessibilityUtils.selectionFeedback()
                }) {
                    VStack(spacing: AppSpacing.xs) {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .scaleEffect(showingQuickAdd ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showingQuickAdd)
                        Text("Quick Add")
                            .font(AppTypography.caption)
                            .dynamicTypeSize(maxSize: .accessibility2)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(AccessibilityUtils.scaledSpacing(AppSpacing.lg))
                    .background(
                        AccessibilityUtils.contrastAwareColor(
                            normal: AppColors.primary,
                            highContrast: Color.blue
                        )
                    )
                    .cornerRadius(AppCornerRadius.md)
                    .scaleEffect(showingQuickAdd ? 0.95 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.8), value: showingQuickAdd)
                }
                .actionButtonAccessibility(
                    label: "Quick add meal",
                    hint: "Create a new meal with custom macronutrients"
                )
                .accessibilityIdentifier(AccessibilityIdentifiers.quickAddButton)
                .keyboardNavigationSupport()
                
                Button(action: { 
                    showingDailyLogging = true
                    AccessibilityUtils.selectionFeedback()
                }) {
                    VStack(spacing: AppSpacing.xs) {
                        Image(systemName: "list.bullet")
                            .font(.title2)
                            .scaleEffect(showingDailyLogging ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showingDailyLogging)
                        Text("Daily Log")
                            .font(AppTypography.caption)
                            .dynamicTypeSize(maxSize: .accessibility2)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(AccessibilityUtils.scaledSpacing(AppSpacing.lg))
                    .background(
                        AccessibilityUtils.contrastAwareColor(
                            normal: AppColors.warning,
                            highContrast: Color.yellow
                        )
                    )
                    .cornerRadius(AppCornerRadius.md)
                    .scaleEffect(showingDailyLogging ? 0.95 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.8), value: showingDailyLogging)
                }
                .actionButtonAccessibility(
                    label: "Daily food log",
                    hint: "View and manage today's food entries"
                )
                .accessibilityIdentifier("daily_logging_button")
                .keyboardNavigationSupport()
            }
        }
    }
    
    // MARK: - Food Log Section
    
    private func foodLogSection(observedViewModel: FuelLogViewModel) -> some View {
        // CRITICAL FIX: Force entire section to recreate when food logs change
        // let _ = print("🍽️ FoodLogSection: Rendering with \(viewModel?.todaysFoodLogs.count ?? 0) total food logs - \(viewModel?.foodLogsSummary ?? "")")
        // let _ = print("🍽️ FoodLogSection: Detailed content - \(viewModel?.foodLogsDetailedSummary ?? "No ViewModel")")
        
        return VStack(spacing: AppSpacing.lg) {
            ForEach(MealType.allCases, id: \.self) { mealType in
                let mealFoodLogs = observedViewModel.foodLogsByMealType[mealType] ?? []
                // let _ = print("🍽️ FoodLogSection: \(mealType.displayName) has \(mealFoodLogs.count) items")
                
                MealSectionView(
                    mealType: mealType,
                    foodLogs: mealFoodLogs,
                    nutritionTotals: observedViewModel.nutritionTotals(for: mealType),
                    refreshTrigger: observedViewModel.uiRefreshTrigger,
                    onDeleteFood: { foodLog in
                        Task {
                            await observedViewModel.deleteFood(foodLog)
                        }
                    },
                    onEditFood: { foodLog in
                        print("🔄 Setting editingFoodLog: \(foodLog.name), id: \(foodLog.id)")
                        editingFoodLog = foodLog
                        showingQuickEdit = true
                    },
                    onAddFood: {
                        // CRITICAL FIX: Set the meal type before showing food search
                        selectedMealTypeForSearch = mealType
                        showingFoodSearch = true
                    }
                )
                .id("\(mealType.rawValue)-\(observedViewModel.uiRefreshTrigger.uuidString)") // CRITICAL FIX: Use global refresh trigger
            }
        }
        .id("foodLogSection-\(observedViewModel.uiRefreshTrigger.uuidString)") // CRITICAL FIX: Force recreation using refresh trigger
    }
    
    // MARK: - Formatters
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }
    
    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter
    }
}

// MARK: - Observable ViewModel Wrapper

/// Wrapper to properly observe a ViewModel's @Published properties
struct ObservableViewModelWrapper<Content: View>: View {
    @ObservedObject var viewModel: FuelLogViewModel
    let content: (FuelLogViewModel) -> Content
    
    var body: some View {
        content(viewModel)
    }
}

// MARK: - Macro Progress Bar Component

struct MacroProgressBar: View {
    let nutrient: NutrientType
    let current: Double
    let goal: Double
    let progress: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: AccessibilityUtils.scaledSpacing(AppSpacing.xs)) {
            HStack {
                Text(nutrient.displayName)
                    .font(AppTypography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AccessibilityUtils.contrastAwareText())
                    .dynamicTypeSize(maxSize: .accessibility2)
                
                Spacer()
                
                HStack(spacing: AppSpacing.xs) {
                    Text("\(Int(round(current)))")
                        .font(AppTypography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AccessibilityUtils.contrastAwareText())
                        .dynamicTypeSize(maxSize: .accessibility2)
                    
                    Text("/ \(Int(round(goal))) \(nutrient.unit)")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .dynamicTypeSize(maxSize: .accessibility2)
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(
                            AccessibilityUtils.contrastAwareColor(
                                normal: color.opacity(0.2),
                                highContrast: color.opacity(0.4)
                            )
                        )
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    // Progress with enhanced animations
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AccessibilityUtils.contrastAwareColor(
                                        normal: color,
                                        highContrast: color
                                    ),
                                    AccessibilityUtils.contrastAwareColor(
                                        normal: color.opacity(0.8),
                                        highContrast: color.opacity(0.9)
                                    )
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(progress, 1.0), height: 8)
                        .cornerRadius(4)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                        .overlay(
                            // Shimmer effect for completed goals
                            progress >= 1.0 ? 
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.clear, Color.white.opacity(0.3), Color.clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(4)
                                .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: progress >= 1.0)
                            : nil
                        )
                }
            }
            .frame(height: 8)
        }
        .nutritionProgressAccessibility(
            nutrient: nutrient.displayName,
            current: current,
            goal: goal,
            unit: nutrient.unit
        )
        .accessibilityIdentifier(nutrientAccessibilityIdentifier)
        .onChange(of: progress >= 1.0) { _, isCompleted in
            if isCompleted {
                AccessibilityUtils.announceGoalCompletion(for: nutrient.displayName)
            }
        }
    }
    
    private var nutrientAccessibilityIdentifier: String {
        switch nutrient {
        case .protein:
            return AccessibilityIdentifiers.proteinProgress
        case .carbohydrates:
            return AccessibilityIdentifiers.carbProgress
        case .fat:
            return AccessibilityIdentifiers.fatProgress
        default:
            return "fuel_log_\(nutrient.displayName.lowercased())_progress"
        }
    }
}

// MARK: - Meal Section View

struct MealSectionView: View {
    let mealType: MealType
    let foodLogs: [FoodLog]
    let nutritionTotals: DailyNutritionTotals
    let refreshTrigger: UUID
    let onDeleteFood: (FoodLog) -> Void
    let onEditFood: (FoodLog) -> Void
    let onAddFood: () -> Void
    
    var body: some View {
        // Debug logging to track UI rendering
        // let _ = print("🎨 MealSectionView: Rendering \(mealType.displayName) with \(foodLogs.count) food logs")
        // let _ = foodLogs.isEmpty ? print("🎨 MealSectionView: \(mealType.displayName) is empty") : print("🎨 MealSectionView: \(mealType.displayName) items: \(foodLogs.map { $0.name }.joined(separator: ", "))")
        
        ModernCard {
            VStack(spacing: AccessibilityUtils.scaledSpacing(AppSpacing.md)) {
                // Meal header
                HStack {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: mealType.icon)
                            .font(.title3)
                            .foregroundColor(AppColors.primary)
                        
                        Text(mealType.displayName)
                            .font(AppTypography.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(AccessibilityUtils.contrastAwareText())
                            .dynamicTypeSize(maxSize: .accessibility2)
                    }
                    
                    Spacer()
                    
                    if nutritionTotals.totalCalories > 0 {
                        Text("\(Int(nutritionTotals.totalCalories)) kcal")
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .dynamicTypeSize(maxSize: .accessibility2)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(AccessibilityUtils.mealSectionLabel(
                    mealType: mealType,
                    totalCalories: nutritionTotals.totalCalories,
                    itemCount: foodLogs.count
                ))
                
                // Food items or empty state
                if foodLogs.isEmpty {
                    // let _ = print("🎨 MealSectionView: Showing empty state for \(mealType.displayName)")
                    VStack(spacing: AccessibilityUtils.scaledSpacing(AppSpacing.sm)) {
                        Text("No food logged")
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textTertiary)
                            .dynamicTypeSize(maxSize: .accessibility2)
                        
                        Button("Add Food") {
                            onAddFood()
                            AccessibilityUtils.selectionFeedback()
                        }
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.primary)
                        .dynamicTypeSize(maxSize: .accessibility2)
                        .actionButtonAccessibility(
                            label: "Add food to \(mealType.displayName)",
                            hint: "Double tap to add food to this meal"
                        )
                        .keyboardNavigationSupport()
                    }
                    .padding(.vertical, AppSpacing.md)
                } else {
                    // let _ = print("🎨 MealSectionView: Rendering \(foodLogs.count) food items for \(mealType.displayName)")
                    VStack(spacing: AccessibilityUtils.scaledSpacing(AppSpacing.sm)) {
                        ForEach(foodLogs, id: \.id) { foodLog in
                            FoodLogRowView(
                                foodLog: foodLog,
                                onDelete: { 
                                    onDeleteFood(foodLog)
                                    AccessibilityUtils.announceFoodDeleted(foodLog.name)
                                },
                                onEdit: { 
                                    onEditFood(foodLog)
                                    AccessibilityUtils.selectionFeedback()
                                }
                            )
                            .id("\(foodLog.id)-\(refreshTrigger.uuidString)") // CRITICAL FIX: Use global refresh trigger
                        }
                        
                        // Add more food button
                        Button(action: {
                            onAddFood()
                            AccessibilityUtils.selectionFeedback()
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                    .font(.subheadline)
                                Text("Add Food")
                                    .font(AppTypography.subheadline)
                                    .dynamicTypeSize(maxSize: .accessibility2)
                                Spacer()
                            }
                            .foregroundColor(AppColors.primary)
                            .padding(.vertical, AppSpacing.sm)
                        }
                        .actionButtonAccessibility(
                            label: "Add more food to \(mealType.displayName)",
                            hint: "Double tap to add another food item to this meal"
                        )
                        .keyboardNavigationSupport()
                    }
                }
            }
            .padding(AppSpacing.lg)
        }
        .accessibilityIdentifier(mealSectionAccessibilityIdentifier)
    }
    
    private var mealSectionAccessibilityIdentifier: String {
        switch mealType {
        case .breakfast:
            return AccessibilityIdentifiers.breakfastSection
        case .lunch:
            return AccessibilityIdentifiers.lunchSection
        case .dinner:
            return AccessibilityIdentifiers.dinnerSection
        case .snacks:
            return AccessibilityIdentifiers.snacksSection
        }
    }
}

// MARK: - Food Log Row View

struct FoodLogRowView: View {
    let foodLog: FoodLog
    let onDelete: () -> Void
    let onEdit: (() -> Void)?
    
    var body: some View {
        // Debug logging to track what data the row view receives
        // let _ = print("🍎 FoodLogRowView: Rendering food item '\(foodLog.name)' with ID \(foodLog.id)")
        
        Button(action: {
            if let onEdit = onEdit {
                onEdit()
                AccessibilityUtils.selectionFeedback()
            }
        }) {
            HStack(spacing: AccessibilityUtils.scaledSpacing(AppSpacing.md)) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(foodLog.name)
                    .font(AppTypography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AccessibilityUtils.contrastAwareText())
                    .lineLimit(2)
                    .dynamicTypeSize(maxSize: .accessibility2)
                
                HStack(spacing: AppSpacing.md) {
                    Text("\(foodLog.formattedServing)")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .dynamicTypeSize(maxSize: .accessibility2)
                    
                    Text("•")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                    
                    Text("\(Int(foodLog.calories)) kcal")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .dynamicTypeSize(maxSize: .accessibility2)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                Text("\(Int(round(foodLog.protein)))g P")
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
                    .dynamicTypeSize(maxSize: .accessibility2)
                
                Text("\(Int(round(foodLog.carbohydrates)))g C")
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
                    .dynamicTypeSize(maxSize: .accessibility2)
                
                Text("\(Int(round(foodLog.fat)))g F")
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
                    .dynamicTypeSize(maxSize: .accessibility2)
            }
            
            Button(action: {
                onDelete()
                AccessibilityUtils.selectionFeedback()
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundColor(
                        AccessibilityUtils.contrastAwareColor(
                            normal: AppColors.error,
                            highContrast: Color.red
                        )
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .actionButtonAccessibility(
                label: "Delete \(foodLog.name)",
                hint: AccessibilityUtils.deleteFoodHint
            )
            .keyboardNavigationSupport()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                .fill(AppColors.tertiaryBackground)
        )
        .padding(.vertical, AppSpacing.xs)
        .foodLogAccessibility(
            name: foodLog.name,
            calories: foodLog.calories,
            protein: foodLog.protein,
            carbohydrates: foodLog.carbohydrates,
            fat: foodLog.fat,
            servingSize: foodLog.servingSize,
            servingUnit: foodLog.servingUnit,
            canEdit: onEdit != nil,
            canDelete: true
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let onEdit = onEdit {
                Button("Edit") {
                    onEdit()
                    AccessibilityUtils.selectionFeedback()
                }
                .tint(AppColors.primary)
                .accessibilityLabel("Edit \(foodLog.name)")
                .accessibilityHint(AccessibilityUtils.editFoodHint)
            }
            
            Button("Delete", role: .destructive) {
                onDelete()
            }
            .accessibilityLabel("Delete \(foodLog.name)")
            .accessibilityHint(AccessibilityUtils.deleteFoodHint)
        }
    }
}

// MARK: - Barcode Handling

extension FuelLogDashboardView {
    // Barcode scanning functionality is temporarily disabled
    // private func handleBarcodeScanned(_ barcode: String, viewModel: FuelLogViewModel) async {
    //     guard let foodSearchViewModel = foodSearchViewModel else { return }
    //     
    //     await foodSearchViewModel.searchByBarcode(barcode)
    //     
    //     if let result = foodSearchViewModel.barcodeResult {
    //         barcodeResult = result
    //         scannedBarcode = barcode
    //         showingBarcodeResult = true
    //     }
    // }
}

// MARK: - Preview

struct FuelLogDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        let container = try! ModelContainer(for: FoodLog.self, CustomFood.self, NutritionGoals.self)
        let dataManager = DataManager(modelContext: container.mainContext)
        
        FuelLogDashboardView()
            .environmentObject(dataManager)
            .environmentObject(PerformanceDateModel())
            .environmentObject(TabSelectionModel())
    }
}
