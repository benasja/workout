# Implementation Plan

- [ ] 1. Set up new data models and update model container
  - Create new Supplement and SupplementLog SwiftData models with proper relationships and validation
  - Update workApp.swift model container to include new Supplement and SupplementLog models
  - Test model creation and basic CRUD operations with unit tests
  - _Requirements: 3.1, 5.1, 5.2_

- [ ] 2. Implement Weight Tracker CSV export functionality
  - Create WeightCSVExporter class with exportWeightDataToCSV method that queries all WeightEntry objects
  - Format weight data into standard CSV string with date,weight columns
  - Implement ShareLink integration to present share sheet for CSV file saving
  - Add export functionality to WeightTrackerView toolbar menu
  - _Requirements: 1.1, 1.2_

- [ ] 3. Implement Weight Tracker CSV import functionality
  - Create WeightCSVImporter class with importWeightDataFromCSV method using DocumentPicker
  - Implement CSV parsing logic with proper error handling for invalid data
  - Add duplicate detection logic to avoid creating duplicate WeightEntry objects for existing dates
  - Integrate import functionality into WeightTrackerView toolbar menu with user feedback
  - _Requirements: 1.3, 1.4, 1.5, 1.6_

- [ ] 4. Create supplement data seeding system
  - Implement SupplementDataSeeder class with seedDefaultSupplements method
  - Create morning supplement stack: Omega 3 (500/250 EPA/DHA), Vitamin D3 (2000IU), Vitamin C (500mg), Creatine (5g)
  - Create evening supplement stack: Zinc (40mg), Magnesium Glycinate (200mg), Ashwagandha (570mg)
  - Integrate seeding into app launch sequence in workApp.swift with existence check
  - _Requirements: 3.1, 4.1, 4.4_

- [ ] 5. Build new SupplementTrackerView with auto-save functionality
  - Create SupplementTrackerView.swift with DateSliderView at top for date selection
  - Implement morning and evening sections that query Supplement objects by timeOfDay
  - Add supplement display with name, dosage, and tappable checkbox for each supplement
  - Implement auto-save logic that immediately persists SupplementLog changes to SwiftData on checkbox tap
  - _Requirements: 3.2, 3.3, 3.4_

- [ ] 6. Implement supplement state restoration and persistence
  - Add logic to query SupplementLog objects matching supplement name and selected date for checkbox state
  - Implement automatic state restoration when view appears or date changes
  - Create or update SupplementLog objects when user toggles supplement checkboxes
  - Ensure state persistence across app restarts and date navigation
  - _Requirements: 3.5, 3.6, 3.7_

- [ ] 7. Refactor Journal view for auto-saving tag interactions
  - Modify JournalView.swift to implement immediate SwiftData persistence on tag tap
  - Update tag toggle logic to find or create DailyJournal object for selected date
  - Remove manual save button and implement automatic saving on tag state changes
  - Ensure tag state changes are immediately reflected in UI and persisted to SwiftData
  - _Requirements: 2.1, 2.2_

- [ ] 8. Implement Journal state restoration system
  - Add logic to query SwiftData for DailyJournal object when selectedDate changes or view appears
  - Restore saved tag states from DailyJournal object and update UI accordingly
  - Handle cases where no journal entry exists for selected date by displaying unselected tags
  - Ensure consistent state restoration across app sessions and date navigation
  - _Requirements: 2.3, 2.4, 2.5, 2.6_

- [ ] 9. Create exercise library data seeding system
  - Implement ExerciseDataSeeder class with seedExerciseLibrary method
  - Create exercise definitions for chest: Bench Press, Dumbbell Press, Incline Dumbbell Press, Dips
  - Create exercise definitions for back: Pull-ups, Barbell Row, Deadlift, Lat Pulldowns
  - Create exercise definitions for legs: Barbell Squat, Leg Press, Romanian Deadlift, Leg Curls, Calf Raises
  - Create exercise definitions for shoulders: Overhead Press, Lateral Raises, Face Pulls
  - Create exercise definitions for arms: Barbell Curl, Skull Crushers, Tricep Pushdowns
  - _Requirements: 4.2, 4.3_

- [ ] 10. Integrate exercise seeding into app launch
  - Add exercise seeding call to workApp.swift seedDataIfNeeded method
  - Implement existence check to prevent duplicate exercise creation
  - Ensure ExerciseDefinition objects are properly saved to SwiftData with correct muscle group categorization
  - Verify exercise library view displays seeded exercises organized by muscle groups
  - _Requirements: 4.4, 4.5_

- [ ] 11. Implement comprehensive error handling and user feedback
  - Add error handling for CSV import/export operations with user-friendly error messages
  - Implement error handling for SwiftData persistence operations across all modified views
  - Add loading states and user feedback for async operations like CSV processing
  - Create error recovery mechanisms where possible and inform users of available actions
  - _Requirements: 1.6, 5.3, 6.1, 6.2, 6.3_

- [ ] 12. Add performance optimizations and testing
  - Optimize SwiftData queries with proper predicates and sorting for large datasets
  - Implement background processing for heavy operations like CSV import/export
  - Add unit tests for data models, CSV operations, and business logic components
  - Test state restoration and auto-save functionality across different scenarios
  - _Requirements: 6.4, 6.5, 6.6_