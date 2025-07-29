import Foundation

/// Custom error types for Fuel Log functionality
enum FuelLogError: LocalizedError, Equatable {
    case healthKitNotAvailable
    case healthKitAuthorizationDenied
    case networkError(Error)
    case invalidBarcode
    case foodNotFound
    case invalidNutritionData
    case persistenceError(Error)
    case invalidUserData
    case calculationError
    case rateLimitExceeded
    case serverUnavailable
    case dataCorruption
    case insufficientStorage
    case operationCancelled
    case timeout
    case syncUnavailable
    
    // Equatable conformance
    static func == (lhs: FuelLogError, rhs: FuelLogError) -> Bool {
        switch (lhs, rhs) {
        case (.healthKitNotAvailable, .healthKitNotAvailable),
             (.healthKitAuthorizationDenied, .healthKitAuthorizationDenied),
             (.invalidBarcode, .invalidBarcode),
             (.foodNotFound, .foodNotFound),
             (.invalidNutritionData, .invalidNutritionData),
             (.invalidUserData, .invalidUserData),
             (.calculationError, .calculationError),
             (.rateLimitExceeded, .rateLimitExceeded),
             (.serverUnavailable, .serverUnavailable),
             (.dataCorruption, .dataCorruption),
             (.insufficientStorage, .insufficientStorage),
             (.operationCancelled, .operationCancelled),
             (.timeout, .timeout),
             (.syncUnavailable, .syncUnavailable):
            return true
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.persistenceError(let lhsError), .persistenceError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
    
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
        case .invalidUserData:
            return "Invalid user data for calculations"
        case .calculationError:
            return "Error performing nutrition calculations"
        case .rateLimitExceeded:
            return "Too many requests. Please wait before trying again"
        case .serverUnavailable:
            return "Food database is temporarily unavailable"
        case .dataCorruption:
            return "Data corruption detected"
        case .insufficientStorage:
            return "Insufficient storage space available"
        case .operationCancelled:
            return "Operation was cancelled"
        case .timeout:
            return "Request timed out"
        case .syncUnavailable:
            return "Data synchronization is not available"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .healthKitNotAvailable:
            return "This device does not support HealthKit functionality"
        case .healthKitAuthorizationDenied:
            return "User has not granted permission to access HealthKit data"
        case .networkError:
            return "Unable to connect to food database"
        case .invalidBarcode:
            return "The scanned barcode is not valid or not found in the database"
        case .foodNotFound:
            return "The requested food item could not be found"
        case .invalidNutritionData:
            return "The nutrition data contains invalid values"
        case .persistenceError:
            return "Unable to save or retrieve data from local storage"
        case .invalidUserData:
            return "User physical data is incomplete or invalid"
        case .calculationError:
            return "Unable to calculate nutrition values"
        case .rateLimitExceeded:
            return "API rate limit has been exceeded"
        case .serverUnavailable:
            return "The food database server is experiencing issues"
        case .dataCorruption:
            return "Local data has become corrupted"
        case .insufficientStorage:
            return "Device storage is full"
        case .operationCancelled:
            return "The operation was cancelled by the user or system"
        case .timeout:
            return "The request took too long to complete"
        case .syncUnavailable:
            return "Data synchronization manager is not configured"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .healthKitNotAvailable:
            return "Please use manual input for your physical data"
        case .healthKitAuthorizationDenied:
            return "Please grant HealthKit permissions in Settings > Privacy & Security > Health"
        case .networkError:
            return "Please check your internet connection and try again"
        case .invalidBarcode:
            return "Try scanning the barcode again or search for the food manually"
        case .foodNotFound:
            return "Try searching with different keywords or create a custom food entry"
        case .invalidNutritionData:
            return "Please check that all nutrition values are valid numbers"
        case .persistenceError:
            return "Please try again or restart the app"
        case .invalidUserData:
            return "Please complete your profile setup with valid physical data"
        case .calculationError:
            return "Please verify your input data and try again"
        case .rateLimitExceeded:
            return "Wait a few moments before making another request"
        case .serverUnavailable:
            return "Please try again later or use offline functionality"
        case .dataCorruption:
            return "Please restart the app or contact support if the issue persists"
        case .insufficientStorage:
            return "Free up storage space on your device"
        case .operationCancelled:
            return "Try the operation again if needed"
        case .timeout:
            return "Check your internet connection and try again"
        case .syncUnavailable:
            return "Data synchronization features are not available in this configuration"
        }
    }
    
    /// Indicates whether this error is recoverable through retry
    var isRetryable: Bool {
        switch self {
        case .networkError, .rateLimitExceeded, .serverUnavailable, .timeout:
            return true
        case .persistenceError:
            return true
        case .healthKitNotAvailable, .healthKitAuthorizationDenied, .invalidBarcode, 
             .foodNotFound, .invalidNutritionData, .invalidUserData, .calculationError,
             .dataCorruption, .insufficientStorage, .operationCancelled, .syncUnavailable:
            return false
        }
    }
    
    /// Suggested retry delay in seconds
    var retryDelay: TimeInterval {
        switch self {
        case .rateLimitExceeded:
            return 5.0
        case .serverUnavailable:
            return 3.0
        case .networkError, .timeout:
            return 2.0
        case .persistenceError:
            return 1.0
        default:
            return 0.0
        }
    }
}