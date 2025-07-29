import SwiftUI
import SwiftData

struct WelcomeStepView: View {
    @ObservedObject var viewModel: NutritionGoalsViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .accessibilityHidden(true)
            
            // Title
            Text("Welcome to Fuel Log")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundColor(AccessibilityUtils.contrastAwareText())
                .dynamicTypeSize(maxSize: .accessibility1)
            
            // Description
            VStack(spacing: AccessibilityUtils.scaledSpacing(16)) {
                Text("Track your nutrition with precision and ease")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .dynamicTypeSize(maxSize: .accessibility2)
                
                VStack(alignment: .leading, spacing: AccessibilityUtils.scaledSpacing(12)) {
                    FeatureRow(icon: "barcode.viewfinder", title: "Barcode Scanning", description: "Instantly log foods by scanning barcodes")
                    FeatureRow(icon: "magnifyingglass", title: "Food Search", description: "Search from a comprehensive food database")
                    FeatureRow(icon: "chart.pie.fill", title: "Macro Tracking", description: "Monitor calories, protein, carbs, and fat")
                    FeatureRow(icon: "heart.fill", title: "HealthKit Integration", description: "Sync with Apple Health for complete tracking")
                }
                .padding(.horizontal)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Fuel Log features: Barcode Scanning to instantly log foods, Food Search from comprehensive database, Macro Tracking for calories and nutrients, HealthKit Integration for complete health tracking")
            }
            
            Spacer()
            
            // Getting started text
            Text("Let's set up your nutrition goals in just a few steps")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .dynamicTypeSize(maxSize: .accessibility2)
        }
        .padding()
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: AccessibilityUtils.scaledSpacing(16)) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: AccessibilityUtils.scaledSpacing(4)) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(AccessibilityUtils.contrastAwareText())
                    .dynamicTypeSize(maxSize: .accessibility2)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .dynamicTypeSize(maxSize: .accessibility2)
            }
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
    }
}



#Preview {
    WelcomeStepView(viewModel: NutritionGoalsViewModel(repository: FuelLogRepository(modelContext: ModelContext(try! ModelContainer(for: NutritionGoals.self)))))
}