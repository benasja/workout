import SwiftUI

class PerformanceDateModel: ObservableObject {
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())
}

struct PerformanceView: View {
    @EnvironmentObject var dateModel: PerformanceDateModel
    @EnvironmentObject var tabSelectionModel: TabSelectionModel
    @State private var recoveryScore: Int? = nil
    @State private var sleepScore: Int? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var loadingWorkItem: DispatchWorkItem? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        HStack(spacing: 20) {
                            Button(action: {
                                tabSelectionModel.selection = 1
                                tabSelectionModel.moreTabDetail = .recovery
                            }) {
                                ScoreGaugeView(
                                    title: "Recovery",
                                    score: recoveryScore,
                                    color: .green
                                )
                                .accessibilityLabel("Recovery Score: \(recoveryScore ?? 0)")
                            }
                            Button(action: {
                                tabSelectionModel.selection = 1
                                tabSelectionModel.moreTabDetail = .sleep
                            }) {
                                ScoreGaugeView(
                                    title: "Sleep",
                                    score: sleepScore,
                                    color: .blue
                                )
                                .accessibilityLabel("Sleep Score: \(sleepScore ?? 0)")
                            }
                        }
                        .padding(.top, 24)
                        DateSliderView(selectedDate: $dateModel.selectedDate)
                    }
                    .frame(maxWidth: .infinity)
                }
                .background(AppColors.background)
                .navigationTitle("Performance")
                .onAppear(perform: fetchScores)
                .refreshable { fetchScores() }
                .onChange(of: dateModel.selectedDate) { _, _ in
                    fetchScores()
                }
                if isLoading {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                if let errorMessage = errorMessage {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                        Button("Retry") { fetchScores() }
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private func fetchScores() {
        isLoading = false
        errorMessage = nil
        loadingWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            self.isLoading = true
        }
        loadingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
        HealthKitManager.shared.fetchScores(for: dateModel.selectedDate) { recovery, sleep, error in
            DispatchQueue.main.async {
                self.loadingWorkItem?.cancel()
                self.recoveryScore = recovery
                self.sleepScore = sleep
                self.isLoading = false
                self.errorMessage = error
            }
        }
    }
}

struct ScoreGaugeView: View {
    let title: String
    let score: Int?
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 16)
                    .frame(width: 120, height: 120)
                if let score = score {
                    Text("\(score)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: color))
                        .frame(width: 48, height: 48)
                }
            }
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(20)
    }
} 
