# Work: Complete Health & Fitness Ecosystem

## Overview

**Work** is a next-generation iOS health and fitness app built with SwiftUI, SwiftData, and deep HealthKit integration. It provides advanced, evidence-based analytics for recovery, sleep, and performance, powered by your real Apple Health data. The app features a modern, accessible UI, AI-powered insights, and a comprehensive workout management system.

---

## Table of Contents

1. [App Architecture](#app-architecture)
2. [Core Features](#core-features)
3. [Data Models](#data-models)
4. [Key Algorithms](#key-algorithms)
5. [HealthKit Integration](#healthkit-integration)
6. [Persistence & Storage](#persistence--storage)
7. [Testing & Quality](#testing--quality)
8. [Known Issues & TODOs](#known-issues--todos)
9. [What Needs to Be Done](#what-needs-to-be-done)
10. [Documentation & File Cleanup](#documentation--file-cleanup)
11. [Contributing & Support](#contributing--support)

---

## Core Features

# Work App - Feature List

## Core Application Features

### Today Dashboard
- Real-time health and recovery metrics
- Personalized insights and recommendations
- Quick actions: Start workout, add journal, log weight
- Health metrics grid: HRV, RHR, sleep, activity

### Complete Fitness Module ("Digital Logbook")
- **Live Workout Tracker**: Frictionless gym experience with one-handed operation
  - Real-time workout timer with elapsed time display
  - Smart set logging with weight/rep defaults from previous sessions
  - Automatic rest timer with notifications (90s default, customizable)
  - Quick exercise addition mid-workout
  - Set type tracking: Warmup, working, drop set, failure, back-off
- **Exercise Library**: Comprehensive, searchable database
  - 50+ pre-loaded exercises with detailed instructions
  - Filter by body part (Chest, Back, Shoulders, Legs, etc.)
  - Custom exercise creation with user-defined categories
  - Exercise detail pages with progress visualization
- **Workout Programs**: Intelligent routine management
  - Create custom programs with selected exercises
  - Quick program selection to start workouts
  - Program-based workout tracking
- **Advanced Analytics & Progress Tracking**:
  - Personal Records (PRs) with best set identification using e1RM
  - Estimated 1-Rep Max calculations using Brzycki formula
  - Interactive Swift Charts with gradient fills and scrubbing
  - Volume tracking per session and exercise
  - Historical performance graphs showing strength progression
- **Workout History**: Complete session logging
  - Chronological workout list with filtering (week/month/all time)
  - Detailed workout breakdowns with exercise-by-exercise analysis
  - Total volume, duration, and set count tracking
  - Exercise performance comparison across sessions

### Health Analytics
- Recovery score: HRV, RHR, sleep, stress
- Sleep score: Duration, efficiency, deep/REM, HR dip, consistency
- Dynamic baselines: Personalized from 60-90 day history
- Correlation engine: Lifestyle factors vs. health metrics
- Trend analysis: Interactive charts and progress

### Journal & Lifestyle Tracking
- Daily journal: Tags for alcohol, caffeine, stress, etc.
- Supplement tracking: Creatine, vitamins, magnesium, etc.
- Notes and reflections
- Insights based on journal and health data

### Weight Tracking
- Manual and HealthKit-synced entries
- CSV import/export
- Trend visualization

### Insights & Analytics
- AI-powered recommendations
- Correlation discovery: Actionable lifestyle insights
- Weekly and monthly trends

### User Experience
- Modern SwiftUI interface
- Dark/light mode
- Accessibility: VoiceOver, dynamic type, high contrast
- Haptic feedback
- Smooth animations and loading states

### Privacy & Security
- All data stored locally on device
- Strict HealthKit privacy compliance
- No cloud sync by default

### Hydration Tracker
- Log daily water intake with one tap (200ml, 500ml, 700ml buttons)
- Animated circular progress gauge visualizes progress toward your hydration goal
- Intake/goal text always visible, with celebratory feedback when goal is reached
- Edit hydration goal per day or globally (with toggle)
- Reset button to clear daily intake
- Data persists across date changes and app restarts
- Accessible from the More tab

---

## Planned & In-Progress Features
- Apple Watch companion app
- Machine learning predictions
- Social/community features
- Nutrition and meal tracking
- More advanced analytics and forecasting

---

For technical details, algorithms, and architecture, see the main [README.md](README.md).

---

## App Architecture

- **Entry Point:** `workApp.swift` initializes the app, sets up the SwiftData model container, and launches the `MainTabView`.
- **Navigation:** The app uses a 5-tab structure:
  - **Today:** Performance dashboard (`PerformanceView`)
  - **Recovery:** Detailed recovery analytics (`RecoveryDetailView`)
  - **Sleep:** Advanced sleep scoring (`SleepDetailView`)
  - **Train:** Workout library and session management (`WorkoutLibraryView`)
  - **More:** Access to weight tracker, journal, analytics, settings, and more
- **State Management:** Uses `@StateObject`, `@EnvironmentObject`, and SwiftData's `@Query` for reactive data flow.
- **Modern UI:** Built with SwiftUI 5, supports dark/light mode, accessibility, and haptic feedback.

---

## Data Models

All models are defined in `work/Models/` and use SwiftData for persistence.

### Core Health Models
- **UserProfile:** Stores user info, height, experience, and goals.
- **DailyJournal:** Tracks daily lifestyle factors, supplements, notes, and health metrics.
- **WeightEntry:** Body weight tracking, supports manual and HealthKit entries.
- **ScoreHistory:** Stores historical recovery and sleep scores for trend analysis.
- **HydrationLog:** Tracks daily water intake and hydration goal. Integrated with DataManager for all hydration operations.

### Fitness Models (Complete Digital Logbook System)
- **ExerciseDefinition:** Comprehensive exercise library with instructions, muscle groups, equipment, and user-created flag
- **WorkoutProgram:** Simple program structure linking exercises for quick workout starts
- **WorkoutSession:** Complete workout representation with date, duration, program name, and relationships to sets
- **WorkoutSet:** Individual set with weight, reps, date, set type, and computed e1RM property using Brzycki formula
- **CompletedExercise:** Links exercises to workout sessions for organization and history tracking

### Legacy Fitness Models (Maintained for Compatibility)
- **Program/ProgramDay/ProgramExercise:** Advanced workout programs with progression rules and periodization

---

## Key Algorithms

### Recovery Score (see `RecoveryScoreCalculator.swift`)

- **Formula:**  
  `Total_Recovery_Score = (HRV * 0.50) + (RHR * 0.25) + (Sleep * 0.15) + (Stress * 0.10)`
- **HRV Component:** Piecewise, baseline of 75, logarithmic growth above baseline, exponential decay below.
- **RHR Component:** Piecewise, baseline of 75, logarithmic for lower RHR, exponential for higher.
- **Sleep Component:** Uses the final sleep score (see below).
- **Stress Component:** Weighted deviations from baseline for walking HR, respiratory rate, and oxygen saturation.

### Sleep Score (see `SleepScoreCalculator.swift`)

- **Formula:**  
  `Total_Sleep_Score = (Restoration * 0.45) + (Efficiency * 0.30) + (Consistency * 0.25) * Duration_Multiplier`
- **Restoration:** Deep sleep (13-23%), REM (20-35%), HR dip (autonomic recovery).
- **Efficiency:** Sleep efficiency (time asleep / time in bed).
- **Consistency:** Deviation from 14-day average bedtime/wake time.
- **Duration Multiplier:** Penalizes short (<6h) or long (>9h) sleep.

### Correlation Engine

- **Analyzes:** Relationships between lifestyle tags (alcohol, late eating, stress, etc.) and health metrics (sleep, recovery, HRV).
- **Methods:** T-tests, effect size, confidence intervals, multi-factor regression.
- **Insights:** Actionable recommendations and reliability scoring.

### Fitness Analytics

- **Estimated 1-Rep Max (e1RM):** Uses Brzycki formula: `weight / (1.0278 - (0.0278 × reps))` for reps ≤ 10
- **Personal Records:** Automatically identifies best sets using highest e1RM values across all workout history
- **Volume Tracking:** Calculates total volume per session: `Σ(weight × reps)` for each exercise
- **Progress Visualization:** Charts highest e1RM per session over time to show true strength progression
- **Set Type Classification:** Warmup, working, drop set, failure, and back-off sets with different visual indicators

---

## HealthKit Integration

- **Permissions:** Requests read access to HRV, RHR, sleep, respiratory rate, walking HR, oxygen saturation, active energy, workouts, and body mass.
- **Sync:** Real-time and background data fetching, with robust error handling.
- **Baselines:** 60-day and 14-day rolling averages for all key metrics.
- **Debugging:** Extensive console output for troubleshooting authorization and data issues.

---

## Persistence & Storage

- **SwiftData:** All models use SwiftData for local, on-device storage.
- **Autosave:** Enabled for all models.
- **ScoreHistory:** Uses JSON file in the app's document directory for historical scores.
- **Weight Data:** Supports CSV import/export for weight entries.
- **Baseline Data:** Persisted in `UserDefaults` for fast access and recalibration.

---

## Testing & Quality

- **Unit Tests:**  
  - `SleepScoreCalculatorTests.swift` covers optimal, poor, and moderate sleep scenarios, as well as normalization and component calculations.
  - `workTests.swift` is a placeholder for general tests.
- **Manual Testing:**  
  - All major features are exercised in the UI.
  - Debug info and error messages are present throughout the app.
- **Known Gaps:**  
  - Some computed properties (e.g., `UserProfile.currentWeight`, `WorkoutSession.setCount`, `CompletedExercise.totalVolume`) are placeholders and calculated in views.
  - No automated UI tests for navigation or accessibility.

---

## Known Issues & TODOs

- **Algorithm Bugs:**  
  - Some scoring edge cases (see SLEEP_AND_RECOVERY_FORMULAS.md issues section) may need further calibration.
  - REM sleep penalty may be too harsh; RHR scoring may be too generous.
- **UI/UX:**  
  - Some "Coming Soon" placeholders (e.g., Edit Program).
  - Trends visualization in `EnhancedPerformanceView` is not fully implemented.
- **Persistence:**  
  - Some computed properties are not persisted and rely on view logic.
- **HealthKit:**  
  - If HealthKit permissions are not granted, some features will not work.
  - Beat-to-beat HRV analysis is prepared but not fully implemented.
- **Testing:**  
  - Broader test coverage needed for edge cases, error handling, and UI flows.
- **Documentation:**  
  - Some .md files are redundant or outdated (see below).

---

## What Needs to Be Done

1. **Algorithm Refinement:**
   - Address known scoring bugs (see SLEEP_AND_RECOVERY_FORMULAS.md).
   - Further calibrate REM sleep and RHR scoring.
   - Add more test cases for edge scenarios.

2. **UI/UX Improvements:**
   - Complete "Edit Program" and other "Coming Soon" features.
   - Implement full trends visualization in EnhancedPerformanceView.
   - Add more accessibility tests and improvements.

3. **Testing:**
   - Expand unit tests for all major algorithms and data flows.
   - Add UI tests for navigation, error states, and accessibility.

4. **HealthKit:**
   - Finalize beat-to-beat HRV analysis.
   - Improve error handling for missing or partial HealthKit data.

5. **Documentation & File Cleanup:**
   - Remove or merge redundant .md files:
     - **KEEP:** `README.md`, `FEATURES.md`, `CHANGELOG.md`
     - **MERGE/REMOVE:** All formulas and algorithm details should be consolidated into a single "Algorithms.md" or the README
   - Update README with the latest architecture, algorithms, and troubleshooting info.

6. **General Codebase:**
   - Replace all placeholder computed properties with real queries or calculations.
   - Ensure all error messages are user-friendly and actionable.
   - Continue to refactor for clarity, maintainability, and performance.

---

## Documentation & File Cleanup

**Recommended .md file structure:**
- `README.md` (main overview, setup, usage, architecture)
- `FEATURES.md` (detailed feature list)
- `CHANGELOG.md` (version history)
- Remove or merge all other .md files as above.

---

## Usage

### Using the Hydration Tracker

1. Go to the **More** tab and select **Hydration**.
2. Tap a water button (200ml, 500ml, 700ml) to log intake. The circular gauge animates to show your progress.
3. Tap the pencil icon to edit your daily hydration goal. Use the toggle to apply the goal to all days.
4. Use the reset button to set today’s intake to zero.
5. Your hydration data is saved automatically and persists across app restarts.

---

## Contributing & Support

- **Development:** Fork, branch, PR workflow. Follow Swift style guidelines.
- **Testing:** Add/expand unit and UI tests for all new features.
- **Support:**  
  - Email: support@workapp.com  
  - GitHub Issues/Discussions for bugs and feature requests.

---

## Final Notes

- The app is robust, modern, and well-architected, but there are still areas for improvement, especially in algorithm calibration, UI polish, and test coverage.
- All code compiles and runs, and the app uses only real HealthKit data (no demo data).
- The project is ready for further development, refinement, and scaling.

---

**This document is now your single source of truth for the Work app. Use it for onboarding, planning, and as a reference for all future development.** 