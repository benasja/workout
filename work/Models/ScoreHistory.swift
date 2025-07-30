import Foundation
import SwiftData

@Model
final class ScoreHistory {
    var id: UUID
    var date: Date
    var scoreType: ScoreType
    var score: Int
    var calculatedAt: Date
    
    // Baseline snapshot properties
    var hrv60: Double?
    var rhr60: Double?
    var sleepDuration90: Double?
    var bedtime90: Date?
    var wake90: Date?
    
    init(date: Date, scoreType: ScoreType, score: Int, baseline: BaselineSnapshot, calculatedAt: Date = Date()) {
        self.id = UUID()
        self.date = date
        self.scoreType = scoreType
        self.score = score
        self.calculatedAt = calculatedAt
        
        // Store baseline data as individual properties
        self.hrv60 = baseline.hrv60
        self.rhr60 = baseline.rhr60
        self.sleepDuration90 = baseline.sleepDuration90
        self.bedtime90 = baseline.bedtime90
        self.wake90 = baseline.wake90
    }
    
    // Computed property for compatibility
    var baseline: BaselineSnapshot {
        BaselineSnapshot(
            hrv60: hrv60,
            rhr60: rhr60,
            sleepDuration90: sleepDuration90,
            bedtime90: bedtime90,
            wake90: wake90
        )
    }
}

@Model
final class RecoveryScore {
    var id: UUID
    var date: Date
    var score: Int
    var calculatedAt: Date
    var sleepSessionStart: Date
    var sleepSessionEnd: Date
    
    // Component scores
    var hrvScore: Double
    var rhrScore: Double
    var sleepScore: Double
    var stressScore: Double
    
    // Raw metrics used for calculation
    var hrvValue: Double?
    var rhrValue: Double?
    var sleepScoreValue: Int?
    var walkingHRValue: Double?
    var respiratoryRateValue: Double?
    var oxygenSaturationValue: Double?
    
    // Baseline values at time of calculation
    var baselineHRV: Double?
    var baselineRHR: Double?
    var baselineWalkingHR: Double?
    var baselineRespiratoryRate: Double?
    var baselineOxygenSaturation: Double?
    
    // Directive and description
    var directive: String
    var hrvDescription: String
    var rhrDescription: String
    var sleepDescription: String
    var stressDescription: String
    
    init(
        date: Date,
        score: Int,
        sleepSessionStart: Date,
        sleepSessionEnd: Date,
        hrvScore: Double,
        rhrScore: Double,
        sleepScore: Double,
        stressScore: Double,
        hrvValue: Double?,
        rhrValue: Double?,
        sleepScoreValue: Int?,
        walkingHRValue: Double?,
        respiratoryRateValue: Double?,
        oxygenSaturationValue: Double?,
        baselineHRV: Double?,
        baselineRHR: Double?,
        baselineWalkingHR: Double?,
        baselineRespiratoryRate: Double?,
        baselineOxygenSaturation: Double?,
        directive: String,
        hrvDescription: String,
        rhrDescription: String,
        sleepDescription: String,
        stressDescription: String,
        calculatedAt: Date = Date()
    ) {
        self.id = UUID()
        self.date = date
        self.score = score
        self.calculatedAt = calculatedAt
        self.sleepSessionStart = sleepSessionStart
        self.sleepSessionEnd = sleepSessionEnd
        self.hrvScore = hrvScore
        self.rhrScore = rhrScore
        self.sleepScore = sleepScore
        self.stressScore = stressScore
        self.hrvValue = hrvValue
        self.rhrValue = rhrValue
        self.sleepScoreValue = sleepScoreValue
        self.walkingHRValue = walkingHRValue
        self.respiratoryRateValue = respiratoryRateValue
        self.oxygenSaturationValue = oxygenSaturationValue
        self.baselineHRV = baselineHRV
        self.baselineRHR = baselineRHR
        self.baselineWalkingHR = baselineWalkingHR
        self.baselineRespiratoryRate = baselineRespiratoryRate
        self.baselineOxygenSaturation = baselineOxygenSaturation
        self.directive = directive
        self.hrvDescription = hrvDescription
        self.rhrDescription = rhrDescription
        self.sleepDescription = sleepDescription
        self.stressDescription = stressDescription
    }
}

enum ScoreType: String, CaseIterable, Codable {
    case recovery
    case sleep
}

struct BaselineSnapshot: Codable {
    let hrv60: Double?
    let rhr60: Double?
    let sleepDuration90: Double?
    let bedtime90: Date?
    let wake90: Date?
}

@MainActor
class ScoreHistoryStore {
    static let shared = ScoreHistoryStore()
    
    private var modelContext: ModelContext?
    
    private init() {}
    
    func initialize(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Recovery Score Methods
    
    func saveRecoveryScore(_ recoveryScore: RecoveryScore) {
        guard let modelContext = modelContext else {
            print("❌ ScoreHistoryStore not initialized")
            return
        }
        
        modelContext.insert(recoveryScore)
        
        do {
            try modelContext.save()
            print("✅ Saved recovery score for \(recoveryScore.date)")
        } catch {
            print("❌ Failed to save recovery score: \(error)")
        }
    }
    
    func getRecoveryScore(for date: Date) -> RecoveryScore? {
        guard let modelContext = modelContext else {
            print("❌ ScoreHistoryStore not initialized")
            return nil
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        let descriptor = FetchDescriptor<RecoveryScore>(
            predicate: #Predicate<RecoveryScore> { score in
                score.date >= startOfDay && score.date < endOfDay
            },
            sortBy: [SortDescriptor(\.calculatedAt, order: .reverse)]
        )
        
        do {
            let scores = try modelContext.fetch(descriptor)
            return scores.first
        } catch {
            print("❌ Failed to fetch recovery score: \(error)")
            return nil
        }
    }
    
    func hasRecoveryScore(for date: Date) -> Bool {
        return getRecoveryScore(for: date) != nil
    }
    
    func deleteRecoveryScore(for date: Date) {
        guard let modelContext = modelContext else {
            print("❌ ScoreHistoryStore not initialized")
            return
        }
        
        if let score = getRecoveryScore(for: date) {
            modelContext.delete(score)
            
            do {
                try modelContext.save()
                print("🗑️ Deleted recovery score for \(date)")
            } catch {
                print("❌ Failed to delete recovery score: \(error)")
            }
        }
    }
    
    func getRecoveryScores(from startDate: Date, to endDate: Date) -> [RecoveryScore] {
        guard let modelContext = modelContext else {
            print("❌ ScoreHistoryStore not initialized")
            return []
        }
        
        let descriptor = FetchDescriptor<RecoveryScore>(
            predicate: #Predicate<RecoveryScore> { score in
                score.date >= startDate && score.date <= endDate
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ Failed to fetch recovery scores: \(error)")
            return []
        }
    }
    
    // MARK: - Legacy Score History Methods (for backward compatibility)
    
    func saveScore(_ score: ScoreHistory) {
        guard let modelContext = modelContext else {
            print("❌ ScoreHistoryStore not initialized")
            return
        }
        
        modelContext.insert(score)
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save score: \(error)")
        }
    }
    
    func getScores(for date: Date, type: ScoreType) -> [ScoreHistory] {
        guard let modelContext = modelContext else {
            print("❌ ScoreHistoryStore not initialized")
            return []
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        let descriptor = FetchDescriptor<ScoreHistory>(
            predicate: #Predicate<ScoreHistory> { score in
                score.date >= startOfDay && score.date < endOfDay && score.scoreType == type
            },
            sortBy: [SortDescriptor(\.calculatedAt, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ Failed to fetch scores: \(error)")
            return []
        }
    }
    
    func getScores(from startDate: Date, to endDate: Date, type: ScoreType) -> [ScoreHistory] {
        guard let modelContext = modelContext else {
            print("❌ ScoreHistoryStore not initialized")
            return []
        }
        
        let descriptor = FetchDescriptor<ScoreHistory>(
            predicate: #Predicate<ScoreHistory> { score in
                score.date >= startDate && score.date <= endDate && score.scoreType == type
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ Failed to fetch scores: \(error)")
            return []
        }
    }
} 