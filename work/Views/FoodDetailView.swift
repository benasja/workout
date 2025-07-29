import SwiftUI
import SwiftData

// MARK: - Food Detail View

struct FoodDetailView: View {
    let foodResult: FoodSearchResult
    let onConfirm: (FoodLog) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMealType: MealType = .breakfast
    @State private var servingMultiplier: Double = 1.0
    @State private var showingMealTypePicker = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Food Header
                    foodHeader
                    
                    // Serving Size Adjustment
                    servingSizeSection
                    
                    // Nutrition Information
                    nutritionSection
                    
                    // Meal Type Selection
                    mealTypeSection
                }
                .padding()
            }
            .navigationTitle("Food Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add to Log") {
                        let foodLog = createFoodLog()
                        onConfirm(foodLog)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Food Header
    
    private var foodHeader: some View {
        VStack(spacing: 12) {
            // Food image placeholder or icon
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary)
                }
            
            VStack(spacing: 4) {
                Text(foodResult.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                if let brand = foodResult.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    if foodResult.source == .custom {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("Custom Food")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "globe")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("Food Database")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Serving Size Section
    
    private var servingSizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Serving Size")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                HStack {
                    Text("Amount:")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            if servingMultiplier > 0.25 {
                                servingMultiplier = max(0.25, servingMultiplier - 0.25)
                                AccessibilityUtils.selectionFeedback()
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .disabled(servingMultiplier <= 0.25)
                        .accessibilityLabel("Decrease serving size")
                        .accessibilityHint(AccessibilityUtils.adjustServingHint)
                        
                        Text(servingMultiplierDisplay)
                            .font(.title3)
                            .fontWeight(.medium)
                            .frame(minWidth: 60)
                            .dynamicTypeSize(maxSize: .accessibility2)
                            .accessibilityLabel("Serving multiplier: \(servingMultiplierDisplay)")
                        
                        Button(action: {
                            servingMultiplier = min(10.0, servingMultiplier + 0.25)
                            AccessibilityUtils.selectionFeedback()
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .disabled(servingMultiplier >= 10.0)
                        .accessibilityLabel("Increase serving size")
                        .accessibilityHint(AccessibilityUtils.adjustServingHint)
                    }
                }
                
                HStack {
                    Text("Equals:")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(adjustedServingDescription)
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                // Quick serving buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { multiplier in
                            Button(action: {
                                servingMultiplier = multiplier
                                AccessibilityUtils.selectionFeedback()
                            }) {
                                Text(multiplier == 1.0 ? "1 serving" : "\(multiplier, specifier: "%.1f")x")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(servingMultiplier == multiplier ? .white : .blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(servingMultiplier == multiplier ? Color.blue : Color.blue.opacity(0.1))
                                    )
                                    .dynamicTypeSize(maxSize: .accessibility2)
                            }
                            .accessibilityLabel("Set serving to \(multiplier == 1.0 ? "1 serving" : "\(multiplier, specifier: "%.1f") times")")
                            .accessibilityAddTraits(servingMultiplier == multiplier ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Nutrition Section
    
    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrition Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 0) {
                // Calories
                nutritionRow(
                    title: "Calories",
                    value: adjustedCalories,
                    unit: "cal",
                    color: .orange,
                    isMain: true
                )
                
                Divider()
                
                // Protein
                nutritionRow(
                    title: "Protein",
                    value: adjustedProtein,
                    unit: "g",
                    color: .red
                )
                
                Divider()
                
                // Carbohydrates
                nutritionRow(
                    title: "Carbohydrates",
                    value: adjustedCarbohydrates,
                    unit: "g",
                    color: .green
                )
                
                Divider()
                
                // Fat
                nutritionRow(
                    title: "Fat",
                    value: adjustedFat,
                    unit: "g",
                    color: .purple
                )
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }
    
    private func nutritionRow(
        title: String,
        value: Double,
        unit: String,
        color: Color,
        isMain: Bool = false
    ) -> some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(title)
                    .font(isMain ? .body : .body)
                    .fontWeight(isMain ? .semibold : .medium)
            }
            
            Spacer()
            
            Text("\(value, specifier: "%.1f") \(unit)")
                .font(isMain ? .body : .body)
                .fontWeight(isMain ? .bold : .medium)
                .foregroundColor(isMain ? color : .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Meal Type Section
    
    private var mealTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add to Meal")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MealType.allCases, id: \.self) { mealType in
                        Button(action: {
                            selectedMealType = mealType
                            AccessibilityUtils.selectionFeedback()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: mealType.icon)
                                    .font(.body)
                                    .accessibilityHidden(true)
                                
                                Text(mealType.displayName)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .dynamicTypeSize(maxSize: .accessibility2)
                            }
                            .foregroundColor(selectedMealType == mealType ? .white : AccessibilityUtils.contrastAwareText())
                            .padding(.horizontal, AccessibilityUtils.scaledSpacing(16))
                            .padding(.vertical, AccessibilityUtils.scaledSpacing(10))
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedMealType == mealType ? 
                                          AccessibilityUtils.contrastAwareColor(normal: Color.blue, highContrast: Color.blue) : 
                                          AccessibilityUtils.contrastAwareBackground())
                            )
                        }
                        .accessibilityLabel(mealType.displayName)
                        .accessibilityHint(AccessibilityUtils.selectMealTypeHint)
                        .accessibilityAddTraits(selectedMealType == mealType ? .isSelected : [])
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var adjustedServingDescription: String {
        let adjustedSize = foodResult.servingSize * servingMultiplier
        
        // For serving-based foods (like "1 medium banana"), show whole numbers
        if foodResult.servingUnit.contains("banana") || 
           foodResult.servingUnit.contains("apple") || 
           foodResult.servingUnit.contains("orange") ||
           foodResult.servingUnit.contains("egg") ||
           foodResult.servingUnit.contains("slice") ||
           foodResult.servingUnit.contains("cup") {
            
            if adjustedSize == 1.0 {
                return "1 \(foodResult.servingUnit)"
            } else if adjustedSize.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(adjustedSize)) \(foodResult.servingUnit)"
            } else {
                return String(format: "%.1f", adjustedSize) + " \(foodResult.servingUnit)"
            }
        } else {
            // For weight-based foods, show the actual weight
            return String(format: "%.0f", adjustedSize) + " \(foodResult.servingUnit)"
        }
    }
    
    private var adjustedCalories: Double {
        foodResult.calories * servingMultiplier
    }
    
    private var adjustedProtein: Double {
        foodResult.protein * servingMultiplier
    }
    
    private var adjustedCarbohydrates: Double {
        foodResult.carbohydrates * servingMultiplier
    }
    
    private var adjustedFat: Double {
        foodResult.fat * servingMultiplier
    }
    
    private var servingMultiplierDisplay: String {
        if servingMultiplier.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(servingMultiplier))"
        } else {
            return String(format: "%.1f", servingMultiplier)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createFoodLog() -> FoodLog {
        return foodResult.createFoodLog(
            mealType: selectedMealType,
            servingMultiplier: servingMultiplier
        )
    }
}

// MARK: - Preview

#Preview {
    FoodDetailView(
        foodResult: FoodSearchResult(
            id: "1",
            name: "Chicken Breast",
            brand: "Fresh Market",
            calories: 165,
            protein: 31,
            carbohydrates: 0,
            fat: 3.6,
            servingSize: 100,
            servingUnit: "g",
            imageUrl: nil,
            source: .openFoodFacts
        )
    ) { foodLog in
        print("Confirmed: \(foodLog.name)")
    }
}