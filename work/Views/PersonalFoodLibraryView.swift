import SwiftUI
import SwiftData

struct PersonalFoodLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PersonalFoodLibraryViewModel
    @State private var showingCustomFoodCreation = false
    @State private var showingDeleteConfirmation = false
    @State private var foodToDelete: CustomFood?
    @State private var searchText = ""
    @State private var selectedFilter: FoodFilter = .all
    
    let onFoodSelected: (FoodLog) -> Void
    let isEmbedded: Bool
    
    init(repository: FuelLogRepositoryProtocol, initialFilter: FoodFilter = .all, isEmbedded: Bool = false, onFoodSelected: @escaping (FoodLog) -> Void) {
        self._viewModel = StateObject(wrappedValue: PersonalFoodLibraryViewModel(repository: repository))
        self.onFoodSelected = onFoodSelected
        self.isEmbedded = isEmbedded
        self._selectedFilter = State(initialValue: initialFilter)
    }
    
    var body: some View {
        Group {
            if isEmbedded {
                contentView
            } else {
                NavigationStack {
                    contentView
                        .navigationTitle("Personal Food Library")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Cancel") {
                                    dismiss()
                                }
                            }
                            
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Menu {
                                    Button(action: {
                                        showingCustomFoodCreation = true
                                    }) {
                                        Label("Create Food", systemImage: "leaf.fill")
                                    }
                                    
                                    Button(action: {
                                        showingCustomFoodCreation = true
                                    }) {
                                        Label("Create Meal", systemImage: "fork.knife")
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showingCustomFoodCreation) {
            CustomFoodCreationView(
                repository: viewModel.repository,
                defaultToComposite: selectedFilter == .meals
            )
        }
        .onChange(of: showingCustomFoodCreation) { _, isShowing in
            if !isShowing {
                // Refresh the food list when the creation sheet is dismissed
                Task {
                    await viewModel.loadFoods()
                }
            }
        }
        .sheet(isPresented: $viewModel.showingCustomFoodEdit) {
            if let customFood = viewModel.selectedCustomFoodForEditing {
                CustomFoodCreationView(repository: viewModel.repository, customFood: customFood)
            }
        }
        .onChange(of: viewModel.showingCustomFoodEdit) { _, isShowing in
            if !isShowing {
                // Refresh the food list when the edit sheet is dismissed
                Task {
                    await viewModel.loadFoods()
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadFoods()
            }
        }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        VStack(spacing: 0) {
            // Search and Filter Bar (only show if not embedded or show simplified version)
            if !isEmbedded {
                searchAndFilterBar
            } else {
                embeddedSearchBar
            }
            
            // Content
            if viewModel.isLoading {
                loadingState
            } else if filteredFoods.isEmpty {
                emptyState
            } else {
                foodLibraryList
            }
        }
        .alert("Delete Food", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let food = foodToDelete {
                    Task {
                        await viewModel.deleteFood(food)
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let food = foodToDelete {
                Text("Are you sure you want to delete '\(food.name)'? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Embedded Search Bar
    
    private var embeddedSearchBar: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search your foods...", text: $searchText)
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
                
                Button(action: {
                    showingCustomFoodCreation = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(AppColors.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding()
    }
    
    // MARK: - Search and Filter Bar
    
    private var searchAndFilterBar: some View {
        VStack(spacing: AppSpacing.sm) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search your foods...", text: $searchText)
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
            
            // Filter buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(FoodFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            selectedFilter = filter
                        }) {
                            Text(filter.displayName)
                                .font(AppTypography.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedFilter == filter ? AppColors.primary : Color(.systemGray5))
                                .foregroundColor(selectedFilter == filter ? .white : .primary)
                                .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
    }
    
    // MARK: - Loading State
    
    private var loadingState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading your foods...")
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "heart.text.square")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(emptyStateMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(selectedFilter == .meals ? "Create Meal" : "Create Food") {
                showingCustomFoodCreation = true
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Food Library List
    
    private var foodLibraryList: some View {
        List {
            ForEach(filteredFoods) { food in
                PersonalFoodRow(
                    food: food,
                    isFromDatabase: selectedFilter == .all && !viewModel.foods.contains(where: { $0.id == food.id }),
                    onSelect: { foodLog in
                        onFoodSelected(foodLog)
                        if !isEmbedded {
                            dismiss()
                        }
                    },
                    onEdit: {
                        viewModel.selectedCustomFoodForEditing = food
                        viewModel.showingCustomFoodEdit = true
                    },
                    onDelete: {
                        foodToDelete = food
                        showingDeleteConfirmation = true
                    }
                )
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Computed Properties
    
    private var filteredFoods: [CustomFood] {
        var foods = viewModel.foods
        
        // Apply search filter
        if !searchText.isEmpty {
            foods = foods.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Apply category filter
        switch selectedFilter {
        case .all:
            // For "All" tab, we need to show recently used foods from all sources
            // This will be handled by the new allRecentFoods computed property
            return viewModel.allRecentFoods.filter { food in
                searchText.isEmpty || food.name.localizedCaseInsensitiveContains(searchText)
            }
        case .individualFoods:
            foods = foods.filter { !$0.isComposite }
        case .meals:
            foods = foods.filter { $0.isComposite }
        }
        
        return foods.sorted { $0.name < $1.name }
    }
    
    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all:
            return "No Foods Yet"
        case .meals:
            return "No Meals Yet"
        case .individualFoods:
            return "No Custom Foods Yet"
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all:
            return "Create your first custom food or meal to get started"
        case .meals:
            return "Create your first composite meal with multiple ingredients"
        case .individualFoods:
            return "Create your first custom food item"
        }
    }
}

// MARK: - Personal Food Row

struct PersonalFoodRow: View {
    let food: CustomFood
    let isFromDatabase: Bool
    let onSelect: (FoodLog) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showingMealTypeSelector = false
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Food icon
            Image(systemName: food.isComposite ? "fork.knife" : "leaf.fill")
                .font(.title2)
                .foregroundColor(food.isComposite ? AppColors.secondary : AppColors.accent)
                .frame(width: 40, height: 40)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            // Food details
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text(food.name)
                        .font(AppTypography.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    if food.isComposite {
                        Text("Meal")
                            .font(AppTypography.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.secondary.opacity(0.2))
                            .foregroundColor(AppColors.secondary)
                            .cornerRadius(4)
                    }
                    
                    if isFromDatabase {
                        Text("Database")
                            .font(AppTypography.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.accent.opacity(0.2))
                            .foregroundColor(AppColors.accent)
                            .cornerRadius(4)
                    }
                }
                
                Text("\(Int(food.caloriesPerServing)) kcal • \(Int(food.proteinPerServing))g P • \(Int(food.carbohydratesPerServing))g C • \(Int(food.fatPerServing))g F")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text("Per \(food.formattedServing)")
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: AppSpacing.sm) {
                Button(action: {
                    showingMealTypeSelector = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(AppColors.primary)
                }
                
                if !isFromDatabase {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.vertical, AppSpacing.xs)
        .actionSheet(isPresented: $showingMealTypeSelector) {
            ActionSheet(
                title: Text("Add to which meal?"),
                buttons: MealType.allCases.map { mealType in
                    .default(Text(mealType.displayName)) {
                        let foodLog = FoodLog(
                            name: food.name,
                            calories: food.caloriesPerServing,
                            protein: food.proteinPerServing,
                            carbohydrates: food.carbohydratesPerServing,
                            fat: food.fatPerServing,
                            mealType: mealType,
                            servingSize: food.servingSize,
                            servingUnit: food.servingUnit,
                            customFoodId: food.id
                        )
                        onSelect(foodLog)
                    }
                } + [.cancel()]
            )
        }
    }
}

// MARK: - Food Filter

enum FoodFilter: CaseIterable {
    case all
    case individualFoods
    case meals
    
    var displayName: String {
        switch self {
        case .all:
            return "All"
        case .individualFoods:
            return "Foods"
        case .meals:
            return "Meals"
        }
    }
}

// MARK: - Personal Food Library ViewModel

@MainActor
final class PersonalFoodLibraryViewModel: ObservableObject {
    @Published var foods: [CustomFood] = []
    @Published var recentFoodLogs: [FoodLog] = []
    @Published var isLoading = false
    @Published var showingCustomFoodEdit = false
    @Published var selectedCustomFoodForEditing: CustomFood?
    
    let repository: FuelLogRepositoryProtocol
    
    init(repository: FuelLogRepositoryProtocol) {
        self.repository = repository
    }
    
    // Computed property to combine custom foods with recently used database foods
    var allRecentFoods: [CustomFood] {
        var allFoods: [CustomFood] = []
        var foodNames: Set<String> = []
        
        // Add custom foods (sorted by creation date)
        let sortedCustomFoods = foods.sorted { $0.createdDate > $1.createdDate }
        for food in sortedCustomFoods {
            if !foodNames.contains(food.name) {
                allFoods.append(food)
                foodNames.insert(food.name)
            }
        }
        
        // Add recently used database foods (create temporary CustomFood objects)
        let recentDatabaseFoods = recentFoodLogs
            .filter { $0.customFoodId == nil } // Only database foods
            .sorted { $0.timestamp > $1.timestamp } // Most recent first
        
        for foodLog in recentDatabaseFoods {
            if !foodNames.contains(foodLog.name) {
                // Create a temporary CustomFood object for display
                let tempCustomFood = CustomFood(
                    name: foodLog.name,
                    caloriesPerServing: foodLog.calories,
                    proteinPerServing: foodLog.protein,
                    carbohydratesPerServing: foodLog.carbohydrates,
                    fatPerServing: foodLog.fat,
                    servingSize: foodLog.servingSize,
                    servingUnit: foodLog.servingUnit,
                    isComposite: false
                )
                // Set the creation date to the food log timestamp for proper sorting
                tempCustomFood.createdDate = foodLog.timestamp
                allFoods.append(tempCustomFood)
                foodNames.insert(foodLog.name)
            }
        }
        
        // Sort all foods by most recently used/created
        return allFoods.sorted { $0.createdDate > $1.createdDate }
    }
    
    func loadFoods() async {
        isLoading = true
        
        do {
            // Load custom foods
            foods = try await repository.fetchCustomFoods()
            
            // Load recent food logs (last 30 days) to show recently used database foods
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            recentFoodLogs = try await repository.fetchFoodLogsByDateRange(from: thirtyDaysAgo, to: Date(), limit: 100)
        } catch {
            print("Error loading foods: \(error)")
        }
        
        isLoading = false
    }
    
    func deleteFood(_ food: CustomFood) async {
        do {
            try await repository.deleteCustomFood(food)
            await loadFoods()
        } catch {
            print("Error deleting food: \(error)")
        }
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
    
    return PersonalFoodLibraryView(
        repository: PreviewRepository(),
        initialFilter: .all,
        isEmbedded: false
    ) { foodLog in
        print("Selected: \(foodLog.name)")
    }
} 