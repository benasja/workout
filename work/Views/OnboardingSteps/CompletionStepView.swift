import SwiftUI
import SwiftData

struct CompletionStepView: View {
    @ObservedObject var viewModel: NutritionGoalsViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            // Title
            Text("You're All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            Text("Your personalized nutrition goals have been calculated and are ready to use.")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Goals summary
            GoalsSummaryCard(viewModel: viewModel)
            
            Spacer()
            
            // Next steps
            VStack(spacing: 16) {
                Text("What's next?")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 12) {
                    NextStepRow(
                        icon: "barcode.viewfinder",
                        title: "Scan barcodes",
                        description: "Quickly log foods by scanning product barcodes"
                    )
                    
                    NextStepRow(
                        icon: "magnifyingglass",
                        title: "Search foods",
                        description: "Find foods from our comprehensive database"
                    )
                    
                    NextStepRow(
                        icon: "chart.pie.fill",
                        title: "Track progress",
                        description: "Monitor your daily intake and macro balance"
                    )
                    
                    NextStepRow(
                        icon: "plus.circle.fill",
                        title: "Create custom foods",
                        description: "Add your own recipes and favorite meals"
                    )
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct GoalsSummaryCard: View {
    @ObservedObject var viewModel: NutritionGoalsViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Your Daily Goals")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let physicalData = viewModel.userPhysicalData,
               let tdee = physicalData.tdee {
                
                let adjustedCalories = tdee + viewModel.selectedGoal.calorieAdjustment
                let macros = calculateMacros(calories: adjustedCalories, goal: viewModel.selectedGoal)
                
                VStack(spacing: 12) {
                    // Calories
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.blue)
                        Text("Calories")
                            .font(.subheadline)
                        Spacer()
                        Text("\(String(format: "%.0f", adjustedCalories))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Divider()
                    
                    // Macros
                    HStack {
                        MacroSummaryItem(
                            name: "Protein",
                            value: macros.protein,
                            color: .red
                        )
                        
                        Spacer()
                        
                        MacroSummaryItem(
                            name: "Carbs",
                            value: macros.carbs,
                            color: .green
                        )
                        
                        Spacer()
                        
                        MacroSummaryItem(
                            name: "Fat",
                            value: macros.fat,
                            color: .yellow
                        )
                    }
                    
                    Divider()
                    
                    // Goal and activity level
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Goal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(viewModel.selectedGoal.displayName)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Activity Level")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(viewModel.selectedActivityLevel.displayName)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.3), lineWidth: 2)
                )
        )
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

struct MacroSummaryItem: View {
    let name: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(String(format: "%.0f", value))g")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct NextStepRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    CompletionStepView(viewModel: NutritionGoalsViewModel(repository: FuelLogRepository(modelContext: ModelContext(try! ModelContainer(for: NutritionGoals.self)))))
}