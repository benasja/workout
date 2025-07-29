import Foundation
import SwiftUI

@MainActor
final class IngredientPickerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var searchText: String = ""
    @Published var selectedSource: IngredientSource = .custom
    @Published var searchResults: [IngredientSearchResult] = []
    @Published var isLoading: Bool = false
    @Published var showingError: Bool = false
    @Published var errorMessage: String = ""
    @Published var showingCustomFoodCreation: Bool = false
    @Published var showingPortionAdjustment: Bool = false
    @Published var selectedFood: IngredientSearchResult?
    
    // MARK: - Dependencies
    let repository: FuelLogRepositoryProtocol
    
    // MARK: - Private Properties
    private var customFoods: [CustomFood] = []
    
    // MARK: - Initialization
    
    init(repository: FuelLogRepositoryProtocol) {
        self.repository = repository
    }
    
    // MARK: - Public Methods
    
    func loadCustomFoods() async {
        isLoading = true
        
        do {
            customFoods = try await repository.fetchCustomFoods()
            updateSearchResults()
        } catch {
            showError("Failed to load custom foods: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func performSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !query.isEmpty else {
            updateSearchResults()
            return
        }
        
        isLoading = true
        
        do {
            switch selectedSource {
            case .custom:
                let filteredFoods = try await repository.searchCustomFoods(query: query)
                searchResults = filteredFoods.map { IngredientSearchResult(from: $0) }
                
            case .database:
                // For now, just show custom foods that match
                // In the future, this would integrate with the food database API
                let filteredFoods = try await repository.searchCustomFoods(query: query)
                searchResults = filteredFoods.map { IngredientSearchResult(from: $0) }
            }
        } catch {
            showError("Search failed: \(error.localizedDescription)")
            searchResults = []
        }
        
        isLoading = false
    }
    
    func selectFood(_ result: IngredientSearchResult) {
        selectedFood = result
        showingPortionAdjustment = true
    }
    
    // MARK: - Private Methods
    
    private func updateSearchResults() {
        switch selectedSource {
        case .custom:
            searchResults = customFoods.map { IngredientSearchResult(from: $0) }
        case .database:
            // For now, show custom foods
            // In the future, this would show database results
            searchResults = customFoods.map { IngredientSearchResult(from: $0) }
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}