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
    
    init(repository: FuelLogRepositoryProtocol, onFoodSelected: @escaping (FoodLog) -> Void) {
        self._viewModel = StateObject(wrappedValue: PersonalFoodLibraryViewModel(repository: repository))
        self.onFoodSelected = onFoodSelected
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and Filter Bar
                searchAndFilterBar
                
                // Content
                if viewModel.isLoading {
                    loadingState
                } else if filteredFoods.isEmpty {
                    emptyState
                } else {
                    foodLibraryList
                }
            }
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
            .sheet(isPresented: $showingCustomFoodCreation) {
                CustomFoodCreationView(repository: viewModel.repository)
            }
            .sheet(isPresented: $viewModel.showingCustomFoodEdit) {
                if let customFood = viewModel.selectedCustomFoodForEditing {
                    CustomFoodCreationView(repository: viewModel.repository, customFood: customFood)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadFoods()
            }
        }
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
                Text("No Foods Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create your first custom food or meal to get started")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Create Food") {
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
                    onSelect: { foodLog in
                        onFoodSelected(foodLog)
                        dismiss()
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
            break
        case .individualFoods:
            foods = foods.filter { !$0.isComposite }
        case .meals:
            foods = foods.filter { $0.isComposite }
        }
        
        return foods.sorted { $0.name < $1.name }
    }
}

// MARK: - Personal Food Row

struct PersonalFoodRow: View {
    let food: CustomFood
    let onSelect: (FoodLog) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
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
                    let foodLog = FoodLog(
                        name: food.name,
                        calories: food.caloriesPerServing,
                        protein: food.proteinPerServing,
                        carbohydrates: food.carbohydratesPerServing,
                        fat: food.fatPerServing,
                        mealType: .snacks,
                        servingSize: food.servingSize,
                        servingUnit: food.servingUnit,
                        customFoodId: food.id
                    )
                    onSelect(foodLog)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(AppColors.primary)
                }
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, AppSpacing.xs)
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
    @Published var isLoading = false
    @Published var showingCustomFoodEdit = false
    @Published var selectedCustomFoodForEditing: CustomFood?
    
    let repository: FuelLogRepositoryProtocol
    
    init(repository: FuelLogRepositoryProtocol) {
        self.repository = repository
    }
    
    func loadFoods() async {
        isLoading = true
        
        do {
            foods = try await repository.fetchCustomFoods()
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
        repository: PreviewRepository()
    ) { foodLog in
        print("Selected: \(foodLog.name)")
    }
} 