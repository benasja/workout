import Foundation
import Network

// Test compilation of our models
struct TestCompile {
    func test() {
        let _ = OpenFoodFactsResponse(status: 1, statusVerbose: "test", product: nil)
        let _ = FoodNetworkManager.shared
    }
}