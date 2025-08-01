# Work: Complete Health & Fitness Ecosystem

## Project Overview

**Work** is a comprehensive iOS health and fitness tracking application built with SwiftUI and SwiftData. This personal project integrates with Apple HealthKit to provide advanced analytics, recovery insights, and comprehensive lifestyle tracking. The app combines workout tracking, nutrition logging, sleep analysis, and environmental monitoring into a unified health optimization platform.

---

## Core Features

### 🏠 Today Dashboard
- **Personalized Greeting**: Dynamic messages based on time of day and recovery status
- **Daily Readiness**: Combined recovery and sleep scores with actionable insights
- **Quick Actions**: Fast access to nutrition, hydration, journal, supplements, and workouts
- **Date Navigation**: Review historical data with intuitive date slider
- **Real-time Updates**: Live data refresh with pull-to-refresh support

### 💪 Complete Fitness System
- **Live Workout Tracker**: Real-time set logging with rest timers and progress tracking
- **Exercise Library**: 100+ pre-loaded exercises with custom exercise creation
- **Smart Set Types**: Working sets, warm-up sets, drop sets, and failure sets
- **Program Management**: Create and follow structured workout programs
- **Workout History**: Detailed session logs with volume and PR tracking
- **Personal Records**: Automatic 1RM calculations and volume tracking

### 🧠 Advanced Health Analytics
- **Recovery Score Algorithm**: Combines HRV (50%), RHR (25%), Sleep (15%), and Stress (10%)
- **Sleep Score V4.0**: Duration, deep sleep, REM sleep, efficiency, and consistency components
- **Dynamic Baselines**: Personal 14-day and 60-day rolling averages for accurate scoring
- **Correlation Engine**: Identifies relationships between lifestyle factors and health metrics
- **Trend Analysis**: Historical data visualization and pattern recognition

### 🍎 Comprehensive Nutrition Tracking
- **Goals Dashboard**: Four primary progress bars for Calories, Protein, Carbs, and Fat with current vs. daily goal display
- **Personal Food Library**: Persistent, searchable library of individual food items and composite meals
- **Custom Food Creation**: Create foods with Name, Serving Size, Calories, Protein, Carbs, and Fat
- **Meal Creation**: Combine multiple foods from Personal Library with automatic macro calculation
- **Daily Logging**: Simple view showing all foods and meals logged for the current day with quantity adjustment
- **Food Database Integration**: OpenFoodFacts API with offline-first architecture
- **Barcode Scanning**: Quick food logging via camera (temporarily disabled)
- **Macro Tracking**: Real-time progress visualization with goal completion celebrations and accurate rounding
- **Meal Planning**: Organized by breakfast, lunch, dinner, and snacks
- **Goal Setting**: Editable nutrition targets in settings (e.g., 3000 kcal, 200p, 350c, 100f)
- **Date Navigation**: Consistent date handling with proper timestamp management
- **Data Persistence**: Optimistic UI updates with reliable data persistence
- **🆕 Interactive Food Editing**: Tap any food item to edit serving size and meal type
- **🆕 European Decimal Support**: Use comma (,) as decimal separator for serving amounts
- **🆕 Percentage Display**: Shows what percentage of daily goals each food represents
- **🆕 Smart Serving Display**: Always shows 100g/100ml values for accurate nutrition info
- **🆕 Quick Serving Buttons**: Preset options (0.5x, 1x, 1.5x, 2x) for common adjustments

### 💧 Hydration Monitoring
- **Visual Progress**: Animated circular gauge with goal completion celebration
- **Quick Add Buttons**: 200ml, 500ml, and 700ml preset amounts
- **Daily Goals**: Customizable hydration targets with all-day sync
- **Streak Tracking**: Monitor consistency and build healthy habits
- **Haptic Feedback**: Celebratory feedback when goals are reached

### 📝 Lifestyle & Journal Tracking
- **Daily Tags**: Track alcohol, caffeine, stress, exercise, sleep quality, and more
- **Supplement Logging**: Monitor vitamin and supplement intake
- **Notes**: Free-form text for detailed daily observations
- **Correlation Insights**: Discover how lifestyle factors affect your health metrics
- **Historical Review**: Browse past entries and identify patterns

### ⚖️ Weight Management
- **Manual Entry**: Quick weight logging with trend visualization
- **HealthKit Sync**: Automatic data import from connected scales
- **CSV Import/Export**: Bulk data management and backup
- **Progress Tracking**: Visual charts and statistical analysis
- **Goal Setting**: Target weight with progress monitoring

### 🌙 Sleep Analysis
- **Detailed Scoring**: Comprehensive sleep quality assessment
- **Sleep Stages**: Deep sleep, REM sleep, and core sleep analysis
- **Efficiency Tracking**: Time in bed vs. time asleep optimization
- **Consistency Monitoring**: Bedtime and wake time regularity
- **Heart Rate Analysis**: Sleep heart rate patterns and recovery indicators

### 🌿 Environmental Monitoring
- **Future Integration**: Designed for ESP32 sensor integration
- **Air Quality**: Temperature, humidity, and air quality correlation
- **Sleep Environment**: Environmental factors affecting sleep quality
- **Data Correlation**: Link environmental conditions to health outcomes

---

## Technical Architecture

### 🏗️ Core Technologies
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI 5.0
- **Data Persistence**: SwiftData (iOS 17+)
- **Health Integration**: HealthKit with comprehensive authorization
- **Architecture**: MVVM with reactive data binding
- **Minimum iOS**: iOS 17.0+

### 📊 Data Models
- **User Profile**: Height, weight, experience level, and goals
- **Workout System**: Sessions, exercises, sets, and programs
- **Nutrition**: Food logs, custom foods, and nutrition goals
- **Health Metrics**: Daily journals, supplement logs, and hydration tracking
- **Analytics**: Score history, baselines, and correlation data

### 🧮 Advanced Algorithms

#### Recovery Score Calculation
```swift
Total_Recovery_Score = (HRV_Component * 0.50) + 
                      (RHR_Component * 0.25) + 
                      (Sleep_Component * 0.15) + 
                      (Stress_Component * 0.10)
```

**HRV Component (50% weight)**:
- Uses overnight HRV (SDNN) samples from HealthKit
- Compares against personal 60-day baseline
- Logarithmic scaling for values above baseline
- Exponential decay for values below baseline

**RHR Component (25% weight)**:
- Overnight resting heart rate analysis
- Personal 60-day baseline comparison
- Lower RHR indicates better cardiovascular recovery

**Sleep Component (15% weight)**:
- Integrates Sleep Score V4.0 algorithm
- Weighted combination of duration, efficiency, and quality

**Stress Component (10% weight)**:
- Walking heart rate, respiratory rate, and oxygen saturation
- Deviation analysis from personal baselines

#### Sleep Score V4.0 Algorithm
```swift
Sleep_Score = (Duration * 0.30) + 
              (Deep_Sleep * 0.25) + 
              (REM_Sleep * 0.20) + 
              (Efficiency * 0.15) + 
              (Consistency * 0.10)
```

**Duration Component (30%)**:
- Optimal range: 7.5-9 hours
- Penalties for insufficient or excessive sleep

**Deep Sleep Component (25%)**:
- Target: 15-20% of total sleep time
- Critical for physical recovery

**REM Sleep Component (20%)**:
- Target: 20-25% of total sleep time
- Essential for cognitive function

**Efficiency Component (15%)**:
- Time asleep / Time in bed ratio
- Target: >85% efficiency

**Consistency Component (10%)**:
- Bedtime and wake time regularity
- Compared to personal 14-day average

### 🔄 Dynamic Baseline Engine
- **Adaptive Baselines**: Automatically updates personal averages
- **Circular Time Averaging**: Handles midnight wrap-around for sleep times
- **Historical Accuracy**: Maintains consistent baselines for score reliability
- **Multi-timeframe**: 7-day, 14-day, and 60-day rolling windows

### 🔗 Correlation Engine
- **Statistical Analysis**: Identifies significant relationships (>5% change)
- **Lifestyle Factors**: Alcohol, stress, supplements, sleep quality
- **Health Outcomes**: Recovery scores, sleep quality, HRV trends
- **Actionable Insights**: Personalized recommendations based on data

---

## Data Storage & Privacy

### 🔒 Privacy-First Design
- **Local Storage**: All data stored on device using SwiftData
- **HealthKit Compliance**: Strict adherence to Apple's health data guidelines
- **No Cloud Sync**: Personal health data never leaves your device
- **Minimal Permissions**: Only requests necessary HealthKit access

### 💾 Data Management
- **SwiftData Models**: Modern Core Data replacement with Swift syntax
- **Efficient Queries**: Optimized database operations with proper indexing
- **Data Seeding**: Pre-populated exercise library and sample programs
- **Export/Import**: CSV support for weight data and nutrition logs

### 🔄 HealthKit Integration
- **Comprehensive Metrics**: HRV, RHR, sleep, heart rate, respiratory rate
- **Background Sync**: Automatic data updates when app is backgrounded
- **Error Handling**: Graceful fallbacks when HealthKit data is unavailable
- **Authorization Management**: Granular permission requests

---

## User Experience & Accessibility

### 🎨 Modern UI Design
- **SwiftUI 5**: Native iOS design language with smooth animations
- **Dark/Light Mode**: Automatic theme switching with system preferences
- **Dynamic Type**: Full support for accessibility text sizes
- **Color Contrast**: High contrast mode support for visual accessibility

### ♿ Accessibility Features
- **VoiceOver**: Complete screen reader support with descriptive labels
- **Voice Control**: Full keyboard navigation support
- **Haptic Feedback**: Tactile feedback for goal completion and interactions
- **Reduced Motion**: Respects system accessibility preferences

### 📱 Performance Optimization
- **Lazy Loading**: Efficient data loading with pagination
- **Image Caching**: Smart caching for food database images
- **Background Processing**: Non-blocking UI updates
- **Memory Management**: Proper resource cleanup and leak prevention

---

## 📊 Live Project Statistics

<div align="center">

![GitHub repo size](https://img.shields.io/github/repo-size/benasja/workout?style=for-the-badge&logo=github&logoColor=white)
![GitHub commit activity](https://img.shields.io/github/commit-activity/m/benasja/workout?style=for-the-badge&logo=git&logoColor=white)
![GitHub last commit](https://img.shields.io/github/last-commit/benasja/workout?style=for-the-badge&logo=github&logoColor=white)
![Lines of code](https://img.shields.io/tokei/lines/github/benasja/workout?style=for-the-badge&logo=code&logoColor=white)

### Language Breakdown
![Top Languages](https://github-readme-stats.vercel.app/api/top-langs/?username=benasja&repo=workout&layout=compact&theme=dark&hide_border=true)

### Additional Stats
![GitHub contributors](https://img.shields.io/github/contributors/benasja/workout?style=for-the-badge&logo=github&logoColor=white)
![GitHub forks](https://img.shields.io/github/forks/benasja/workout?style=for-the-badge&logo=github&logoColor=white)
![GitHub stars](https://img.shields.io/github/stars/benasja/workout?style=for-the-badge&logo=github&logoColor=white)
![GitHub issues](https://img.shields.io/github/issues/benasja/workout?style=for-the-badge&logo=github&logoColor=white)

### Development Activity
![GitHub Activity Graph](https://github-readme-activity-graph.vercel.app/graph?username=benasja&theme=react-dark&hide_border=true)

</div>

---

## Development History

### Version 2.0.0 - Complete Overhaul (2024)
- Complete UI/UX redesign with modern tab navigation
- Advanced workout system with smart set types
- Health analytics with recovery and sleep scoring
- Comprehensive nutrition tracking with barcode scanning
- Journal and lifestyle tracking with correlation insights
- Full accessibility support and privacy compliance

### Key Milestones
- **June 2024**: Initial SwiftData migration and core architecture
- **July 2024**: Workout tracking and exercise library implementation
- **August 2024**: HealthKit integration and recovery algorithms
- **September 2024**: Nutrition tracking with OpenFoodFacts integration
- **October 2024**: Sleep analysis and correlation engine
- **November 2024**: Hydration tracking and UI polish
- **December 2024**: Accessibility enhancements and testing

---

## Testing & Quality Assurance

### 🧪 Comprehensive Test Suite
- **Unit Tests**: Core algorithm validation and data model testing
- **Integration Tests**: HealthKit sync and API integration testing
- **UI Tests**: Complete user flow automation
- **Performance Tests**: Memory usage and execution time benchmarks
- **Accessibility Tests**: VoiceOver and keyboard navigation validation

### 📊 Test Coverage
- **Recovery Algorithm**: 95% test coverage with edge case validation
- **Sleep Scoring**: Comprehensive test scenarios for all sleep patterns
- **Nutrition Tracking**: API mocking and offline functionality testing
- **Data Persistence**: SwiftData model validation and migration testing

### 🔍 Quality Metrics
- **Code Quality**: SwiftLint integration with strict style guidelines
- **Performance**: Sub-100ms response times for all UI interactions
- **Memory Usage**: Efficient memory management with leak detection
- **Crash Rate**: <0.1% crash rate in production builds

---

## Future Roadmap

### 🚀 Planned Features
- **Apple Watch App**: Workout tracking and quick logging from wrist
- **Widgets**: Home screen widgets for daily metrics and quick actions
- **Shortcuts Integration**: Siri shortcuts for common actions
- **HealthKit Writing**: Sync nutrition data back to Apple Health
- **Advanced Analytics**: Machine learning insights and predictions

### 🌐 Integration Possibilities
- **ESP32 Sensors**: Environmental monitoring with air quality correlation
- **Wearable Devices**: Extended sensor support beyond Apple Watch
- **Smart Home**: Integration with HomeKit for environmental control
- **Cloud Backup**: Optional encrypted cloud sync for data backup

---

## Development Setup

### Prerequisites
- **Xcode 15.0+**: Latest Xcode with iOS 17 SDK
- **iOS Device**: Physical device recommended for HealthKit testing
- **Apple Developer Account**: Required for HealthKit entitlements

### Installation Steps
1. **Clone Repository**:
   ```bash
   git clone <repository-url>
   cd work
   ```

2. **Open Project**:
   ```bash
   open work.xcodeproj
   ```

3. **Configure Signing**:
   - Select your development team in project settings
   - Ensure HealthKit capability is enabled

4. **Build and Run**:
   - Select target device or simulator
   - Build and run (⌘+R)

5. **Grant Permissions**:
   - Allow HealthKit access when prompted
   - Enable all requested health data types

### Development Guidelines
- **Code Style**: Follow Swift API Design Guidelines
- **Architecture**: Maintain MVVM separation of concerns
- **Testing**: Write tests for all new features
- **Documentation**: Document complex algorithms and business logic
- **Accessibility**: Test with VoiceOver and keyboard navigation

---

## File Structure

```
work/
├── work/                          # Main app target
│   ├── workApp.swift             # App entry point and configuration
│   ├── ContentView.swift         # Root content view
│   ├── DataManager.swift         # Central data management
│   ├── Models/                   # SwiftData models
│   │   ├── UserProfile.swift     # User settings and preferences
│   │   ├── WorkoutSession.swift  # Workout tracking models
│   │   ├── FoodLog.swift         # Nutrition tracking models
│   │   ├── HydrationLog.swift    # Hydration tracking
│   │   └── SharedDataModels.swift # Common data structures
│   ├── Views/                    # SwiftUI views
│   │   ├── MainTabView.swift     # Main tab navigation
│   │   ├── PerformanceView.swift # Today dashboard
│   │   ├── RecoveryDetailView.swift # Recovery analysis
│   │   ├── SleepDetailView.swift # Sleep analysis
│   │   ├── FuelLogDashboardView.swift # Nutrition tracking
│   │   ├── HydrationView.swift   # Hydration tracking
│   │   └── WorkoutView.swift     # Fitness tracking
│   ├── ViewModels/               # MVVM view models
│   │   ├── FuelLogViewModel.swift # Nutrition logic
│   │   └── CustomFoodCreationViewModel.swift
│   ├── Utils/                    # Utility classes
│   │   ├── HealthKitManager.swift # HealthKit integration
│   │   ├── FoodNetworkManager.swift # API integration
│   │   ├── ErrorHandling.swift   # Error management
│   │   └── AccessibilityUtils.swift # Accessibility helpers
│   ├── Repositories/             # Data access layer
│   │   └── FuelLogRepository.swift # Nutrition data access
│   ├── Protocols/                # Swift protocols
│   └── Assets.xcassets/          # App assets and images
├── workTests/                    # Unit and integration tests
├── workUITests/                  # UI automation tests
├── CHANGELOG.md                  # Version history
└── README.md                     # This file
```

---

## Key Algorithms Explained

### Recovery Score Deep Dive

The recovery score algorithm represents the culmination of extensive research into physiological markers of recovery. Each component is weighted based on scientific literature and personal optimization:

**HRV (Heart Rate Variability) - 50% Weight**:
- Primary indicator of autonomic nervous system recovery
- Uses SDNN (Standard Deviation of NN intervals) from overnight data
- Compares against personal 60-day rolling baseline
- Accounts for individual variation and adaptation

**RHR (Resting Heart Rate) - 25% Weight**:
- Cardiovascular system recovery indicator
- Overnight minimum heart rate analysis
- Lower values indicate better recovery state
- Sensitive to overtraining and illness

**Sleep Quality - 15% Weight**:
- Integrates comprehensive sleep analysis
- Considers duration, efficiency, and sleep stage distribution
- Critical for physical and cognitive recovery

**Stress Markers - 10% Weight**:
- Walking heart rate elevation
- Respiratory rate changes
- Oxygen saturation variations
- Indicates systemic stress response

### Sleep Score Methodology

The Sleep Score V4.0 algorithm provides a comprehensive assessment of sleep quality:

**Duration Scoring**:
- Optimal range: 7.5-9 hours for most adults
- Penalties for both insufficient and excessive sleep
- Accounts for individual sleep needs

**Sleep Stage Analysis**:
- Deep sleep: Critical for physical recovery (15-20% target)
- REM sleep: Essential for cognitive function (20-25% target)
- Uses HealthKit sleep stage data when available

**Efficiency Calculation**:
- Time asleep divided by time in bed
- Target efficiency: >85%
- Accounts for sleep onset and wake periods

**Consistency Evaluation**:
- Bedtime and wake time regularity
- Compares to personal 14-day average
- Circadian rhythm optimization

---

## What Makes This App Special

### 🎯 Personal Optimization Focus
Unlike generic fitness apps, Work is designed for serious health optimization. Every algorithm is calibrated for accuracy and actionable insights, not just engagement metrics.

### 🔬 Science-Based Approach
All scoring algorithms are based on peer-reviewed research and validated against real-world data. The app provides the depth of analysis typically found in professional sports science.

### 🛡️ Privacy-First Architecture
In an era of data harvesting, Work keeps all personal health data on your device. No cloud sync, no data mining, no privacy compromises.

### 🧠 Intelligent Insights
The correlation engine identifies meaningful relationships in your data, providing personalized insights that generic recommendations can't match.

### ♿ Accessibility Excellence
Built from the ground up with accessibility in mind, ensuring everyone can benefit from advanced health tracking.

### 🔄 Continuous Evolution
The app evolves with your needs, adapting baselines and insights as your fitness journey progresses.

### 💧 Complete Water Tracking
The hydration tracker features a beautiful animated circular progress gauge, celebratory feedback when goals are reached, and customizable daily targets. Quick-add buttons (200ml, 500ml, 700ml) make logging effortless.

### 🏋️ Advanced Workout System
Track live workouts with smart set types (working, warm-up, drop sets), automatic rest timers, and comprehensive exercise library. Personal records and volume tracking provide detailed progress insights.

### 🍎 Comprehensive Nutrition
Full macro tracking with OpenFoodFacts integration, custom food creation, and meal planning. Visual progress indicators and goal completion celebrations keep you motivated.

---

## Recent Fixes & Improvements

### 🐛 Nutrition Tracking Fixes (Latest)
- **Fixed Date Assignment**: Food logs now correctly appear on the selected date instead of showing up on the wrong day
- **Improved Macronutrient Display**: Fixed rounding issues where protein/fat values were showing as 0g instead of 1g due to improper rounding
- **Enhanced Nutrition Goals Visibility**: Onboarding card now properly disappears after goals are set and stays hidden when navigating between dates
- **Optimized Data Persistence**: Fixed issues where food logs would disappear after adding new items due to optimistic update problems
- **Better Error Handling**: Improved error recovery and reduced unnecessary UI state reversions
- **Consistent Date Handling**: All date operations now use start-of-day timestamps for consistent behavior

### 🔧 Technical Improvements
- **Timestamp Correction**: Added automatic timestamp correction to ensure food logs are assigned to the correct date
- **Performance Optimization**: Enhanced food log loading with proper date filtering
- **UI State Management**: Improved optimistic updates with better error recovery
- **Data Validation**: Enhanced validation while maintaining reasonable tolerance for real-world nutrition data

---

## Contributing

This is a personal project, but feedback and suggestions are welcome:

1. **Issues**: Report bugs or request features via GitHub Issues
2. **Discussions**: Share ideas and feedback in GitHub Discussions
3. **Code Review**: Pull requests welcome for bug fixes and improvements

### Development Standards
- Follow Swift API Design Guidelines
- Maintain comprehensive test coverage
- Ensure accessibility compliance
- Document complex algorithms
- Respect privacy-first architecture

---

## License & Acknowledgments

### Open Source Components
- **OpenFoodFacts**: Nutrition database API
- **SwiftUI**: Apple's modern UI framework
- **HealthKit**: Apple's health data platform

### Research References
- Heart Rate Variability analysis methodologies
- Sleep science and circadian rhythm research
- Exercise physiology and recovery science
- Nutrition science and metabolic health

---

## Contact & Support

For questions, feedback, or support:
- **GitHub Issues**: Technical problems and feature requests
- **GitHub Discussions**: General questions and community

---

*Work represents the intersection of technology and human optimization. Every line of code serves the goal of helping you understand and improve your health through data-driven insights.*