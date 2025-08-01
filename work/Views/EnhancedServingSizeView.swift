import SwiftUI

/// Enhanced serving size adjustment view with better UX for different food types
struct EnhancedServingSizeView: View {
    let foodName: String
    let baseCalories: Double
    let baseProtein: Double
    let baseCarbs: Double
    let baseFat: Double
    let baseServingSize: Double
    let baseServingUnit: String
    
    @Binding var selectedQuantity: Double
    @Binding var selectedUnit: String
    
    @State private var showingCustomUnit = false
    @State private var customUnit = ""
    
    // Smart unit suggestions based on food type and base unit
    private var suggestedUnits: [ServingUnit] {
        let baseUnit = baseServingUnit.lowercased()
        
        // Weight-based foods
        if baseUnit.contains("g") || baseUnit.contains("gram") || baseUnit.contains("kg") {
            return [
                ServingUnit(name: "g", multiplier: 1.0, category: .weight),
                ServingUnit(name: "kg", multiplier: 1000.0, category: .weight),
                ServingUnit(name: "oz", multiplier: 28.35, category: .weight),
                ServingUnit(name: "lb", multiplier: 453.6, category: .weight)
            ]
        }
        
        // Volume-based foods
        if baseUnit.contains("ml") || baseUnit.contains("l") || baseUnit.contains("cup") {
            return [
                ServingUnit(name: "ml", multiplier: 1.0, category: .volume),
                ServingUnit(name: "l", multiplier: 1000.0, category: .volume),
                ServingUnit(name: "cup", multiplier: 240.0, category: .volume),
                ServingUnit(name: "tbsp", multiplier: 15.0, category: .volume),
                ServingUnit(name: "tsp", multiplier: 5.0, category: .volume)
            ]
        }
        
        // Count-based foods
        return [
            ServingUnit(name: "piece", multiplier: 1.0, category: .count),
            ServingUnit(name: "slice", multiplier: 1.0, category: .count),
            ServingUnit(name: "serving", multiplier: 1.0, category: .count),
            ServingUnit(name: "portion", multiplier: 1.0, category: .count)
        ]
    }
    
    private var currentMultiplier: Double {
        if let unit = suggestedUnits.first(where: { $0.name == selectedUnit }) {
            return selectedQuantity * unit.multiplier / baseServingSize
        }
        return selectedQuantity / baseServingSize
    }
    
    private var adjustedNutrition: (calories: Double, protein: Double, carbs: Double, fat: Double) {
        let multiplier = currentMultiplier
        return (
            calories: baseCalories * multiplier,
            protein: baseProtein * multiplier,
            carbs: baseCarbs * multiplier,
            fat: baseFat * multiplier
        )
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Food info header
            foodInfoHeader
            
            // Quantity input
            quantitySection
            
            // Unit selection
            unitSelectionSection
            
            // Nutrition preview
            nutritionPreviewSection
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - View Components
    
    private var foodInfoHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(foodName)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Base: \(formattedBaseServing)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var quantitySection: some View {
        HStack {
            Text("Amount:")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { adjustQuantity(-0.5) }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .disabled(selectedQuantity <= 0.5)
                
                TextField("Amount", value: $selectedQuantity, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.center)
                
                Button(action: { adjustQuantity(0.5) }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    private var unitSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unit:")
                .font(.subheadline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(suggestedUnits, id: \.name) { unit in
                    Button(action: {
                        selectedUnit = unit.name
                        showingCustomUnit = false
                    }) {
                        Text(unit.name)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedUnit == unit.name && !showingCustomUnit ? Color.blue : Color(.systemGray5))
                            .foregroundColor(selectedUnit == unit.name && !showingCustomUnit ? .white : .primary)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Toggle("Custom unit", isOn: $showingCustomUnit)
                .font(.caption)
                .onChange(of: showingCustomUnit) { _, isOn in
                    if !isOn {
                        customUnit = ""
                        if suggestedUnits.first != nil {
                            selectedUnit = suggestedUnits.first!.name
                        }
                    }
                }
            
            if showingCustomUnit {
                TextField("Enter custom unit", text: $customUnit)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: customUnit) { _, newValue in
                        selectedUnit = newValue
                    }
            }
        }
    }
    
    private var nutritionPreviewSection: some View {
        VStack(spacing: 12) {
            Text("Nutrition for \(formattedSelectedServing)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                NutritionPreviewCard(
                    label: "Calories",
                    value: adjustedNutrition.calories,
                    unit: "kcal",
                    color: .orange
                )
                
                NutritionPreviewCard(
                    label: "Protein",
                    value: adjustedNutrition.protein,
                    unit: "g",
                    color: .blue
                )
            }
            
            HStack(spacing: 12) {
                NutritionPreviewCard(
                    label: "Carbs",
                    value: adjustedNutrition.carbs,
                    unit: "g",
                    color: .green
                )
                
                NutritionPreviewCard(
                    label: "Fat",
                    value: adjustedNutrition.fat,
                    unit: "g",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Methods
    
    private func adjustQuantity(_ delta: Double) {
        let newQuantity = selectedQuantity + delta
        if newQuantity > 0 {
            selectedQuantity = newQuantity
        }
    }
    
    private var formattedBaseServing: String {
        if baseServingSize.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(baseServingSize)) \(baseServingUnit)"
        } else {
            return String(format: "%.1f", baseServingSize) + " \(baseServingUnit)"
        }
    }
    
    private var formattedSelectedServing: String {
        if selectedQuantity.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(selectedQuantity)) \(selectedUnit)"
        } else {
            return String(format: "%.1f", selectedQuantity) + " \(selectedUnit)"
        }
    }
}

// MARK: - Supporting Types

struct ServingUnit {
    let name: String
    let multiplier: Double // Conversion factor to base unit
    let category: ServingCategory
}

enum ServingCategory {
    case weight
    case volume
    case count
}

// Note: NutritionPreviewCard is defined in PortionAdjustmentView.swift

// MARK: - Preview

#Preview {
    VStack {
        EnhancedServingSizeView(
            foodName: "Banana",
            baseCalories: 105,
            baseProtein: 1.3,
            baseCarbs: 27,
            baseFat: 0.4,
            baseServingSize: 1,
            baseServingUnit: "medium banana",
            selectedQuantity: .constant(1.0),
            selectedUnit: .constant("piece")
        )
        
        Spacer()
    }
    .padding()
}