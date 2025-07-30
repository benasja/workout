# Design Document

## Overview

The Sleep Lab Analytics feature enhances the existing SleepLabView by transforming it from a basic correlation display into a comprehensive analytical platform. The design leverages the existing infrastructure (HealthKitManager, APIService, SleepScoreCalculator, RecoveryScoreCalculator, and HealthStatsViewModel) while adding three major analytical capabilities:

1. **Nightly Analysis with Master Timeline Graph** - Interactive visualization showing sleep stages synchronized with environmental data
2. **Enhanced Correlation Engine** - Statistical analysis tools with scatter plots and correlation coefficients  
3. **Experimentation Mode** - Scientific hypothesis testing for environmental optimization

The design maintains the existing dark theme and navigation patterns while introducing new analytical views accessible from the current correlation cards.

## Architecture

### High-Level Component Structure

```
SleepLabView (Enhanced)
├── CorrelationCardsView (Existing - Enhanced)
├── NightlyAnalysisView (New)
│   ├── MasterTimelineGraph (New)
│   ├── MetricsOverviewCard (New)
│   └── AutomatedInsightsCard (New)
├── CorrelationEngineView (New)
│   ├── VariableSelectionPanel (New)
│   ├── ScatterPlotChart (New)
│   └── StatisticalInsightsPanel (New)
└── ExperimentationView (New)
    ├── ExperimentSetupPanel (New)
    ├── ActiveExperimentTracker (New)
    └── ExperimentResultsView (New)
```

### Data Flow Architecture

```
HealthKit Data → HealthStatsViewModel → Sleep Lab Components
ESP32 Sensors → APIService → Environmental Data Integration
Correlation API → Statistical Analysis → Insights Generation
```

### Navigation Flow

```
SleepLabView (Main)
├── Tap Correlation Card → NightlyAnalysisView
├── "Analyze Patterns" Button → CorrelationEngineView  
└── "Run Experiment" Button → ExperimentationView
```

## Components and Interfaces

### 1. Enhanced SleepLabView

**Purpose**: Main entry point with enhanced navigation and correlation cards

**Key Enhancements**:
- Add navigation buttons for Correlation Engine and Experimentation Mode
- Enhance existing correlation cards with tap-to-analyze functionality
- Integrate with new analytical views

**Interface**:
```swift
struct SleepLabView: View {
    @StateObject private var viewModel = SleepLabViewModel()
    @State private var selectedAnalysisMode: AnalysisMode = .overview
    
    enum AnalysisMode {
        case overview, nightly(CorrelationData), correlation, experimentation
    }
}
```

### 2. NightlyAnalysisView (New)

**Purpose**: Detailed analysis of a single night with synchronized timeline

**Key Components**:
- **MasterTimelineGraph**: Dual-axis chart showing sleep stages and environmental data
- **MetricsOverviewCard**: Enhanced metrics with baseline comparisons
- **AutomatedInsightsCard**: AI-generated observations and recommendations

**Interface**:
```swift
struct NightlyAnalysisView: View {
    let correlationData: CorrelationData
    @StateObject private var viewModel = NightlyAnalysisViewModel()
    @State private var selectedTimeRange: TimeRange = .fullNight
    @State private var zoomLevel: Double = 1.0
}

class NightlyAnalysisViewModel: ObservableObject {
    @Published var sleepStages: [SleepStageData] = []
    @Published var environmentalData: [EnvironmentalTimePoint] = []
    @Published var insights: [AutomatedInsight] = []
    @Published var isLoading = false
}
```

### 3. MasterTimelineGraph (New)

**Purpose**: Core visualization component showing synchronized sleep and environmental data

**Technical Approach**:
- Use SwiftUI Charts framework for performance
- Dual Y-axis implementation with sleep stages as bars and environmental data as lines
- Interactive zoom and pan capabilities
- Time synchronization markers for correlation events

**Interface**:
```swift
struct MasterTimelineGraph: View {
    let sleepStages: [SleepStageData]
    let environmentalData: [EnvironmentalTimePoint]
    @Binding var selectedTimeRange: TimeRange
    @Binding var zoomLevel: Double
    
    var body: some View {
        Chart {
            // Sleep stage bars (primary Y-axis)
            ForEach(sleepStages) { stage in
                BarMark(...)
            }
            // Environmental line graphs (secondary Y-axis)  
            ForEach(environmentalData) { point in
                LineMark(...)
            }
        }
    }
}
```

### 4. CorrelationEngineView (New)

**Purpose**: Advanced statistical analysis with variable selection and scatter plots

**Key Components**:
- **VariableSelectionPanel**: Dropdowns for selecting sleep and environmental metrics
- **ScatterPlotChart**: Interactive scatter plot with trend lines
- **StatisticalInsightsPanel**: Correlation coefficients and interpretations

**Interface**:
```swift
struct CorrelationEngineView: View {
    @StateObject private var viewModel = CorrelationEngineViewModel()
    @State private var selectedSleepMetric: SleepMetric = .sleepScore
    @State private var selectedEnvironmentalMetric: EnvironmentalMetric = .temperature
    @State private var timeRange: CorrelationTimeRange = .thirtyDays
}

class CorrelationEngineViewModel: ObservableObject {
    @Published var correlationData: [CorrelationPoint] = []
    @Published var statisticalResults: StatisticalAnalysis?
    @Published var isCalculating = false
    
    func calculateCorrelation(sleep: SleepMetric, environmental: EnvironmentalMetric, range: CorrelationTimeRange) async
}
```

### 5. ExperimentationView (New)

**Purpose**: Scientific hypothesis testing with experiment tracking

**Key Components**:
- **ExperimentSetupPanel**: Define hypothesis, target parameters, and duration
- **ActiveExperimentTracker**: Monitor ongoing experiments with progress indicators
- **ExperimentResultsView**: Comprehensive results analysis with statistical significance

**Interface**:
```swift
struct ExperimentationView: View {
    @StateObject private var viewModel = ExperimentationViewModel()
    @State private var activeExperiments: [SleepExperiment] = []
    @State private var completedExperiments: [SleepExperiment] = []
}

class ExperimentationViewModel: ObservableObject {
    @Published var experiments: [SleepExperiment] = []
    @Published var isCreatingExperiment = false
    
    func createExperiment(_ experiment: SleepExperiment) async
    func trackExperimentProgress(_ experimentId: UUID) async
    func generateExperimentResults(_ experimentId: UUID) async -> ExperimentResults
}
```

## Data Models

### Sleep Stage Data Model
```swift
struct SleepStageData: Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let stage: SleepStage
    let duration: TimeInterval
}

enum SleepStage: String, CaseIterable {
    case awake = "Awake"
    case light = "Light Sleep"
    case deep = "Deep Sleep"
    case rem = "REM Sleep"
    
    var color: Color {
        switch self {
        case .awake: return .orange
        case .light: return .blue.opacity(0.6)
        case .deep: return .blue
        case .rem: return .purple
        }
    }
}
```

### Environmental Time Point Model
```swift
struct EnvironmentalTimePoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let temperature: Double
    let humidity: Double
    let airQuality: Double
    let luminosity: Double
}
```

### Correlation Analysis Models
```swift
struct CorrelationPoint: Identifiable {
    let id = UUID()
    let date: Date
    let sleepValue: Double
    let environmentalValue: Double
}

struct StatisticalAnalysis {
    let correlationCoefficient: Double
    let pValue: Double
    let confidenceInterval: (lower: Double, upper: Double)
    let sampleSize: Int
    let interpretation: String
    let significance: StatisticalSignificance
}

enum StatisticalSignificance {
    case veryStrong, strong, moderate, weak, negligible
}
```

### Experimentation Models
```swift
struct SleepExperiment: Identifiable, Codable {
    let id = UUID()
    let name: String
    let hypothesis: String
    let targetParameter: EnvironmentalParameter
    let targetValue: Double
    let duration: Int // days
    let startDate: Date
    let status: ExperimentStatus
    let baselineData: ExperimentBaseline?
    let results: ExperimentResults?
}

enum ExperimentStatus {
    case planned, active, completed, cancelled
}

struct ExperimentResults {
    let baselineMetrics: [String: Double]
    let experimentMetrics: [String: Double]
    let percentageChanges: [String: Double]
    let statisticalSignificance: Bool
    let conclusion: String
    let recommendations: [String]
}
```

## Error Handling

### Data Availability Handling
- **Missing Sleep Data**: Show placeholder with data collection guidance
- **Missing Environmental Data**: Indicate sensor connectivity issues with troubleshooting steps
- **Incomplete Correlation Data**: Display partial results with data quality indicators

### Performance Error Handling
- **Large Dataset Processing**: Implement progressive loading with user feedback
- **Memory Constraints**: Automatic data pagination and cache management
- **Network Timeouts**: Retry mechanisms with offline mode fallbacks

### User Input Validation
- **Experiment Parameters**: Validate target values are within reasonable ranges
- **Time Range Selection**: Ensure sufficient data points for statistical validity
- **Variable Selection**: Prevent invalid metric combinations

## Testing Strategy

### Unit Testing
- **Statistical Calculations**: Verify correlation coefficient calculations and statistical significance
- **Data Processing**: Test sleep stage parsing and environmental data synchronization
- **Experiment Logic**: Validate experiment tracking and results generation

### Integration Testing
- **HealthKit Integration**: Test sleep data retrieval and processing with existing HealthStatsViewModel
- **API Integration**: Verify environmental data synchronization with existing APIService
- **Cross-Component Communication**: Test navigation and data flow between analytical views

### Performance Testing
- **Large Dataset Handling**: Test with 90+ days of correlation data
- **Chart Rendering**: Verify smooth interaction with complex timeline graphs
- **Memory Usage**: Monitor memory consumption during extended analysis sessions

### User Experience Testing
- **Navigation Flow**: Test intuitive movement between analysis modes
- **Data Visualization**: Verify chart readability and interaction responsiveness
- **Insight Generation**: Validate automated observations are accurate and helpful

## Implementation Considerations

### SwiftUI Charts Integration
- Leverage SwiftUI Charts for high-performance timeline visualization
- Implement custom chart modifiers for dual-axis display
- Use chart annotations for correlation event markers

### Statistical Analysis Library
- Implement correlation calculations using Swift Numerics
- Add statistical significance testing with appropriate p-value calculations
- Include confidence interval calculations for robust analysis

### Data Synchronization Strategy
- Extend existing HealthStatsViewModel caching for timeline data
- Implement efficient data merging for sleep and environmental datasets
- Use background processing for heavy statistical calculations

### Accessibility Considerations
- Provide VoiceOver descriptions for chart data points
- Include alternative text representations of visual correlations
- Ensure all interactive elements meet accessibility guidelines

### Performance Optimization
- Implement data virtualization for large timeline datasets
- Use lazy loading for historical correlation data
- Optimize chart rendering with appropriate data sampling

This design builds comprehensively on your existing infrastructure while adding the sophisticated analytical capabilities you described. The modular approach allows for incremental implementation while maintaining the existing user experience.