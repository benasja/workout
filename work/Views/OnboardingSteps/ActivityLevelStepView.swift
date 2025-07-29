import SwiftUI
import SwiftData

struct ActivityLevelStepView: View {
    @ObservedObject var viewModel: NutritionGoalsViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            // Title
            Text("Activity Level")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            Text("Select your typical activity level to calculate your daily calorie needs")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Activity level options
            VStack(spacing: 12) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    ActivityLevelCard(
                        level: level,
                        isSelected: viewModel.selectedActivityLevel == level,
                        tdee: calculateTDEE(for: level)
                    ) {
                        viewModel.updateActivityLevel(level)
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // TDEE explanation
            if let tdee = viewModel.userPhysicalData?.tdee {
                VStack(spacing: 8) {
                    Text("Your Total Daily Energy Expenditure")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(String(format: "%.0f", tdee)) calories/day")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
    }
    
    private func calculateTDEE(for level: ActivityLevel) -> Double? {
        guard let bmr = viewModel.userPhysicalData?.bmr else { return nil }
        return NutritionGoals.calculateTDEE(bmr: bmr, activityLevel: level)
    }
}

struct ActivityLevelCard: View {
    let level: ActivityLevel
    let isSelected: Bool
    let tdee: Double?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(level.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let tdee = tdee {
                        Text("\(String(format: "%.0f", tdee)) cal")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    Text("×\(String(format: "%.2f", level.multiplier))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .secondary)
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
}

#Preview {
    ActivityLevelStepView(viewModel: NutritionGoalsViewModel(repository: FuelLogRepository(modelContext: ModelContext(try! ModelContainer(for: NutritionGoals.self)))))
}