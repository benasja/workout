import SwiftUI
import UIKit

// MARK: - Accessibility Utilities

/// Utility class for managing accessibility features across the Fuel Log feature
struct AccessibilityUtils {
    
    // MARK: - VoiceOver Labels
    
    /// Creates accessible labels for nutrition progress
    static func nutritionProgressLabel(
        nutrient: String,
        current: Double,
        goal: Double,
        unit: String
    ) -> String {
        let percentage = goal > 0 ? Int((current / goal) * 100) : 0
        return "\(nutrient): \(Int(current)) of \(Int(goal)) \(unit), \(percentage) percent complete"
    }
    
    /// Creates accessible labels for calorie progress
    static func calorieProgressLabel(
        current: Double,
        goal: Double,
        remaining: Double
    ) -> String {
        let percentage = goal > 0 ? Int((current / goal) * 100) : 0
        return "Calories: \(Int(current)) consumed, \(Int(remaining)) remaining, \(percentage) percent of daily goal"
    }
    
    /// Creates accessible labels for food log entries
    static func foodLogLabel(
        name: String,
        calories: Double,
        protein: Double,
        carbohydrates: Double,
        fat: Double,
        servingSize: Double,
        servingUnit: String
    ) -> String {
        let serving = servingSize == 1.0 ? "1 \(servingUnit)" : "\(String(format: "%.1f", servingSize)) \(servingUnit)"
        return "\(name), \(serving), \(Int(calories)) calories, \(Int(protein)) grams protein, \(Int(carbohydrates)) grams carbohydrates, \(Int(fat)) grams fat"
    }
    
    /// Creates accessible labels for meal sections
    static func mealSectionLabel(
        mealType: MealType,
        totalCalories: Double,
        itemCount: Int
    ) -> String {
        let itemText = itemCount == 1 ? "1 item" : "\(itemCount) items"
        return "\(mealType.displayName) meal, \(Int(totalCalories)) calories, \(itemText)"
    }
    
    /// Creates accessible labels for search results
    static func searchResultLabel(
        name: String,
        calories: Double,
        protein: Double,
        carbohydrates: Double,
        fat: Double,
        isCustom: Bool
    ) -> String {
        let source = isCustom ? "custom food" : "food database"
        return "\(name) from \(source), \(Int(calories)) calories, \(Int(protein)) grams protein, \(Int(carbohydrates)) grams carbohydrates, \(Int(fat)) grams fat per serving"
    }
    
    // MARK: - VoiceOver Hints
    
    static let scanBarcodeHint = "Double tap to open barcode scanner"
    static let searchFoodHint = "Double tap to search for foods"
    static let quickAddHint = "Double tap to quickly add macronutrients"
    static let editFoodHint = "Double tap to edit this food entry"
    static let deleteFoodHint = "Double tap to delete this food entry"
    static let adjustServingHint = "Swipe up or down to adjust serving size"
    static let selectMealTypeHint = "Double tap to select meal type"
    static let navigationHint = "Swipe left or right to navigate between dates"
    
    // MARK: - Haptic Feedback
    
    /// Provides haptic feedback for successful actions
    static func successFeedback() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
    
    /// Provides haptic feedback for errors
    static func errorFeedback() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        #endif
    }
    
    /// Provides haptic feedback for warnings
    static func warningFeedback() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
    }
    
    /// Provides light impact feedback for selections
    static func selectionFeedback() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
    
    /// Provides medium impact feedback for important actions
    static func impactFeedback() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
    
    /// Provides heavy impact feedback for major achievements
    static func heavyImpactFeedback() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        #endif
    }
    
    // MARK: - Dynamic Type Support
    
    /// Returns appropriate font size based on Dynamic Type settings
    static func scaledFont(_ font: Font, maxSize: CGFloat? = nil) -> Font {
        if maxSize != nil {
            return font.weight(.regular) // Simplified for now, can be enhanced
        }
        return font
    }
    
    /// Returns scaled spacing based on Dynamic Type settings
    static func scaledSpacing(_ baseSpacing: CGFloat) -> CGFloat {
        let contentSizeCategory = UIApplication.shared.preferredContentSizeCategory
        
        switch contentSizeCategory {
        case .extraSmall, .small, .medium:
            return baseSpacing * 0.9
        case .large:
            return baseSpacing
        case .extraLarge, .extraExtraLarge:
            return baseSpacing * 1.1
        case .extraExtraExtraLarge:
            return baseSpacing * 1.2
        case .accessibilityMedium, .accessibilityLarge:
            return baseSpacing * 1.3
        case .accessibilityExtraLarge, .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
            return baseSpacing * 1.4
        default:
            return baseSpacing
        }
    }
    
    // MARK: - High Contrast Support
    
    /// Returns appropriate colors for high contrast mode
    static func contrastAwareColor(
        normal: Color,
        highContrast: Color
    ) -> Color {
        if UIAccessibility.isDarkerSystemColorsEnabled {
            return highContrast
        }
        return normal
    }
    
    /// Returns appropriate background colors for high contrast mode
    static func contrastAwareBackground() -> Color {
        if UIAccessibility.isDarkerSystemColorsEnabled {
            return Color.black
        }
        return AppColors.secondaryBackground
    }
    
    /// Returns appropriate text colors for high contrast mode
    static func contrastAwareText() -> Color {
        if UIAccessibility.isDarkerSystemColorsEnabled {
            return Color.white
        }
        return AppColors.textPrimary
    }
    
    // MARK: - Keyboard Navigation Support
    
    /// Determines if keyboard navigation is active
    static var isKeyboardNavigationActive: Bool {
        #if canImport(UIKit)
        return UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning
        #else
        return false
        #endif
    }
    
    // MARK: - Accessibility Announcements
    
    /// Posts accessibility announcements for important events
    static func announce(_ message: String) {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }
    
    /// Announces goal completion with celebration
    static func announceGoalCompletion(for nutrient: String) {
        let message = "\(nutrient) goal completed! Great job!"
        announce(message)
        heavyImpactFeedback()
    }
    
    /// Announces successful food logging
    static func announceFoodLogged(_ foodName: String) {
        let message = "\(foodName) added to food log"
        announce(message)
        successFeedback()
    }
    
    /// Announces food deletion
    static func announceFoodDeleted(_ foodName: String) {
        let message = "\(foodName) removed from food log"
        announce(message)
        selectionFeedback()
    }
    
    /// Announces barcode scan success
    static func announceBarcodeScanSuccess() {
        let message = "Barcode scanned successfully"
        announce(message)
        successFeedback()
    }
    
    /// Announces search results
    static func announceSearchResults(count: Int) {
        let message = count == 0 ? "No search results found" : 
                     count == 1 ? "1 search result found" : 
                     "\(count) search results found"
        announce(message)
    }
}

// MARK: - View Extensions for Accessibility

extension View {
    /// Adds comprehensive accessibility support to nutrition progress views
    func nutritionProgressAccessibility(
        nutrient: String,
        current: Double,
        goal: Double,
        unit: String
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(AccessibilityUtils.nutritionProgressLabel(
                nutrient: nutrient,
                current: current,
                goal: goal,
                unit: unit
            ))
            .accessibilityAddTraits(.updatesFrequently)
    }
    
    /// Adds accessibility support to food log entries
    func foodLogAccessibility(
        name: String,
        calories: Double,
        protein: Double,
        carbohydrates: Double,
        fat: Double,
        servingSize: Double,
        servingUnit: String,
        canEdit: Bool = false,
        canDelete: Bool = true
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(AccessibilityUtils.foodLogLabel(
                name: name,
                calories: calories,
                protein: protein,
                carbohydrates: carbohydrates,
                fat: fat,
                servingSize: servingSize,
                servingUnit: servingUnit
            ))
            .accessibilityHint(canEdit ? AccessibilityUtils.editFoodHint : AccessibilityUtils.deleteFoodHint)
            .accessibilityAddTraits(canEdit ? [.isButton] : [])
    }
    
    /// Adds accessibility support to action buttons
    func actionButtonAccessibility(
        label: String,
        hint: String
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(.isButton)
    }
    
    /// Adds accessibility support to search results
    func searchResultAccessibility(
        name: String,
        calories: Double,
        protein: Double,
        carbohydrates: Double,
        fat: Double,
        isCustom: Bool
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(AccessibilityUtils.searchResultLabel(
                name: name,
                calories: calories,
                protein: protein,
                carbohydrates: carbohydrates,
                fat: fat,
                isCustom: isCustom
            ))
            .accessibilityAddTraits(.isButton)
    }
    
    /// Adds Dynamic Type support with maximum scaling
    func dynamicTypeSize(maxSize: DynamicTypeSize = .accessibility3) -> some View {
        self.dynamicTypeSize(...maxSize)
    }
    
    /// Adds high contrast support
    func highContrastSupport() -> some View {
        self
            .foregroundColor(AccessibilityUtils.contrastAwareText())
            .background(AccessibilityUtils.contrastAwareBackground())
    }
    
    /// Adds keyboard navigation support
    func keyboardNavigationSupport() -> some View {
        self
            .focusable(AccessibilityUtils.isKeyboardNavigationActive)
    }
}

// MARK: - Accessibility Constants

struct AccessibilityIdentifiers {
    // Dashboard
    static let calorieProgress = "fuel_log_calorie_progress"
    static let proteinProgress = "fuel_log_protein_progress"
    static let carbProgress = "fuel_log_carb_progress"
    static let fatProgress = "fuel_log_fat_progress"
    
    // Action Buttons
    static let scanBarcodeButton = "fuel_log_scan_barcode"
    static let searchFoodButton = "fuel_log_search_food"
    static let quickAddButton = "fuel_log_quick_add"
    
    // Food Log
    static let breakfastSection = "fuel_log_breakfast_section"
    static let lunchSection = "fuel_log_lunch_section"
    static let dinnerSection = "fuel_log_dinner_section"
    static let snacksSection = "fuel_log_snacks_section"
    
    // Forms
    static let foodNameField = "fuel_log_food_name"
    static let caloriesField = "fuel_log_calories"
    static let proteinField = "fuel_log_protein"
    static let carbsField = "fuel_log_carbs"
    static let fatField = "fuel_log_fat"
    static let servingSizeField = "fuel_log_serving_size"
    
    // Navigation
    static let previousDayButton = "fuel_log_previous_day"
    static let nextDayButton = "fuel_log_next_day"
    static let dateDisplay = "fuel_log_date_display"
}