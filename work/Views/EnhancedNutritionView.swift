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
        VStack(spacing: 0) {
            // Main Card
            VStack(spacing: 24) {
                // Tabs
                tabSection
                
                // Radial Progress
                radialProgressSection
                
                // Macro Details
                macroDetailsSection
            }
            .padding(24)
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
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Nutrition dashboard with \(caloriesRemaining) calories remaining")
        .accessibilityHint("Shows your daily nutrition progress with macronutrient breakdown")
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
                .stroke(Color.white.opacity(0.3), lineWidth: 16)
                .frame(width: 192, height: 192)
            
            // Progress rings - overlapping segments like in the HTML
            Group {
                // Carbs progress (green) - starts from top
                Circle()
                    .trim(from: 0, to: carbsProgress)
                    .stroke(Color.green, lineWidth: 16)
                    .frame(width: 192, height: 192)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: carbsProgress)
                
                // Protein progress (pink) - starts from where carbs end
                Circle()
                    .trim(from: 0, to: proteinProgress)
                    .stroke(Color.pink, lineWidth: 16)
                    .frame(width: 192, height: 192)
                    .rotationEffect(.degrees(-90 + (carbsProgress * 360)))
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: proteinProgress)
                
                // Fat progress (yellow) - starts from where protein ends
                Circle()
                    .trim(from: 0, to: fatProgress)
                    .stroke(Color.yellow, lineWidth: 16)
                    .frame(width: 192, height: 192)
                    .rotationEffect(.degrees(-90 + ((carbsProgress + proteinProgress) * 360)))
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: fatProgress)
            }
            
            // Center content
            VStack(spacing: 4) {
                Text("\(caloriesRemaining)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Calories Left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(caloriesRemaining) calories remaining")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nutrition progress ring showing \(Int(carbsProgress * 100))% carbs, \(Int(proteinProgress * 100))% protein, and \(Int(fatProgress * 100))% fat progress")
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Macronutrient breakdown: \(Int(carbsCurrent)) grams of carbs, \(Int(proteinCurrent)) grams of protein, and \(Int(fatCurrent)) grams of fat")
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
    
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "Macros"
        case 1: return "Nutrients"
        case 2: return "Calories"
        default: return ""
        }
    }
}

// Preview with test data
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
                fatGoal: 65
            )
        }
    }
} 