import SwiftUI
import SwiftData

struct DailyLoggingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DailyLoggingViewModel
    @State private var showingFoodSearch = false
    @State private var showingPersonalLibrary = false
    @State private var showingQuickAdd = false
    @State private var selectedMealType: MealType = .snacks
    
    let onFoodAdded: (FoodLog) -> Void
    
    init(repository: FuelLogRepositoryProtocol, selectedDate: Date, onFoodAdded: @escaping (FoodLog) -> Void) {
        self._viewModel = StateObject(wrappedValue: DailyLoggingViewModel(repository: repository, selectedDate: selectedDate))
        self.onFoodAdded = onFoodAdded
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Daily Summary Header
                dailySummaryHeader
                
                // Quick Add Buttons
                quickAddButtons
                
                // Food Log List
                foodLogList
            }
            .navigationTitle("Daily Food Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showingFoodSearch = true
                        }) {
                            Label("Search Foods", systemImage: "magnifyingglass")
                        }
                        
                        Button(action: {
                            showingPersonalLibrary = true
                        }) {
                            Label("My Food Library", systemImage: "heart.text.square")
                        }
                        
                        Button(action: {
                            showingQuickAdd = true
                        }) {
                            Label("Quick Add", systemImage: "plus.circle")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingFoodSearch) {
                FoodSearchView(repository: viewModel.repository, selectedDate: viewModel.selectedDate) { foodLog in
                    onFoodAdded(foodLog)
                    Task {
                        await viewModel.loadFoodLogs()
                    }
                }
            }
            .sheet(isPresented: $showingPersonalLibrary) {
                PersonalFoodLibraryView(repository: viewModel.repository) { foodLog in
                    onFoodAdded(foodLog)
                    Task {
                        await viewModel.loadFoodLogs()
                    }
                }
            }
            .sheet(isPresented: $showingQuickAdd) {
                QuickAddView(selectedDate: viewModel.selectedDate) { foodLog in
                    onFoodAdded(foodLog)
                    Task {
                        await viewModel.loadFoodLogs()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadFoodLogs()
            }
        }
    }
    
    // MARK: - Daily Summary Header
    
    private var dailySummaryHeader: some View {
        ModernCard {
            VStack(spacing: AppSpacing.md) {
                HStack {
                    Text("Today's Summary")
                        .font(AppTypography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Text(viewModel.selectedDate, style: .date)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                // Nutrition totals
                HStack(spacing: AppSpacing.lg) {
                    NutritionSummaryItem(
                        label: "Calories",
                        value: "\(Int(viewModel.dailyTotals.totalCalories))",
                        unit: "kcal",
                        color: AppColors.primary
                    )
                    
                    NutritionSummaryItem(
                        label: "Protein",
                        value: "\(Int(viewModel.dailyTotals.totalProtein))",
                        unit: "g",
                        color: AppColors.accent
                    )
                    
                    NutritionSummaryItem(
                        label: "Carbs",
                        value: "\(Int(viewModel.dailyTotals.totalCarbohydrates))",
                        unit: "g",
                        color: AppColors.secondary
                    )
                    
                    NutritionSummaryItem(
                        label: "Fat",
                        value: "\(Int(viewModel.dailyTotals.totalFat))",
                        unit: "g",
                        color: AppColors.warning
                    )
                }
            }
            .padding(AppSpacing.lg)
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - Quick Add Buttons
    
    private var quickAddButtons: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("Quick Actions")
                .font(AppTypography.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            HStack(spacing: AppSpacing.sm) {
                QuickActionButton(
                    title: "Search",
                    icon: "magnifyingglass",
                    color: AppColors.secondary
                ) {
                    showingFoodSearch = true
                }
                
                QuickActionButton(
                    title: "My Foods",
                    icon: "heart.text.square",
                    color: AppColors.accent
                ) {
                    showingPersonalLibrary = true
                }
                
                QuickActionButton(
                    title: "Quick Add",
                    icon: "plus.circle",
                    color: AppColors.primary
                ) {
                    showingQuickAdd = true
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, AppSpacing.md)
    }
    
    // MARK: - Food Log List
    
    private var foodLogList: some View {
        List {
            ForEach(MealType.allCases, id: \.self) { mealType in
                Section {
                    let mealFoods = viewModel.foodLogs.filter { $0.mealType == mealType }
                    let mealTotals = viewModel.nutritionTotals(for: mealType)
                    
                    if mealFoods.isEmpty {
                        EmptyMealSection(mealType: mealType) {
                            selectedMealType = mealType
                            showingFoodSearch = true
                        }
                    } else {
                        ForEach(mealFoods) { foodLog in
                            DailyLoggingFoodRow(
                                foodLog: foodLog,
                                onDelete: {
                                    Task {
                                        await viewModel.deleteFood(foodLog)
                                    }
                                }
                            )
                        }
                        
                        // Meal summary
                        if mealTotals.totalCalories > 0 {
                            MealSummaryRow(totals: mealTotals)
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: mealType.icon)
                            .foregroundColor(AppColors.primary)
                        Text(mealType.displayName)
                            .font(AppTypography.subheadline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if !viewModel.foodLogs.filter({ $0.mealType == mealType }).isEmpty {
                            Text("\(viewModel.foodLogs.filter({ $0.mealType == mealType }).count) items")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - Nutrition Summary Item

struct NutritionSummaryItem: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Text(value)
                .font(AppTypography.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(unit)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
            
            Text(label)
                .font(AppTypography.caption2)
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(AppTypography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.md)
            .background(color)
            .cornerRadius(AppCornerRadius.md)
        }
    }
}

// MARK: - Empty Meal Section

struct EmptyMealSection: View {
    let mealType: MealType
    let onAddFood: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "plus.circle")
                .font(.title3)
                .foregroundColor(AppColors.primary)
            
            Text("Add food to \(mealType.displayName)")
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
        }
        .padding(.vertical, AppSpacing.sm)
        .contentShape(Rectangle())
        .onTapGesture {
            onAddFood()
        }
    }
}

// MARK: - Daily Logging Food Row

struct DailyLoggingFoodRow: View {
    let foodLog: FoodLog
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(foodLog.name)
                    .font(AppTypography.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text("\(foodLog.formattedServing)")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                Text("\(Int(foodLog.calories)) kcal")
                    .font(AppTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                HStack(spacing: AppSpacing.xs) {
                    Text("\(Int(foodLog.protein))g P")
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textTertiary)
                    
                    Text("\(Int(foodLog.carbohydrates))g C")
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textTertiary)
                    
                    Text("\(Int(foodLog.fat))g F")
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundColor(AppColors.error)
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }
}

// MARK: - Meal Summary Row

struct MealSummaryRow: View {
    let totals: DailyNutritionTotals
    
    var body: some View {
        HStack {
            Text("Meal Total")
                .font(AppTypography.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Text("\(Int(totals.totalCalories)) kcal")
                .font(AppTypography.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            Text("•")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
            
            Text("\(Int(totals.totalProtein))g P")
                .font(AppTypography.caption2)
                .foregroundColor(AppColors.textTertiary)
            
            Text("\(Int(totals.totalCarbohydrates))g C")
                .font(AppTypography.caption2)
                .foregroundColor(AppColors.textTertiary)
            
            Text("\(Int(totals.totalFat))g F")
                .font(AppTypography.caption2)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.vertical, AppSpacing.xs)
        .padding(.horizontal, AppSpacing.sm)
        .background(Color(.systemGray6))
        .cornerRadius(AppCornerRadius.sm)
    }
}

// MARK: - Daily Logging ViewModel

@MainActor
final class DailyLoggingViewModel: ObservableObject {
    @Published var foodLogs: [FoodLog] = []
    @Published var dailyTotals = DailyNutritionTotals()
    @Published var isLoading = false
    
    let repository: FuelLogRepositoryProtocol
    let selectedDate: Date
    
    init(repository: FuelLogRepositoryProtocol, selectedDate: Date) {
        self.repository = repository
        self.selectedDate = selectedDate
    }
    
    func loadFoodLogs() async {
        isLoading = true
        
        do {
            foodLogs = try await repository.fetchFoodLogs(for: selectedDate)
            calculateDailyTotals()
        } catch {
            print("Error loading food logs: \(error)")
        }
        
        isLoading = false
    }
    
    func deleteFood(_ foodLog: FoodLog) async {
        do {
            try await repository.deleteFoodLog(foodLog)
            await loadFoodLogs()
        } catch {
            print("Error deleting food log: \(error)")
        }
    }
    
    func nutritionTotals(for mealType: MealType) -> DailyNutritionTotals {
        let mealFoods = foodLogs.filter { $0.mealType == mealType }
        return DailyNutritionTotals(
            totalCalories: mealFoods.reduce(0) { $0 + $1.calories },
            totalProtein: mealFoods.reduce(0) { $0 + $1.protein },
            totalCarbohydrates: mealFoods.reduce(0) { $0 + $1.carbohydrates },
            totalFat: mealFoods.reduce(0) { $0 + $1.fat }
        )
    }
    
    private func calculateDailyTotals() {
        dailyTotals = DailyNutritionTotals(
            totalCalories: foodLogs.reduce(0) { $0 + $1.calories },
            totalProtein: foodLogs.reduce(0) { $0 + $1.protein },
            totalCarbohydrates: foodLogs.reduce(0) { $0 + $1.carbohydrates },
            totalFat: foodLogs.reduce(0) { $0 + $1.fat }
        )
    }
}

// MARK: - Preview

#Preview {
    struct PreviewRepository: FuelLogRepositoryProtocol {
        nonisolated func fetchFoodLogs(for date: Date) async throws -> [FoodLog] { [] }
        nonisolated func fetchFoodLogs(for date: Date, limit: Int, offset: Int) async throws -> [FoodLog] { [] }
        nonisolated func saveFoodLog(_ foodLog: FoodLog) async throws { }
        nonisolated func updateFoodLog(_ foodLog: FoodLog) async throws { }
        nonisolated func deleteFoodLog(_ foodLog: FoodLog) async throws { }
        nonisolated func fetchFoodLogsByDateRange(from startDate: Date, to endDate: Date) async throws -> [FoodLog] { [] }
        nonisolated func fetchFoodLogsByDateRange(from startDate: Date, to endDate: Date, limit: Int) async throws -> [FoodLog] { [] }
        nonisolated func fetchCustomFoods() async throws -> [CustomFood] { [] }
        nonisolated func fetchCustomFoods(limit: Int, offset: Int, searchQuery: String?) async throws -> [CustomFood] { [] }
        nonisolated func fetchCustomFood(by id: UUID) async throws -> CustomFood? { nil }
        nonisolated func saveCustomFood(_ customFood: CustomFood) async throws { }
        nonisolated func updateCustomFood(_ customFood: CustomFood) async throws { }
        nonisolated func deleteCustomFood(_ customFood: CustomFood) async throws { }
        nonisolated func searchCustomFoods(query: String) async throws -> [CustomFood] { [] }
        nonisolated func fetchNutritionGoals() async throws -> NutritionGoals? { nil }
        nonisolated func fetchNutritionGoals(for userId: String) async throws -> NutritionGoals? { nil }
        nonisolated func saveNutritionGoals(_ goals: NutritionGoals) async throws { }
        nonisolated func updateNutritionGoals(_ goals: NutritionGoals) async throws { }
        nonisolated func deleteNutritionGoals(_ goals: NutritionGoals) async throws { }
    }
    
    return DailyLoggingView(
        repository: PreviewRepository(),
        selectedDate: Date()
    ) { foodLog in
        print("Added: \(foodLog.name)")
    }
} 