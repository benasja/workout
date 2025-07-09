import SwiftUI

struct SupplementsView: View {
    @State private var selectedTime: TimeOfDay = .morning
    @State private var supplementLog: [TimeOfDay: Set<Supplement>] = [
        .morning: [], .midday: [], .evening: []
    ]
    var tabSelection: Binding<Int>?
    
    let allSupplements: [Supplement] = [
        .creatine, .vitaminC, .vitaminD, .vitaminB, .magnesium, .zinc, .omega3, .multivitamin, .probiotic
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Picker("Time of Day", selection: $selectedTime) {
                    ForEach(TimeOfDay.allCases, id: \.self) { time in
                        Text(time.displayName).tag(time)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                ModernCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Supplements for \(selectedTime.displayName)")
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 16)], spacing: 16) {
                            ForEach(allSupplements, id: \.self) { supplement in
                                SupplementToggle(
                                    supplement: supplement,
                                    isOn: supplementLog[selectedTime, default: []].contains(supplement),
                                    toggle: {
                                        if supplementLog[selectedTime, default: []].contains(supplement) {
                                            supplementLog[selectedTime]?.remove(supplement)
                                        } else {
                                            supplementLog[selectedTime, default: []].insert(supplement)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Supplements")
            .navigationBarTitleDisplayMode(.large)
            .background(AppColors.background)
        }
    }
    
    enum TimeOfDay: String, CaseIterable {
        case morning, midday, evening
        var displayName: String {
            switch self {
            case .morning: return "Morning"
            case .midday: return "Midday"
            case .evening: return "Evening"
            }
        }
    }
    
    enum Supplement: String, CaseIterable, Hashable {
        case creatine = "Creatine"
        case vitaminC = "Vitamin C"
        case vitaminD = "Vitamin D"
        case vitaminB = "Vitamin B Complex"
        case magnesium = "Magnesium"
        case zinc = "Zinc"
        case omega3 = "Omega-3"
        case multivitamin = "Multivitamin"
        case probiotic = "Probiotic"
        
        var icon: String {
            switch self {
            case .creatine: return "bolt.heart.fill"
            case .vitaminC: return "sun.max.fill"
            case .vitaminD: return "sun.max"
            case .vitaminB: return "capsule.portrait.fill"
            case .magnesium: return "leaf.fill"
            case .zinc: return "drop.fill"
            case .omega3: return "fish.fill"
            case .multivitamin: return "pills.fill"
            case .probiotic: return "face.smiling"
            }
        }
    }
}

struct SupplementToggle: View {
    let supplement: SupplementsView.Supplement
    let isOn: Bool
    let toggle: () -> Void
    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Image(systemName: supplement.icon)
                    .font(.title2)
                    .foregroundColor(isOn ? .blue : .gray)
                Text(supplement.rawValue)
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isOn ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
} 