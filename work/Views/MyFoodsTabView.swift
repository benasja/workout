import SwiftUI

struct MyFoodsTabView: View {
    @Environment(\.dismiss) private var dismiss
    let repository: FuelLogRepositoryProtocol
    let onFoodSelected: (FoodLog) -> Void
    
    @State private var selectedTab = 0
    @State private var selectedMealTypeForSearch: MealType = .breakfast
    @State private var showingFoodSearch = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Tab Bar
                customTabBar
                
                // Tab Content
                TabView(selection: $selectedTab) {
                    // All Foods Tab
                    PersonalFoodLibraryView(
                        repository: repository,
                        initialFilter: .all,
                        isEmbedded: true,
                        onFoodSelected: onFoodSelected
                    )
                    .tag(0)
                    
                    // Meals Tab
                    PersonalFoodLibraryView(
                        repository: repository,
                        initialFilter: .meals,
                        isEmbedded: true,
                        onFoodSelected: onFoodSelected
                    )
                    .tag(1)
                    
                    // User Foods Tab
                    PersonalFoodLibraryView(
                        repository: repository,
                        initialFilter: .individualFoods,
                        isEmbedded: true,
                        onFoodSelected: onFoodSelected
                    )
                    .tag(2)
                    
                    // Food Database Tab
                    FoodDatabaseSearchView(
                        repository: repository,
                        selectedMealType: selectedMealTypeForSearch,
                        onFoodSelected: onFoodSelected
                    )
                    .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("My Foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingFoodSearch) {
            FoodSearchView(
                repository: repository,
                selectedDate: Date(),
                defaultMealType: selectedMealTypeForSearch,
                nutritionGoals: nil,
                onFoodSelected: onFoodSelected
            )
        }
    }
    
    // MARK: - Custom Tab Bar
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tabIcon(for: index))
                            .font(.system(size: 16, weight: .medium))
                        
                        Text(tabTitle(for: index))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(selectedTab == index ? AppColors.primary : AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedTab == index ? AppColors.primary.opacity(0.1) : Color.clear)
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "All"
        case 1: return "Meals"
        case 2: return "User Foods"
        case 3: return "Food Database"
        default: return ""
        }
    }
    
    private func tabIcon(for index: Int) -> String {
        switch index {
        case 0: return "square.grid.2x2"
        case 1: return "fork.knife"
        case 2: return "leaf.fill"
        case 3: return "magnifyingglass"
        default: return "square"
        }
    }
}

// MARK: - Food Database Search View

struct FoodDatabaseSearchView: View {
    let repository: FuelLogRepositoryProtocol
    let selectedMealType: MealType
    let onFoodSelected: (FoodLog) -> Void
    
    @State private var searchText = ""
    @State private var showingMealTypeSelector = false
    @State private var selectedFoodForAdd: BasicFoodItem?
    
    private var filteredFoods: [BasicFoodItem] {
        if searchText.isEmpty {
            return BasicFoodDatabase.shared.foods
        } else {
            return BasicFoodDatabase.shared.searchFoods(query: searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            searchBar
            
            // Food List
            List {
                ForEach(filteredFoods, id: \.name) { food in
                    FoodDatabaseRow(
                        food: food,
                        onSelect: { selectedFood in
                            selectedFoodForAdd = selectedFood
                            showingMealTypeSelector = true
                        }
                    )
                }
            }
            .listStyle(PlainListStyle())
        }
        .actionSheet(isPresented: $showingMealTypeSelector) {
            ActionSheet(
                title: Text("Add to which meal?"),
                buttons: MealType.allCases.map { mealType in
                    .default(Text(mealType.displayName)) {
                        if let selectedFood = selectedFoodForAdd {
                            let foodLog = FoodLog(
                                name: selectedFood.name,
                                calories: selectedFood.calories,
                                protein: selectedFood.protein,
                                carbohydrates: selectedFood.carbs,
                                fat: selectedFood.fat,
                                mealType: mealType,
                                servingSize: selectedFood.servingSize,
                                servingUnit: selectedFood.servingUnit
                            )
                            onFoodSelected(foodLog)
                        }
                    }
                } + [.cancel()]
            )
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search food database...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .autocorrectionDisabled()
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }
}

// MARK: - Food Database Row

struct FoodDatabaseRow: View {
    let food: BasicFoodItem
    let onSelect: (BasicFoodItem) -> Void
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Food icon
            Image(systemName: "leaf.fill")
                .font(.title2)
                .foregroundColor(AppColors.accent)
                .frame(width: 40, height: 40)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            // Food details
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(food.name)
                    .font(AppTypography.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("\(Int(food.calories)) kcal • \(Int(food.protein))g P • \(Int(food.carbs))g C • \(Int(food.fat))g F")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text("Per \(food.servingSize.formatted()) \(food.servingUnit)")
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }
            
            Spacer()
            
            // Add button
            Button(action: {
                onSelect(food)
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(AppColors.primary)
            }
        }
        .padding(.vertical, AppSpacing.xs)
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
    
    return MyFoodsTabView(
        repository: PreviewRepository()
    ) { foodLog in
        print("Selected: \(foodLog.name)")
    }
}