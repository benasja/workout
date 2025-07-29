import SwiftUI
import SwiftData
import HealthKit

struct FuelLogOnboardingView: View {
    @StateObject private var viewModel: NutritionGoalsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep: OnboardingStep = .welcome
    @State private var showingManualDataEntry = false
    
    init(repository: FuelLogRepository) {
        self._viewModel = StateObject(wrappedValue: NutritionGoalsViewModel(repository: repository))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.green.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator
                    OnboardingProgressView(currentStep: currentStep)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Content
                    TabView(selection: $currentStep) {
                        WelcomeStepView(viewModel: viewModel)
                            .tag(OnboardingStep.welcome)
                        
                        HealthKitAuthorizationStepView(viewModel: viewModel, showingManualEntry: $showingManualDataEntry)
                            .tag(OnboardingStep.healthKit)
                        
                        PhysicalDataStepView(viewModel: viewModel)
                            .tag(OnboardingStep.physicalData)
                        
                        ActivityLevelStepView(viewModel: viewModel)
                            .tag(OnboardingStep.activityLevel)
                        
                        GoalSelectionStepView(viewModel: viewModel)
                            .tag(OnboardingStep.goalSelection)
                        
                        ManualOverrideStepView(viewModel: viewModel)
                            .tag(OnboardingStep.manualOverride)
                        
                        CompletionStepView(viewModel: viewModel)
                            .tag(OnboardingStep.completion)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: currentStep)
                    
                    // Navigation buttons
                    OnboardingNavigationView(
                        currentStep: $currentStep,
                        viewModel: viewModel,
                        onComplete: {
                            dismiss()
                        }
                    )
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingManualDataEntry) {
            ManualPhysicalDataEntryView(viewModel: viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
}

// MARK: - Onboarding Steps Enum

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case healthKit = 1
    case physicalData = 2
    case activityLevel = 3
    case goalSelection = 4
    case manualOverride = 5
    case completion = 6
    
    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .healthKit: return "HealthKit"
        case .physicalData: return "Physical Data"
        case .activityLevel: return "Activity Level"
        case .goalSelection: return "Goal"
        case .manualOverride: return "Customize"
        case .completion: return "Complete"
        }
    }
    
    var progress: Double {
        return Double(rawValue) / Double(OnboardingStep.allCases.count - 1)
    }
}

// MARK: - Progress View

struct OnboardingProgressView: View {
    let currentStep: OnboardingStep
    
    var body: some View {
        VStack(spacing: AccessibilityUtils.scaledSpacing(8)) {
            ProgressView(value: currentStep.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .accessibilityLabel("Onboarding progress")
                .accessibilityValue("\(Int(currentStep.progress * 100)) percent complete")
            
            HStack {
                Text("Step \(currentStep.rawValue + 1) of \(OnboardingStep.allCases.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .dynamicTypeSize(maxSize: .accessibility2)
                
                Spacer()
                
                Text(currentStep.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .dynamicTypeSize(maxSize: .accessibility2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(currentStep.rawValue + 1) of \(OnboardingStep.allCases.count): \(currentStep.title). \(Int(currentStep.progress * 100)) percent complete")
    }
}

// MARK: - Navigation View

struct OnboardingNavigationView: View {
    @Binding var currentStep: OnboardingStep
    @ObservedObject var viewModel: NutritionGoalsViewModel
    let onComplete: () -> Void
    
    var body: some View {
        HStack {
            // Back button
            if currentStep != .welcome {
                Button("Back") {
                    withAnimation {
                        if let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) {
                            currentStep = previousStep
                        }
                    }
                    AccessibilityUtils.selectionFeedback()
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Go back to previous step")
                .accessibilityHint("Double tap to return to the previous onboarding step")
                .keyboardNavigationSupport()
            } else {
                Spacer()
            }
            
            Spacer()
            
            // Next/Complete button
            Button(currentStep == .completion ? "Complete" : "Next") {
                if currentStep == .completion {
                    Task {
                        await viewModel.completeOnboarding()
                        if viewModel.isOnboardingComplete {
                            AccessibilityUtils.announce("Onboarding completed successfully")
                            AccessibilityUtils.successFeedback()
                            onComplete()
                        }
                    }
                } else {
                    withAnimation {
                        if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
                            currentStep = nextStep
                        }
                    }
                    AccessibilityUtils.selectionFeedback()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isNextButtonDisabled)
            .accessibilityLabel(currentStep == .completion ? "Complete onboarding" : "Continue to next step")
            .accessibilityHint(currentStep == .completion ? "Double tap to finish setting up your nutrition goals" : "Double tap to continue to the next onboarding step")
            .keyboardNavigationSupport()
        }
    }
    
    private var isNextButtonDisabled: Bool {
        switch currentStep {
        case .welcome:
            return false
        case .healthKit:
            return !viewModel.hasHealthKitAuthorization && viewModel.userPhysicalData == nil
        case .physicalData:
            return viewModel.userPhysicalData == nil
        case .activityLevel:
            return false
        case .goalSelection:
            return false
        case .manualOverride:
            return viewModel.isManualOverride && !viewModel.validateManualInputs()
        case .completion:
            return viewModel.isLoading
        }
    }
}

#Preview {
    FuelLogOnboardingView(repository: FuelLogRepository(modelContext: ModelContext(try! ModelContainer(for: NutritionGoals.self))))
}