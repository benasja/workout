import Foundation

// MARK: - Open Food Facts API Response Models

struct OpenFoodFactsResponse: Codable {
    let status: Int
    let statusVerbose: String
    let product: OpenFoodFactsProduct?
    
    enum CodingKeys: String, CodingKey {
        case status
        case statusVerbose = "status_verbose"
        case product
    }
}

struct OpenFoodFactsProduct: Codable {
    let id: String
    let productName: String?
    let brands: String?
    let nutriments: OpenFoodFactsNutriments
    let servingSize: String?
    let servingQuantity: Double?
    let imageUrl: String?
    let categories: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case productName = "product_name"
        case brands
        case nutriments
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case imageUrl = "image_url"
        case categories
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
    let salt100g: Double?
    
    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
        case fiber100g = "fiber_100g"
        case sugars100g = "sugars_100g"
        case sodium100g = "sodium_100g"
        case salt100g = "salt_100g"
    }
}

// MARK: - Search Response Models

struct OpenFoodFactsSearchResponse: Codable {
    let count: Int
    let page: Int
    let pageCount: Int
    let pageSize: Int
    let products: [OpenFoodFactsProduct]
    
    enum CodingKeys: String, CodingKey {
        case count
        case page
        case pageCount = "page_count"
        case pageSize = "page_size"
        case products
    }
}

// MARK: - Internal Food Search Result Model

struct FoodSearchResult {
    let id: String
    let name: String
    let brand: String?
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let servingSize: Double
    let servingUnit: String
    let imageUrl: String?
    let source: FoodSource
    let customFood: CustomFood? // Reference to original CustomFood for editing
    
    enum FoodSource: Codable {
        case openFoodFacts
        case custom
    }
    
    init(fromOpenFoodFacts product: OpenFoodFactsProduct) {
        self.id = product.id
        self.name = product.productName ?? "Unknown Product"
        self.brand = product.brands
        self.calories = product.nutriments.energyKcal100g ?? 0
        self.protein = product.nutriments.proteins100g ?? 0
        self.carbohydrates = product.nutriments.carbohydrates100g ?? 0
        self.fat = product.nutriments.fat100g ?? 0
        self.servingSize = product.servingQuantity ?? 100
        self.servingUnit = "g"
        self.imageUrl = product.imageUrl
        self.source = .openFoodFacts
        self.customFood = nil
    }
    
    // Direct initializer for testing and previews
    init(
        id: String,
        name: String,
        brand: String? = nil,
        calories: Double,
        protein: Double,
        carbohydrates: Double,
        fat: Double,
        servingSize: Double,
        servingUnit: String,
        imageUrl: String? = nil,
        source: FoodSource,
        customFood: CustomFood? = nil
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.imageUrl = imageUrl
        self.source = source
        self.customFood = customFood
    }
}