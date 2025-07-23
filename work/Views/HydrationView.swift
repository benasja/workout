import SwiftUI
import SwiftData

struct WaterIntakeOption: Hashable {
    let icon: String
    let label: String
    let amount: Int
}

struct HydrationView: View {
    @EnvironmentObject private var dataManager: DataManager
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var animateGoalReached = false
    @State private var showGoalSheet = false
    @State private var newGoalText = ""
    @State private var didCelebrate = false
    @State private var applyToAllDays = false
    
    private let waterOptions: [WaterIntakeOption] = [
        WaterIntakeOption(icon: "drop.fill", label: "+200ml", amount: 200),
        WaterIntakeOption(icon: "cup.and.saucer.fill", label: "+500ml", amount: 500),
        WaterIntakeOption(icon: "mug.fill", label: "+700ml", amount: 700)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Date Selection
                DateSliderView(selectedDate: $selectedDate)
                    .padding(.top, 8)
                    .onChange(of: selectedDate) {
                        dataManager.fetchHydrationLog(for: selectedDate)
                        animateGoalReached = false
                        didCelebrate = false
                    }
                    .onAppear {
                        dataManager.fetchHydrationLog(for: selectedDate)
                    }
                // Card
                hydrationCard
                // Water Buttons
                waterButtons
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(AppColors.secondaryBackground.ignoresSafeArea())
        .navigationTitle("Hydration")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: dataManager.currentHydrationLog?.currentIntakeInML) {
            if let log = dataManager.currentHydrationLog, log.currentIntakeInML >= log.goalInML {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    animateGoalReached = true
                }
                if !didCelebrate {
                    if #available(iOS 17.0, *) {
                        DispatchQueue.main.async {
                            _ = sensoryFeedback(.success, trigger: true)
                        }
                    } else {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    }
                    didCelebrate = true
                }
            } else {
                animateGoalReached = false
                didCelebrate = false
            }
        }
        .sheet(isPresented: $showGoalSheet) {
            goalEditSheet
        }
    }
    
    private var hydrationCard: some View {
        let log = dataManager.currentHydrationLog
        let rawIntake = Double(log?.currentIntakeInML ?? 0)
        let goal = Double(log?.goalInML ?? 2500)
        let currentIntake = min(max(rawIntake, 0), max(goal, 1)) // Clamp to 0...goal, avoid 0 goal
        let progress = min(currentIntake / max(goal, 1), 1.0)
        let goalReached = (log?.currentIntakeInML ?? 0) >= (log?.goalInML ?? 2500)
        let textColor: Color = goalReached && animateGoalReached ? .green : AppColors.primary
        
        return VStack(spacing: 0) {
            // Gauge at the top
            Gauge(value: currentIntake, in: 0...max(goal, 1)) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            } minimumValueLabel: {
                EmptyView()
            } maximumValueLabel: {
                EmptyView()
            }
            .gaugeStyle(.accessoryCircular)
            .tint(
                goalReached && animateGoalReached ?
                    AnyShapeStyle(.green) :
                    AnyShapeStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom))
            )
            .scaleEffect(1.4)
            .frame(width: 180, height: 180)
            .animation(.easeInOut(duration: 0.5), value: progress)
            // Intake/goal text and edit button below the gauge
            VStack(spacing: 8) {
                Text("\(log?.currentIntakeInML ?? 0) / \(log?.goalInML ?? 2500) ml")
                    .font(.title3.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundColor(textColor)
                    .animation(.easeInOut(duration: 0.5), value: textColor)
                // Goal reached message below the intake/goal text
                if goalReached && animateGoalReached {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.green)
                        Text("Goal Reached!")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.top, 16)
            // Move edit/reset buttons below water buttons
            HStack(spacing: 24) {
                Button(action: {
                    newGoalText = String(log?.goalInML ?? 2500)
                    showGoalSheet = true
                }) {
                    Label("Edit Goal", systemImage: "pencil")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Edit hydration goal")
                Button(action: {
                    dataManager.resetHydrationIntake(for: selectedDate)
                }) {
                    Label("Reset Intake", systemImage: "arrow.counterclockwise")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Reset intake for today")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }
    
    private var waterButtons: some View {
        HStack(spacing: 16) {
            ForEach(waterOptions, id: \.self) { option in
                if #available(iOS 17.0, *) {
                    Button(action: {
                        dataManager.addWater(amountInML: option.amount, for: selectedDate)
                    }) {
                        VStack(spacing: 6) {
                            // Fallback for bottle icon if not available
                            if option.icon == "bottle.fill" && !UIImage.isSymbolAvailable("bottle.fill") {
                                Image(systemName: "drop.fill")
                                    .font(.title2)
                                    .foregroundColor(AppColors.primary)
                            } else {
                                Image(systemName: option.icon)
                                    .font(.title2)
                                    .foregroundColor(AppColors.primary)
                            }
                            Text(option.label)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 18)
                        .padding(.horizontal, 20)
                        .background(
                            Capsule()
                                .fill(AppColors.primary.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact, trigger: true)
                } else {
                    Button(action: {
                        dataManager.addWater(amountInML: option.amount, for: selectedDate)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }) {
                        VStack(spacing: 6) {
                            if option.icon == "bottle.fill" && !UIImage.isSymbolAvailable("bottle.fill") {
                                Image(systemName: "drop.fill")
                                    .font(.title2)
                                    .foregroundColor(AppColors.primary)
                            } else {
                                Image(systemName: option.icon)
                                    .font(.title2)
                                    .foregroundColor(AppColors.primary)
                            }
                            Text(option.label)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 18)
                        .padding(.horizontal, 20)
                        .background(
                            Capsule()
                                .fill(AppColors.primary.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 8)
    }
    
    private var goalEditSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Set Daily Hydration Goal")
                    .font(.headline)
                TextField("Goal in ml", text: $newGoalText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 120)
                    .multilineTextAlignment(.center)
                Toggle("Apply to all days", isOn: $applyToAllDays)
                    .padding(.horizontal)
                Button("Save") {
                    if let newGoal = Int(newGoalText), newGoal > 0 {
                        if applyToAllDays {
                            dataManager.updateHydrationGoalForAllDays(newGoal: newGoal)
                        } else {
                            dataManager.updateHydrationGoal(newGoal: newGoal, for: selectedDate)
                        }
                        showGoalSheet = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showGoalSheet = false }
                }
            }
        }
    }
}

// Helper to check if SF Symbol exists (for fallback)
extension UIImage {
    static func isSymbolAvailable(_ name: String) -> Bool {
        return UIImage(systemName: name) != nil
    }
}

#Preview {
    HydrationView()
        .environmentObject(DataManager(modelContext: try! ModelContainer(for: HydrationLog.self).mainContext))
} 