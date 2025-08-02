import SwiftUI
import SwiftData

struct WaterIntakeOption: Hashable {
    let icon: String
    let label: String
    let amount: Int
    let description: String
}

struct HydrationView: View {
    @EnvironmentObject private var dataManager: DataManager
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var animateGoalReached = false
    @State private var showGoalSheet = false
    @State private var showCustomAmountSheet = false
    @State private var showCalendar = false
    @State private var newGoalText = ""
    @State private var customAmountText = ""
    @State private var didCelebrate = false
    @State private var applyToAllDays = false
    @State private var showingErrorAlert = false
    @State private var showingResetAlert = false
    @State private var errorMessage = ""
    
    private let waterOptions: [WaterIntakeOption] = [
        WaterIntakeOption(icon: "drop.fill", label: "200ml", amount: 200, description: "Glass"),
        WaterIntakeOption(icon: "cup.and.saucer.fill", label: "500ml", amount: 500, description: "Bottle"),
        WaterIntakeOption(icon: "mug.fill", label: "700ml", amount: 700, description: "Large")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Enhanced Date Navigator
                enhancedDateNavigator
                    .padding(.top, 8)
                
                // Main Hydration Card
                mainHydrationCard
                
                // Quick Add Buttons
                quickAddSection
                
                // 7-Day History
                historySection
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Hydration")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: selectedDate) {
            do {
                try dataManager.fetchHydrationLog(for: selectedDate)
            } catch {
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
            animateGoalReached = false
            didCelebrate = false
        }
        .onAppear {
            do {
                try dataManager.fetchHydrationLog(for: selectedDate)
            } catch {
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
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
        .sheet(isPresented: $showCustomAmountSheet) {
            customAmountSheet
        }
        .sheet(isPresented: $showCalendar) {
            calendarSheet
        }
        .alert("Save Failed", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text("Unable to save your changes: \(errorMessage)")
        }
        .alert("Reset Water Intake", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetWaterIntake()
            }
        } message: {
            Text("Are you sure you want to reset your water intake for this day? This action cannot be undone.")
        }
    }
    
    // MARK: - Enhanced Date Navigator
    private var enhancedDateNavigator: some View {
        HStack(spacing: 12) {
            // Scrollable date picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(dateRange, id: \.self) { date in
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        
                        Button(action: { selectedDate = date }) {
                            VStack(spacing: 4) {
                                Text(dayOfWeek(for: date))
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(isSelected ? .white : .secondary)
                                    .textCase(.uppercase)
                                
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(isSelected ? .white : .primary)
                            }
                            .frame(width: 56, height: 64)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(isSelected ? Color.blue : Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // Calendar button
            Button(action: { showCalendar = true }) {
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundColor(.primary)
                    .frame(width: 56, height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Main Hydration Card
    private var mainHydrationCard: some View {
        let log = dataManager.currentHydrationLog
        let currentIntake = log?.currentIntakeInML ?? 0
        let goal = log?.goalInML ?? 2000
        let progress = min(Double(currentIntake) / Double(goal), 1.0)
        let goalReached = currentIntake >= goal
        let streak = calculateStreak()
        
        return VStack(spacing: 0) {
            // Header with refresh button
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                    Text("Daily Hydration")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Refresh/Reset button with "spill" concept
                Button(action: {
                    showingResetAlert = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.triangle")
                            .font(.system(size: 14, weight: .medium))
                        Text("Reset")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset water intake for this day")
                .accessibilityHint("Double tap to reset your water intake to zero")
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            
            // Circular Progress
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 192, height: 192)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 192, height: 192)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                
                // Center content
                VStack(spacing: 4) {
                    Text("\(currentIntake)")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("/ \(goal) ml")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(.bottom, 24)
            
            // Status indicators
            VStack(spacing: 12) {
                if goalReached {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green.opacity(0.8))
                        Text("Goal Reached! 🎉")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green.opacity(0.9))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.2))
                    )
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "target")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        Text("\(goal - currentIntake)ml to go")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                    )
                }
                
                if streak > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange.opacity(0.8))
                        Text("\(streak) day streak")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.orange.opacity(0.9))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.2))
                    )
                }
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
    
    // MARK: - Quick Add Section
    private var quickAddSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Add")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack(spacing: 12) {
                ForEach(waterOptions, id: \.self) { option in
                    Button(action: {
                        addWater(amount: option.amount)
                    }) {
                        VStack(spacing: 12) {
                            // Icon container
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 48, height: 48)
                                
                                Image(systemName: option.icon)
                                    .font(.title3)
                                    .foregroundColor(.white)
                            }
                            
                            // Text content
                            VStack(spacing: 2) {
                                Text(option.label)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text(option.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.blue.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 0.1), value: false)
                }
            }
            
            // Custom amount button
            Button(action: { showCustomAmountSheet = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text("Custom Amount")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.systemGray6))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }
    
    // MARK: - History Section
    private var historySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("7-Day History")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(getHistoryData(), id: \.date) { dayData in
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dayData.label)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("\(dayData.intake)ml of \(dayData.goal)ml")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(progressColor(for: dayData.percentage))
                                        .frame(width: geometry.size.width * min(dayData.percentage / 100, 1.0), height: 8)
                                        .animation(.easeInOut(duration: 0.3), value: dayData.percentage)
                                }
                            }
                            .frame(width: 80, height: 8)
                            
                            // Percentage and trophy
                            HStack(spacing: 8) {
                                Text("\(Int(dayData.percentage))%")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 44, alignment: .trailing)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                
                                if dayData.percentage >= 100 {
                                    Image(systemName: "trophy.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.green)
                                }
                            }
                            .frame(width: 68)
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemGray6))
                    )
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }
    
    // MARK: - Helper Methods
    private var dateRange: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<31).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }
    
    private func dayOfWeek(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private func addWater(amount: Int) {
        do {
            try dataManager.addWater(amountInML: amount, for: selectedDate)
            
            if #available(iOS 17.0, *) {
                // Sensory feedback for iOS 17+
            } else {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
    
    private func resetWaterIntake() {
        do {
            // Reset the data first
            try dataManager.resetHydrationIntake(for: selectedDate)
            
            // Then animate the UI changes
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                // Reset celebration state with animation
                animateGoalReached = false
                didCelebrate = false
            }
            
            // Provide haptic feedback for the reset action
            if #available(iOS 17.0, *) {
                // Light impact feedback for reset
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
    
    private func calculateStreak() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        
        // Check backwards from today to find consecutive days where goal was reached
        for i in 0..<30 { // Check up to 30 days back
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let (intake, goal) = getHydrationDataForDate(date)
            
            if intake >= goal {
                streak += 1
            } else {
                break // Streak is broken
            }
        }
        
        return streak
    }
    
    private func getHistoryData() -> [HistoryData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var historyData: [HistoryData] = []
        
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let label = i == 0 ? "Today" : i == 1 ? "Yesterday" : "\(i) days ago"
            
            // Fetch real data from DataManager
            let (intake, goal) = getHydrationDataForDate(date)
            let percentage = goal > 0 ? Double(intake) / Double(goal) * 100 : 0
            
            historyData.append(HistoryData(
                date: date,
                label: label,
                intake: intake,
                goal: goal,
                percentage: percentage
            ))
        }
        
        return historyData
    }
    
    private func getHydrationDataForDate(_ date: Date) -> (intake: Int, goal: Int) {
        return dataManager.getHydrationDataForDate(date)
    }
    
    private func progressColor(for percentage: Double) -> Color {
        if percentage >= 100 {
            return .green
        } else if percentage >= 80 {
            return .blue
        } else {
            return .yellow
        }
    }
    
    // MARK: - Sheet Views
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
                        do {
                            if applyToAllDays {
                                try dataManager.updateHydrationGoalForAllDays(newGoal: newGoal)
                            } else {
                                try dataManager.updateHydrationGoal(newGoal: newGoal, for: selectedDate)
                            }
                            showGoalSheet = false
                        } catch {
                            errorMessage = error.localizedDescription
                            showingErrorAlert = true
                        }
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
    
    private var customAmountSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Add Custom Amount")
                    .font(.headline)
                
                TextField("e.g., 350", text: $customAmountText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 120)
                    .multilineTextAlignment(.center)
                
                Button("Add Water") {
                    if let amount = Int(customAmountText), amount > 0 {
                        addWater(amount: amount)
                        customAmountText = ""
                        showCustomAmountSheet = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Custom Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { 
                        customAmountText = ""
                        showCustomAmountSheet = false 
                    }
                }
            }
        }
    }
    
    private var calendarSheet: some View {
        NavigationView {
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showCalendar = false }
                }
            }
        }
    }
}

// MARK: - Supporting Types
struct HistoryData {
    let date: Date
    let label: String
    let intake: Int
    let goal: Int
    let percentage: Double
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