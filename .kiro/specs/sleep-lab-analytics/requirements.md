# Requirements Document

## Introduction

The Sleep Lab Analytics feature enhances the existing sleep analysis capabilities by creating an interactive, analytical tool that bridges Apple Watch physiological data with ESP32 environmental sensor data. Building on the current SleepLabView correlation display, this feature transforms the Sleep Lab into the ultimate personal performance optimization platform. The core philosophy centers on answering one fundamental question: "How does my external environment affect my internal recovery?"

The current implementation provides basic correlation cards showing sleep scores alongside environmental averages. This enhancement will add:
- A synchronized timeline graph showing sleep stages overlaid with real-time environmental data
- Advanced correlation analysis tools with statistical insights
- Scientific experimentation capabilities for hypothesis testing
- Automated AI-powered observations and recommendations

## Requirements

### Requirement 1

**User Story:** As a user, I want to view a detailed nightly analysis with a synchronized timeline graph, so that I can understand the precise relationship between my sleep stages and environmental conditions throughout the night.

#### Acceptance Criteria

1. WHEN I select a specific night from the existing correlation cards THEN the system SHALL display a detailed nightly analysis view with a master timeline graph
2. WHEN viewing the master graph THEN the system SHALL show sleep stages as colored blocks (Deep Sleep: Dark Blue, REM: Purple, Core/Light: Light Blue, Awake: Orange) on the primary Y-axis using HealthKit sleep analysis data
3. WHEN viewing the master graph THEN the system SHALL overlay environmental data as line graphs (Temperature: solid white, Humidity: dotted blue, Luminosity: thin yellow, Air Quality: dashed green) on the secondary Y-axis using ESP32 sensor data
4. WHEN I interact with the timeline THEN the system SHALL allow me to zoom and pan to examine specific time periods in detail
5. WHEN environmental spikes occur THEN the system SHALL visually correlate them with corresponding sleep stage changes through synchronized time markers

### Requirement 2

**User Story:** As a user, I want to see enhanced key metrics and insights for each night, so that I can quickly assess my sleep quality and environmental conditions with deeper context than the current correlation cards.

#### Acceptance Criteria

1. WHEN viewing a nightly analysis THEN the system SHALL display internal state metrics including Sleep Score (from existing SleepScoreCalculator), Time in Deep Sleep, Time in REM, Overnight HRV, and Lowest RHR with baseline comparisons
2. WHEN viewing a nightly analysis THEN the system SHALL display external environment metrics including Average Temperature, Average Humidity, Maximum Light Level, and Average Air Quality from ESP32 sensor data
3. WHEN displaying metrics THEN the system SHALL show comparisons to personal baselines using the existing DynamicBaselineEngine (e.g., "+12m vs. 14-day avg")
4. WHEN metrics fall outside optimal ranges THEN the system SHALL indicate whether values are optimal, slightly high/low, or concerning using color-coded indicators
5. WHEN insufficient data exists THEN the system SHALL clearly indicate missing metrics and suggest data collection improvements

### Requirement 3

**User Story:** As a user, I want to receive automated observations about my sleep patterns, so that I can understand what environmental factors may have influenced my sleep quality.

#### Acceptance Criteria

1. WHEN viewing a nightly analysis THEN the system SHALL generate 2-3 plain-language observations based on the night's data
2. WHEN environmental correlations are detected THEN the system SHALL describe the relationship in simple terms (e.g., "Your deepest sleep cycles occurred when your room temperature was between 19°C and 20°C")
3. WHEN sleep disruptions occur THEN the system SHALL identify potential environmental causes (e.g., "A brief spike in light was detected at 3:15 AM, which may have contributed to a short period of wakefulness")
4. WHEN HRV patterns correlate with environmental factors THEN the system SHALL highlight these relationships in the observations
5. WHEN no significant patterns are detected THEN the system SHALL provide general sleep quality observations

### Requirement 4

**User Story:** As a user, I want to analyze correlations between any sleep metric and environmental factor over time, so that I can identify long-term patterns that affect my sleep quality beyond the basic correlation cards currently shown.

#### Acceptance Criteria

1. WHEN I access the enhanced Correlation Engine THEN the system SHALL provide dropdown menus to select any two variables for statistical analysis
2. WHEN selecting variables THEN the system SHALL offer sleep metrics (Sleep Score, Deep Sleep %, REM Sleep %, HRV, Sleep Efficiency) and environmental metrics (Avg. Temp, Avg. Humidity, Avg. Air Quality, Max Luminosity)
3. WHEN I choose two variables THEN the system SHALL display a scatter plot graph showing their relationship over the selected time period (30, 60, or 90 days) using existing correlation data from APIService
4. WHEN displaying correlations THEN the system SHALL calculate and show the Pearson correlation coefficient (r) with statistical significance and confidence intervals
5. WHEN correlation strength is significant THEN the system SHALL provide plain-language explanation of the relationship strength, direction, and practical implications

### Requirement 5

**User Story:** As a user, I want to set up and track sleep experiments, so that I can scientifically test hypotheses about environmental factors affecting my sleep.

#### Acceptance Criteria

1. WHEN I create an experiment THEN the system SHALL allow me to define a hypothesis and target environmental parameter
2. WHEN setting up an experiment THEN the system SHALL let me specify the duration (minimum 7 days) and target values for environmental variables
3. WHEN an experiment is active THEN the system SHALL track all sleep and environmental data during the experiment period
4. WHEN an experiment concludes THEN the system SHALL generate a comprehensive report comparing experimental period to baseline
5. WHEN presenting experiment results THEN the system SHALL show percentage changes in key sleep metrics and provide a clear conclusion about the experiment's success

### Requirement 6

**User Story:** As a user, I want the Sleep Lab to integrate seamlessly with my existing health data infrastructure, so that I can access comprehensive sleep analysis building on the current HealthKitManager and APIService implementations.

#### Acceptance Criteria

1. WHEN the app launches THEN the system SHALL leverage the existing HealthKitManager to retrieve sleep stage data, HRV, and heart rate data without additional authorization requests
2. WHEN environmental data is available THEN the system SHALL use the existing APIService to integrate ESP32 sensor readings with corresponding sleep sessions from the correlation data endpoint
3. WHEN data synchronization occurs THEN the system SHALL build on the existing HealthStatsViewModel caching mechanism to handle missing data gracefully
4. WHEN new sleep data becomes available THEN the system SHALL automatically update analyses using the existing SleepScoreCalculator and RecoveryScoreCalculator
5. WHEN data conflicts exist THEN the system SHALL use the existing DynamicBaselineEngine prioritization logic for data reliability

### Requirement 7

**User Story:** As a user, I want to navigate between different Sleep Lab features intuitively, so that I can efficiently access the analysis tools I need.

#### Acceptance Criteria

1. WHEN I access the Sleep Lab THEN the system SHALL provide clear navigation between Nightly Analysis, Correlation Engine, and Experimentation Mode
2. WHEN viewing any analysis THEN the system SHALL allow me to quickly jump to related views (e.g., from nightly analysis to setting up an experiment)
3. WHEN using date selection THEN the system SHALL provide intuitive date navigation with calendar picker and quick date range options
4. WHEN switching between features THEN the system SHALL maintain context where appropriate (e.g., selected date range)
5. WHEN returning to previously viewed analyses THEN the system SHALL restore the previous state and selections

### Requirement 8

**User Story:** As a user, I want the Sleep Lab to perform efficiently with large amounts of historical data, so that I can analyze months of sleep data without performance issues while building on existing caching infrastructure.

#### Acceptance Criteria

1. WHEN loading historical data THEN the system SHALL display analyses within 2 seconds for up to 90 days of data using the existing HealthStatsViewModel caching system
2. WHEN rendering the master timeline graph THEN the system SHALL handle smooth zooming and panning without lag using optimized SwiftUI Chart components
3. WHEN calculating correlations THEN the system SHALL process up to 90 days of data points within 1 second leveraging existing correlation data from APIService
4. WHEN switching between different time periods THEN the system SHALL extend the existing cache management in HealthStatsViewModel to improve response times
5. WHEN memory usage becomes high THEN the system SHALL implement data pagination building on the existing SleepScoreCalculator cache cleanup mechanisms