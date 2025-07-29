//
//  FoodNetworkManagerProtocol.swift
//  work
//
//  Created by Kiro on 7/29/25.
//

import Foundation

/// Protocol defining the interface for food network operations
protocol FoodNetworkManagerProtocol {
    /// Searches for food by barcode
    func searchFoodByBarcode(_ barcode: String) async throws -> FoodSearchResult
    
    /// Searches for food by name
    func searchFoodByName(_ query: String, page: Int) async throws -> [FoodSearchResult]
}