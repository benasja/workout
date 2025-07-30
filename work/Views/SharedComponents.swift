//
//  SharedComponents.swift
//  work
//
//  Created by Benas on 6/27/25.
//

import SwiftUI

// MARK: - TimeInterval Extension for Consistent Formatting
extension TimeInterval {
    /// Formats duration as "6h 50m" for consistent display across the app
    func formattedAsHoursAndMinutes() -> String {
        let totalMinutes = Int(self) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Formats duration as hours with one decimal place (e.g., "7.5h") - for backwards compatibility
    func formattedAsDecimalHours() -> String {
        let hours = self / 3600
        return String(format: "%.1fh", hours)
    }
}

extension Color {
    static let cardBackground = AppColors.secondaryBackground
    static let cardSelected = AppColors.tertiaryBackground
}

// MARK: - Shared Components

struct ScoreBreakdownRow: View {
    let component: String
    let score: Double
    let maxScore: Double
    let description: String? // Optional detailed description
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(component)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
                // For recovery scores, clamp to 100 and show as percentage
                let percentageScore = min(score, 100.0)
                Text("\(Int(percentageScore)) / 100")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            // Show detailed description if available
            if let description = description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Design System
struct AppColors {
    static let primary = Color(red: 0.2, green: 0.6, blue: 1.0) // Modern blue
    static let secondary = Color(red: 0.3, green: 0.8, blue: 0.6) // Fresh green
    static let accent = Color(red: 1.0, green: 0.6, blue: 0.2) // Energetic orange
    static let success = Color(red: 0.2, green: 0.8, blue: 0.4) // Success green
    static let warning = Color(red: 1.0, green: 0.7, blue: 0.0) // Warning yellow
    static let error = Color(red: 1.0, green: 0.3, blue: 0.3) // Error red
    
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let tertiaryBackground = Color(.tertiarySystemBackground)
    
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)
}

struct AppTypography {
    static let largeTitle = Font.largeTitle.weight(.bold)
    static let title1 = Font.title.weight(.bold)
    static let title2 = Font.title2.weight(.semibold)
    static let title3 = Font.title3.weight(.semibold)
    static let headline = Font.headline.weight(.semibold)
    static let body = Font.body
    static let callout = Font.callout
    static let subheadline = Font.subheadline
    static let footnote = Font.footnote
    static let caption = Font.caption
    static let caption2 = Font.caption2
}

struct AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

struct AppCornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
}

// MARK: - Enhanced Summary Card
struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let subtitle: String?
    
    init(title: String, value: String, icon: String, color: Color, subtitle: String? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                Spacer()
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(value)
                    .font(AppTypography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.lg)
        .background(AppColors.secondaryBackground)
        .cornerRadius(AppCornerRadius.md)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Modern Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.lg)
            .background(
                LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(AppCornerRadius.md)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.subheadline)
            .foregroundColor(AppColors.primary)
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.lg)
            .background(AppColors.primary.opacity(0.1))
            .cornerRadius(AppCornerRadius.md)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
    }
}

struct IconButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .foregroundColor(color)
            .frame(width: 44, height: 44)
            .background(color.opacity(0.1))
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Modern Card Components
struct ModernCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    
    init(padding: CGFloat = AppSpacing.lg, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(AppColors.secondaryBackground)
            .cornerRadius(AppCornerRadius.md)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Progress Indicators
struct CircularProgressView: View {
    let progress: Double
    let size: CGFloat
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Loading States
struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColors.primary)
            
            Text(message)
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
    }
}

// MARK: - Empty States
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(AppColors.textTertiary)
            
            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(AppTypography.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(message)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(AppTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(AppSpacing.lg)
                        .background(AppColors.primary)
                        .cornerRadius(AppCornerRadius.md)
                }
            }
        }
        .padding(AppSpacing.xxl)
    }
}

// MARK: - Section Headers
struct SectionHeaderView: View {
    let title: String
    let subtitle: String?
    let actionTitle: String?
    let action: (() -> Void)?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            Spacer()
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
    }
}

// MARK: - Extensions for Better UX
extension View {
    func modernCard() -> some View {
        self
            .padding(AppSpacing.lg)
            .background(AppColors.secondaryBackground)
            .cornerRadius(AppCornerRadius.md)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    func primaryButton() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }
    
    func secondaryButton() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }
    
    func iconButton(color: Color = AppColors.primary) -> some View {
        self.buttonStyle(IconButtonStyle(color: color))
    }
} 

// MARK: - Biomarker Trend Card
struct BiomarkerTrendCard: View {
    let title: String
    let value: Double
    let unit: String
    let percentageChange: Double?
    let trendData: [Double]
    let color: Color
    
    // Trend arrow logic
    private var trendIcon: Image {
        guard trendData.count >= 2 else { return Image(systemName: "arrow.right") }
        let last = trendData[trendData.count - 1]
        let prev = trendData[trendData.count - 2]
        if last > prev { return Image(systemName: "arrow.up.right") }
        if last < prev { return Image(systemName: "arrow.down.right") }
        return Image(systemName: "arrow.right")
    }
    private var trendColor: Color {
        guard trendData.count >= 2 else { return .gray }
        let last = trendData[trendData.count - 1]
        let prev = trendData[trendData.count - 2]
        if last > prev { return .green }
        if last < prev { return .red }
        return .gray
    }
    
    init(
        title: String,
        value: Double,
        unit: String,
        percentageChange: Double? = nil,
        trendData: [Double] = [],
        color: Color = .green
    ) {
        self.title = title
        self.value = value
        self.unit = unit
        self.percentageChange = percentageChange
        self.trendData = trendData
        self.color = color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            HStack {
                // Value and unit
                HStack(alignment: .bottom, spacing: 4) {
                    if unit == "h" {
                        // Format time as hh:mm instead of decimal hours
                        let timeInterval = value * 3600
                        Text(timeInterval.formattedAsHoursAndMinutes())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(String(format: "%.1f", value))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Trend indicator
                HStack(spacing: 4) {
                    if let change = percentageChange {
                        Text(String(format: "%+.1f%%", change))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(change >= 0 ? .green : .red)
                    }
                    // Trend arrow
                    trendIcon
                        .font(.title3)
                        .foregroundColor(trendColor)
                        .padding(.leading, 2)
                }
            }
        }
        .padding(12)
        .background(AppColors.secondaryBackground)
        .cornerRadius(12)
    }
    
    private func accessibilityValueString() -> String {
        if unit == "h" {
            let timeInterval = value * 3600
            return timeInterval.formattedAsHoursAndMinutes()
        } else if unit == "ms" || unit == "bpm" || unit == "%" {
            return "\(Int(value)) \(unit)"
        } else {
            return "\(String(format: "%.1f", value)) \(unit)"
        }
    }
}

// MARK: - Score Display Card
struct ScoreDisplayCard: View {
    let title: String
    let score: Int
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("\(score)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AppColors.background)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Metric Card (Shared)
struct MetricCard: View {
    let title: String
    let value: Double?
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 2) {
                if let value = value {
                    Text("\(String(format: "%.0f", value))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                } else {
                    Text("--")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
                Text("\(title) (\(unit))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(AppColors.secondaryBackground)
        .cornerRadius(12)
    }
}

// MARK: - Insight Row (Shared)
struct InsightRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 16)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}


// MARK: - Error View
struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                retryAction()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
    }
}





// MARK: - Meal Type Button (Shared Component)
struct MealTypeButton: View {
    let mealType: MealType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            action()
            AccessibilityUtils.selectionFeedback()
        }) {
            VStack(spacing: AccessibilityUtils.scaledSpacing(AppSpacing.sm)) {
                Image(systemName: mealType.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : AppColors.primary)
                    .accessibilityHidden(true)
                
                Text(mealType.displayName)
                    .font(AppTypography.subheadline)
                    .foregroundColor(isSelected ? .white : AccessibilityUtils.contrastAwareText())
                    .dynamicTypeSize(maxSize: .accessibility2)
            }
            .frame(maxWidth: .infinity)
            .padding(AccessibilityUtils.scaledSpacing(AppSpacing.md))
            .background(
                isSelected ? 
                AccessibilityUtils.contrastAwareColor(
                    normal: AppColors.primary,
                    highContrast: Color.blue
                ) : 
                AccessibilityUtils.contrastAwareBackground()
            )
            .cornerRadius(AppCornerRadius.md)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(mealType.displayName)
        .accessibilityHint(AccessibilityUtils.selectMealTypeHint)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview
struct SharedComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            BiomarkerTrendCard(
                title: "Resting HRV",
                value: 58,
                unit: "ms",
                percentageChange: 8,
                trendData: [45, 52, 48, 55, 58, 62, 58],
                color: .green
            )
            
            ScoreDisplayCard(
                title: "Recovery Score",
                score: 85,
                subtitle: "Primed for peak performance",
                color: .green
            )
        }
        .padding()
        .background(AppColors.background)
    }
} 