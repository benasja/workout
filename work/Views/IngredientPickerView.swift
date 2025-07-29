import SwiftUI
import SwiftData

struct IngredientPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: IngredientPickerViewModel
    
    let onIngredientSelected: (CustomFoodIngredient) -> Void
    
    init(repository: FuelLogRepositoryProtocol, onIngredientSelected: @escaping (CustomFoodIngredient) -> Void) {
        self._viewModel = StateObject(wrappedValue: IngredientPickerViewModel(repository: repository))
        self.onIngredientSelected = onIngredientSelected
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchSection
                
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    resultsSection
                }
            }
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create New") {
                        viewModel.showingCustomFoodCreation = true
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingCustomFoodCreation) {
                CustomFoodCreationView(repository: viewModel.repository)
            }
            .sheet(isPresented: $viewModel.showingPortionAdjustment) {
                if let selectedFood = viewModel.selectedFood {
                    PortionAdjustmentView(
                        food: selectedFood,
                        onPortionConfirmed: { ingredient in
                            onIngredientSelected(ingredient)
                        }
                    )
                }
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .task {
                await viewModel.loadCustomFoods()
            }
        }
    }
    
    // MARK: - View Sections
    
    private var searchSection: some View {
        VStack(spacing: 12) {
            SearchBar(text: $viewModel.searchText, onSearchButtonClicked: {
                Task {
                    await viewModel.performSearch()
                }
            })
            
            Picker("Source", selection: $viewModel.selectedSource) {
                Text("Custom Foods").tag(IngredientSource.custom)
                Text("Food Database").tag(IngredientSource.database)
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    private var resultsSection: some View {
        List {
            if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No foods found matching '\(viewModel.searchText)'")
                )
            } else {
                ForEach(viewModel.searchResults, id: \.id) { result in
                    IngredientResultRow(result: result) {
                        viewModel.selectFood(result)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Supporting Views

struct SearchBar: View {
    @Binding var text: String
    let onSearchButtonClicked: () -> Void
    
    var body: some View {
        HStack {
            TextField("Search for ingredients...", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    onSearchButtonClicked()
                }
            
            Button("Search", action: onSearchButtonClicked)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

struct IngredientResultRow: View {
    let result: IngredientSearchResult
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(result.source.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let serving = result.servingInfo {
                        Text(serving)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(String(format: "%.0f", result.calories)) kcal")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 4) {
                        Text("P: \(String(format: "%.1f", result.protein))g")
                        Text("C: \(String(format: "%.1f", result.carbohydrates))g")
                        Text("F: \(String(format: "%.1f", result.fat))g")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Data Models

enum IngredientSource: CaseIterable {
    case custom
    case database
    
    var displayName: String {
        switch self {
        case .custom: return "Custom Foods"
        case .database: return "Food Database"
        }
    }
}

struct IngredientSearchResult: Identifiable {
    let id: UUID
    let name: String
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let servingSize: Double
    let servingUnit: String
    let source: IngredientSource
    let customFood: CustomFood?
    
    var servingInfo: String? {
        if servingSize == 1.0 {
            return "per \(servingUnit)"
        } else {
            return "per \(String(format: "%.1f", servingSize)) \(servingUnit)"
        }
    }
    
    var formattedServing: String {
        if servingSize == 1.0 {
            return "1 \(servingUnit)"
        } else if servingSize.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(servingSize)) \(servingUnit)"
        } else {
            return String(format: "%.1f", servingSize) + " \(servingUnit)"
        }
    }
    
    init(from customFood: CustomFood) {
        self.id = customFood.id
        self.name = customFood.name
        self.calories = customFood.caloriesPerServing
        self.protein = customFood.proteinPerServing
        self.carbohydrates = customFood.carbohydratesPerServing
        self.fat = customFood.fatPerServing
        self.servingSize = customFood.servingSize
        self.servingUnit = customFood.servingUnit
        self.source = .custom
        self.customFood = customFood
    }
    
    // For future database integration
    init(name: String, calories: Double, protein: Double, carbohydrates: Double, fat: Double, servingSize: Double = 1.0, servingUnit: String = "serving") {
        self.id = UUID()
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.source = .database
        self.customFood = nil
    }
}

#Preview {
    let schema = Schema([FoodLog.self, CustomFood.self, NutritionGoals.self])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [modelConfiguration])
    let repository = FuelLogRepository(modelContext: container.mainContext)
    
    IngredientPickerView(repository: repository) { _ in }
}