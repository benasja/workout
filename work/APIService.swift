import Foundation
import HealthKit

// MARK: - API Data Models

// This struct defines the data payload sent TO the server.
// It should only be defined here.
struct SleepData: Codable {
    let session_date: String // ISO 8601 date string (e.g., "2025-07-22")
    let deep_sleep_minutes: Double
    let rem_sleep_minutes: Double
    let time_asleep_minutes: Double
    let score: Int
    
    // Initializer from SleepScoreResult
    init(from sleepResult: SleepScoreResult, date: Date) throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        self.session_date = formatter.string(from: date)
        
        // Convert seconds to minutes and validate values
        let deepSleepMinutes = max(0, sleepResult.deepSleep / 60)
        let remSleepMinutes = max(0, sleepResult.remSleep / 60)  
        let timeAsleepMinutes = max(0, sleepResult.timeAsleep / 60)
        
        // Debug: Print original values in seconds
        // print("🔍 Debug - Sleep data conversion:")
        // print("   Deep Sleep: \(sleepResult.deepSleep) seconds → \(deepSleepMinutes) minutes")
        // print("   REM Sleep: \(sleepResult.remSleep) seconds → \(remSleepMinutes) minutes") 
        // print("   Time Asleep: \(sleepResult.timeAsleep) seconds → \(timeAsleepMinutes) minutes")
        // print("   Sleep Score: \(sleepResult.finalScore)")
        
        // Validate ranges (ensure reasonable values)
        guard deepSleepMinutes >= 0 && deepSleepMinutes <= 720, // Max 12 hours
              remSleepMinutes >= 0 && remSleepMinutes <= 720,
              timeAsleepMinutes >= 0 && timeAsleepMinutes <= 720,
              sleepResult.finalScore >= 0 && sleepResult.finalScore <= 100 else {
            print("⚠️ Warning: Sleep data values are outside expected ranges")
            print("   Deep: \(deepSleepMinutes), REM: \(remSleepMinutes), Total: \(timeAsleepMinutes), Score: \(sleepResult.finalScore)")
            throw APIError.requestFailed(description: "Sleep data values are outside expected ranges")
        }
        
        self.deep_sleep_minutes = deepSleepMinutes
        self.rem_sleep_minutes = remSleepMinutes
        self.time_asleep_minutes = timeAsleepMinutes
        self.score = sleepResult.finalScore
    }
}

// MARK: - API Error Enum

enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed(description: String)
    case decodingError(description: String)
    case serverError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The server URL is invalid."
        case .requestFailed(let description):
            return "The network request failed: \(description)"
        case .decodingError(let description):
            return "Failed to decode the server's response: \(description)"
        case .serverError(let statusCode):
            return "The server responded with an error: \(statusCode)"
        }
    }
}

// MARK: - APIService Singleton

final class APIService {
    static let shared = APIService()
    
    // private let baseURL = "http://localhost:3000/api"
    private let baseURL = "https://sensor-api-c5arcwcxc7dsa7ce.polandcentral-01.azurewebsites.net/api"
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Sleep Data Sync
    
    /// Posts sleep data to the backend server.
    /// - Parameter sleepData: The SleepData object to be sent.
    func postSleepData(sleepData: SleepData) async throws {
        // The API is currently disconnected, skip posting to prevent errors
        print("⚠️ Sleep API is disconnected, skipping data posting")
        return
    }
    
    // MARK: - Correlation Data Fetch
    
    /// Fetches correlation data from the backend server.
    /// - Returns: An array of CorrelationData objects.
    func fetchCorrelationData() async throws -> [CorrelationData] {
        guard let url = URL(string: "\(baseURL)/correlation") else {
            throw APIError.invalidURL
        }
        
        do {
            // print("🌐 Fetching correlation data...")
            
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
                print("❌ Server returned status code: \(statusCode)")
                throw APIError.serverError(statusCode: statusCode)
            }
            
            let decoder = JSONDecoder()
            // The server sends a root object with a "data" key
            let apiResponse = try decoder.decode(CorrelationAPIResponse.self, from: data)
            
            // print("✅ Fetched \(apiResponse.data.count) correlation entries.")
            return apiResponse.data
            
        } catch let decodingError as DecodingError {
            // print("❌ Decoding error: \(decodingError)")
            throw APIError.decodingError(description: decodingError.localizedDescription)
        } catch {
            // print("❌ Error fetching correlation data: \(error.localizedDescription)")
            throw APIError.requestFailed(description: error.localizedDescription)
        }
    }
    
    // MARK: - Environmental Data Fetch
    
    /// Fetches the latest environmental sensor data from the backend server.
    /// - Returns: LatestEnvironmentalData object with current readings.
    func fetchLatestEnvironmentalData() async throws -> LatestEnvironmentalData {
        guard let url = URL(string: "\(baseURL)/data/latest") else {
            throw APIError.invalidURL
        }
        
        do {
            // print("🌐 Fetching latest environmental data...")
            
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
                print("❌ Server returned status code: \(statusCode)")
                throw APIError.serverError(statusCode: statusCode)
            }
            
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(LatestEnvironmentalDataResponse.self, from: data)
            
            // print("✅ Fetched latest environmental data.")
            return apiResponse.data
            
        } catch let decodingError as DecodingError {
            // print("❌ Decoding error: \(decodingError)")
            throw APIError.decodingError(description: decodingError.localizedDescription)
        } catch {
            // print("❌ Error fetching latest environmental data: \(error.localizedDescription)")
            throw APIError.requestFailed(description: error.localizedDescription)
        }
    }
    
    /// Fetches 24-hour historical environmental data from the backend server.
    /// - Returns: An array of EnvironmentalData objects for trend analysis.
    func fetchEnvironmentalHistory() async throws -> [EnvironmentalData] {
        guard let url = URL(string: "\(baseURL)/data/history?range=24h") else {
            throw APIError.invalidURL
        }
        
        do {
            // print("🌐 Fetching environmental history...")
            
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
                print("❌ Server returned status code: \(statusCode)")
                throw APIError.serverError(statusCode: statusCode)
            }
            
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(EnvironmentalDataResponse.self, from: data)
            
            // print("✅ Fetched \(apiResponse.data.count) environmental history entries.")
            return apiResponse.data
            
        } catch let decodingError as DecodingError {
            print("❌ Decoding error: \(decodingError)")
            throw APIError.decodingError(description: decodingError.localizedDescription)
        } catch {
            print("❌ Error fetching environmental history: \(error.localizedDescription)")
            throw APIError.requestFailed(description: error.localizedDescription)
        }
    }
}

// MARK: - Environmental Data Models

struct EnvironmentalData: Codable, Identifiable {
    let id: Int
    let timestamp: String // ISO 8601 timestamp
    let temperature: Double
    let humidity: Double
    let airQuality: Double
    let luminosity: Double // Added luminosity field
    
    // This is the corrected computed property for ISO 8601 timestamps
    var date: Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: timestamp) ?? Date()
    }
}

struct LatestEnvironmentalData: Codable {
    let id: Int
    let temperature: Double
    let humidity: Double
    let airQuality: Double
    let luminosity: Double
    let timestamp: String
}

// MARK: - Helper Structs for Decoding
// This struct matches the root JSON object from your server: {"status": "success", "data": [...]}
struct CorrelationAPIResponse: Codable {
    let status: String
    let data: [CorrelationData]
}

struct EnvironmentalDataResponse: Codable {
    let status: String
    let data: [EnvironmentalData]
}

struct LatestEnvironmentalDataResponse: Codable {
    let status: String
    let data: LatestEnvironmentalData
}
