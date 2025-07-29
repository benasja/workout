import SwiftUI
import SwiftData

struct GoalSelectionStepView: View {
    @ObservedObject var viewModel: NutritionGoalsViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "target")
                .font(.system(size: 80))
                .foregroundColor(.purple)
            
            // Title
            Text("Your Goal")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            Text("What's your primary nutrition goal?")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Goal options
            VStack(spacing: 16) {
                ForEach(NutritionGoal.allCases, id: \.self) { goal in
                    GoalCard(
                        goal: goal,
                        isSelected: viewModel.selectedGoal == goal,
                        adjustedCalories: calculateAdjustedCalories(for: goal),
                        macros: calculateMacros(for: goal)
                    ) {
                        viewModel.updateGoal(goal)
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Current selection summary
            if let tdee = viewModel.userPhysicalData?.tdee {
                GoalSummaryCard(
                    goal: viewModel.selectedGoal,
                    tdee: tdee,
                    adjustedCalories: calculateAdjustedCalories(for: viewModel.selectedGoal),
                    macros: calculateMacros(for: viewModel.selectedGoal)
                )
            }
        }
        .padding()
    }
    
    private func calculateAdjustedCalories(for goal: NutritionGoal) -> Double? {
        guard let tdee = viewModel.userPhysicalData?.tdee else { return nil }
        return tdee + goal.calorieAdjustment
    }
    
    private func calculateMacros(for goal: NutritionGoal) -> (protein: Double, carbs: Double, fat: Double)? {
        guard let adjustedCalories = calculateAdjustedCalories(for: goal) else { return nil }
        
        switch goal {
        case .cut:
            return (
                protein: adjustedCalories * 0.35 / 4, // 35% protein
                carbs: adjustedCalories * 0.40 / 4,   // 40% carbs
                fat: adjustedCalories * 0.25 / 9      // 25% fat
            )
        case .maintain:
            return (
                protein: adjustedCalories * 0.25 / 4, // 25% protein
                carbs: adjustedCalories * 0.45 / 4,   // 45% carbs
                fat: adjustedCalories * 0.30 / 9      // 30% fat
            )
        case .bulk:
            return (
                protein: adjustedCalories * 0.20 / 4, // 20% protein
                carbs: adjustedCalories * 0.55 / 4,   // 55% carbs
                fat: adjustedCalories * 0.25 / 9      // 25% fat
            )
        }
    }
}

struct GoalCard: View {
    let goal: NutritionGoal
    let isSelected: Bool
    let adjustedCalories: Double?
    let macros: (protein: Double, carbs: Double, fat: Double)?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: goal.icon)
                        .font(.title2)
                        .foregroundColor(goalColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(goal.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let calories = adjustedCalories {
                        Text("\(String(format: "%.0f", calories)) cal")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .blue : .secondary)
                }
                
                if isSelected, let macros = macros {
                    Divider()
                    
                    HStack {
                        MacroPreview(name: "Protein", value: macros.protein, color: .red)
                        Spacer()
                        MacroPreview(name: "Carbs", value: macros.carbs, color: .green)
                        Spacer()
                        MacroPreview(name: "Fat", value: macros.fat, color: .yellow)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var goalColor: Color {
        switch goal {
        case .cut: return .red
        case .maintain: return .blue
        case .bulk: return .green
        }
    }
}

struct MacroPreview: View {
    let name: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(String(format: "%.0f", value))g")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct GoalSummaryCard: View {
    let goal: NutritionGoal
    let tdee: Double
    let adjustedCalories: Double?
    let macros: (protein: Double, carbs: Double, fat: Double)?
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Daily Targets")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let calories = adjustedCalories {
                HStack {
                    Text("Calories:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(String(format: "%.0f", calories))")
                        .fontWeight(.semibold)
                }
            }
            
            if let macros = macros {
                HStack {
                    Text("Protein:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(String(format: "%.0f", macros.protein))g")
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
                
                HStack {
                    Text("Carbohydrates:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(String(format: "%.0f", macros.carbs))g")
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Fat:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(String(format: "%.0f", macros.fat))g")
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    GoalSelectionStepView(viewModel: NutritionGoalsViewModel(repository: FuelLogRepository(modelContext: ModelContext(try! ModelContainer(for: NutritionGoals.self)))))
}