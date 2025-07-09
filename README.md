# Work - Advanced Fitness & Health Tracking App

A comprehensive SwiftUI fitness and health tracking application with advanced features including HealthKit integration, performance scoring, journaling, and correlation analysis.

## 🚀 Features

### Core Workout Features
- **Workout Tracking**: Log exercises, sets, reps, and weights
- **Exercise Library**: Comprehensive exercise database with descriptions
- **Program Management**: Create and follow structured workout programs
- **Workout History**: Track progress over time with detailed analytics
- **Weight Tracking**: Monitor body weight with CSV import/export

### Advanced Health Integration
- **HealthKit Integration**: Seamless sync with Apple Health data
- **Recovery Scoring**: Advanced algorithm based on HRV, RHR, and sleep data
- **Sleep Analysis**: Comprehensive sleep quality scoring
- **Performance Dashboard**: Real-time health metrics and insights
- **Trends Analysis**: Interactive charts for health data over time

### Lifestyle Journaling & Correlations
- **Daily Journal**: Track lifestyle factors (alcohol, caffeine, stress, supplements)
- **Correlation Analysis**: Discover relationships between lifestyle and health
- **Statistical Insights**: Advanced analytics with statistical significance testing
- **Health Data Sync**: Automatic integration with HealthKit metrics
- **Actionable Insights**: Personalized recommendations based on patterns

### Data Management
- **CSV Import/Export**: Backup and restore weight data
- **SwiftData Persistence**: Robust local data storage
- **HealthKit Sync**: Real-time health data integration
- **Data Seeding**: Demo data for feature exploration

## 📱 App Structure

### Main Tabs
1. **Today** - Daily overview and quick actions
2. **Workout** - Active workout tracking
3. **Performance** - Health metrics and recovery scoring
4. **Trends** - Interactive charts and historical data
5. **Journal** - Lifestyle tracking and insights
6. **Correlations** - Statistical analysis of lifestyle-health relationships
7. **Weight** - Body weight tracking with charts
8. **History** - Workout and exercise history
9. **Settings** - App configuration and preferences

### Key Components

#### HealthKitManager
- Singleton pattern for HealthKit integration
- Recovery and sleep scoring algorithms
- HRV and RHR data processing
- Journal data synchronization

#### Performance Scoring Engine
- Dynamic baselining for personalized metrics
- Advanced recovery algorithms
- Sleep quality assessment
- Actionable insights generation

#### Journal System
- Daily lifestyle factor tracking
- Health metric correlation
- Statistical analysis engine
- Pattern recognition

#### Correlation Analysis
- Interactive charts with SwiftUI Charts
- Statistical significance testing
- Multi-factor correlation matrix
- Real-time data visualization

## 🛠 Technical Implementation

### Architecture
- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Persistent data storage
- **HealthKit**: Health data integration
- **Charts**: Interactive data visualization
- **Combine**: Reactive programming patterns

### Data Models
- `UserProfile`: User information and preferences
- `WorkoutSession`: Complete workout sessions
- `CompletedExercise`: Individual exercise instances
- `WorkoutSet`: Set-specific data
- `ExerciseDefinition`: Exercise library entries
- `Program`: Structured workout programs
- `WeightEntry`: Body weight tracking
- `DailyJournal`: Lifestyle and health correlation data

### Key Algorithms

#### Recovery Scoring
```swift
// Multi-factor algorithm considering:
// - HRV baseline and current values
// - RHR trends
// - Sleep quality and duration
// - Previous day's workout intensity
// - Weekly training load
```

#### Sleep Scoring
```swift
// Comprehensive sleep assessment:
// - Sleep duration vs. recommended ranges
// - Sleep efficiency
// - Deep sleep percentage
// - REM sleep patterns
// - Sleep consistency
```

#### Correlation Analysis
```swift
// Statistical correlation engine:
// - T-test for significance
// - Effect size calculation
// - Multi-factor regression
// - Pattern recognition
// - Confidence intervals
```

## 📊 Data Visualization

### Interactive Charts
- **Line Charts**: Health metrics over time
- **Scatter Plots**: Correlation analysis
- **Bar Charts**: Statistical comparisons
- **Progress Indicators**: Real-time metrics

### Color-Coded Metrics
- **Green**: Optimal ranges
- **Orange**: Suboptimal but acceptable
- **Red**: Needs attention
- **Blue**: Neutral/informational

## 🔧 Setup & Configuration

### Prerequisites
- iOS 17.0+
- Xcode 15.0+
- Apple Developer Account (for HealthKit)

### Installation
1. Clone the repository
2. Open `work.xcodeproj` in Xcode
3. Configure HealthKit capabilities
4. Build and run on device or simulator

### HealthKit Permissions
The app requests access to:
- Heart Rate (HRV, RHR)
- Sleep Analysis
- Activity Data
- Workout Data

## 🎯 Usage Guide

### Getting Started
1. **First Launch**: Grant HealthKit permissions
2. **Demo Data**: Use "Try Demo Data" in Journal tab to explore features
3. **Health Sync**: Tap "Sync Health Data" to connect with HealthKit
4. **Journal Entry**: Add daily lifestyle factors
5. **Correlation Analysis**: Explore relationships in Correlations tab

### Daily Workflow
1. **Morning**: Check recovery score and insights
2. **Throughout Day**: Log lifestyle factors in Journal
3. **Workout**: Track exercises and performance
4. **Evening**: Review daily summary and trends

### Advanced Features
- **Program Creation**: Design custom workout programs
- **Data Export**: Backup weight data to CSV
- **Correlation Discovery**: Find lifestyle-health patterns
- **Performance Optimization**: Use insights to improve training

## 🔬 Scientific Foundation

### Recovery Scoring
Based on research from:
- Heart Rate Variability (HRV) studies
- Resting Heart Rate (RHR) trends
- Sleep quality research
- Training load monitoring

### Sleep Analysis
Incorporates findings from:
- Sleep cycle research
- Recovery optimization studies
- Circadian rhythm science
- Sleep hygiene recommendations

### Correlation Analysis
Uses statistical methods:
- T-tests for significance
- Effect size calculations
- Multiple regression analysis
- Confidence interval estimation

## 🚀 Future Enhancements

### Planned Features
- **Machine Learning**: Predictive analytics
- **Social Features**: Community challenges
- **Wearable Integration**: Additional device support
- **Nutrition Tracking**: Meal and supplement logging
- **Advanced Analytics**: More sophisticated correlation models

### Technical Improvements
- **Performance Optimization**: Faster data processing
- **Offline Support**: Enhanced local functionality
- **Data Export**: Additional format support
- **API Integration**: Third-party service connections

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📞 Support

For support, email support@workapp.com or create an issue in the repository.

---

**Work** - Transform your fitness journey with data-driven insights and comprehensive health tracking. 