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
    private let healthKit = HealthKitManager.shared
    
    init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        healthKit.requestAuthorization { [weak self] success in
            if success {
                self?.fetchStepsToday()
                self?.fetchAllSteps()
            }
        }
    }
    
    func fetchStepsToday() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            DispatchQueue.main.async {
                self.stepsToday = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
            }
        }
        healthKit.execute(query)
    }
    
    func fetchAllSteps() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .year, value: -5, to: Date()) ?? calendar.startOfDay(for: Date())
        let endDate = Date()
        var interval = DateComponents()
        interval.day = 1
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: calendar.startOfDay(for: startDate),
            intervalComponents: interval
        )
        query.initialResultsHandler = { _, results, _ in
            var days: [StepDay] = []
            results?.enumerateStatistics(from: startDate, to: endDate) { stat, _ in
                let steps = stat.sumQuantity()?.doubleValue(for: .count()) ?? 0
                days.append(StepDay(date: stat.startDate, steps: steps))
            }
            DispatchQueue.main.async {
                self.allStepDays = days
            }
        }
        healthKit.execute(query)
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
                Text("Steps Today: \(Int(viewModel.stepsToday))")
                    .font(.title)
                    .padding(.top)
                if !lastMonthSteps.isEmpty {
                    Chart(lastMonthSteps) { day in
                        BarMark(
                            x: .value("Date", day.date, unit: .day),
                            y: .value("Steps", day.steps)
                        )
                    }
                    .frame(height: 200)
                    .padding()
                } else {
                    Text("No step data available.")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .navigationTitle("Steps")
        }
    }
} 