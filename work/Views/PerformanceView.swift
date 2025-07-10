import SwiftUI

class PerformanceDateModel: ObservableObject {
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())
}

struct PerformanceView: View {
    @StateObject private var dateModel = PerformanceDateModel()
    @State private var recoveryScore: Int? = nil
    @State private var sleepScore: Int? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        HStack(spacing: 20) {
                            NavigationLink(destination: RecoveryDetailView().environmentObject(dateModel)) {
                                ScoreGaugeView(
                                    title: "Recovery",
                                    score: recoveryScore,
                                    color: .green
                                )
                                .accessibilityLabel("Recovery Score: \(recoveryScore ?? 0)")
                            }
                            NavigationLink(destination: SleepDetailView().environmentObject(dateModel)) {
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
                .background(Color.black.ignoresSafeArea())
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
        isLoading = true
        errorMessage = nil
        HealthKitManager.shared.fetchScores(for: dateModel.selectedDate) { recovery, sleep, error in
            DispatchQueue.main.async {
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
                .foregroundColor(.gray)
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
        .background(Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.9))
        .cornerRadius(20)
    }
} 