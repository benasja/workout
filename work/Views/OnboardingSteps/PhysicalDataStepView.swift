import SwiftUI
import SwiftData
import HealthKit

struct PhysicalDataStepView: View {
    @ObservedObject var viewModel: NutritionGoalsViewModel
    @State private var showingManualEntry = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            // Title
            Text("Your Physical Data")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Data display or loading
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Fetching your data from HealthKit...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            } else if let physicalData = viewModel.userPhysicalData {
                VStack(spacing: 20) {
                    Text("Here's what we found:")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        PhysicalDataCard(
                            icon: "scalemass.fill",
                            title: "Weight",
                            value: physicalData.weight != nil ? String(format: "%.1f kg", physicalData.weight!) : "Not available",
                            color: .blue
                        )
                        
                        PhysicalDataCard(
                            icon: "ruler.fill",
                            title: "Height",
                            value: physicalData.height != nil ? String(format: "%.0f cm", physicalData.height!) : "Not available",
                            color: .green
                        )
                        
                        PhysicalDataCard(
                            icon: "calendar",
                            title: "Age",
                            value: physicalData.age != nil ? "\(physicalData.age!) years" : "Not available",
                            color: .orange
                        )
                        
                        PhysicalDataCard(
                            icon: "person.fill",
                            title: "Sex",
                            value: physicalData.biologicalSex?.stringRepresentation.capitalized ?? "Not available",
                            color: .purple
                        )
                    }
                    
                    // BMR and TDEE if available
                    if let bmr = physicalData.bmr, let tdee = physicalData.tdee {
                        VStack(spacing: 12) {
                            Divider()
                            
                            HStack {
                                VStack {
                                    Text("BMR")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.0f cal", bmr))
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                
                                Spacer()
                                
                                VStack {
                                    Text("TDEE")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.0f cal", tdee))
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            } else {
                VStack(spacing: 20) {
                    Text("No data available")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text("We couldn't retrieve your physical data from HealthKit. You can enter it manually or continue with default values.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Enter Data Manually") {
                        showingManualEntry = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            Spacer()
            
            // Edit button if data is available
            if viewModel.userPhysicalData != nil {
                Button("Edit Data") {
                    showingManualEntry = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .sheet(isPresented: $showingManualEntry) {
            ManualPhysicalDataEntryView(viewModel: viewModel)
        }
        .onAppear {
            if viewModel.hasHealthKitAuthorization && viewModel.userPhysicalData == nil {
                Task {
                    await viewModel.fetchUserPhysicalData()
                }
            }
        }
    }
}

struct PhysicalDataCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ManualPhysicalDataEntryView: View {
    @ObservedObject var viewModel: NutritionGoalsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var weight: String = ""
    @State private var height: String = ""
    @State private var age: String = ""
    @State private var biologicalSex: HKBiologicalSex = .notSet
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Physical Data") {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("kg", text: $weight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("cm", text: $height)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Age")
                        Spacer()
                        TextField("years", text: $age)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Picker("Biological Sex", selection: $biologicalSex) {
                        Text("Not Set").tag(HKBiologicalSex.notSet)
                        Text("Female").tag(HKBiologicalSex.female)
                        Text("Male").tag(HKBiologicalSex.male)
                        Text("Other").tag(HKBiologicalSex.other)
                    }
                }
                
                Section {
                    Button("Save") {
                        saveData()
                    }
                    .disabled(!isValidInput)
                }
            }
            .navigationTitle("Enter Physical Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadExistingData()
        }
    }
    
    private var isValidInput: Bool {
        guard let weightValue = Double(weight), weightValue > 0,
              let heightValue = Double(height), heightValue > 0,
              let ageValue = Int(age), ageValue > 0 else {
            return false
        }
        return true
    }
    
    private func loadExistingData() {
        if let physicalData = viewModel.userPhysicalData {
            weight = physicalData.weight != nil ? String(format: "%.1f", physicalData.weight!) : ""
            height = physicalData.height != nil ? String(format: "%.0f", physicalData.height!) : ""
            age = physicalData.age != nil ? String(physicalData.age!) : ""
            biologicalSex = physicalData.biologicalSex ?? .notSet
        }
    }
    
    private func saveData() {
        guard let weightValue = Double(weight),
              let heightValue = Double(height),
              let ageValue = Int(age) else {
            return
        }
        
        let bmr = NutritionGoals.calculateBMR(
            weight: weightValue,
            height: heightValue,
            age: ageValue,
            biologicalSex: biologicalSex
        )
        
        let tdee = NutritionGoals.calculateTDEE(
            bmr: bmr,
            activityLevel: viewModel.selectedActivityLevel
        )
        
        viewModel.userPhysicalData = UserPhysicalData(
            weight: weightValue,
            height: heightValue,
            age: ageValue,
            biologicalSex: biologicalSex,
            bmr: bmr,
            tdee: tdee
        )
        
        dismiss()
    }
}

#Preview {
    PhysicalDataStepView(viewModel: NutritionGoalsViewModel(repository: FuelLogRepository(modelContext: ModelContext(try! ModelContainer(for: NutritionGoals.self)))))
}