import SwiftUI
import SwiftData

// MARK: - Food Detail View

struct FoodDetailView: View {
    let foodResult: FoodSearchResult
    let selectedDate: Date
    let nutritionGoals: NutritionGoals?
    let onConfirm: (FoodLog) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMealType: MealType
    @State private var servingMultiplier: Double = 1.0
    @State private var showingMealTypePicker = false
    @State private var servingText: String = "1"
    @State private var isEditingServing = false
    @FocusState private var isServingFieldFocused: Bool
    
    init(foodResult: FoodSearchResult, selectedDate: Date, nutritionGoals: NutritionGoals? = nil, defaultMealType: MealType = .breakfast, onConfirm: @escaping (FoodLog) -> Void) {
        self.foodResult = foodResult
        self.selectedDate = selectedDate
        self.nutritionGoals = nutritionGoals
        self.onConfirm = onConfirm
        self._selectedMealType = State(initialValue: defaultMealType)
        self._servingText = State(initialValue: "1")
    }
    
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
                    Text("Number of servings:")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Editable text field for serving amount
                    TextField("Amount", text: $servingText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                        .multilineTextAlignment(.center)
                        .focused($isServingFieldFocused)
                        .onChange(of: servingText) { _, newValue in
                            // Convert European comma format to decimal
                            let normalizedValue = newValue.replacingOccurrences(of: ",", with: ".")
                            if let value = Double(normalizedValue), value > 0 {
                                servingMultiplier = min(value, 99.0)
                            }
                        }
                        .onChange(of: servingMultiplier) { _, newValue in
                            // Update text field when multiplier changes from other sources
                            let formatter = NumberFormatter()
                            formatter.decimalSeparator = ","
                            formatter.maximumFractionDigits = 1
                            servingText = formatter.string(from: NSNumber(value: newValue)) ?? "1"
                        }
                        .onTapGesture {
                            isServingFieldFocused = true
                        }
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    isServingFieldFocused = false
                                }
                            }
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
                            }
                            .accessibilityLabel("Set serving to \(multiplier == 1.0 ? "1 serving" : "\(multiplier, specifier: "%.1f") times")")
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
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(value)) \(unit)")
                    .font(isMain ? .body : .body)
                    .fontWeight(isMain ? .bold : .medium)
                    .foregroundColor(isMain ? color : .primary)
                
                if let goals = nutritionGoals {
                    let percentage = calculatePercentage(for: title, value: value, goals: goals)
                    if percentage > 0 {
                        Text("\(Int(percentage))% of daily intake")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func calculatePercentage(for nutrient: String, value: Double, goals: NutritionGoals) -> Double {
        switch nutrient {
        case "Calories":
            return (value / goals.dailyCalories) * 100
        case "Protein":
            return (value / goals.dailyProtein) * 100
        case "Carbohydrates":
            return (value / goals.dailyCarbohydrates) * 100
        case "Fat":
            return (value / goals.dailyFat) * 100
        default:
            return 0
        }
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
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: mealType.icon)
                                    .font(.body)
                                    .accessibilityHidden(true)
                                
                                Text(mealType.displayName)
                                    .font(.body)
                                    .fontWeight(.medium)
    
                            }
                            .foregroundColor(selectedMealType == mealType ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedMealType == mealType ? Color.blue : Color(.systemGray6))
                            )
                        }
                        .accessibilityLabel(mealType.displayName)
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
            servingMultiplier: servingMultiplier,
            timestamp: selectedDate
        )
    }
}

// MARK: - Food Edit View

struct FoodEditView: View {
    let foodLog: FoodLog
    let nutritionGoals: NutritionGoals?
    let onUpdate: (FoodLog) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var servingMultiplier: Double
    @State private var servingText: String
    @State private var selectedMealType: MealType
    @State private var isEditingServing = false
    @FocusState private var isServingFieldFocused: Bool
    
    init(foodLog: FoodLog, nutritionGoals: NutritionGoals? = nil, onUpdate: @escaping (FoodLog) -> Void) {
        self.foodLog = foodLog
        self.nutritionGoals = nutritionGoals
        self.onUpdate = onUpdate
        
        // The servingMultiplier represents the total number of servings
        // foodLog.servingSize already contains the total servings (e.g., 2 for 2 apples)
        self._servingMultiplier = State(initialValue: foodLog.servingSize)
        self._selectedMealType = State(initialValue: foodLog.mealType)
        
        // Initialize serving text with European comma formatting
        let formatter = NumberFormatter()
        formatter.decimalSeparator = ","
        formatter.maximumFractionDigits = 1
        self._servingText = State(initialValue: formatter.string(from: NSNumber(value: foodLog.servingSize)) ?? "1")
    }
    
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
            .navigationTitle("Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Update") {
                        let updatedFoodLog = createUpdatedFoodLog()
                        onUpdate(updatedFoodLog)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isServingFieldFocused = false
                    }
                }
            }
        }
    }
    
    // MARK: - Food Header
    
    private var foodHeader: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(foodLog.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 4) {
                    if foodLog.customFoodId != nil {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("Custom Food")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if foodLog.barcode != nil {
                        Image(systemName: "barcode")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("Scanned Food")
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
                    Text("Number of servings:")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Editable text field for serving amount
                    TextField("Amount", text: $servingText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                        .multilineTextAlignment(.center)
                        .focused($isServingFieldFocused)
                        .onChange(of: servingText) { _, newValue in
                            // Convert European comma format to decimal
                            let normalizedValue = newValue.replacingOccurrences(of: ",", with: ".")
                            if let value = Double(normalizedValue), value > 0 {
                                servingMultiplier = min(value, 99.0)
                            }
                        }
                        .onChange(of: servingMultiplier) { _, newValue in
                            // Update text field when multiplier changes from other sources
                            let formatter = NumberFormatter()
                            formatter.decimalSeparator = ","
                            formatter.maximumFractionDigits = 1
                            servingText = formatter.string(from: NSNumber(value: newValue)) ?? "1"
                        }
                        .onTapGesture {
                            isServingFieldFocused = true
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
                            }
                            .accessibilityLabel("Set serving to \(multiplier == 1.0 ? "1 serving" : "\(multiplier, specifier: "%.1f") times")")
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
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(value)) \(unit)")
                    .font(isMain ? .body : .body)
                    .fontWeight(isMain ? .bold : .medium)
                    .foregroundColor(isMain ? color : .primary)
                
                if let goals = nutritionGoals {
                    let percentage = calculatePercentage(for: title, value: value, goals: goals)
                    if percentage > 0 {
                        Text("\(Int(percentage))% of daily intake")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func calculatePercentage(for nutrient: String, value: Double, goals: NutritionGoals) -> Double {
        switch nutrient {
        case "Calories":
            return (value / goals.dailyCalories) * 100
        case "Protein":
            return (value / goals.dailyProtein) * 100
        case "Carbohydrates":
            return (value / goals.dailyCarbohydrates) * 100
        case "Fat":
            return (value / goals.dailyFat) * 100
        default:
            return 0
        }
    }
    
    // MARK: - Meal Type Section
    
    private var mealTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meal Type")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MealType.allCases, id: \.self) { mealType in
                        Button(action: {
                            selectedMealType = mealType
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: mealType.icon)
                                    .font(.body)
                                    .accessibilityHidden(true)
                                
                                Text(mealType.displayName)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(selectedMealType == mealType ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedMealType == mealType ? Color.blue : Color(.systemGray6))
                            )
                        }
                        .accessibilityLabel(mealType.displayName)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var adjustedServingDescription: String {
        let adjustedSize = servingMultiplier // servingMultiplier represents the total servings
        
        // For serving-based foods (like "1 medium banana"), show whole numbers
        if foodLog.servingUnit.contains("banana") || 
           foodLog.servingUnit.contains("apple") || 
           foodLog.servingUnit.contains("orange") ||
           foodLog.servingUnit.contains("egg") ||
           foodLog.servingUnit.contains("slice") ||
           foodLog.servingUnit.contains("cup") {
            
            if adjustedSize == 1.0 {
                return "1 \(foodLog.servingUnit)"
            } else if adjustedSize.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(adjustedSize)) \(foodLog.servingUnit)"
            } else {
                return String(format: "%.1f", adjustedSize) + " \(foodLog.servingUnit)"
            }
        } else {
            // For weight-based foods, show the actual weight
            return String(format: "%.0f", adjustedSize) + " \(foodLog.servingUnit)"
        }
    }
    
    private var adjustedCalories: Double {
        // Calculate base calories per serving, then multiply by current servings
        let baseCalories = foodLog.calories / foodLog.servingSize
        return baseCalories * servingMultiplier
    }
    
    private var adjustedProtein: Double {
        // Calculate base protein per serving, then multiply by current servings
        let baseProtein = foodLog.protein / foodLog.servingSize
        return baseProtein * servingMultiplier
    }
    
    private var adjustedCarbohydrates: Double {
        // Calculate base carbs per serving, then multiply by current servings
        let baseCarbs = foodLog.carbohydrates / foodLog.servingSize
        return baseCarbs * servingMultiplier
    }
    
    private var adjustedFat: Double {
        // Calculate base fat per serving, then multiply by current servings
        let baseFat = foodLog.fat / foodLog.servingSize
        return baseFat * servingMultiplier
    }
    
    // MARK: - Helper Methods
    
    private func createUpdatedFoodLog() -> FoodLog {
        var updatedFoodLog = foodLog
        updatedFoodLog.mealType = selectedMealType
        updatedFoodLog.servingSize = servingMultiplier // servingMultiplier represents the total servings
        updatedFoodLog.calories = adjustedCalories
        updatedFoodLog.protein = adjustedProtein
        updatedFoodLog.carbohydrates = adjustedCarbohydrates
        updatedFoodLog.fat = adjustedFat
        return updatedFoodLog
    }
}

// MARK: - Food Edit View Preview

#Preview("Food Edit View") {
    FoodEditView(
        foodLog: FoodLog(
            timestamp: Date(),
            name: "Banana",
            calories: 178, // 2 * 89 calories
            protein: 2,    // 2 * 1 protein
            carbohydrates: 46, // 2 * 23 carbs
            fat: 0,
            mealType: .breakfast,
            servingSize: 2, // 2 bananas
            servingUnit: "banana"
        ),
        nutritionGoals: NutritionGoals(
            dailyCalories: 2000,
            dailyProtein: 150,
            dailyCarbohydrates: 250,
            dailyFat: 67,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            bmr: 1500,
            tdee: 2325
        )
    ) { updatedFoodLog in
        print("Updated: \(updatedFoodLog.name)")
    }
}

// MARK: - Food Detail View Preview

#Preview("Food Detail View") {
    FoodDetailView(
        foodResult: FoodSearchResult(
            id: "1",
            name: "Chicken Breast",
            brand: "Fresh Market",
            calories: 165,
            protein: 31,
            carbohydrates: 0,
            fat: 4,
            servingSize: 100,
            servingUnit: "g",
            imageUrl: nil,
            source: .openFoodFacts
        ),
        selectedDate: Date(),
        nutritionGoals: NutritionGoals(
            dailyCalories: 2000,
            dailyProtein: 150,
            dailyCarbohydrates: 250,
            dailyFat: 67,
            activityLevel: .moderatelyActive,
            goal: .maintain,
            bmr: 1500,
            tdee: 2325
        )
    ) { foodLog in
        print("Confirmed: \(foodLog.name)")
    }
}