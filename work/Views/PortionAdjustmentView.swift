import SwiftUI

struct PortionAdjustmentView: View {
    @Environment(\.dismiss) private var dismiss
    
    let food: IngredientSearchResult
    let onPortionConfirmed: (CustomFoodIngredient) -> Void
    
    @State private var quantity: Double = 1.0
    @State private var selectedUnit: String = ""
    @State private var customUnit: String = ""
    @State private var showingCustomUnit: Bool = false
    
    // Common units for different food types
    private let commonUnits = [
        "g", "kg", "oz", "lb",
        "ml", "l", "fl oz", "cup", "tbsp", "tsp",
        "piece", "slice", "serving", "portion"
    ]
    
    var adjustedCalories: Double {
        food.calories * quantity / food.servingSize
    }
    
    var adjustedProtein: Double {
        food.protein * quantity / food.servingSize
    }
    
    var adjustedCarbohydrates: Double {
        food.carbohydrates * quantity / food.servingSize
    }
    
    var adjustedFat: Double {
        food.fat * quantity / food.servingSize
    }
    
    var finalUnit: String {
        showingCustomUnit ? customUnit : selectedUnit
    }
    
    var isValid: Bool {
        quantity > 0 && !finalUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                foodInfoSection
                portionSection
                nutritionPreviewSection
            }
            .navigationTitle("Adjust Portion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addIngredient()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                selectedUnit = food.servingUnit
            }
        }
    }
    
    // MARK: - View Sections
    
    private var foodInfoSection: some View {
        Section("Food Information") {
            VStack(alignment: .leading, spacing: 8) {
                Text(food.name)
                    .font(.headline)
                
                Text("Base serving: \(food.formattedServing)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    NutritionBadge(label: "Cal", value: food.calories, unit: "")
                    NutritionBadge(label: "P", value: food.protein, unit: "g")
                    NutritionBadge(label: "C", value: food.carbohydrates, unit: "g")
                    NutritionBadge(label: "F", value: food.fat, unit: "g")
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var portionSection: some View {
        Section("Portion Size") {
            HStack {
                Text("Quantity")
                Spacer()
                TextField("1.0", value: $quantity, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Unit")
                    .font(.headline)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(commonUnits, id: \.self) { unit in
                        Button(action: {
                            selectedUnit = unit
                            showingCustomUnit = false
                        }) {
                            Text(unit)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedUnit == unit && !showingCustomUnit ? Color.blue : Color(.systemGray5))
                                .foregroundColor(selectedUnit == unit && !showingCustomUnit ? .white : .primary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Toggle("Custom Unit", isOn: $showingCustomUnit)
                    .onChange(of: showingCustomUnit) { _, isOn in
                        if isOn {
                            selectedUnit = ""
                        } else {
                            customUnit = ""
                        }
                    }
                
                if showingCustomUnit {
                    TextField("Enter custom unit", text: $customUnit)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }
    
    private var nutritionPreviewSection: some View {
        Section("Nutrition Preview") {
            VStack(spacing: 12) {
                Text("For \(formattedQuantity)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    NutritionPreviewCard(label: "Calories", value: adjustedCalories, unit: "kcal", color: .orange)
                    NutritionPreviewCard(label: "Protein", value: adjustedProtein, unit: "g", color: .blue)
                }
                
                HStack {
                    NutritionPreviewCard(label: "Carbs", value: adjustedCarbohydrates, unit: "g", color: .green)
                    NutritionPreviewCard(label: "Fat", value: adjustedFat, unit: "g", color: .purple)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var formattedQuantity: String {
        let unit = finalUnit
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(quantity)) \(unit)"
        } else {
            return String(format: "%.1f", quantity) + " \(unit)"
        }
    }
    
    // MARK: - Actions
    
    private func addIngredient() {
        let ingredient = CustomFoodIngredient(
            name: food.name,
            quantity: quantity,
            unit: finalUnit.trimmingCharacters(in: .whitespacesAndNewlines),
            calories: adjustedCalories,
            protein: adjustedProtein,
            carbohydrates: adjustedCarbohydrates,
            fat: adjustedFat
        )
        
        onPortionConfirmed(ingredient)
        dismiss()
    }
}

// MARK: - Supporting Views

struct NutritionBadge: View {
    let label: String
    let value: Double
    let unit: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(String(format: "%.0f", value))\(unit)")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
}

struct NutritionPreviewCard: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(String(format: "%.1f", value))")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    let sampleFood = IngredientSearchResult(
        name: "Chicken Breast",
        calories: 165,
        protein: 31,
        carbohydrates: 0,
        fat: 3.6,
        servingSize: 100,
        servingUnit: "g"
    )
    
    PortionAdjustmentView(food: sampleFood) { _ in }
}