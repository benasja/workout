import SwiftUI

// MARK: - Barcode Result View

struct BarcodeResultView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BarcodeResultViewModel()
    
    let foodResult: FoodSearchResult
    let barcode: String
    let onFoodLogged: (FoodLog) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Product Header
                    ProductHeaderView(foodResult: foodResult)
                    
                    // Nutrition Information
                    NutritionInfoView(foodResult: foodResult, servingMultiplier: viewModel.servingMultiplier)
                    
                    // Serving Size Adjustment
                    ServingSizeAdjustmentView(
                        foodResult: foodResult,
                        servingMultiplier: $viewModel.servingMultiplier
                    )
                    
                    // Meal Type Selection
                    MealTypeSelectionView(selectedMealType: $viewModel.selectedMealType)
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Confirm Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Food") {
                        addFood()
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.isLogging)
                }
            }
            .alert("Error", isPresented: $viewModel.showErrorAlert) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    private func addFood() {
        // Validate serving multiplier
        guard viewModel.servingMultiplier > 0 else {
            viewModel.errorMessage = "Serving size must be greater than zero"
            viewModel.showErrorAlert = true
            return
        }
        
        viewModel.isLogging = true
        
        let foodLog = foodResult.createFoodLog(
            mealType: viewModel.selectedMealType,
            servingMultiplier: viewModel.servingMultiplier,
            barcode: barcode
        )
        
        onFoodLogged(foodLog)
        dismiss()
    }
}

// MARK: - Product Header View

struct ProductHeaderView: View {
    let foodResult: FoodSearchResult
    
    var body: some View {
        VStack(spacing: 16) {
            // Product Image Placeholder
            AsyncImage(url: foodResult.imageUrl.flatMap(URL.init)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    }
            }
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Product Name and Brand
            VStack(spacing: 4) {
                Text(foodResult.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                if let brand = foodResult.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Nutrition Info View

struct NutritionInfoView: View {
    let foodResult: FoodSearchResult
    let servingMultiplier: Double
    
    private var adjustedCalories: Double {
        foodResult.calories * servingMultiplier
    }
    
    private var adjustedProtein: Double {
        foodResult.protein * servingMultiplier
    }
    
    private var adjustedCarbs: Double {
        foodResult.carbohydrates * servingMultiplier
    }
    
    private var adjustedFat: Double {
        foodResult.fat * servingMultiplier
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Nutrition Information")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Calories
            NutritionRowView(
                title: "Calories",
                value: String(format: "%.0f", adjustedCalories),
                unit: "kcal",
                color: .orange
            )
            
            Divider()
            
            // Macronutrients
            VStack(spacing: 12) {
                NutritionRowView(
                    title: "Protein",
                    value: String(format: "%.1f", adjustedProtein),
                    unit: "g",
                    color: .blue
                )
                
                NutritionRowView(
                    title: "Carbohydrates",
                    value: String(format: "%.1f", adjustedCarbs),
                    unit: "g",
                    color: .green
                )
                
                NutritionRowView(
                    title: "Fat",
                    value: String(format: "%.1f", adjustedFat),
                    unit: "g",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Nutrition Row View

struct NutritionRowView: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(title)
                    .font(.body)
            }
            
            Spacer()
            
            Text("\(value) \(unit)")
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Serving Size Adjustment View

struct ServingSizeAdjustmentView: View {
    let foodResult: FoodSearchResult
    @Binding var servingMultiplier: Double
    
    private var adjustedServingSize: Double {
        foodResult.servingSize * servingMultiplier
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Serving Size")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                // Current serving display
                HStack {
                    Text("Amount:")
                    Spacer()
                    Text(String(format: "%.1f %@", adjustedServingSize, foodResult.servingUnit))
                        .fontWeight(.medium)
                }
                
                // Multiplier slider
                VStack(spacing: 8) {
                    HStack {
                        Text("Servings:")
                        Spacer()
                        Text(String(format: "%.1fx", servingMultiplier))
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    Slider(value: $servingMultiplier, in: 0.1...5.0, step: 0.1) {
                        Text("Serving Multiplier")
                    }
                    .accentColor(.blue)
                }
                
                // Quick serving buttons
                HStack(spacing: 12) {
                    ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { multiplier in
                        Button(String(format: "%.1fx", multiplier)) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                servingMultiplier = multiplier
                            }
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(servingMultiplier == multiplier ? .white : .blue)
                        .background(servingMultiplier == multiplier ? Color.blue : Color.clear)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Meal Type Selection View

struct MealTypeSelectionView: View {
    @Binding var selectedMealType: MealType
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Meal Type")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Meal Type Button (Using shared component from SharedComponents.swift)

// MARK: - Barcode Result ViewModel

@MainActor
final class BarcodeResultViewModel: ObservableObject {
    @Published var servingMultiplier: Double = 1.0
    @Published var selectedMealType: MealType = .breakfast
    @Published var isLogging: Bool = false
    @Published var showErrorAlert: Bool = false
    @Published var errorMessage: String = ""
    
    init() {
        // Set default meal type based on current time
        selectedMealType = defaultMealTypeForCurrentTime()
    }
    
    private func defaultMealTypeForCurrentTime() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<11:
            return .breakfast
        case 11..<16:
            return .lunch
        case 16..<22:
            return .dinner
        default:
            return .snacks
        }
    }
}

// MARK: - Preview

#Preview {
    BarcodeResultView(
        foodResult: FoodSearchResult(
            id: "123",
            name: "Sample Product",
            brand: "Sample Brand",
            calories: 250,
            protein: 10,
            carbohydrates: 30,
            fat: 8,
            servingSize: 100,
            servingUnit: "g",
            imageUrl: nil,
            source: .openFoodFacts
        ),
        barcode: "1234567890123"
    ) { _ in
        print("Food logged")
    }
}