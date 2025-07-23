import SwiftUI
import SwiftData

struct SupplementsView: View {
    @EnvironmentObject private var dataManager: DataManager
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    
    // Supplement definitions (name, dosage)
    private let dailyHealthSupplements = [
        ("Omega 3", "500 EPA / 250 DHA"),
        ("Vitamin D3", "2000IU"),
        ("Vitamin C", "500mg"),
        ("Creatine", "5g")
    ]
    private let preWorkoutSupplements = [
        ("Caffeine", "200mg"),
        ("Beta Alanine", "4g"),
        ("Citrulline", "6g"),
        ("Salt", ""),
        ("Electrolytes", "")
    ]
    private let eveningRecoverySupplements = [
        ("Zinc", "40mg"),
        ("Magnesium Glycinate", "200mg"),
        ("Ashwagandha", "570mg")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Date Selection
                    DateSliderView(selectedDate: $selectedDate)
                        .padding(.top, 8)
                        .onChange(of: selectedDate) {
                            dataManager.fetchSupplementRecord(for: selectedDate)
                        }
                        .onAppear {
                            dataManager.fetchSupplementRecord(for: selectedDate)
                        }
                    // Cards
                    SupplementSectionCard(
                        title: "Daily Health",
                        supplements: dailyHealthSupplements,
                        selectedDate: selectedDate
                    )
                    SupplementSectionCard(
                        title: "Pre-Workout / Hydration",
                        supplements: preWorkoutSupplements,
                        selectedDate: selectedDate
                    )
                    SupplementSectionCard(
                        title: "Evening Recovery",
                        supplements: eveningRecoverySupplements,
                        selectedDate: selectedDate
                    )
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color(.secondarySystemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Supplements")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct SupplementSectionCard: View {
    let title: String
    let supplements: [(String, String)] // (name, dosage)
    let selectedDate: Date
    @EnvironmentObject private var dataManager: DataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 4)
            VStack(spacing: 10) {
                ForEach(supplements, id: \.0) { supplement in
                    SupplementCardButton(
                        name: supplement.0,
                        dosage: supplement.1,
                        isTaken: dataManager.isSupplementTaken(supplement.0),
                        onTap: {
                            dataManager.toggleSupplement(supplement.0, for: selectedDate)
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .padding(.vertical, 2)
    }
}

struct SupplementCardButton: View {
    let name: String
    let dosage: String
    let isTaken: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body.weight(.semibold))
                        .foregroundColor(isTaken ? .accentColor : .primary)
                    if !dosage.isEmpty {
                        Text(dosage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isTaken {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .transition(.scale)
                        .imageScale(.large)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isTaken ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
            )
            .animation(.easeInOut(duration: 0.18), value: isTaken)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SupplementsView()
        .modelContainer(for: [DailySupplementRecord.self], inMemory: true)
} 
