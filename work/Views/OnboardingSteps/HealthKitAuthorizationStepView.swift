import SwiftUI
import SwiftData
import HealthKit

struct HealthKitAuthorizationStepView: View {
    @ObservedObject var viewModel: NutritionGoalsViewModel
    @Binding var showingManualEntry: Bool
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            // Title
            Text("Connect to HealthKit")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            VStack(spacing: 16) {
                Text("We'll use your health data to calculate personalized nutrition goals")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 12) {
                    HealthKitPermissionRow(icon: "scalemass.fill", title: "Weight", description: "For accurate calorie calculations")
                    HealthKitPermissionRow(icon: "ruler.fill", title: "Height", description: "For BMR calculation")
                    HealthKitPermissionRow(icon: "calendar", title: "Age", description: "For metabolic rate calculation")
                    HealthKitPermissionRow(icon: "person.fill", title: "Biological Sex", description: "For accurate BMR formula")
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Authorization status
            if viewModel.hasHealthKitAuthorization {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("HealthKit Connected")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            } else if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Requesting Authorization...")
                        .font(.headline)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            } else {
                VStack(spacing: 16) {
                    Button("Connect to HealthKit") {
                        Task {
                            await viewModel.requestHealthKitAuthorization()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Enter Data Manually") {
                        viewModel.skipHealthKitAndContinue()
                        showingManualEntry = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Privacy note
            Text("Your health data stays private and secure on your device")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct HealthKitPermissionRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.red)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    HealthKitAuthorizationStepView(
        viewModel: NutritionGoalsViewModel(repository: FuelLogRepository(modelContext: ModelContext(try! ModelContainer(for: NutritionGoals.self)))),
        showingManualEntry: .constant(false)
    )
}