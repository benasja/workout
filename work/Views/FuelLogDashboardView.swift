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
    @State private var showingBarcodeScan = false
    @State private var showingQuickAdd = false
    @State private var showingQuickEdit = false
    @State private var editingFoodLog: FoodLog?
    @State private var showingGoalsSetup = false
    @State private var isInitialized = false
    @State private var showingBarcodeResult = false
    @State private var barcodeResult: FoodSearchResult?
    @State private var scannedBarcode: String?
    @State private var foodSearchViewModel: FoodSearchViewModel?
    
    var body: some View {
        NavigationView {
            Group {
                if let viewModel = viewModel {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.lg) {
                            // Date Navigation Header
                            dateNavigationHeader
                            
                            if viewModel.isLoadingInitialData {
                                LoadingView(message: "Loading nutrition data...")
                                    .frame(height: 200)
                            } else if !viewModel.hasNutritionGoals {
                                // Onboarding state when no goals are set
                                nutritionGoalsOnboardingCard
                            } else {
                                // Main dashboard content
                                VStack(spacing: AppSpacing.lg) {
                                    // Calorie Progress Circle
                                    calorieProgressSection
                                    
                                    // Macro Progress Bars
                                    macroProgressSection
                                    
                                    // Quick Action Buttons
                                    quickActionButtons
                                    
                                    // Food Log by Meal Type
                                    foodLogSection
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.xxxl)
                    }
                    .navigationTitle("Nutrition")
                    .navigationBarTitleDisplayMode(.large)
                    .refreshable {
                        await viewModel.refresh()
                    }
                    .disabled(viewModel.isRefreshing)
                    .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                        Button("OK") {
                            viewModel.clearError()
                        }
                    } message: {
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                        }
                    }
                    .onChange(of: dateModel.selectedDate) { _, newDate in
                        viewModel.selectedDate = newDate
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
            
            // Temporary debug: Create test nutrition goals if none exist
            Task {
                if let viewModel = viewModel {
                    let repository = FuelLogRepository(modelContext: dataManager.modelContext)
                    let existingGoals = try? await repository.fetchNutritionGoals()
                    if existingGoals == nil {
                        print("🔧 Creating test nutrition goals for debugging...")
                        let testGoals = NutritionGoals(
                            dailyCalories: 2000,
                            dailyProtein: 150,
                            dailyCarbohydrates: 200,
                            dailyFat: 67,
                            activityLevel: .moderatelyActive,
                            goal: .maintain,
                            bmr: 1600,
                            tdee: 2000
                        )
                        try? await repository.saveNutritionGoals(testGoals)
                        print("🔧 Test nutrition goals created successfully")
                        
                        // Reload data to pick up the new goals
                        await viewModel.loadInitialData()
                    }
                }
            }
        }
        .sheet(isPresented: $showingGoalsSetup) {
            if let repository = viewModel?.repository as? FuelLogRepository {
                FuelLogOnboardingView(repository: repository)
            }
        }
        .sheet(isPresented: $showingFoodSearch) {
            if let repository = viewModel?.repository {
                FoodSearchView(repository: repository) { foodLog in
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
            QuickAddView { foodLog in
                Task {
                    await viewModel?.logFood(foodLog)
                }
            }
        }
        .sheet(isPresented: $showingQuickEdit) {
            if let editingFoodLog = editingFoodLog {
                QuickEditView(foodLog: editingFoodLog) { updatedFoodLog in
                    Task {
                        await viewModel?.updateFoodLog(editingFoodLog, with: updatedFoodLog)
                    }
                }
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
    
    // MARK: - Date Navigation Header
    
    private var dateNavigationHeader: some View {
        HStack {
            Button(action: {
                viewModel?.navigateToPreviousDay()
                if let selectedDate = viewModel?.selectedDate {
                    dateModel.selectedDate = selectedDate
                }
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
                Text(dateFormatter.string(from: viewModel?.selectedDate ?? dateModel.selectedDate))
                    .font(AppTypography.headline)
                    .foregroundColor(AccessibilityUtils.contrastAwareText())
                    .dynamicTypeSize(maxSize: .accessibility2)
                
                if viewModel?.isSelectedDateToday ?? Calendar.current.isDateInToday(dateModel.selectedDate) {
                    Text("Today")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.primary)
                        .dynamicTypeSize(maxSize: .accessibility2)
                } else {
                    Text(relativeDateFormatter.string(for: viewModel?.selectedDate ?? dateModel.selectedDate) ?? "")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .dynamicTypeSize(maxSize: .accessibility2)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Selected date: \(dateFormatter.string(from: viewModel?.selectedDate ?? dateModel.selectedDate))")
            .accessibilityIdentifier(AccessibilityIdentifiers.dateDisplay)
            
            Spacer()
            
            Button(action: {
                viewModel?.navigateToNextDay()
                if let selectedDate = viewModel?.selectedDate {
                    dateModel.selectedDate = selectedDate
                }
                AccessibilityUtils.selectionFeedback()
            }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(AppColors.primary)
            }
            .iconButton()
            .disabled(Calendar.current.isDateInToday(viewModel?.selectedDate ?? dateModel.selectedDate))
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
    
    private var quickActionButtons: some View {
        HStack(spacing: AccessibilityUtils.scaledSpacing(AppSpacing.md)) {
            Button(action: { 
                // Barcode scanning is temporarily disabled
                // showingBarcodeScan = true
                // AccessibilityUtils.selectionFeedback()
            }) {
                VStack(spacing: AppSpacing.xs) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.title2)
                    Text("Scan")
                        .font(AppTypography.caption)
                        .dynamicTypeSize(maxSize: .accessibility2)
                }
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding(AccessibilityUtils.scaledSpacing(AppSpacing.lg))
                .background(Color.gray.opacity(0.3))
                .cornerRadius(AppCornerRadius.md)
            }
            .disabled(true)
            .actionButtonAccessibility(
                label: "Scan barcode (temporarily disabled)",
                hint: "Barcode scanning is currently unavailable"
            )
            .accessibilityIdentifier(AccessibilityIdentifiers.scanBarcodeButton)
            .keyboardNavigationSupport()
            
            Button(action: { 
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
                showingQuickAdd = true
                AccessibilityUtils.selectionFeedback()
            }) {
                VStack(spacing: AppSpacing.xs) {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .scaleEffect(showingQuickAdd ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showingQuickAdd)
                    Text("Add New Meal")
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
                .scaleEffect(showingQuickAdd ? 0.95 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: showingQuickAdd)
            }
            .actionButtonAccessibility(
                label: "Add new meal",
                hint: "Create a new meal with custom macronutrients"
            )
            .accessibilityIdentifier(AccessibilityIdentifiers.quickAddButton)
            .keyboardNavigationSupport()
        }
    }
    
    // MARK: - Food Log Section
    
    private var foodLogSection: some View {
        VStack(spacing: AppSpacing.lg) {
            ForEach(MealType.allCases, id: \.self) { mealType in
                MealSectionView(
                    mealType: mealType,
                    foodLogs: viewModel?.foodLogs(for: mealType) ?? [],
                    nutritionTotals: viewModel?.nutritionTotals(for: mealType) ?? DailyNutritionTotals(),
                    onDeleteFood: { foodLog in
                        Task {
                            await viewModel?.deleteFood(foodLog)
                        }
                    },
                    onEditFood: { foodLog in
                        editingFoodLog = foodLog
                        showingQuickEdit = true
                    },
                    onAddFood: {
                        // TODO: Navigate to food selection for specific meal type
                        showingFoodSearch = true
                    }
                )
            }
        }
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
                    Text("\(Int(current))")
                        .font(AppTypography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AccessibilityUtils.contrastAwareText())
                        .dynamicTypeSize(maxSize: .accessibility2)
                    
                    Text("/ \(Int(goal)) \(nutrient.unit)")
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
    let onDeleteFood: (FoodLog) -> Void
    let onEditFood: (FoodLog) -> Void
    let onAddFood: () -> Void
    
    var body: some View {
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
                    VStack(spacing: AccessibilityUtils.scaledSpacing(AppSpacing.sm)) {
                        ForEach(foodLogs) { foodLog in
                            FoodLogRowView(
                                foodLog: foodLog,
                                onDelete: { 
                                    onDeleteFood(foodLog)
                                    AccessibilityUtils.announceFoodDeleted(foodLog.name)
                                },
                                onEdit: foodLog.isQuickAdd ? { 
                                    onEditFood(foodLog)
                                    AccessibilityUtils.selectionFeedback()
                                } : nil
                            )
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
                Text("\(Int(foodLog.protein))g P")
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
                    .dynamicTypeSize(maxSize: .accessibility2)
                
                Text("\(Int(foodLog.carbohydrates))g C")
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
                    .dynamicTypeSize(maxSize: .accessibility2)
                
                Text("\(Int(foodLog.fat))g F")
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
            .actionButtonAccessibility(
                label: "Delete \(foodLog.name)",
                hint: AccessibilityUtils.deleteFoodHint
            )
            .keyboardNavigationSupport()
        }
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
            if let onEdit = onEdit, foodLog.isQuickAdd {
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
