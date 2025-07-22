//
//  SupplementModelTests.swift
//  workTests
//
//  Created by Kiro on 7/18/25.
//

import XCTest
import SwiftData
@testable import work

final class SupplementModelTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() {
        super.setUp()
        
        // Create an in-memory model container for testing
        let schema = Schema([
            Supplement.self,
            SupplementLog.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContext = ModelContext(modelContainer)
        } catch {
            fatalError("Failed to create model container for testing: \(error)")
        }
    }
    
    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    // MARK: - Supplement Model Tests
    
    func testSupplementCreation() throws {
        // Test creating a supplement with all required properties
        let supplement = Supplement(
            name: "Vitamin D3",
            timeOfDay: "Morning",
            dosage: "2000 IU",
            sortOrder: 1
        )
        
        XCTAssertNotNil(supplement.id, "Supplement should have a valid UUID")
        XCTAssertEqual(supplement.name, "Vitamin D3", "Supplement name should match")
        XCTAssertEqual(supplement.timeOfDay, "Morning", "Time of day should match")
        XCTAssertEqual(supplement.dosage, "2000 IU", "Dosage should match")
        XCTAssertEqual(supplement.sortOrder, 1, "Sort order should match")
        XCTAssertTrue(supplement.isActive, "Supplement should be active by default")
    }
    
    func testSupplementDefaultValues() throws {
        // Test creating a supplement with default sort order
        let supplement = Supplement(
            name: "Omega 3",
            timeOfDay: "Evening",
            dosage: "500mg"
        )
        
        XCTAssertEqual(supplement.sortOrder, 0, "Default sort order should be 0")
        XCTAssertTrue(supplement.isActive, "Supplement should be active by default")
    }
    
    func testSupplementPersistence() throws {
        // Test saving and retrieving a supplement
        let supplement = Supplement(
            name: "Magnesium",
            timeOfDay: "Evening",
            dosage: "200mg",
            sortOrder: 2
        )
        
        modelContext.insert(supplement)
        
        do {
            try modelContext.save()
        } catch {
            XCTFail("Failed to save supplement: \(error)")
        }
        
        // Query the saved supplement
        let fetchDescriptor = FetchDescriptor<Supplement>(
            predicate: #Predicate { $0.name == "Magnesium" }
        )
        
        do {
            let supplements = try modelContext.fetch(fetchDescriptor)
            XCTAssertEqual(supplements.count, 1, "Should find exactly one supplement")
            
            let savedSupplement = supplements.first!
            XCTAssertEqual(savedSupplement.name, "Magnesium")
            XCTAssertEqual(savedSupplement.timeOfDay, "Evening")
            XCTAssertEqual(savedSupplement.dosage, "200mg")
            XCTAssertEqual(savedSupplement.sortOrder, 2)
            XCTAssertTrue(savedSupplement.isActive)
        } catch {
            XCTFail("Failed to fetch supplement: \(error)")
        }
    }
    
    func testSupplementUpdate() throws {
        // Test updating supplement properties
        let supplement = Supplement(
            name: "Vitamin C",
            timeOfDay: "Morning",
            dosage: "500mg"
        )
        
        modelContext.insert(supplement)
        try modelContext.save()
        
        // Update the supplement
        supplement.dosage = "1000mg"
        supplement.isActive = false
        
        try modelContext.save()
        
        // Verify the update
        let fetchDescriptor = FetchDescriptor<Supplement>(
            predicate: #Predicate { $0.name == "Vitamin C" }
        )
        
        let supplements = try modelContext.fetch(fetchDescriptor)
        let updatedSupplement = supplements.first!
        
        XCTAssertEqual(updatedSupplement.dosage, "1000mg", "Dosage should be updated")
        XCTAssertFalse(updatedSupplement.isActive, "isActive should be updated")
    }
    
    func testSupplementDeletion() throws {
        // Test deleting a supplement
        let supplement = Supplement(
            name: "Creatine",
            timeOfDay: "Morning",
            dosage: "5g"
        )
        
        modelContext.insert(supplement)
        try modelContext.save()
        
        // Delete the supplement
        modelContext.delete(supplement)
        try modelContext.save()
        
        // Verify deletion
        let fetchDescriptor = FetchDescriptor<Supplement>(
            predicate: #Predicate { $0.name == "Creatine" }
        )
        
        let supplements = try modelContext.fetch(fetchDescriptor)
        XCTAssertEqual(supplements.count, 0, "Supplement should be deleted")
    }
    
    // MARK: - SupplementLog Model Tests
    
    func testSupplementLogCreation() throws {
        let testDate = Date()
        let supplementLog = SupplementLog(
            date: testDate,
            supplementName: "Vitamin D3",
            isTaken: true
        )
        
        XCTAssertNotNil(supplementLog.id, "SupplementLog should have a valid UUID")
        XCTAssertEqual(supplementLog.supplementName, "Vitamin D3", "Supplement name should match")
        XCTAssertTrue(supplementLog.isTaken, "isTaken should match")
        XCTAssertNotNil(supplementLog.timestamp, "Timestamp should be set")
        
        // Verify date normalization (should be start of day)
        let expectedDate = Calendar.current.startOfDay(for: testDate)
        XCTAssertEqual(supplementLog.date, expectedDate, "Date should be normalized to start of day")
    }
    
    func testSupplementLogDefaultValues() throws {
        let testDate = Date()
        let supplementLog = SupplementLog(
            date: testDate,
            supplementName: "Omega 3"
        )
        
        XCTAssertFalse(supplementLog.isTaken, "Default isTaken should be false")
        XCTAssertNotNil(supplementLog.timestamp, "Timestamp should be set automatically")
    }
    
    func testSupplementLogDateNormalization() throws {
        // Test with a date that has time components
        let calendar = Calendar.current
        let dateComponents = DateComponents(year: 2025, month: 7, day: 18, hour: 14, minute: 30, second: 45)
        let testDate = calendar.date(from: dateComponents)!
        
        let supplementLog = SupplementLog(
            date: testDate,
            supplementName: "Test Supplement"
        )
        
        let expectedDate = calendar.startOfDay(for: testDate)
        XCTAssertEqual(supplementLog.date, expectedDate, "Date should be normalized to start of day")
    }
    
    func testSupplementLogPersistence() throws {
        let testDate = Date()
        let supplementLog = SupplementLog(
            date: testDate,
            supplementName: "Magnesium",
            isTaken: true
        )
        
        modelContext.insert(supplementLog)
        try modelContext.save()
        
        // Query the saved log
        let fetchDescriptor = FetchDescriptor<SupplementLog>(
            predicate: #Predicate { $0.supplementName == "Magnesium" }
        )
        
        let logs = try modelContext.fetch(fetchDescriptor)
        XCTAssertEqual(logs.count, 1, "Should find exactly one supplement log")
        
        let savedLog = logs.first!
        XCTAssertEqual(savedLog.supplementName, "Magnesium")
        XCTAssertTrue(savedLog.isTaken)
        XCTAssertEqual(savedLog.date, Calendar.current.startOfDay(for: testDate))
    }
    
    func testSupplementLogUpdate() throws {
        let testDate = Date()
        let supplementLog = SupplementLog(
            date: testDate,
            supplementName: "Zinc",
            isTaken: false
        )
        
        modelContext.insert(supplementLog)
        try modelContext.save()
        
        // Update the log
        supplementLog.isTaken = true
        try modelContext.save()
        
        // Verify the update
        let fetchDescriptor = FetchDescriptor<SupplementLog>(
            predicate: #Predicate { $0.supplementName == "Zinc" }
        )
        
        let logs = try modelContext.fetch(fetchDescriptor)
        let updatedLog = logs.first!
        
        XCTAssertTrue(updatedLog.isTaken, "isTaken should be updated to true")
    }
    
    func testSupplementLogDeletion() throws {
        let testDate = Date()
        let supplementLog = SupplementLog(
            date: testDate,
            supplementName: "Ashwagandha",
            isTaken: true
        )
        
        modelContext.insert(supplementLog)
        try modelContext.save()
        
        // Delete the log
        modelContext.delete(supplementLog)
        try modelContext.save()
        
        // Verify deletion
        let fetchDescriptor = FetchDescriptor<SupplementLog>(
            predicate: #Predicate { $0.supplementName == "Ashwagandha" }
        )
        
        let logs = try modelContext.fetch(fetchDescriptor)
        XCTAssertEqual(logs.count, 0, "Supplement log should be deleted")
    }
    
    // MARK: - Integration Tests
    
    func testMultipleSupplementsAndLogs() throws {
        // Create multiple supplements
        let supplements = [
            Supplement(name: "Vitamin D3", timeOfDay: "Morning", dosage: "2000 IU", sortOrder: 1),
            Supplement(name: "Omega 3", timeOfDay: "Morning", dosage: "500mg", sortOrder: 2),
            Supplement(name: "Magnesium", timeOfDay: "Evening", dosage: "200mg", sortOrder: 1)
        ]
        
        for supplement in supplements {
            modelContext.insert(supplement)
        }
        try modelContext.save()
        
        // Create logs for these supplements
        let testDate = Date()
        let logs = [
            SupplementLog(date: testDate, supplementName: "Vitamin D3", isTaken: true),
            SupplementLog(date: testDate, supplementName: "Omega 3", isTaken: false),
            SupplementLog(date: testDate, supplementName: "Magnesium", isTaken: true)
        ]
        
        for log in logs {
            modelContext.insert(log)
        }
        try modelContext.save()
        
        // Verify all data was saved correctly
        let supplementFetch = FetchDescriptor<Supplement>()
        let savedSupplements = try modelContext.fetch(supplementFetch)
        XCTAssertEqual(savedSupplements.count, 3, "Should have 3 supplements")
        
        let logFetch = FetchDescriptor<SupplementLog>()
        let savedLogs = try modelContext.fetch(logFetch)
        XCTAssertEqual(savedLogs.count, 3, "Should have 3 supplement logs")
        
        // Test querying by time of day
        let morningSupplements = savedSupplements.filter { $0.timeOfDay == "Morning" }
        XCTAssertEqual(morningSupplements.count, 2, "Should have 2 morning supplements")
        
        let eveningSupplements = savedSupplements.filter { $0.timeOfDay == "Evening" }
        XCTAssertEqual(eveningSupplements.count, 1, "Should have 1 evening supplement")
    }
    
    func testSupplementLogQueryByDate() throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // Create logs for different dates
        let todayLog = SupplementLog(date: today, supplementName: "Vitamin D3", isTaken: true)
        let yesterdayLog = SupplementLog(date: yesterday, supplementName: "Vitamin D3", isTaken: false)
        
        modelContext.insert(todayLog)
        modelContext.insert(yesterdayLog)
        try modelContext.save()
        
        // Query logs for today
        let todayStart = calendar.startOfDay(for: today)
        let fetchDescriptor = FetchDescriptor<SupplementLog>(
            predicate: #Predicate { $0.date == todayStart }
        )
        
        let todayLogs = try modelContext.fetch(fetchDescriptor)
        XCTAssertEqual(todayLogs.count, 1, "Should find exactly one log for today")
        XCTAssertTrue(todayLogs.first!.isTaken, "Today's log should be marked as taken")
    }
}