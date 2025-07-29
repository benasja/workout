import Foundation
import SwiftUI
import Network

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Error Handling Utilities

/// Centralized error handling utility for Fuel Log functionality
@MainActor
final class ErrorHandler: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentError: FuelLogError?
    @Published var showErrorAlert: Bool = false
    @Published var isRetrying: Bool = false
    @Published var retryCount: Int = 0
    
    // MARK: - Constants
    
    private let maxRetryAttempts = 3
    private let retryDelayMultiplier: TimeInterval = 1.5
    
    // MARK: - Public Methods
    
    /// Handles an error with optional retry mechanism
    func handleError(
        _ error: Error,
        context: String = "",
        retryAction: (() async -> Void)? = nil
    ) {
        let fuelLogError = convertToFuelLogError(error)
        currentError = fuelLogError
        showErrorAlert = true
        
        // Log error for debugging
        logError(fuelLogError, context: context)
        
        // Provide haptic feedback for errors
        provideErrorFeedback()
        
        // Auto-retry for certain errors if retry action is provided
        if let retryAction = retryAction,
           fuelLogError.isRetryable,
           retryCount < maxRetryAttempts {
            Task {
                await performRetry(retryAction, for: fuelLogError)
            }
        }
    }
    
    /// Manually retry the last failed operation
    func retry(action: @escaping () async -> Void) async {
        guard let error = currentError,
              error.isRetryable,
              retryCount < maxRetryAttempts else {
            return
        }
        
        await performRetry(action, for: error)
    }
    
    /// Clear the current error state
    func clearError() {
        currentError = nil
        showErrorAlert = false
        retryCount = 0
        isRetrying = false
    }
    
    /// Reset retry count for new operations
    func resetRetryCount() {
        retryCount = 0
    }
    
    // MARK: - Private Methods
    
    private func convertToFuelLogError(_ error: Error) -> FuelLogError {
        if let fuelLogError = error as? FuelLogError {
            return fuelLogError
        }
        
        if let networkError = error as? FoodNetworkError {
            switch networkError {
            case .rateLimitExceeded:
                return .rateLimitExceeded
            case .serverError:
                return .serverUnavailable
            case .noInternetConnection:
                return .networkError(networkError)
            case .productNotFound:
                return .foodNotFound
            case .invalidBarcode:
                return .invalidBarcode
            default:
                return .networkError(networkError)
            }
        }
        
        // Check for common system errors
        let nsError = error as NSError
        switch nsError.code {
        case NSURLErrorTimedOut:
            return .timeout
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            return .networkError(error)
        case NSURLErrorCancelled:
            return .operationCancelled
        default:
            return .networkError(error)
        }
    }
    
    private func performRetry(_ action: @escaping () async -> Void, for error: FuelLogError) async {
        isRetrying = true
        retryCount += 1
        
        // Calculate delay with exponential backoff
        let delay = error.retryDelay * pow(retryDelayMultiplier, Double(retryCount - 1))
        
        do {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await action()
            
            // If successful, clear error state
            clearError()
        } catch {
            // If retry fails, handle the new error
            handleError(error, retryAction: action)
        }
        
        isRetrying = false
    }
    
    private func logError(_ error: FuelLogError, context: String) {
        let contextString = context.isEmpty ? "" : " [\(context)]"
        print("🚨 FuelLog Error\(contextString): \(error.localizedDescription)")
        
        if let failureReason = error.failureReason {
            print("   Reason: \(failureReason)")
        }
        
        if let recoverySuggestion = error.recoverySuggestion {
            print("   Recovery: \(recoverySuggestion)")
        }
    }
    
    private func provideErrorFeedback() {
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        #endif
    }
}

// MARK: - Error Alert View Modifier

struct ErrorAlertModifier: ViewModifier {
    @ObservedObject var errorHandler: ErrorHandler
    let retryAction: (() async -> Void)?
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $errorHandler.showErrorAlert) {
                Button("OK") {
                    errorHandler.clearError()
                }
                
                if let error = errorHandler.currentError,
                   error.isRetryable,
                   let retryAction = retryAction,
                   errorHandler.retryCount < 3 {
                    Button("Retry") {
                        Task {
                            await errorHandler.retry(action: retryAction)
                        }
                    }
                }
            } message: {
                if let error = errorHandler.currentError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(error.localizedDescription)
                        
                        if let recoverySuggestion = error.recoverySuggestion {
                            Text(recoverySuggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if errorHandler.retryCount > 0 {
                            Text("Retry attempt \(errorHandler.retryCount) of 3")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
    }
}

extension View {
    /// Adds error handling with optional retry functionality
    func errorAlert(
        errorHandler: ErrorHandler,
        retryAction: (() async -> Void)? = nil
    ) -> some View {
        modifier(ErrorAlertModifier(errorHandler: errorHandler, retryAction: retryAction))
    }
}

// MARK: - Loading State Manager

@MainActor
final class LoadingStateManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String = "Loading..."
    @Published var progress: Double = 0.0
    @Published var showProgress: Bool = false
    
    // MARK: - Private Properties
    
    private var loadingTasks: Set<String> = []
    
    // MARK: - Public Methods
    
    /// Start loading with optional message and progress tracking
    func startLoading(
        taskId: String = UUID().uuidString,
        message: String = "Loading...",
        showProgress: Bool = false
    ) {
        loadingTasks.insert(taskId)
        loadingMessage = message
        self.showProgress = showProgress
        isLoading = true
        
        if showProgress {
            progress = 0.0
        }
    }
    
    /// Update loading progress
    func updateProgress(_ progress: Double, message: String? = nil) {
        self.progress = min(max(progress, 0.0), 1.0)
        
        if let message = message {
            loadingMessage = message
        }
    }
    
    /// Stop loading for a specific task
    func stopLoading(taskId: String = "") {
        if taskId.isEmpty {
            loadingTasks.removeAll()
        } else {
            loadingTasks.remove(taskId)
        }
        
        if loadingTasks.isEmpty {
            isLoading = false
            showProgress = false
            progress = 0.0
            loadingMessage = "Loading..."
        }
    }
    
    /// Stop all loading operations
    func stopAllLoading() {
        loadingTasks.removeAll()
        isLoading = false
        showProgress = false
        progress = 0.0
        loadingMessage = "Loading..."
    }
    
    /// Check if a specific task is loading
    func isTaskLoading(_ taskId: String) -> Bool {
        return loadingTasks.contains(taskId)
    }
}

// MARK: - Loading View Modifier

struct LoadingOverlayModifier: ViewModifier {
    @ObservedObject var loadingManager: LoadingStateManager
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if loadingManager.isLoading {
                    LoadingOverlayView(
                        message: loadingManager.loadingMessage,
                        progress: loadingManager.progress,
                        showProgress: loadingManager.showProgress
                    )
                }
            }
    }
}

struct LoadingOverlayView: View {
    let message: String
    let progress: Double
    let showProgress: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                if showProgress {
                    ProgressView(value: progress)
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                        .scaleEffect(1.5)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                        .scaleEffect(1.5)
                }
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if showProgress {
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
            )
        }
    }
}

extension View {
    /// Adds loading overlay functionality
    func loadingOverlay(loadingManager: LoadingStateManager) -> some View {
        modifier(LoadingOverlayModifier(loadingManager: loadingManager))
    }
}

// MARK: - Network Status Manager

@MainActor
final class NetworkStatusManager: ObservableObject {
    
    @Published var isConnected: Bool = true
    @Published var connectionType: ConnectionType = .wifi
    @Published var showOfflineMessage: Bool = false
    
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case other
        case none
        
        var displayName: String {
            switch self {
            case .wifi: return "Wi-Fi"
            case .cellular: return "Cellular"
            case .ethernet: return "Ethernet"
            case .other: return "Network"
            case .none: return "No Connection"
            }
        }
    }
    
    init() {
        startMonitoring()
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    private func startMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateConnectionStatus(path)
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    private func updateConnectionStatus(_ path: NWPath) {
        let wasConnected = isConnected
        isConnected = path.status == .satisfied
        
        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else if isConnected {
            connectionType = .other
        } else {
            connectionType = .none
        }
        
        // Show offline message when connection is lost
        if wasConnected && !isConnected {
            showOfflineMessage = true
            
            // Auto-hide after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.showOfflineMessage = false
            }
        }
    }
}

// MARK: - Offline Message View

struct OfflineMessageView: View {
    @ObservedObject var networkManager: NetworkStatusManager
    
    var body: some View {
        if networkManager.showOfflineMessage {
            HStack {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.white)
                
                Text("You're offline. Some features may be limited.")
                    .font(.caption)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("Dismiss") {
                    networkManager.showOfflineMessage = false
                }
                .font(.caption)
                .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange)
            .transition(.move(edge: .top))
        }
    }
}