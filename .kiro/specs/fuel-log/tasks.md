# Implementation Plan

- [x] 1. Set up core SwiftData models and data foundation
  - Create SwiftData models for FoodLog, CustomFood, NutritionGoals with proper relationships and validation
  - Implement model computed properties for nutrition calculations and data integrity
  - Add models to the existing SwiftData container configuration
  - Write unit tests for model validation and computed properties
  - _Requirements: 7.1, 7.2, 7.4_

- [x] 2. Extend HealthKit integration for nutrition data
  - Extend existing HealthKitManager with nutrition-specific authorization requests (bodyMass, height, dateOfBirth, biologicalSex)
  - Implement async functions to fetch user physical data (weight, height, age, sex) from HealthKit
  - Add BMR calculation using Mifflin-St Jeor formula
  - Implement HealthKit write capabilities for nutrition data (dietaryEnergyConsumed, dietaryProtein, etc.)
  - Write unit tests for HealthKit nutrition integration
  - _Requirements: 1.1, 1.2, 1.3, 8.1, 8.2_

- [x] 3. Create FuelLogRepository for data access abstraction
  - Implement FuelLogRepository protocol and concrete implementation using SwiftData
  - Add methods for CRUD operations on FoodLog, CustomFood, and NutritionGoals
  - Implement date-based queries for daily food logs with proper sorting
  - Add error handling and data validation in repository methods
  - Write comprehensive unit tests for repository operations
  - _Requirements: 7.1, 7.3, 7.5_

- [x] 4. Implement network layer for food database integration
  - Create FoodNetworkManager with Open Food Facts API integration
  - Implement Codable structs for OpenFoodFactsResponse and related models
  - Add async methods for barcode lookup and food name search
  - Implement proper error handling, rate limiting, and network timeout handling
  - Add caching mechanism for API responses to support offline functionality
  - Write unit tests for network operations and error scenarios
  - _Requirements: 4.1, 4.2, 4.5, 9.2, 9.5_

- [x] 5. Create user onboarding and goal setting functionality
  - Implement NutritionGoalsViewModel for managing user goals and calculations
  - Create onboarding flow views for HealthKit authorization and physical data collection
  - Add activity level selection UI with TDEE calculation
  - Implement goal selection (Cut/Maintain/Bulk) with automatic macro calculations
  - Add manual override capabilities for all nutritional targets
  - Write unit tests for goal calculations and validation logic
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8_

- [x] 6. Build core FuelLogViewModel and business logic
  - Create FuelLogViewModel with @Published properties for UI state management
  - Implement daily food log loading and real-time totals calculation
  - Add food logging functionality with optimistic UI updates
  - Implement date navigation and data filtering
  - Add error handling and loading states for all operations
  - Write comprehensive unit tests for ViewModel business logic
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 9.1, 9.3_

- [x] 7. Create daily dashboard UI with progress visualization
  - Implement FuelLogDashboardView as the main nutrition tracking interface
  - Create circular progress view component for calorie tracking
  - Build linear progress bars for protein, carbohydrates, and fat macros
  - Add meal-sectioned food log list with proper grouping and sorting
  - Implement sensory feedback for goal completion milestones
  - Add date navigation controls and empty state handling
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.7, 2.8_

- [x] 8. Implement barcode scanning functionality
  - Create DataScannerView using DataScannerViewController for barcode detection
  - Implement UIViewControllerRepresentable wrapper for SwiftUI integration
  - Add haptic feedback and visual indicators for successful barcode detection
  - Create barcode result processing and food data retrieval flow
  - Implement error handling for scanning failures and unsupported barcodes
  - Add camera permission handling and user guidance
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [x] 9. Build food search and selection interface
  - Create FoodSearchViewModel for managing search state and results
  - Implement FoodSearchView with real-time search capabilities
  - Add search result display with local and API results prioritization
  - Create food detail view for nutrition information confirmation
  - Implement search result caching and offline fallback functionality
  - Add empty states and error handling for search operations
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_

- [x] 10. Create custom food and meal creation functionality
  - Implement CustomFoodCreationView with comprehensive nutrition input form
  - Add form validation for nutritional values and data consistency
  - Create composite meal builder for multi-ingredient recipes
  - Implement custom food editing and deletion capabilities
  - Add custom food search integration and reuse functionality
  - Write unit tests for custom food validation and persistence
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8_

- [x] 11. Implement quick add functionality for raw macros
  - Create QuickAddView with simplified macro input interface
  - Add macro-to-calorie validation and consistency checking
  - Implement quick add entry creation with generic naming
  - Add quick add entries to daily food log with proper identification
  - Implement editing capabilities for quick add entries
  - Add real-time daily totals updates for quick add operations
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

- [x] 12. Integrate Fuel Log tab into main application
  - Add Fuel Log tab to existing MainTabView with proper navigation
  - Extend DataManager to include nutrition-related data operations
  - Integrate with existing date model and tab selection patterns
  - Add proper environment object passing for shared state
  - Implement tab-specific styling and icon selection
  - Test navigation flow and state preservation
  - _Requirements: 2.1, 7.1, 9.1_

- [x] 13. Add comprehensive error handling and user feedback
  - Implement FuelLogError enum with localized error descriptions
  - Add error state handling in all ViewModels with user-friendly messages
  - Create error recovery mechanisms and retry functionality
  - Implement graceful degradation for network and HealthKit failures
  - Add loading states and progress indicators for long-running operations
  - Write unit tests for error handling scenarios
  - _Requirements: 4.5, 8.4, 9.5, 9.6_

- [x] 14. Implement data persistence and offline functionality
  - Add SwiftData persistence for all user-created content (custom foods, goals)
  - Implement offline caching for API responses and search results
  - Create data synchronization logic for HealthKit integration
  - Add data export and backup capabilities
  - Implement data cleanup and storage management
  - Write integration tests for offline functionality
  - _Requirements: 7.1, 7.2, 7.3, 7.5, 7.6, 9.2_

- [x] 15. Add performance optimizations and caching
  - Implement lazy loading for food logs and search results
  - Add image caching for food photos and barcode results
  - Optimize SwiftData queries with proper predicates and limits
  - Implement request debouncing for search operations
  - Add background processing for network requests and calculations
  - Write performance tests and benchmarks
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.7_

- [x] 16. Create comprehensive unit and integration tests
  - Write unit tests for all ViewModels with mock dependencies
  - Create integration tests for HealthKit and network operations
  - Add UI tests for critical user flows (onboarding, logging, search)
  - Implement performance tests for dashboard loading and search
  - Create mock data generators for testing scenarios
  - Add test coverage reporting and quality gates
  - _Requirements: All requirements - testing validation_

- [x] 17. Implement accessibility and user experience enhancements
  - Add VoiceOver support for all interactive elements
  - Implement Dynamic Type support for text scaling
  - Add haptic feedback for key interactions and goal completions
  - Create high contrast mode compatibility
  - Implement keyboard navigation support
  - Add accessibility labels and hints for complex UI elements
  - _Requirements: 2.6, 9.6, 9.7_

- [x] 18. Final integration testing and polish
  - Perform end-to-end testing of complete user workflows
  - Test integration with existing app features and data
  - Validate HealthKit data flow and privacy compliance
  - Test offline functionality and data synchronization
  - Perform memory leak detection and performance profiling
  - Add final UI polish and animation refinements
  - _Requirements: All requirements - final validation_