import Foundation
import SwiftUI
import HealthKit

@MainActor
final class NutritionGoalsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var nutritionGoals: NutritionGoals?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingOnboarding = false
    
    // Enhanced error handling
    @Published var errorHandler = ErrorHandler()
    @Published var loadingManager = LoadingStateManager()
    
    // Onboarding state
    @Published var hasHealthKitAuthorization = false
    @Published var userPhysicalData: UserPhysicalData?
    @Published var selectedActivityLevel: ActivityLevel = .sedentary
    @Published var selectedGoal: NutritionGoal = .maintain
    @Published var isOnboardingComplete = false
    
    // Manual override state
    @Published var isManualOverride = false
    @Published var manualCalories: String = ""
    @Published var manualProtein: String = ""
    @Published var manualCarbs: String = ""
    @Published var manualFat: String = ""
    
    // Dependencies
    private let repository: FuelLogRepository
    private let healthKitManager: HealthKitManager
    
    init(repository: FuelLogRepository, healthKitManager: HealthKitManager = .shared) {
        self.repository = repository
        self.healthKitManager = healthKitManager
        
        Task {
            await loadExistingGoals()
        }
    }
    
    // MARK: - Data Loading
    
    func loadExistingGoals() async {
        isLoading = true
        loadingManager.startLoading(
            taskId: "load-goals",
            message: "Loading nutrition goals..."
        )
        
        do {
            nutritionGoals = try await repository.fetchNutritionGoals()
            
            if nutritionGoals == nil {
                // No existing goals, show onboarding
                showingOnboarding = true
            } else {
                isOnboardingComplete = true
                updateManualOverrideFields()
            }
        } catch {
            errorHandler.handleError(
                error,
                context: "Loading existing nutrition goals"
            ) { [weak self] in
                await self?.loadExistingGoals()
            }
        }
        
        isLoading = false
        loadingManager.stopLoading(taskId: "load-goals")
    }
    
    // MARK: - Onboarding Flow
    
    func startOnboarding() async {
        showingOnboarding = true
        await requestHealthKitAuthorization()
    }
    
    func requestHealthKitAuthorization() async {
        isLoading = true
        loadingManager.startLoading(
            taskId: "healthkit-auth",
            message: "Requesting HealthKit authorization..."
        )
        
        do {
            hasHealthKitAuthorization = try await withCheckedThrowingContinuation { continuation in
                healthKitManager.requestAuthorization { success in
                    continuation.resume(returning: success)
                }
            }
            
            if hasHealthKitAuthorization {
                await fetchUserPhysicalData()
            }
        } catch {
            let healthKitError = FuelLogError.healthKitAuthorizationDenied
            errorHandler.handleError(
                healthKitError,
                context: "HealthKit authorization"
            )
            hasHealthKitAuthorization = false
        }
        
        isLoading = false
        loadingManager.stopLoading(taskId: "healthkit-auth")
    }
    
    func fetchUserPhysicalData() async {
        isLoading = true
        loadingManager.startLoading(
            taskId: "fetch-physical-data",
            message: "Fetching physical data from HealthKit..."
        )
        
        do {
            userPhysicalData = try await withCheckedThrowingContinuation { continuation in
                fetchPhysicalDataFromHealthKit { result in
                    switch result {
                    case .success(let data):
                        continuation.resume(returning: data)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            errorHandler.handleError(
                error,
                context: "Fetching HealthKit physical data"
            ) { [weak self] in
                await self?.fetchUserPhysicalData()
            }
        }
        
        isLoading = false
        loadingManager.stopLoading(taskId: "fetch-physical-data")
    }
    
    private func fetchPhysicalDataFromHealthKit(completion: @escaping (Result<UserPhysicalData, Error>) -> Void) {
        let group = DispatchGroup()
        var weight: Double?
        var height: Double?
        var age: Int?
        var biologicalSex: HKBiologicalSex?
        var fetchError: Error?
        
        // Fetch weight
        group.enter()
        healthKitManager.fetchLatestWeight { value in
            weight = value
            group.leave()
        }
        
        // Fetch height
        group.enter()
        fetchHeight { value in
            height = value
            group.leave()
        }
        
        // Fetch age and biological sex
        group.enter()
        fetchAgeAndSex { ageValue, sexValue, error in
            age = ageValue
            biologicalSex = sexValue
            if let error = error {
                fetchError = error
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            if let error = fetchError {
                completion(.failure(error))
                return
            }
            
            let bmr = self.calculateBMR(weight: weight, height: height, age: age, biologicalSex: biologicalSex)
            let tdee = self.calculateTDEE(bmr: bmr, activityLevel: self.selectedActivityLevel)
            
            let physicalData = UserPhysicalData(
                weight: weight,
                height: height,
                age: age,
                biologicalSex: biologicalSex,
                bmr: bmr,
                tdee: tdee
            )
            
            completion(.success(physicalData))
        }
    }
    
    private func fetchHeight(completion: @escaping (Double?) -> Void) {
        guard let heightType = HKObjectType.quantityType(forIdentifier: .height) else {
            completion(nil)
            return
        }
        
        let query = HKSampleQuery(sampleType: heightType, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, _ in
            let heightSample = samples?.first as? HKQuantitySample
            let height = heightSample?.quantity.doubleValue(for: HKUnit.meter()) ?? nil
            let heightInCm = height != nil ? height! * 100 : nil
            DispatchQueue.main.async {
                completion(heightInCm)
            }
        }
        
        healthKitManager.healthStore.execute(query)
    }
    
    private func fetchAgeAndSex(completion: @escaping (Int?, HKBiologicalSex?, Error?) -> Void) {
        do {
            let dateOfBirth = try healthKitManager.healthStore.dateOfBirthComponents()
            let biologicalSex = try healthKitManager.healthStore.biologicalSex()
            
            let age = Calendar.current.dateComponents([.year], from: dateOfBirth.date ?? Date(), to: Date()).year
            
            DispatchQueue.main.async {
                completion(age, biologicalSex.biologicalSex, nil)
            }
        } catch {
            DispatchQueue.main.async {
                completion(nil, nil, error)
            }
        }
    }
    
    // MARK: - Goal Calculations
    
    func calculateBMR(weight: Double?, height: Double?, age: Int?, biologicalSex: HKBiologicalSex?) -> Double? {
        guard let weight = weight,
              let height = height,
              let age = age,
              let biologicalSex = biologicalSex else {
            return nil
        }
        
        return NutritionGoals.calculateBMR(weight: weight, height: height, age: age, biologicalSex: biologicalSex)
    }
    
    func calculateTDEE(bmr: Double?, activityLevel: ActivityLevel) -> Double? {
        guard let bmr = bmr else { return nil }
        return NutritionGoals.calculateTDEE(bmr: bmr, activityLevel: activityLevel)
    }
    
    func updateActivityLevel(_ level: ActivityLevel) {
        selectedActivityLevel = level
        
        if let physicalData = userPhysicalData,
           let bmr = physicalData.bmr {
            let newTDEE = NutritionGoals.calculateTDEE(bmr: bmr, activityLevel: level)
            userPhysicalData = UserPhysicalData(
                weight: physicalData.weight,
                height: physicalData.height,
                age: physicalData.age,
                biologicalSex: physicalData.biologicalSex,
                bmr: physicalData.bmr,
                tdee: newTDEE
            )
        }
    }
    
    func updateGoal(_ goal: NutritionGoal) {
        selectedGoal = goal
    }
    
    // MARK: - Manual Override
    
    func toggleManualOverride() {
        isManualOverride.toggle()
        
        if isManualOverride {
            updateManualOverrideFields()
        }
    }
    
    private func updateManualOverrideFields() {
        guard let goals = nutritionGoals else { return }
        
        manualCalories = String(format: "%.0f", goals.dailyCalories)
        manualProtein = String(format: "%.0f", goals.dailyProtein)
        manualCarbs = String(format: "%.0f", goals.dailyCarbohydrates)
        manualFat = String(format: "%.0f", goals.dailyFat)
    }
    
    func validateManualInputs() -> Bool {
        guard let calories = Double(manualCalories),
              let protein = Double(manualProtein),
              let carbs = Double(manualCarbs),
              let fat = Double(manualFat) else {
            return false
        }
        
        // Basic validation
        guard calories > 0, protein >= 0, carbs >= 0, fat >= 0 else {
            return false
        }
        
        // Check if macro calories are reasonable (within 20% of total calories)
        let macroCalories = (protein * 4) + (carbs * 4) + (fat * 9)
        let difference = abs(calories - macroCalories)
        let percentDifference = difference / calories
        
        return percentDifference <= 0.20 // Allow 20% variance for manual input
    }
    
    // MARK: - Save Goals
    
    func completeOnboarding() async {
        isLoading = true
        loadingManager.startLoading(
            taskId: "complete-onboarding",
            message: "Saving nutrition goals..."
        )
        
        do {
            let goals = try await createNutritionGoals()
            try await repository.saveNutritionGoals(goals)
            
            nutritionGoals = goals
            isOnboardingComplete = true
            showingOnboarding = false
        } catch {
            errorHandler.handleError(
                error,
                context: "Completing onboarding"
            ) { [weak self] in
                await self?.completeOnboarding()
            }
        }
        
        isLoading = false
        loadingManager.stopLoading(taskId: "complete-onboarding")
    }
    
    func updateGoals() async {
        isLoading = true
        loadingManager.startLoading(
            taskId: "update-goals",
            message: "Updating nutrition goals..."
        )
        
        do {
            let goals = try await createNutritionGoals()
            try await repository.saveNutritionGoals(goals)
            
            nutritionGoals = goals
            updateManualOverrideFields()
        } catch {
            errorHandler.handleError(
                error,
                context: "Updating nutrition goals"
            ) { [weak self] in
                await self?.updateGoals()
            }
        }
        
        isLoading = false
        loadingManager.stopLoading(taskId: "update-goals")
    }
    
    private func createNutritionGoals() async throws -> NutritionGoals {
        let physicalData = userPhysicalData
        let bmr = physicalData?.bmr ?? 1500 // Fallback BMR
        let tdee = physicalData?.tdee ?? 2000 // Fallback TDEE
        
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        
        if isManualOverride && validateManualInputs() {
            // Use manual values
            calories = Double(manualCalories) ?? 2000
            protein = Double(manualProtein) ?? 150
            carbs = Double(manualCarbs) ?? 200
            fat = Double(manualFat) ?? 65
        } else {
            // Calculate from TDEE and goal
            let adjustedCalories = tdee + selectedGoal.calorieAdjustment
            calories = adjustedCalories
            
            // Apply standard macro distribution based on goal
            switch selectedGoal {
            case .cut:
                protein = adjustedCalories * 0.35 / 4 // 35% protein
                fat = adjustedCalories * 0.25 / 9     // 25% fat
                carbs = adjustedCalories * 0.40 / 4   // 40% carbs
            case .maintain:
                protein = adjustedCalories * 0.25 / 4 // 25% protein
                fat = adjustedCalories * 0.30 / 9     // 30% fat
                carbs = adjustedCalories * 0.45 / 4   // 45% carbs
            case .bulk:
                protein = adjustedCalories * 0.20 / 4 // 20% protein
                fat = adjustedCalories * 0.25 / 9     // 25% fat
                carbs = adjustedCalories * 0.55 / 4   // 55% carbs
            }
        }
        
        return NutritionGoals(
            dailyCalories: calories,
            dailyProtein: protein,
            dailyCarbohydrates: carbs,
            dailyFat: fat,
            activityLevel: selectedActivityLevel,
            goal: selectedGoal,
            bmr: bmr,
            tdee: tdee,
            weight: physicalData?.weight,
            height: physicalData?.height,
            age: physicalData?.age,
            biologicalSex: physicalData?.biologicalSex?.stringRepresentation
        )
    }
    
    // MARK: - Helper Methods
    
    func resetOnboarding() {
        showingOnboarding = false
        hasHealthKitAuthorization = false
        userPhysicalData = nil
        selectedActivityLevel = .sedentary
        selectedGoal = .maintain
        isOnboardingComplete = false
        isManualOverride = false
        errorMessage = nil
    }
    
    func skipHealthKitAndContinue() {
        hasHealthKitAuthorization = false
        // Set default physical data for manual input
        userPhysicalData = UserPhysicalData(
            weight: nil,
            height: nil,
            age: nil,
            biologicalSex: nil,
            bmr: 1500, // Default BMR
            tdee: 2000 // Default TDEE
        )
    }
}



// MARK: - HKBiologicalSex Extension

extension HKBiologicalSex {
    var stringRepresentation: String {
        switch self {
        case .male: return "male"
        case .female: return "female"
        case .other: return "other"
        default: return "unknown"
        }
    }
}