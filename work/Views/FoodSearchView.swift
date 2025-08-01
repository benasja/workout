import SwiftUI
import SwiftData

// MARK: - Food Search View

struct FoodSearchView: View {
    @StateObject private var viewModel: FoodSearchViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingCustomFoodCreation = false
    @FocusState private var isSearchFieldFocused: Bool
    
    let onFoodSelected: (FoodLog) -> Void
    let selectedDate: Date
    let defaultMealType: MealType
    
    init(
        repository: FuelLogRepositoryProtocol,
        selectedDate: Date,
        defaultMealType: MealType = .breakfast,
        onFoodSelected: @escaping (FoodLog) -> Void
    ) {
        self._viewModel = StateObject(wrappedValue: FoodSearchViewModel(repository: repository))
        self.selectedDate = selectedDate
        self.defaultMealType = defaultMealType
        self.onFoodSelected = onFoodSelected
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Content
                if viewModel.isSearching {
                    loadingState
                } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
                    noResultsState
                } else {
                    searchResultsList
                }
            }
            .navigationTitle("Search Foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCustomFoodCreation = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Search Error", isPresented: $viewModel.showErrorAlert) {
                Button("OK") {
                    viewModel.showErrorAlert = false
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
            .sheet(isPresented: $showingCustomFoodCreation) {
                CustomFoodCreationView(repository: viewModel.repository)
            }
            .sheet(isPresented: $viewModel.showingCustomFoodEdit) {
                if let customFood = viewModel.selectedCustomFoodForEditing {
                    CustomFoodCreationView(repository: viewModel.repository, customFood: customFood)
                }
            }
            .alert("Delete Custom Food", isPresented: $viewModel.showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let customFood = viewModel.customFoodToDelete {
                        Task {
                            await viewModel.deleteCustomFood(customFood)
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let customFood = viewModel.customFoodToDelete {
                    Text("Are you sure you want to delete '\(customFood.name)'? This action cannot be undone.")
                }
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search for foods...", text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocorrectionDisabled()
                    .focused($isSearchFieldFocused)
                    .accessibilityLabel("Food search")
                    .accessibilityHint("Enter food name to search database and custom foods")
                    .accessibilityIdentifier(AccessibilityIdentifiers.foodNameField)
                    .dynamicTypeSize(maxSize: .accessibility2)
                    .keyboardNavigationSupport()
                    .onSubmit {
                        AccessibilityUtils.selectionFeedback()
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.clearSearch()
                        AccessibilityUtils.selectionFeedback()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                    .accessibilityHint("Double tap to clear search text")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, AccessibilityUtils.scaledSpacing(8))
            .background(AccessibilityUtils.contrastAwareBackground())
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Empty Search State
    
    private var emptySearchState: some View {
        VStack(spacing: AccessibilityUtils.scaledSpacing(20)) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            VStack(spacing: AccessibilityUtils.scaledSpacing(8)) {
                Text("Search for Foods")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AccessibilityUtils.contrastAwareText())
                    .dynamicTypeSize(maxSize: .accessibility2)
                
                Text("Enter a food name to search our database\nand your custom foods")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .dynamicTypeSize(maxSize: .accessibility2)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Search for foods. Enter a food name to search database and custom foods")
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Loading State
    
    private var loadingState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Searching...")
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - No Results State
    
    private var noResultsState: some View {
        VStack(spacing: AccessibilityUtils.scaledSpacing(20)) {
            Spacer()
            
            Image(systemName: "questionmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            VStack(spacing: AccessibilityUtils.scaledSpacing(8)) {
                Text("No Results Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AccessibilityUtils.contrastAwareText())
                    .dynamicTypeSize(maxSize: .accessibility2)
                
                Text("Try different keywords or create a custom food item")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .dynamicTypeSize(maxSize: .accessibility2)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("No results found. Try different keywords or create a custom food item")
            
            Button(action: {
                showingCustomFoodCreation = true
                AccessibilityUtils.selectionFeedback()
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Custom Food")
                        .dynamicTypeSize(maxSize: .accessibility2)
                }
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, AccessibilityUtils.scaledSpacing(20))
                .padding(.vertical, AccessibilityUtils.scaledSpacing(12))
                .background(
                    AccessibilityUtils.contrastAwareColor(
                        normal: Color.blue,
                        highContrast: Color.blue
                    )
                )
                .cornerRadius(10)
            }
            .accessibilityLabel("Create custom food")
            .accessibilityHint("Double tap to create a new custom food item")
            
            Spacer()
        }
        .padding()
        .onAppear {
            AccessibilityUtils.announceSearchResults(count: 0)
        }
    }
    
    // MARK: - Search Results List
    
    private var searchResultsList: some View {
        List {
            // Local custom foods section
            if !localResults.isEmpty {
                Section {
                    ForEach(localResults, id: \.id) { result in
                        FoodSearchResultRow(result: result, selectedDate: selectedDate, defaultMealType: defaultMealType) { foodLog in
                            onFoodSelected(foodLog)
                            dismiss()
                        }
                        .contextMenu {
                            if let customFood = result.customFood {
                                Button(action: {
                                    viewModel.selectedCustomFoodForEditing = customFood
                                    viewModel.showingCustomFoodEdit = true
                                }) {
                                    Label("Edit", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive, action: {
                                    viewModel.customFoodToDelete = customFood
                                    viewModel.showingDeleteConfirmation = true
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text("Your Custom Foods")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            
            // API results section
            if !apiResults.isEmpty {
                Section {
                    ForEach(apiResults, id: \.id) { result in
                        FoodSearchResultRow(result: result, selectedDate: selectedDate, defaultMealType: defaultMealType) { foodLog in
                            onFoodSelected(foodLog)
                            dismiss()
                        }
                    }
                } header: {
                    if !localResults.isEmpty {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("Food Database")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .onAppear {
            AccessibilityUtils.announceSearchResults(count: viewModel.searchResults.count)
        }
        .onChange(of: viewModel.searchResults.count) { _, newCount in
            AccessibilityUtils.announceSearchResults(count: newCount)
        }
    }
    
    // MARK: - Computed Properties
    
    private var localResults: [FoodSearchResult] {
        viewModel.searchResults.filter { $0.source == .custom }
    }
    
    private var apiResults: [FoodSearchResult] {
        viewModel.searchResults.filter { $0.source == .openFoodFacts }
    }
}

// MARK: - Food Search Result Row

struct FoodSearchResultRow: View {
    let result: FoodSearchResult
    let selectedDate: Date
    let defaultMealType: MealType
    let onFoodSelected: (FoodLog) -> Void
    
    var body: some View {
        NavigationLink(destination: FoodDetailView(foodResult: result, selectedDate: selectedDate, defaultMealType: defaultMealType, onConfirm: onFoodSelected)) {
            HStack {
                VStack(alignment: .leading, spacing: AccessibilityUtils.scaledSpacing(4)) {
                    Text(result.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(AccessibilityUtils.contrastAwareText())
                        .multilineTextAlignment(.leading)
                        .dynamicTypeSize(maxSize: .accessibility2)
                    
                    Text(result.nutritionSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .dynamicTypeSize(maxSize: .accessibility2)
                    
                    HStack {
                        Text("Per \(result.formattedServing)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .dynamicTypeSize(maxSize: .accessibility2)
                        
                        Spacer()
                        
                        if result.source == .custom {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                    .accessibilityHidden(true)
                                Text("Custom")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .dynamicTypeSize(maxSize: .accessibility2)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, AccessibilityUtils.scaledSpacing(4))
        }
        .buttonStyle(PlainButtonStyle())
        .searchResultAccessibility(
            name: result.displayName,
            calories: result.calories,
            protein: result.protein,
            carbohydrates: result.carbohydrates,
            fat: result.fat,
            isCustom: result.source == .custom
        )
    }
}

// MARK: - Extensions

extension FoodSearchResult {
    var formattedServing: String {
        if servingSize == 1.0 {
            return "1 \(servingUnit)"
        } else if servingSize.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(servingSize)) \(servingUnit)"
        } else {
            return String(format: "%.1f", servingSize) + " \(servingUnit)"
        }
    }
}

// MARK: - Preview Repository

private struct PreviewRepository: FuelLogRepositoryProtocol {
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

// MARK: - Preview

#Preview {
    FoodSearchView(
        repository: PreviewRepository(),
        selectedDate: Date()
    ) { foodLog in
        print("Selected: \(foodLog.name)")
    }
}