import Foundation

// MARK: - Usage Examples for FoodNetworkManager

/*
 Example usage of FoodNetworkManager for food database integration
 
 This file demonstrates how to use the FoodNetworkManager in ViewModels
 and other parts of the application.
 */

// MARK: - Example ViewModel Integration

@MainActor
class ExampleFoodSearchViewModel: ObservableObject {
    @Published var searchResults: [FoodSearchResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkManager = FoodNetworkManager.shared
    
    // Example: Search by barcode
    func searchByBarcode(_ barcode: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await networkManager.searchFoodByBarcode(barcode)
            searchResults = [result]
        } catch let error as FoodNetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Unexpected error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // Example: Search by name
    func searchByName(_ query: String) async {
        guard !query.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let results = try await networkManager.searchFoodByName(query)
            searchResults = results
        } catch let error as FoodNetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Unexpected error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

// MARK: - Example Usage Patterns

/*
 // In a SwiftUI View:
 
 struct FoodSearchView: View {
     @StateObject private var viewModel = ExampleFoodSearchViewModel()
     @State private var searchText = ""
     
     var body: some View {
         NavigationView {
             VStack {
                 SearchBar(text: $searchText) {
                     Task {
                         await viewModel.searchByName(searchText)
                     }
                 }
                 
                 if viewModel.isLoading {
                     ProgressView("Searching...")
                 } else if let errorMessage = viewModel.errorMessage {
                     Text(errorMessage)
                         .foregroundColor(.red)
                 } else {
                     List(viewModel.searchResults, id: \.id) { result in
                         FoodResultRow(result: result)
                     }
                 }
             }
             .navigationTitle("Food Search")
         }
     }
 }
 
 // For barcode scanning:
 
 func handleScannedBarcode(_ barcode: String) {
     Task {
         await viewModel.searchByBarcode(barcode)
     }
 }
 */

// MARK: - Error Handling Examples

/*
 // Comprehensive error handling:
 
 func handleFoodSearch() async {
     do {
         let results = try await FoodNetworkManager.shared.searchFoodByName("apple")
         // Handle success
     } catch FoodNetworkError.noInternetConnection {
         // Show offline message, use cached data
     } catch FoodNetworkError.rateLimitExceeded {
         // Show rate limit message, retry after delay
     } catch FoodNetworkError.productNotFound {
         // Offer to create custom food
     } catch {
         // Handle other errors
     }
 }
 */

// MARK: - Caching Benefits

/*
 The FoodNetworkManager automatically caches responses for 5 minutes.
 This means:
 
 1. Repeated searches for the same barcode return instantly
 2. Network usage is minimized
 3. Offline functionality is improved
 4. User experience is smoother
 
 The cache is automatically managed and expires old entries.
 */

// MARK: - Rate Limiting

/*
 The FoodNetworkManager enforces a 500ms delay between requests to:
 
 1. Respect the Open Food Facts API guidelines
 2. Prevent overwhelming the service
 3. Ensure fair usage for all users
 4. Maintain good API citizenship
 
 This is handled automatically - no need to manage delays manually.
 */