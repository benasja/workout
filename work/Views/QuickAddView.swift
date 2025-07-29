import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// View for quickly adding raw macronutrient values without associating them with a specific food item
struct QuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbohydrates: String = ""
    @State private var fat: String = ""
    @State private var selectedMealType: MealType = .breakfast
    @State private var showingValidationError = false
    @State private var validationErrorMessage = ""
    @State private var isLoading = false
    
    let onQuickAdd: (FoodLog) -> Void
    
    init(onQuickAdd: @escaping (FoodLog) -> Void) {
        self.onQuickAdd = onQuickAdd
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Header
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.accent)
                        
                        Text("Add New Meal")
                            .font(AppTypography.title2)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Create a custom meal with your own macronutrient values")
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, AppSpacing.lg)
                    
                    // Macro Input Form
                    VStack(spacing: AppSpacing.lg) {
                        // Calories Input
                        MacroInputField(
                            title: "Calories",
                            value: $calories,
                            unit: "kcal",
                            icon: "flame.fill",
                            color: AppColors.error
                        )
                        
                        // Protein Input
                        MacroInputField(
                            title: "Protein",
                            value: $protein,
                            unit: "g",
                            icon: "leaf.fill",
                            color: AppColors.success
                        )
                        
                        // Carbohydrates Input
                        MacroInputField(
                            title: "Carbohydrates",
                            value: $carbohydrates,
                            unit: "g",
                            icon: "grain.fill",
                            color: AppColors.warning
                        )
                        
                        // Fat Input
                        MacroInputField(
                            title: "Fat",
                            value: $fat,
                            unit: "g",
                            icon: "drop.fill",
                            color: AppColors.accent
                        )
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    
                    // Meal Type Selection
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Meal Type")
                            .font(AppTypography.headline)
                            .foregroundColor(AppColors.textPrimary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: AppSpacing.md) {
                            ForEach(MealType.allCases, id: \.self) { mealType in
                                MealTypeButton(
                                    mealType: mealType,
                                    isSelected: selectedMealType == mealType
                                ) {
                                    selectedMealType = mealType
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    
                    // Validation Summary
                    if hasValidInput {
                        ValidationSummaryCard(
                            calories: caloriesValue,
                            protein: proteinValue,
                            carbohydrates: carbohydratesValue,
                            fat: fatValue
                        )
                        .padding(.horizontal, AppSpacing.lg)
                    }
                    
                    Spacer(minLength: AppSpacing.xl)
                }
            }
            .navigationTitle("Add New Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addQuickEntry()
                    }
                    .disabled(!canAdd || isLoading)
                    .fontWeight(.semibold)
                }
            }
            .alert("Validation Error", isPresented: $showingValidationError) {
                Button("OK") { }
            } message: {
                Text(validationErrorMessage)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var caloriesValue: Double {
        Double(calories) ?? 0
    }
    
    private var proteinValue: Double {
        Double(protein) ?? 0
    }
    
    private var carbohydratesValue: Double {
        Double(carbohydrates) ?? 0
    }
    
    private var fatValue: Double {
        Double(fat) ?? 0
    }
    
    private var calculatedMacroCalories: Double {
        (proteinValue * 4) + (carbohydratesValue * 4) + (fatValue * 9)
    }
    
    private var hasValidInput: Bool {
        caloriesValue > 0 || proteinValue > 0 || carbohydratesValue > 0 || fatValue > 0
    }
    
    private var canAdd: Bool {
        hasValidInput && isValidMacroDistribution
    }
    
    private var isValidMacroDistribution: Bool {
        // If calories are provided, validate macro-to-calorie consistency
        if caloriesValue > 0 {
            let difference = abs(caloriesValue - calculatedMacroCalories)
            let percentDifference = difference / caloriesValue
            return percentDifference <= 0.15 // Allow 15% variance for quick add
        }
        
        // If no calories provided, just ensure at least one macro is entered
        return proteinValue > 0 || carbohydratesValue > 0 || fatValue > 0
    }
    
    // MARK: - Actions
    
    private func addQuickEntry() {
        guard canAdd else { return }
        
        isLoading = true
        
        // Validate input
        guard validateInput() else {
            isLoading = false
            return
        }
        
        // Use calculated calories if not provided
        let finalCalories = caloriesValue > 0 ? caloriesValue : calculatedMacroCalories
        
        // Create quick add food log entry
        let quickAddEntry = FoodLog(
            timestamp: Date(),
            name: "Quick Add - \(selectedMealType.displayName)",
            calories: finalCalories,
            protein: proteinValue,
            carbohydrates: carbohydratesValue,
            fat: fatValue,
            mealType: selectedMealType,
            servingSize: 1.0,
            servingUnit: "entry"
        )
        
        // Call completion handler
        onQuickAdd(quickAddEntry)
        
        // Provide haptic feedback and accessibility announcement
        AccessibilityUtils.announceFoodLogged("Quick add entry")
        
        dismiss()
    }
    
    private func validateInput() -> Bool {
        // Check for negative values
        if caloriesValue < 0 || proteinValue < 0 || carbohydratesValue < 0 || fatValue < 0 {
            showValidationError("All values must be non-negative")
            return false
        }
        
        // Check for reasonable upper limits
        if caloriesValue > 5000 {
            showValidationError("Calories seem unusually high (over 5000)")
            return false
        }
        
        if proteinValue > 500 || carbohydratesValue > 500 || fatValue > 200 {
            showValidationError("Macro values seem unusually high")
            return false
        }
        
        // Check macro-to-calorie consistency if both are provided
        if caloriesValue > 0 && calculatedMacroCalories > 0 {
            let difference = abs(caloriesValue - calculatedMacroCalories)
            let percentDifference = difference / caloriesValue
            
            if percentDifference > 0.15 {
                showValidationError("Calorie and macro values don't align. Calculated calories from macros: \(Int(calculatedMacroCalories))")
                return false
            }
        }
        
        return true
    }
    
    private func showValidationError(_ message: String) {
        validationErrorMessage = message
        showingValidationError = true
    }
}

// MARK: - Supporting Views

struct MacroInputField: View {
    let title: String
    @Binding var value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: AccessibilityUtils.scaledSpacing(AppSpacing.sm)) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                    .accessibilityHidden(true)
                
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundColor(AccessibilityUtils.contrastAwareText())
                    .dynamicTypeSize(maxSize: .accessibility2)
                
                Spacer()
                
                Text(unit)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .dynamicTypeSize(maxSize: .accessibility2)
            }
            
            TextField("0", text: $value)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.body)
                .dynamicTypeSize(maxSize: .accessibility2)
                .accessibilityLabel("\(title) in \(unit)")
                .accessibilityHint("Enter \(title.lowercased()) value")
                .accessibilityIdentifier(accessibilityIdentifier)
        }
        .padding(AppSpacing.md)
        .background(AccessibilityUtils.contrastAwareBackground())
        .cornerRadius(AppCornerRadius.md)
    }
    
    private var accessibilityIdentifier: String {
        switch title.lowercased() {
        case "calories":
            return AccessibilityIdentifiers.caloriesField
        case "protein":
            return AccessibilityIdentifiers.proteinField
        case "carbohydrates":
            return AccessibilityIdentifiers.carbsField
        case "fat":
            return AccessibilityIdentifiers.fatField
        default:
            return "fuel_log_\(title.lowercased())_field"
        }
    }
}

// MealTypeButton is now defined in SharedComponents.swift

struct ValidationSummaryCard: View {
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    
    private var calculatedCalories: Double {
        (protein * 4) + (carbohydrates * 4) + (fat * 9)
    }
    
    private var isConsistent: Bool {
        if calories > 0 {
            let difference = abs(calories - calculatedCalories)
            let percentDifference = difference / calories
            return percentDifference <= 0.15
        }
        return true
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Image(systemName: isConsistent ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(isConsistent ? AppColors.success : AppColors.warning)
                
                Text("Validation Summary")
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if calories > 0 {
                    HStack {
                        Text("Entered Calories:")
                        Spacer()
                        Text("\(Int(calories)) kcal")
                            .fontWeight(.semibold)
                    }
                }
                
                HStack {
                    Text("Calculated from Macros:")
                    Spacer()
                    Text("\(Int(calculatedCalories)) kcal")
                        .fontWeight(.semibold)
                }
                
                if calories > 0 && !isConsistent {
                    Text("⚠️ Calorie and macro values don't align closely")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.warning)
                }
            }
            .font(AppTypography.subheadline)
            .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.secondaryBackground)
        .cornerRadius(AppCornerRadius.md)
    }
}

#Preview {
    QuickAddView { foodLog in
        print("Quick add: \(foodLog.name)")
    }
}

// MARK: - Quick Edit View

/// View for editing existing quick add entries
struct QuickEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var calories: String
    @State private var protein: String
    @State private var carbohydrates: String
    @State private var fat: String
    @State private var selectedMealType: MealType
    @State private var showingValidationError = false
    @State private var validationErrorMessage = ""
    @State private var isLoading = false
    
    let originalFoodLog: FoodLog
    let onUpdate: (FoodLog) -> Void
    
    init(foodLog: FoodLog, onUpdate: @escaping (FoodLog) -> Void) {
        self.originalFoodLog = foodLog
        self.onUpdate = onUpdate
        
        // Initialize with existing values
        _calories = State(initialValue: foodLog.calories > 0 ? String(Int(foodLog.calories)) : "")
        _protein = State(initialValue: foodLog.protein > 0 ? String(Int(foodLog.protein)) : "")
        _carbohydrates = State(initialValue: foodLog.carbohydrates > 0 ? String(Int(foodLog.carbohydrates)) : "")
        _fat = State(initialValue: foodLog.fat > 0 ? String(Int(foodLog.fat)) : "")
        _selectedMealType = State(initialValue: foodLog.mealType)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Header
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.primary)
                        
                        Text("Edit Quick Add")
                            .font(AppTypography.title2)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Update your macronutrient values")
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, AppSpacing.lg)
                    
                    // Macro Input Form
                    VStack(spacing: AppSpacing.lg) {
                        // Calories Input
                        MacroInputField(
                            title: "Calories",
                            value: $calories,
                            unit: "kcal",
                            icon: "flame.fill",
                            color: AppColors.error
                        )
                        
                        // Protein Input
                        MacroInputField(
                            title: "Protein",
                            value: $protein,
                            unit: "g",
                            icon: "leaf.fill",
                            color: AppColors.success
                        )
                        
                        // Carbohydrates Input
                        MacroInputField(
                            title: "Carbohydrates",
                            value: $carbohydrates,
                            unit: "g",
                            icon: "grain.fill",
                            color: AppColors.warning
                        )
                        
                        // Fat Input
                        MacroInputField(
                            title: "Fat",
                            value: $fat,
                            unit: "g",
                            icon: "drop.fill",
                            color: AppColors.accent
                        )
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    
                    // Meal Type Selection
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Meal Type")
                            .font(AppTypography.headline)
                            .foregroundColor(AppColors.textPrimary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: AppSpacing.md) {
                            ForEach(MealType.allCases, id: \.self) { mealType in
                                MealTypeButton(
                                    mealType: mealType,
                                    isSelected: selectedMealType == mealType
                                ) {
                                    selectedMealType = mealType
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    
                    // Validation Summary
                    if hasValidInput {
                        ValidationSummaryCard(
                            calories: caloriesValue,
                            protein: proteinValue,
                            carbohydrates: carbohydratesValue,
                            fat: fatValue
                        )
                        .padding(.horizontal, AppSpacing.lg)
                    }
                    
                    Spacer(minLength: AppSpacing.xl)
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Update") {
                        updateEntry()
                    }
                    .disabled(!canUpdate || isLoading)
                    .fontWeight(.semibold)
                }
            }
            .alert("Validation Error", isPresented: $showingValidationError) {
                Button("OK") { }
            } message: {
                Text(validationErrorMessage)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var caloriesValue: Double {
        Double(calories) ?? 0
    }
    
    private var proteinValue: Double {
        Double(protein) ?? 0
    }
    
    private var carbohydratesValue: Double {
        Double(carbohydrates) ?? 0
    }
    
    private var fatValue: Double {
        Double(fat) ?? 0
    }
    
    private var calculatedMacroCalories: Double {
        (proteinValue * 4) + (carbohydratesValue * 4) + (fatValue * 9)
    }
    
    private var hasValidInput: Bool {
        caloriesValue > 0 || proteinValue > 0 || carbohydratesValue > 0 || fatValue > 0
    }
    
    private var canUpdate: Bool {
        hasValidInput && isValidMacroDistribution && hasChanges
    }
    
    private var hasChanges: Bool {
        caloriesValue != originalFoodLog.calories ||
        proteinValue != originalFoodLog.protein ||
        carbohydratesValue != originalFoodLog.carbohydrates ||
        fatValue != originalFoodLog.fat ||
        selectedMealType != originalFoodLog.mealType
    }
    
    private var isValidMacroDistribution: Bool {
        // If calories are provided, validate macro-to-calorie consistency
        if caloriesValue > 0 {
            let difference = abs(caloriesValue - calculatedMacroCalories)
            let percentDifference = difference / caloriesValue
            return percentDifference <= 0.15 // Allow 15% variance for quick add
        }
        
        // If no calories provided, just ensure at least one macro is entered
        return proteinValue > 0 || carbohydratesValue > 0 || fatValue > 0
    }
    
    // MARK: - Actions
    
    private func updateEntry() {
        guard canUpdate else { return }
        
        isLoading = true
        
        // Validate input
        guard validateInput() else {
            isLoading = false
            return
        }
        
        // Use calculated calories if not provided
        let finalCalories = caloriesValue > 0 ? caloriesValue : calculatedMacroCalories
        
        // Create updated food log entry
        let updatedEntry = FoodLog(
            timestamp: originalFoodLog.timestamp,
            name: "Quick Add - \(selectedMealType.displayName)",
            calories: finalCalories,
            protein: proteinValue,
            carbohydrates: carbohydratesValue,
            fat: fatValue,
            mealType: selectedMealType,
            servingSize: 1.0,
            servingUnit: "entry"
        )
        
        // Call completion handler
        onUpdate(updatedEntry)
        
        // Provide haptic feedback and accessibility announcement
        AccessibilityUtils.announce("Quick add entry updated")
        AccessibilityUtils.successFeedback()
        
        dismiss()
    }
    
    private func validateInput() -> Bool {
        // Check for negative values
        if caloriesValue < 0 || proteinValue < 0 || carbohydratesValue < 0 || fatValue < 0 {
            showValidationError("All values must be non-negative")
            return false
        }
        
        // Check for reasonable upper limits
        if caloriesValue > 5000 {
            showValidationError("Calories seem unusually high (over 5000)")
            return false
        }
        
        if proteinValue > 500 || carbohydratesValue > 500 || fatValue > 200 {
            showValidationError("Macro values seem unusually high")
            return false
        }
        
        // Check macro-to-calorie consistency if both are provided
        if caloriesValue > 0 && calculatedMacroCalories > 0 {
            let difference = abs(caloriesValue - calculatedMacroCalories)
            let percentDifference = difference / caloriesValue
            
            if percentDifference > 0.15 {
                showValidationError("Calorie and macro values don't align. Calculated calories from macros: \(Int(calculatedMacroCalories))")
                return false
            }
        }
        
        return true
    }
    
    private func showValidationError(_ message: String) {
        validationErrorMessage = message
        showingValidationError = true
    }
}

#Preview {
    let sampleFoodLog = FoodLog(
        name: "Quick Add - Breakfast",
        calories: 300,
        protein: 20,
        carbohydrates: 30,
        fat: 10,
        mealType: .breakfast
    )
    
    return QuickEditView(foodLog: sampleFoodLog) { updatedFoodLog in
        print("Updated: \(updatedFoodLog.name)")
    }
}