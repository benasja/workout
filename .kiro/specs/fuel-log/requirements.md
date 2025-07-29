# Requirements Document

## Introduction

The Fuel Log feature is a comprehensive nutrition tracking module for an existing iOS 17+ health application. This feature will provide users with a powerful, offline-first food logging system that rivals market leaders like MyFitnessPal. The module will be built using modern SwiftUI, SwiftData, and HealthKit integration, following MVVM architecture principles with a focus on data-driven users who demand high performance and information density.

The feature will be implemented as a new tab in the main TabView, providing seamless integration with the existing health application while maintaining complete self-containment for modularity and maintainability.

## Requirements

### Requirement 1: User Onboarding and Profile Setup

**User Story:** As a new user, I want the app to automatically set up my profile by pulling my physical data from HealthKit and guide me to set my nutritional goals so I can start tracking immediately.

#### Acceptance Criteria

1. WHEN the user first launches the Fuel Log feature THEN the system SHALL request authorization for relevant HealthKit data types (bodyMass, height, dateOfBirth, biologicalSex)
2. WHEN HealthKit authorization is granted THEN the system SHALL automatically fetch the user's weight, height, age, and sex from HealthKit
3. WHEN user physical data is retrieved THEN the system SHALL calculate BMR using the Mifflin-St Jeor formula
4. WHEN BMR is calculated THEN the system SHALL prompt the user to select an activity level (Sedentary, Lightly Active, Moderately Active, Very Active, Extremely Active)
5. WHEN activity level is selected THEN the system SHALL calculate TDEE (Total Daily Energy Expenditure)
6. WHEN TDEE is calculated THEN the system SHALL prompt the user to select a goal (Cut, Maintain, Bulk) which pre-fills calorie and macronutrient targets
7. WHEN goal is selected THEN the system SHALL allow the user to manually override all calorie and macronutrient goals
8. WHEN nutritional goals are finalized THEN the system SHALL persist all user settings locally using SwiftData
9. IF HealthKit data is unavailable THEN the system SHALL provide manual input forms for all required physical data

### Requirement 2: Daily Dashboard and Progress Visualization

**User Story:** As a user, I want a daily dashboard that gives me an immediate, clear overview of my caloric and macronutrient consumption against my goals.

#### Acceptance Criteria

1. WHEN the user opens the Fuel Log tab THEN the system SHALL display a prominent circular progress view showing Calories Consumed / Calorie Goal
2. WHEN the dashboard loads THEN the system SHALL display three distinct linear progress bars for Protein, Carbohydrates, and Fats
3. WHEN progress is displayed THEN the system SHALL show clear, large-font text displaying the "remaining" values for calories and each macronutrient
4. WHEN the dashboard loads THEN the system SHALL display a list sectioned by meal type (Breakfast, Lunch, Dinner, Snacks) showing all logged food items for the current day
5. WHEN new food is logged THEN the dashboard SHALL update instantly to reflect the new consumption data
6. WHEN a nutritional goal is completed THEN the system SHALL provide sensory feedback using .sensoryFeedback
7. WHEN the user navigates between dates THEN the system SHALL maintain the same dashboard layout with data for the selected date
8. WHEN no food is logged for a day THEN the system SHALL display appropriate empty state messaging

### Requirement 3: Barcode Scanning Functionality

**User Story:** As a user, I want to quickly scan product barcodes to automatically retrieve and log nutritional information without manual data entry.

#### Acceptance Criteria

1. WHEN the user taps the barcode scan button THEN the system SHALL present a full-screen scanner view using DataScannerViewController
2. WHEN a barcode is detected THEN the system SHALL provide haptic feedback to confirm successful detection
3. WHEN a barcode is successfully scanned THEN the system SHALL automatically query the external food API for product information
4. WHEN product data is retrieved THEN the system SHALL display the food information for user confirmation before logging
5. WHEN the scanner is active THEN the system SHALL provide clear visual indicators for the scanning area
6. WHEN scanning fails or times out THEN the system SHALL provide appropriate error messaging and fallback options
7. WHEN the user cancels scanning THEN the system SHALL return to the previous view without logging any data

### Requirement 4: Food Search and Database Integration

**User Story:** As a user, I need a powerful search interface to find foods from both external databases and my personal saved items.

#### Acceptance Criteria

1. WHEN the user taps the search button THEN the system SHALL present a search interface with a text input field
2. WHEN the user types in the search field THEN the system SHALL query both the external food API and local custom foods database
3. WHEN search results are returned THEN the system SHALL display them in a prioritized list (local custom foods first, then API results)
4. WHEN the user selects a search result THEN the system SHALL display detailed nutritional information for confirmation
5. WHEN search queries fail THEN the system SHALL provide appropriate error messaging and offline alternatives
6. WHEN no results are found THEN the system SHALL offer the option to create a custom food item
7. WHEN the user performs frequent searches THEN the system SHALL cache recent results for improved performance

### Requirement 5: Custom Food and Meal Creation

**User Story:** As a user, I want to create and save my own food items and composite meals for easy reuse in future logging.

#### Acceptance Criteria

1. WHEN the user selects "Create Custom Food" THEN the system SHALL present an intuitive form for entering food details (name, calories, protein, carbs, fat per serving)
2. WHEN custom food data is entered THEN the system SHALL validate all nutritional values for reasonableness
3. WHEN a custom food is saved THEN the system SHALL persist it locally using SwiftData for future reuse
4. WHEN the user creates a composite meal THEN the system SHALL allow adding multiple food items with specified quantities
5. WHEN a composite meal is saved THEN the system SHALL calculate and store total nutritional values
6. WHEN the user searches for foods THEN custom foods and meals SHALL appear in search results
7. WHEN the user wants to edit custom items THEN the system SHALL provide modification capabilities
8. WHEN custom items are deleted THEN the system SHALL remove them from local storage and search results

### Requirement 6: Quick Add Functionality

**User Story:** As a user, I want to quickly log raw macronutrient values when I don't need to associate them with a specific food item.

#### Acceptance Criteria

1. WHEN the user selects "Quick Add" THEN the system SHALL present a simplified form for entering calories, protein, carbs, and fat values
2. WHEN quick add values are entered THEN the system SHALL validate that the macronutrient calories align with total calories
3. WHEN quick add is submitted THEN the system SHALL log the entry with a generic name and current timestamp
4. WHEN quick add entries are created THEN they SHALL appear in the daily food log with clear identification as quick entries
5. WHEN the user wants to edit quick entries THEN the system SHALL provide modification capabilities
6. WHEN quick add is used THEN the system SHALL update daily totals immediately

### Requirement 7: Data Persistence and Synchronization

**User Story:** As a user, I want all my food logging data to be reliably stored locally and remain accessible even when offline.

#### Acceptance Criteria

1. WHEN any food is logged THEN the system SHALL persist the data locally using SwiftData
2. WHEN the app is offline THEN all core functionality SHALL remain available using local data
3. WHEN user settings are modified THEN they SHALL be immediately persisted to local storage
4. WHEN the app launches THEN it SHALL load all user data from local SwiftData storage
5. WHEN data corruption is detected THEN the system SHALL provide recovery mechanisms
6. WHEN storage limits are approached THEN the system SHALL provide data management options

### Requirement 8: HealthKit Integration and Data Export

**User Story:** As a user, I want my nutrition data to integrate with HealthKit so it's available to other health apps and services.

#### Acceptance Criteria

1. WHEN food is logged THEN the system SHALL optionally write nutrition data to HealthKit (with user permission)
2. WHEN HealthKit integration is enabled THEN the system SHALL respect user privacy preferences
3. WHEN nutrition goals are set THEN the system SHALL use HealthKit data for accurate calculations
4. WHEN the user revokes HealthKit permissions THEN the system SHALL continue functioning with local data only
5. WHEN HealthKit data is unavailable THEN the system SHALL provide manual alternatives

### Requirement 9: Performance and User Experience

**User Story:** As a user, I expect the app to be fast, responsive, and provide a smooth experience even with large amounts of logged data.

#### Acceptance Criteria

1. WHEN the user navigates to the Fuel Log tab THEN the interface SHALL load within 500ms
2. WHEN searching for foods THEN results SHALL appear within 2 seconds for network queries
3. WHEN logging food THEN the UI SHALL update immediately with optimistic updates
4. WHEN the app handles large datasets THEN performance SHALL remain consistent
5. WHEN network requests fail THEN the system SHALL provide graceful degradation
6. WHEN the user interacts with the interface THEN all animations SHALL be smooth and responsive
7. WHEN the app is backgrounded and resumed THEN the current state SHALL be preserved