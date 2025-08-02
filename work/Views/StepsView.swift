import SwiftUI
import Charts
import HealthKit

struct StepDay: Identifiable {
    let id = UUID()
    let date: Date
    let steps: Double
}

class StepsViewModel: ObservableObject {
    @Published var stepsToday: Double = 0
    @Published var allStepDays: [StepDay] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    private let healthKit = HealthKitManager.shared
    
    init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        print("🚶‍♂️ Requesting HealthKit authorization for steps...")
        healthKit.requestAuthorization { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    print("✅ HealthKit authorization granted for steps")
                    self?.fetchStepsToday()
                    self?.fetchAllSteps()
                } else {
                    print("❌ HealthKit authorization denied for steps")
                    self?.errorMessage = "HealthKit access denied. Please enable in Settings > Privacy & Security > Health."
                    self?.isLoading = false
                }
            }
        }
    }
    
    func fetchStepsToday() {
        print("📊 Fetching today's steps...")
        healthKit.fetchTodaySteps { [weak self] steps in
            DispatchQueue.main.async {
                if let steps = steps {
                    print("✅ Today's steps: \(Int(steps))")
                    self?.stepsToday = steps
                } else {
                    print("⚠️ No step data available for today")
                    self?.stepsToday = 0
                }
            }
        }
    }
    
    func fetchAllSteps() {
        print("📈 Fetching historical step data...")
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date() // Last 3 months
        let endDate = Date()
        
        healthKit.fetchStepsForDateRange(from: startDate, to: endDate) { [weak self] stepData in
            DispatchQueue.main.async {
                let stepDays = stepData.map { StepDay(date: $0.date, steps: $0.steps) }
                print("✅ Fetched \(stepDays.count) days of step data")
                self?.allStepDays = stepDays
                self?.isLoading = false
            }
        }
    }
    
    func refresh() {
        isLoading = true
        errorMessage = nil
        fetchStepsToday()
        fetchAllSteps()
    }
}

struct StepsView: View {
    @StateObject var viewModel = StepsViewModel()
    
    private var lastMonthSteps: [StepDay] {
        let calendar = Calendar.current
        let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return viewModel.allStepDays.filter { $0.date >= oneMonthAgo }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading step data...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            viewModel.refresh()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Today's steps
                    VStack(spacing: 8) {
                        Text("\(Int(viewModel.stepsToday))")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Steps Today")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Chart
                    if !lastMonthSteps.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Last 30 Days")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Chart(lastMonthSteps) { day in
                                BarMark(
                                    x: .value("Date", day.date, unit: .day),
                                    y: .value("Steps", day.steps)
                                )
                                .foregroundStyle(.blue.gradient)
                            }
                            .frame(height: 200)
                            .padding(.horizontal)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "figure.walk")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No historical step data available")
                                .foregroundColor(.secondary)
                            Text("Start walking to see your progress!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Steps")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        viewModel.refresh()
                    }
                }
            }
        }
    }
} 