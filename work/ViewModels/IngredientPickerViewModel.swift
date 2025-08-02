import Foundation
import SwiftUI

@MainActor
final class IngredientPickerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var searchText: String = ""
    @Published var selectedSource: IngredientSource = .database
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
            // Always update search results to show the appropriate source
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
                // Use the BasicFoodDatabase for database search
                let basicFoods = BasicFoodDatabase.shared.searchFoods(query: query)
                searchResults = basicFoods.map { basicFood in
                    IngredientSearchResult(
                        name: basicFood.name,
                        calories: basicFood.calories,
                        protein: basicFood.protein,
                        carbohydrates: basicFood.carbs,
                        fat: basicFood.fat,
                        servingSize: basicFood.servingSize,
                        servingUnit: basicFood.servingUnit
                    )
                }
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
    
    func updateSearchResultsForSourceChange() async {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updateSearchResults()
        } else {
            await performSearch()
        }
    }
    
    // MARK: - Private Methods
    
    private func updateSearchResults() {
        switch selectedSource {
        case .custom:
            searchResults = customFoods.map { IngredientSearchResult(from: $0) }
        case .database:
            // Show all foods from BasicFoodDatabase when no search query
            let basicFoods = BasicFoodDatabase.shared.foods
            searchResults = basicFoods.map { basicFood in
                IngredientSearchResult(
                    name: basicFood.name,
                    calories: basicFood.calories,
                    protein: basicFood.protein,
                    carbohydrates: basicFood.carbs,
                    fat: basicFood.fat,
                    servingSize: basicFood.servingSize,
                    servingUnit: basicFood.servingUnit
                )
            }
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}