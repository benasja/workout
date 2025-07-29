# Design Document

## Overview

The Fuel Log feature is designed as a comprehensive nutrition tracking module that integrates seamlessly with the existing iOS health application. The architecture follows modern SwiftUI patterns with MVVM design, leveraging SwiftData for local persistence and HealthKit for biometric integration. The design prioritizes offline-first functionality, high performance, and a data-driven user experience that rivals market leaders like MyFitnessPal.

The feature will be implemented as a new tab in the existing MainTabView, maintaining consistency with the current application architecture while providing complete modularity for future maintenance and testing.

## Architecture

### High-Level Architecture Pattern

The Fuel Log feature follows the established MVVM (Model-View-ViewModel) pattern used throughout the existing application:

- **Models**: SwiftData models for local persistence (`@Model` classes)
- **Views**: SwiftUI views that are lightweight and declarative
- **ViewModels**: `@MainActor` classes conforming to `ObservableObject` for business logic
- **Managers**: Singleton service classes for external integrations (HealthKit, Network)
- **Repositories**: Data access layer abstractions for testability

### Data Flow Architecture

The application implements unidirectional data flow:

1. **Views** observe ViewModels via `@StateObject` or `@ObservedObject`
2. **ViewModels** manage business logic and coordinate between repositories/managers
3. **Repositories** abstract data access from ViewModels
4. **Managers** handle external service integration (HealthKit, Network APIs)
5. **Models** represent data structures and persistence

### Dependency Injection Strategy

Following the existing pattern in `DataManager.swift`, services are injected through:
- Environment objects for cross-view dependencies
- Initializer injection for ViewModels
- Singleton pattern for managers (HealthKit, Network)

## Components and Interfaces

### Core SwiftData Models

#### FoodLog Model
```swift
@Model
final class FoodLog {
    var id: UUID
    var timestamp: Date
    var name: String
    var calories: Double
    var protein: Double
    var carbohydrates: Double
    var fat: Double
    var mealType: MealType
    var servingSize: Double
    var servingUnit: String
    var barcode: String?
    var customFoodId: UUID?
    
    // Computed properties
    var totalMacroCalories: Double { (protein * 4) + (carbohydrates * 4) + (fat * 9) }
    var isQuickAdd: Bool { customFoodId == nil && barcode == nil }
}
```

#### CustomFood Model
```swift
@Model
final class CustomFood {
    var id: UUID
    var name: String
    var caloriesPerServing: Double
    var proteinPerServing: Double
    var carbohydratesPerServing: Double
    var fatPerServing: Double
    var servingSize: Double
    var servingUnit: String
    var createdDate: Date
    var isComposite: Bool // For meals made of multiple foods
    var ingredients: [CustomFoodIngredient] // For composite meals
}
```

#### NutritionGoals Model
```swift
@Model
final class NutritionGoals {
    var id: UUID
    var userId: String // For future multi-user support
    var dailyCalories: Double
    var dailyProtein: Double
    var dailyCarbohydrates: Double
    var dailyFat: Double
    var activityLevel: ActivityLevel
    var goal: NutritionGoal
    var bmr: Double
    var tdee: Double
    var lastUpdated: Date
    
    // HealthKit derived data
    var weight: Double?
    var height: Double?
    var age: Int?
    var biologicalSex: String?
}
```

### Enumerations

```swift
enum MealType: String, CaseIterable, Codable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    case snacks = "snacks"
    
    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snacks: return "Snacks"
        }
    }
    
    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "sunset.fill"
        case .snacks: return "star.fill"
        }
    }
}

enum ActivityLevel: String, CaseIterable, Codable {
    case sedentary = "sedentary"
    case lightlyActive = "lightly_active"
    case moderatelyActive = "moderately_active"
    case veryActive = "very_active"
    case extremelyActive = "extremely_active"
    
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        case .extremelyActive: return 1.9
        }
    }
}

enum NutritionGoal: String, CaseIterable, Codable {
    case cut = "cut"
    case maintain = "maintain"
    case bulk = "bulk"
    
    var calorieAdjustment: Double {
        switch self {
        case .cut: return -500 // 500 calorie deficit
        case .maintain: return 0
        case .bulk: return 300 // 300 calorie surplus
        }
    }
}
```

### ViewModels

#### FuelLogViewModel
```swift
@MainActor
final class FuelLogViewModel: ObservableObject {
    @Published var todaysFoodLogs: [FoodLog] = []
    @Published var nutritionGoals: NutritionGoals?
    @Published var dailyTotals: DailyNutritionTotals = DailyNutritionTotals()
    @Published var selectedDate: Date = Date()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let repository: FuelLogRepository
    private let healthKitManager: FuelLogHealthKitManager
    
    init(repository: FuelLogRepository, healthKitManager: FuelLogHealthKitManager) {
        self.repository = repository
        self.healthKitManager = healthKitManager
        loadTodaysData()
    }
    
    // Core functionality methods
    func loadTodaysData() async
    func logFood(_ foodLog: FoodLog) async
    func deleteFood(_ foodLog: FoodLog) async
    func updateNutritionGoals(_ goals: NutritionGoals) async
    func calculateDailyTotals()
}
```

#### FoodSearchViewModel
```swift
@MainActor
final class FoodSearchViewModel: ObservableObject {
    @Published var searchResults: [FoodSearchResult] = []
    @Published var customFoods: [CustomFood] = []
    @Published var isSearching: Bool = false
    @Published var searchText: String = ""
    
    private let networkManager: FoodNetworkManager
    private let repository: FuelLogRepository
    
    func search(query: String) async
    func searchLocal(query: String) async
    func createCustomFood(_ food: CustomFood) async
}
```

### Managers and Services

#### FuelLogHealthKitManager
```swift
final class FuelLogHealthKitManager {
    static let shared = FuelLogHealthKitManager()
    private let healthStore = HKHealthStore()
    
    // Required HealthKit types for nutrition tracking
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.quantityType(forIdentifier: .height)!,
        HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
        HKObjectType.characteristicType(forIdentifier: .biologicalSex)!
    ]
    
    private let writeTypes: Set<HKSampleType> = [
        HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
        HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
        HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
        HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!
    ]
    
    func requestAuthorization() async throws -> Bool
    func fetchUserPhysicalData() async throws -> UserPhysicalData
    func writeNutritionData(_ foodLog: FoodLog) async throws
    func calculateBMR(weight: Double, height: Double, age: Int, sex: HKBiologicalSex) -> Double
}
```

#### FoodNetworkManager
```swift
final class FoodNetworkManager {
    static let shared = FoodNetworkManager()
    private let session = URLSession.shared
    private let baseURL = "https://world.openfoodfacts.org/api/v0"
    
    func searchFoodByBarcode(_ barcode: String) async throws -> OpenFoodFactsProduct
    func searchFoodByName(_ query: String) async throws -> [OpenFoodFactsProduct]
    
    private func buildURL(for endpoint: String, parameters: [String: String] = [:]) -> URL?
    private func performRequest<T: Codable>(_ url: URL, responseType: T.Type) async throws -> T
}
```

### Repository Pattern

#### FuelLogRepository
```swift
protocol FuelLogRepositoryProtocol {
    func fetchFoodLogs(for date: Date) async throws -> [FoodLog]
    func saveFoodLog(_ foodLog: FoodLog) async throws
    func deleteFoodLog(_ foodLog: FoodLog) async throws
    func fetchCustomFoods() async throws -> [CustomFood]
    func saveCustomFood(_ customFood: CustomFood) async throws
    func fetchNutritionGoals() async throws -> NutritionGoals?
    func saveNutritionGoals(_ goals: NutritionGoals) async throws
}

@MainActor
final class FuelLogRepository: FuelLogRepositoryProtocol {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // Implementation of protocol methods using SwiftData
}
```

## Data Models

### External API Integration

#### Open Food Facts API Response Model
```swift
struct OpenFoodFactsResponse: Codable {
    let status: Int
    let statusVerbose: String
    let product: OpenFoodFactsProduct?
}

struct OpenFoodFactsProduct: Codable {
    let id: String
    let productName: String?
    let brands: String?
    let nutriments: OpenFoodFactsNutriments
    let servingSize: String?
    let servingQuantity: Double?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case productName = "product_name"
        case brands
        case nutriments
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
    }
}

struct OpenFoodFactsNutriments: Codable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let fiber100g: Double?
    let sugars100g: Double?
    let sodium100g: Double?
    
    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
        case fiber100g = "fiber_100g"
        case sugars100g = "sugars_100g"
        case sodium100g = "sodium_100g"
    }
}
```

### Internal Data Structures

#### DailyNutritionTotals
```swift
struct DailyNutritionTotals {
    var totalCalories: Double = 0
    var totalProtein: Double = 0
    var totalCarbohydrates: Double = 0
    var totalFat: Double = 0
    
    var caloriesFromMacros: Double {
        (totalProtein * 4) + (totalCarbohydrates * 4) + (totalFat * 9)
    }
    
    mutating func add(_ foodLog: FoodLog) {
        totalCalories += foodLog.calories
        totalProtein += foodLog.protein
        totalCarbohydrates += foodLog.carbohydrates
        totalFat += foodLog.fat
    }
    
    mutating func subtract(_ foodLog: FoodLog) {
        totalCalories -= foodLog.calories
        totalProtein -= foodLog.protein
        totalCarbohydrates -= foodLog.carbohydrates
        totalFat -= foodLog.fat
    }
}
```

#### UserPhysicalData
```swift
struct UserPhysicalData {
    let weight: Double? // kg
    let height: Double? // cm
    let age: Int?
    let biologicalSex: HKBiologicalSex?
    let bmr: Double?
    let tdee: Double?
}
```

## Error Handling

### Custom Error Types

```swift
enum FuelLogError: LocalizedError {
    case healthKitNotAvailable
    case healthKitAuthorizationDenied
    case networkError(Error)
    case invalidBarcode
    case foodNotFound
    case invalidNutritionData
    case persistenceError(Error)
    
    var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device"
        case .healthKitAuthorizationDenied:
            return "HealthKit authorization is required for this feature"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidBarcode:
            return "Invalid or unrecognized barcode"
        case .foodNotFound:
            return "Food item not found in database"
        case .invalidNutritionData:
            return "Invalid nutrition data provided"
        case .persistenceError(let error):
            return "Data storage error: \(error.localizedDescription)"
        }
    }
}
```

### Error Handling Strategy

1. **Network Errors**: Graceful degradation to offline mode with cached data
2. **HealthKit Errors**: Continue with manual input options
3. **Persistence Errors**: Retry mechanisms with user notification
4. **Validation Errors**: Real-time feedback with correction suggestions
5. **API Rate Limiting**: Exponential backoff with local caching

## Testing Strategy

### Unit Testing Approach

#### Repository Testing
```swift
final class FuelLogRepositoryTests: XCTestCase {
    var repository: FuelLogRepository!
    var mockModelContext: ModelContext!
    
    override func setUp() {
        // Setup in-memory SwiftData context for testing
        mockModelContext = createInMemoryModelContext()
        repository = FuelLogRepository(modelContext: mockModelContext)
    }
    
    func testSaveFoodLog() async throws {
        // Test food log persistence
    }
    
    func testFetchFoodLogsForDate() async throws {
        // Test date-based queries
    }
}
```

#### ViewModel Testing
```swift
final class FuelLogViewModelTests: XCTestCase {
    var viewModel: FuelLogViewModel!
    var mockRepository: MockFuelLogRepository!
    var mockHealthKitManager: MockFuelLogHealthKitManager!
    
    override func setUp() {
        mockRepository = MockFuelLogRepository()
        mockHealthKitManager = MockFuelLogHealthKitManager()
        viewModel = FuelLogViewModel(
            repository: mockRepository,
            healthKitManager: mockHealthKitManager
        )
    }
    
    func testLoadTodaysData() async {
        // Test data loading and state management
    }
    
    func testLogFood() async {
        // Test food logging functionality
    }
}
```

#### Network Manager Testing
```swift
final class FoodNetworkManagerTests: XCTestCase {
    var networkManager: FoodNetworkManager!
    var mockURLSession: MockURLSession!
    
    func testBarcodeSearch() async throws {
        // Test barcode API integration
    }
    
    func testNetworkErrorHandling() async {
        // Test error scenarios
    }
}
```

### Integration Testing

#### HealthKit Integration Tests
- Test authorization flow
- Test data fetching and writing
- Test offline fallback scenarios

#### SwiftData Integration Tests
- Test model relationships
- Test data migration scenarios
- Test concurrent access patterns

### UI Testing Strategy

#### Critical User Flows
1. **Onboarding Flow**: Complete setup from HealthKit authorization to goal setting
2. **Food Logging Flow**: Barcode scan → confirmation → logging
3. **Search Flow**: Text search → selection → portion adjustment → logging
4. **Custom Food Flow**: Creation → saving → reuse in logging

#### Performance Testing
- Dashboard load time under 500ms
- Search response time under 2 seconds
- Smooth scrolling with large food logs
- Memory usage optimization

## User Interface Design Patterns

### Design System Integration

The Fuel Log feature will integrate with the existing design system:

- **Colors**: Use `AppColors` from the existing codebase
- **Typography**: Follow established font hierarchy
- **Components**: Leverage existing shared components where possible
- **Navigation**: Integrate with existing `MainTabView` pattern

### Key UI Components

#### Circular Progress View
```swift
struct NutritionProgressView: View {
    let current: Double
    let goal: Double
    let color: Color
    let title: String
    
    var body: some View {
        // Circular progress implementation
    }
}
```

#### Macro Progress Bars
```swift
struct MacroProgressBar: View {
    let macro: MacroType
    let current: Double
    let goal: Double
    
    var body: some View {
        // Linear progress bar with labels
    }
}
```

#### Food Log Card
```swift
struct FoodLogCard: View {
    let foodLog: FoodLog
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        // Card layout with nutrition info and actions
    }
}
```

### Accessibility Considerations

- VoiceOver support for all interactive elements
- Dynamic Type support for text scaling
- High contrast mode compatibility
- Haptic feedback for key interactions
- Keyboard navigation support

## Performance Optimization

### Data Loading Strategy

1. **Lazy Loading**: Load food logs on-demand by date
2. **Pagination**: Implement pagination for large food databases
3. **Caching**: Cache frequently accessed custom foods and search results
4. **Background Processing**: Perform network requests and calculations off main thread

### Memory Management

1. **SwiftData Optimization**: Use appropriate fetch limits and predicates
2. **Image Caching**: Implement efficient image caching for food photos
3. **View Lifecycle**: Proper cleanup of observers and timers
4. **Batch Operations**: Group database operations for efficiency

### Network Optimization

1. **Request Debouncing**: Debounce search requests to reduce API calls
2. **Offline Caching**: Cache API responses for offline access
3. **Compression**: Use appropriate request/response compression
4. **Rate Limiting**: Implement client-side rate limiting for API calls

## Security and Privacy

### Data Protection

1. **Local Storage**: All nutrition data stored locally using SwiftData encryption
2. **HealthKit Integration**: Follow HealthKit privacy guidelines
3. **Network Security**: Use HTTPS for all API communications
4. **Data Minimization**: Only collect necessary data for functionality

### User Privacy

1. **Transparent Permissions**: Clear explanation of HealthKit data usage
2. **Data Control**: User ability to delete all stored data
3. **Offline Operation**: Core functionality works without network access
4. **No Analytics**: No user behavior tracking or analytics collection

## Integration Points

### MainTabView Integration

The Fuel Log will be added as a new tab in the existing `MainTabView.swift`:

```swift
// Add to MainTabView
NavigationStack {
    FuelLogDashboardView()
        .environmentObject(dateModel)
        .environmentObject(tabSelectionModel)
}
.tabItem {
    Image(systemName: "fork.knife")
    Text("Nutrition")
}
.tag(4) // Insert between Environment (3) and More (5)
```

### DataManager Integration

Extend the existing `DataManager.swift` to include nutrition-related methods:

```swift
extension DataManager {
    // MARK: - Nutrition Methods
    func fetchNutritionGoals() -> NutritionGoals?
    func saveNutritionGoals(_ goals: NutritionGoals) throws
    func fetchFoodLogs(for date: Date) -> [FoodLog]
    func saveFoodLog(_ foodLog: FoodLog) throws
}
```

### HealthKit Manager Integration

Extend the existing `HealthKitManager.swift` to support nutrition data:

```swift
extension HealthKitManager {
    // MARK: - Nutrition Data
    func fetchUserPhysicalData() async throws -> UserPhysicalData
    func writeNutritionData(_ foodLog: FoodLog) async throws
    func requestNutritionAuthorization() async throws -> Bool
}
```

## Future Extensibility

### Planned Enhancements

1. **Meal Planning**: Weekly meal planning and prep functionality
2. **Recipe Management**: Custom recipe creation and scaling
3. **Nutrition Analysis**: Advanced micronutrient tracking
4. **Social Features**: Meal sharing and community recipes
5. **AI Recommendations**: Personalized nutrition suggestions

### Architecture Flexibility

The modular design supports future enhancements:

- **Plugin Architecture**: Easy addition of new food databases
- **Customizable Goals**: Support for specialized diets (keto, vegan, etc.)
- **Export Capabilities**: Data export for nutritionists and coaches
- **Integration APIs**: Third-party app integration capabilities

## Technical Debt Considerations

### Code Quality Measures

1. **SwiftLint Integration**: Enforce coding standards
2. **Documentation**: Comprehensive code documentation
3. **Modular Design**: Clear separation of concerns
4. **Test Coverage**: Minimum 80% test coverage target
5. **Performance Monitoring**: Regular performance audits

### Maintenance Strategy

1. **Regular Refactoring**: Scheduled code review and refactoring
2. **Dependency Updates**: Regular updates of external dependencies
3. **API Versioning**: Handle API changes gracefully
4. **Data Migration**: Plan for future data model changes