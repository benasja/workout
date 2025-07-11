import SwiftUI

struct DateSliderView: View {
    @Binding var selectedDate: Date
    private let dates: [Date] = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<30).map { calendar.date(byAdding: .day, value: -$0, to: today)! }
    }()
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(dates, id: \.self) { date in
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    Button(action: { selectedDate = date }) {
                        VStack(spacing: 2) {
                            Text(dayOfWeek(for: date))
                                .font(.caption2)
                                .foregroundColor(isSelected ? .primary : .secondary)
                            Text(shortDateString(for: date))
                                .font(.subheadline)
                                .fontWeight(isSelected ? .bold : .regular)
                                .foregroundColor(isSelected ? .primary : .secondary)
                        }
                        .padding(8)
                        .background(isSelected ? AppColors.primary.opacity(0.15) : AppColors.secondaryBackground)
                        .cornerRadius(8)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(dayOfWeek(for: date)), \(shortDateString(for: date))")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }
    
    private func shortDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    private func dayOfWeek(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

#Preview {
    DateSliderView(selectedDate: .constant(Date()))
        .padding()
} 