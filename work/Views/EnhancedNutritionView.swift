import SwiftUI

struct EnhancedNutritionView: View {
    @State private var selectedTab = 0
    let caloriesRemaining: Int
    let carbsCurrent: Double
    let carbsGoal: Double
    let proteinCurrent: Double
    let proteinGoal: Double
    let fatCurrent: Double
    let fatGoal: Double
    
    // New properties for meal sections
    let foodLogsByMealType: [MealType: [FoodLog]]
    let onAddFood: (MealType) -> Void
    let onEditFood: (FoodLog) -> Void
    let onDeleteFood: (FoodLog) -> Void
    
    private var carbsProgress: Double {
        guard carbsGoal > 0 else { return 0 }
        return min(carbsCurrent / carbsGoal, 1.0)
    }
    
    private var proteinProgress: Double {
        guard proteinGoal > 0 else { return 0 }
        return min(proteinCurrent / proteinGoal, 1.0)
    }
    
    private var fatProgress: Double {
        guard fatGoal > 0 else { return 0 }
        return min(fatCurrent / fatGoal, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Macros Card (existing design)
            macrosCard
            
            // Meal Sections (new design)
            mealSections
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Macros Card (Preserved from original)
    
    private var macrosCard: some View {
        VStack(spacing: 24) {
            // Tabs
            tabSection
            
            // Radial Progress
            radialProgressSection
            
            // Macro Details
            macroDetailsSection
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.blue.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .foregroundColor(.white)
    }
    
    private var tabSection: some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }) {
                    Text(tabTitle(for: index))
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedTab == index ? Color.white : Color.clear)
                        )
                        .foregroundColor(selectedTab == index ? .blue : .white.opacity(0.8))
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.blue.opacity(0.5))
        )
    }
    
    private var radialProgressSection: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 14)
                .frame(width: 160, height: 160)
            
            // Progress rings - overlapping segments like in the HTML
            Group {
                // Carbs progress (green) - starts from top
                Circle()
                    .trim(from: 0, to: carbsProgress)
                    .stroke(Color.green, lineWidth: 14)
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: carbsProgress)
                
                // Protein progress (pink) - starts from where carbs end
                Circle()
                    .trim(from: 0, to: proteinProgress)
                    .stroke(Color.pink, lineWidth: 14)
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90 + (carbsProgress * 360)))
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: proteinProgress)
                
                // Fat progress (yellow) - starts from where protein ends
                Circle()
                    .trim(from: 0, to: fatProgress)
                    .stroke(Color.yellow, lineWidth: 14)
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90 + ((carbsProgress + proteinProgress) * 360)))
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: fatProgress)
            }
            
            // Center content
            VStack(spacing: 4) {
                Text("\(caloriesRemaining)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Calories Left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var macroDetailsSection: some View {
        HStack(spacing: 0) {
            // Carbs
            macroDetailItem(
                value: "\(Int(carbsCurrent))g",
                label: "Carbs",
                color: .green
            )
            
            // Protein
            macroDetailItem(
                value: "\(Int(proteinCurrent))g",
                label: "Protein",
                color: .pink
            )
            
            // Fat
            macroDetailItem(
                value: "\(Int(fatCurrent))g",
                label: "Fat",
                color: .yellow
            )
        }
    }
    
    private func macroDetailItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(value)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Meal Sections (New Design)
    
    private var mealSections: some View {
        LazyVStack(spacing: 16) {
            ForEach(MealType.allCases, id: \.self) { mealType in
                let mealFoodLogs = foodLogsByMealType[mealType] ?? []
                let mealCalories = mealFoodLogs.reduce(0) { $0 + $1.calories }
                
                MealSectionCard(
                    mealType: mealType,
                    foodLogs: mealFoodLogs,
                    totalCalories: mealCalories,
                    onAddFood: { onAddFood(mealType) },
                    onEditFood: onEditFood,
                    onDeleteFood: onDeleteFood
                )
            }
        }
    }
    
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "Macros"
        case 1: return "Nutrients"
        case 2: return "Calories"
        default: return ""
        }
    }
}

// MARK: - Meal Section Card

struct MealSectionCard: View {
    let mealType: MealType
    let foodLogs: [FoodLog]
    let totalCalories: Double
    let onAddFood: () -> Void
    let onEditFood: (FoodLog) -> Void
    let onDeleteFood: (FoodLog) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (Blue background like HTML)
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: mealType.icon)
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mealType.displayName)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("\(Int(totalCalories)) cals")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                Button(action: onAddFood) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.light)
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(16)
            .background(Color.blue)
            
            // Content
            if foodLogs.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Text("No foods logged for \(mealType.displayName.lowercased()) yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            } else {
                // Food items in VStack with individual swipe actions
                VStack(spacing: 8) {
                    ForEach(foodLogs, id: \.id) { foodLog in
                        FoodItemRow(
                            foodLog: foodLog,
                            onEdit: { onEditFood(foodLog) },
                            onDelete: { onDeleteFood(foodLog) }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Delete", role: .destructive) {
                                onDeleteFood(foodLog)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Food Item Row

struct FoodItemRow: View {
    let foodLog: FoodLog
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(foodLog.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(foodLog.formattedServing)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Nutrition insights (like the HTML example)
                if foodLog.protein > 20 {
                    Text("This food has lots of Protein.")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            Spacer()
            
            Text("\(Int(foodLog.calories)) cals")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}

// MARK: - Preview

struct EnhancedNutritionView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gray.opacity(0.1), Color.blue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            EnhancedNutritionView(
                caloriesRemaining: 362,
                carbsCurrent: 216,
                carbsGoal: 250,
                proteinCurrent: 147,
                proteinGoal: 180,
                fatCurrent: 38,
                fatGoal: 65,
                foodLogsByMealType: [
                    .breakfast: [
                        FoodLog(name: "Grade A Large Egg", calories: 140, protein: 12, carbohydrates: 1, fat: 10, mealType: .breakfast, servingSize: 2, servingUnit: "eggs"),
                        FoodLog(name: "Blueberries", calories: 92, protein: 1, carbohydrates: 23, fat: 0, mealType: .breakfast, servingSize: 100, servingUnit: "g"),
                        FoodLog(name: "Maple Chicken Breakfast Sausage", calories: 180, protein: 15, carbohydrates: 2, fat: 12, mealType: .breakfast, servingSize: 4, servingUnit: "links")
                    ],
                    .lunch: [
                        FoodLog(name: "Chicken Breast - Cooked", calories: 246, protein: 45, carbohydrates: 0, fat: 5, mealType: .lunch, servingSize: 5.25, servingUnit: "oz"),
                        FoodLog(name: "Broccoli", calories: 31, protein: 3, carbohydrates: 6, fat: 0, mealType: .lunch, servingSize: 1, servingUnit: "cup")
                    ],
                    .dinner: [],
                    .snacks: []
                ],
                onAddFood: { _ in },
                onEditFood: { _ in },
                onDeleteFood: { _ in }
            )
        }
    }
} 