import SwiftUI
import SwiftData

struct ManualOverrideStepView: View {
    @ObservedObject var viewModel: NutritionGoalsViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 80))
                .foregroundColor(.indigo)
            
            // Title
            Text("Customize Your Goals")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            Text("Want to fine-tune your targets? You can manually adjust your daily goals or stick with our recommendations.")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Toggle for manual override
            VStack(spacing: 20) {
                Toggle("Manual Override", isOn: $viewModel.isManualOverride)
                .font(.headline)
                .padding(.horizontal)
                
                if viewModel.isManualOverride {
                    ManualInputForm(viewModel: viewModel)
                } else {
                    AutomaticGoalsPreview(viewModel: viewModel)
                }
            }
            
            Spacer()
            
            // Validation message
            if viewModel.isManualOverride && !viewModel.validateManualInputs() {
                Text("Please ensure all values are valid and macro calories are within 20% of total calories")
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
    }
}

struct ManualInputForm: View {
    @ObservedObject var viewModel: NutritionGoalsViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Enter your daily targets:")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ManualInputRow(
                    title: "Calories",
                    value: $viewModel.manualCalories,
                    unit: "cal",
                    color: .blue
                )
                
                ManualInputRow(
                    title: "Protein",
                    value: $viewModel.manualProtein,
                    unit: "g",
                    color: .red
                )
                
                ManualInputRow(
                    title: "Carbohydrates",
                    value: $viewModel.manualCarbs,
                    unit: "g",
                    color: .green
                )
                
                ManualInputRow(
                    title: "Fat",
                    value: $viewModel.manualFat,
                    unit: "g",
                    color: .yellow
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Macro breakdown
            if viewModel.validateManualInputs() {
                MacroBreakdownView(viewModel: viewModel)
            }
        }
    }
}

struct ManualInputRow: View {
    let title: String
    @Binding var value: String
    let unit: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: iconForMacro(title))
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            TextField("0", text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
            
            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .leading)
        }
    }
    
    private func iconForMacro(_ macro: String) -> String {
        switch macro {
        case "Calories": return "flame.fill"
        case "Protein": return "p.circle.fill"
        case "Carbohydrates": return "c.circle.fill"
        case "Fat": return "f.circle.fill"
        default: return "circle.fill"
        }
    }
}

struct MacroBreakdownView: View {
    @ObservedObject var viewModel: NutritionGoalsViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Macro Breakdown")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let calories = Double(viewModel.manualCalories),
               let protein = Double(viewModel.manualProtein),
               let carbs = Double(viewModel.manualCarbs),
               let fat = Double(viewModel.manualFat) {
                
                let proteinCal = protein * 4
                let carbsCal = carbs * 4
                let fatCal = fat * 9
                let totalMacroCal = proteinCal + carbsCal + fatCal
                
                HStack(spacing: 16) {
                    MacroPercentage(
                        name: "Protein",
                        percentage: (proteinCal / calories) * 100,
                        color: .red
                    )
                    
                    MacroPercentage(
                        name: "Carbs",
                        percentage: (carbsCal / calories) * 100,
                        color: .green
                    )
                    
                    MacroPercentage(
                        name: "Fat",
                        percentage: (fatCal / calories) * 100,
                        color: .yellow
                    )
                }
                
                Text("Macro calories: \(String(format: "%.0f", totalMacroCal)) / \(String(format: "%.0f", calories))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }
}

struct MacroPercentage: View {
    let name: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("\(String(format: "%.0f", percentage))%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct AutomaticGoalsPreview: View {
    @ObservedObject var viewModel: NutritionGoalsViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Recommended targets based on your data:")
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            if let tdee = viewModel.userPhysicalData?.tdee {
                let adjustedCalories = tdee + viewModel.selectedGoal.calorieAdjustment
                let macros = calculateMacros(calories: adjustedCalories, goal: viewModel.selectedGoal)
                
                VStack(spacing: 12) {
                    GoalPreviewRow(
                        icon: "flame.fill",
                        title: "Calories",
                        value: "\(String(format: "%.0f", adjustedCalories)) cal",
                        color: .blue
                    )
                    
                    GoalPreviewRow(
                        icon: "p.circle.fill",
                        title: "Protein",
                        value: "\(String(format: "%.0f", macros.protein)) g",
                        color: .red
                    )
                    
                    GoalPreviewRow(
                        icon: "c.circle.fill",
                        title: "Carbohydrates",
                        value: "\(String(format: "%.0f", macros.carbs)) g",
                        color: .green
                    )
                    
                    GoalPreviewRow(
                        icon: "f.circle.fill",
                        title: "Fat",
                        value: "\(String(format: "%.0f", macros.fat)) g",
                        color: .yellow
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    private func calculateMacros(calories: Double, goal: NutritionGoal) -> (protein: Double, carbs: Double, fat: Double) {
        switch goal {
        case .cut:
            return (
                protein: calories * 0.35 / 4,
                carbs: calories * 0.40 / 4,
                fat: calories * 0.25 / 9
            )
        case .maintain:
            return (
                protein: calories * 0.25 / 4,
                carbs: calories * 0.45 / 4,
                fat: calories * 0.30 / 9
            )
        case .bulk:
            return (
                protein: calories * 0.20 / 4,
                carbs: calories * 0.55 / 4,
                fat: calories * 0.25 / 9
            )
        }
    }
}

struct GoalPreviewRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    ManualOverrideStepView(viewModel: NutritionGoalsViewModel(repository: FuelLogRepository(modelContext: ModelContext(try! ModelContainer(for: NutritionGoals.self)))))
}
