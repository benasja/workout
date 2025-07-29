import SwiftUI

struct CustomFoodCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CustomFoodCreationViewModel
    
    @State private var showingIngredientPicker = false
    @State private var showingDeleteConfirmation = false
    @State private var ingredientToDelete: CustomFoodIngredient?
    
    private let isEditing: Bool
    
    init(repository: FuelLogRepositoryProtocol, customFood: CustomFood? = nil) {
        self.isEditing = customFood != nil
        self._viewModel = StateObject(wrappedValue: CustomFoodCreationViewModel(
            repository: repository,
            existingFood: customFood
        ))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                nutritionSection
                
                if viewModel.isComposite {
                    ingredientsSection
                } else {
                    servingSection
                }
                
                validationSection
            }
            .navigationTitle(isEditing ? "Edit Food" : "Create Custom Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Create") {
                        Task {
                            await viewModel.saveCustomFood()
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isLoading)
                }
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Delete Ingredient", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let ingredient = ingredientToDelete {
                        viewModel.removeIngredient(ingredient)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to remove this ingredient?")
            }
            .sheet(isPresented: $showingIngredientPicker) {
                IngredientPickerView(
                    repository: viewModel.repository,
                    onIngredientSelected: { ingredient in
                        viewModel.addIngredient(ingredient)
                        showingIngredientPicker = false
                    }
                )
            }
            .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
                if shouldDismiss {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - View Sections
    
    private var basicInfoSection: some View {
        Section("Basic Information") {
            TextField("Food Name", text: $viewModel.name)
                .textInputAutocapitalization(.words)
                .accessibilityLabel("Food name")
                .accessibilityHint("Enter the name of the food item")
                .accessibilityIdentifier(AccessibilityIdentifiers.foodNameField)
                .dynamicTypeSize(maxSize: .accessibility2)
            
            Toggle("Composite Meal", isOn: $viewModel.isComposite)
                .help("Enable this for recipes with multiple ingredients")
                .accessibilityLabel("Composite meal toggle")
                .accessibilityHint("Enable this for recipes with multiple ingredients")
                .dynamicTypeSize(maxSize: .accessibility2)
                .onChange(of: viewModel.isComposite) { _, newValue in
                    AccessibilityUtils.selectionFeedback()
                }
        }
    }
    
    private var nutritionSection: some View {
        Section("Nutrition Information") {
            if viewModel.isComposite {
                // For composite meals, show calculated totals
                NutritionDisplayRow(label: "Calories", value: viewModel.calculatedCalories, unit: "kcal")
                NutritionDisplayRow(label: "Protein", value: viewModel.calculatedProtein, unit: "g")
                NutritionDisplayRow(label: "Carbohydrates", value: viewModel.calculatedCarbohydrates, unit: "g")
                NutritionDisplayRow(label: "Fat", value: viewModel.calculatedFat, unit: "g")
            } else {
                // For simple foods, allow manual input
                NutritionInputRow(label: "Calories", value: $viewModel.calories, unit: "kcal")
                NutritionInputRow(label: "Protein", value: $viewModel.protein, unit: "g")
                NutritionInputRow(label: "Carbohydrates", value: $viewModel.carbohydrates, unit: "g")
                NutritionInputRow(label: "Fat", value: $viewModel.fat, unit: "g")
            }
        }
    }
    
    private var servingSection: some View {
        Section("Serving Information") {
            HStack {
                Text("Serving Size")
                    .dynamicTypeSize(maxSize: .accessibility2)
                Spacer()
                TextField("1.0", value: $viewModel.servingSize, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .accessibilityLabel("Serving size")
                    .accessibilityHint("Enter serving size amount")
                    .accessibilityIdentifier(AccessibilityIdentifiers.servingSizeField)
                    .dynamicTypeSize(maxSize: .accessibility2)
                TextField("Unit", text: $viewModel.servingUnit)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .accessibilityLabel("Serving unit")
                    .accessibilityHint("Enter serving unit like grams or cups")
                    .dynamicTypeSize(maxSize: .accessibility2)
            }
        }
    }
    
    private var ingredientsSection: some View {
        Section("Ingredients") {
            ForEach(viewModel.ingredients) { ingredient in
                IngredientRow(ingredient: ingredient) {
                    ingredientToDelete = ingredient
                    showingDeleteConfirmation = true
                }
            }
            
            Button(action: {
                showingIngredientPicker = true
                AccessibilityUtils.selectionFeedback()
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)
                    Text("Add Ingredient")
                        .dynamicTypeSize(maxSize: .accessibility2)
                }
            }
            .accessibilityLabel("Add ingredient")
            .accessibilityHint("Double tap to add a new ingredient to this recipe")
            .keyboardNavigationSupport()
        }
    }
    
    private var validationSection: some View {
        Section("Validation") {
            if !viewModel.validationMessages.isEmpty {
                ForEach(viewModel.validationMessages, id: \.self) { message in
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else if viewModel.isValid {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All validation checks passed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct NutritionInputRow: View {
    let label: String
    @Binding var value: Double
    let unit: String
    
    var body: some View {
        HStack {
            Text(label)
                .dynamicTypeSize(maxSize: .accessibility2)
            Spacer()
            TextField("0.0", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .accessibilityLabel("\(label) in \(unit)")
                .accessibilityHint("Enter \(label.lowercased()) value")
                .dynamicTypeSize(maxSize: .accessibility2)
            Text(unit)
                .foregroundColor(.secondary)
                .dynamicTypeSize(maxSize: .accessibility2)
        }
    }
}

struct NutritionDisplayRow: View {
    let label: String
    let value: Double
    let unit: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(String(format: "%.1f", value))
                .fontWeight(.medium)
            Text(unit)
                .foregroundColor(.secondary)
        }
    }
}

struct IngredientRow: View {
    let ingredient: CustomFoodIngredient
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: AccessibilityUtils.scaledSpacing(2)) {
                Text(ingredient.name)
                    .font(.body)
                    .foregroundColor(AccessibilityUtils.contrastAwareText())
                    .dynamicTypeSize(maxSize: .accessibility2)
                Text(ingredient.formattedQuantity)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .dynamicTypeSize(maxSize: .accessibility2)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: AccessibilityUtils.scaledSpacing(2)) {
                Text("\(String(format: "%.0f", ingredient.calories)) kcal")
                    .font(.caption)
                    .fontWeight(.medium)
                    .dynamicTypeSize(maxSize: .accessibility2)
                HStack(spacing: 4) {
                    Text("P: \(String(format: "%.1f", ingredient.protein))g")
                    Text("C: \(String(format: "%.1f", ingredient.carbohydrates))g")
                    Text("F: \(String(format: "%.1f", ingredient.fat))g")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .dynamicTypeSize(maxSize: .accessibility2)
            }
            
            Button(action: {
                onDelete()
                AccessibilityUtils.selectionFeedback()
            }) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(
                        AccessibilityUtils.contrastAwareColor(
                            normal: .red,
                            highContrast: Color.red
                        )
                    )
            }
            .accessibilityLabel("Remove \(ingredient.name)")
            .accessibilityHint("Double tap to remove this ingredient from the recipe")
            .keyboardNavigationSupport()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    // Create a simple mock repository for preview
    struct MockFuelLogRepository: FuelLogRepositoryProtocol {
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
    
    return NavigationStack {
        CustomFoodCreationView(repository: MockFuelLogRepository())
    }
}