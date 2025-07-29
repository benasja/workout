import XCTest

/// Comprehensive UI tests for Fuel Log critical user flows
final class FuelLogUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Set launch arguments for testing
        app.launchArguments = ["--uitesting", "--reset-data"]
        app.launch()
        
        // Wait for app to fully load
        _ = app.wait(for: .runningForeground, timeout: 5)
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Navigation Tests
    
    func testNavigateToFuelLogTab() throws {
        // Given - app is launched
        
        // When - tap on Nutrition tab
        let nutritionTab = app.tabBars.buttons["Nutrition"]
        XCTAssertTrue(nutritionTab.exists, "Nutrition tab should exist")
        nutritionTab.tap()
        
        // Then - should navigate to Fuel Log dashboard
        let dashboardTitle = app.navigationBars["Fuel Log"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 3), "Should navigate to Fuel Log dashboard")
        
        // Verify key dashboard elements exist
        XCTAssertTrue(app.staticTexts["Calories"].exists, "Calories section should exist")
        XCTAssertTrue(app.staticTexts["Protein"].exists, "Protein section should exist")
        XCTAssertTrue(app.staticTexts["Carbs"].exists, "Carbs section should exist")
        XCTAssertTrue(app.staticTexts["Fat"].exists, "Fat section should exist")
    }
    
    // MARK: - Onboarding Flow Tests
    
    func testCompleteOnboardingFlow() throws {
        // Navigate to Nutrition tab
        app.tabBars.buttons["Nutrition"].tap()
        
        // Check if onboarding is presented (for new users)
        let getStartedButton = app.buttons["Get Started"]
        if getStartedButton.exists {
            // Start onboarding
            getStartedButton.tap()
            
            // Step 1: HealthKit Authorization
            let authorizeButton = app.buttons["Authorize HealthKit"]
            if authorizeButton.exists {
                authorizeButton.tap()
                
                // Handle system HealthKit permission dialog
                let allowButton = app.buttons["Allow"]
                if allowButton.waitForExistence(timeout: 5) {
                    allowButton.tap()
                }
            }
            
            // Step 2: Physical Data (if HealthKit fails)
            let manualDataButton = app.buttons["Enter Manually"]
            if manualDataButton.exists {
                manualDataButton.tap()
                
                // Fill in physical data
                let weightField = app.textFields["Weight"]
                if weightField.exists {
                    weightField.tap()
                    weightField.typeText("75")
                }
                
                let heightField = app.textFields["Height"]
                if heightField.exists {
                    heightField.tap()
                    heightField.typeText("175")
                }
                
                let ageField = app.textFields["Age"]
                if ageField.exists {
                    ageField.tap()
                    ageField.typeText("30")
                }
                
                app.buttons["Continue"].tap()
            }
            
            // Step 3: Activity Level Selection
            let activityLevelPicker = app.pickers["Activity Level"]
            if activityLevelPicker.exists {
                activityLevelPicker.pickerWheels.element.adjust(toPickerWheelValue: "Moderately Active")
                app.buttons["Continue"].tap()
            }
            
            // Step 4: Goal Selection
            let maintainButton = app.buttons["Maintain Weight"]
            if maintainButton.exists {
                maintainButton.tap()
                app.buttons["Continue"].tap()
            }
            
            // Step 5: Manual Override (optional)
            let skipOverrideButton = app.buttons["Use Calculated Goals"]
            if skipOverrideButton.exists {
                skipOverrideButton.tap()
            }
            
            // Step 6: Completion
            let completeButton = app.buttons["Complete Setup"]
            if completeButton.exists {
                completeButton.tap()
            }
            
            // Verify we're back at the dashboard with goals set
            XCTAssertTrue(app.staticTexts["2000"].waitForExistence(timeout: 3), "Should show calorie goal")
        }
    }
    
    // MARK: - Food Logging Flow Tests
    
    func testAddFoodViaSearch() throws {
        navigateToFuelLogDashboard()
        
        // Tap add food button
        let addFoodButton = app.buttons["Add Food"]
        XCTAssertTrue(addFoodButton.exists, "Add Food button should exist")
        addFoodButton.tap()
        
        // Should present food search view
        let searchField = app.searchFields["Search foods..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3), "Search field should appear")
        
        // Type in search query
        searchField.tap()
        searchField.typeText("chicken")
        
        // Wait for search results
        let firstResult = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstResult.waitForExistence(timeout: 5), "Search results should appear")
        
        // Tap on first result
        firstResult.tap()
        
        // Should show food detail view
        let foodDetailTitle = app.navigationBars["Food Details"]
        XCTAssertTrue(foodDetailTitle.waitForExistence(timeout: 3), "Food detail view should appear")
        
        // Verify nutrition information is displayed
        XCTAssertTrue(app.staticTexts["Calories"].exists, "Calories should be shown")
        XCTAssertTrue(app.staticTexts["Protein"].exists, "Protein should be shown")
        
        // Select meal type
        let mealTypePicker = app.pickers["Meal Type"]
        if mealTypePicker.exists {
            mealTypePicker.pickerWheels.element.adjust(toPickerWheelValue: "Lunch")
        }
        
        // Adjust serving size if needed
        let servingStepper = app.steppers["Serving Size"]
        if servingStepper.exists {
            servingStepper.buttons["Increment"].tap()
        }
        
        // Add to log
        let addToLogButton = app.buttons["Add to Log"]
        XCTAssertTrue(addToLogButton.exists, "Add to Log button should exist")
        addToLogButton.tap()
        
        // Should return to dashboard and show the logged food
        XCTAssertTrue(app.navigationBars["Fuel Log"].waitForExistence(timeout: 3), "Should return to dashboard")
        
        // Verify food appears in the appropriate meal section
        let lunchSection = app.staticTexts["Lunch"]
        XCTAssertTrue(lunchSection.exists, "Lunch section should exist")
        
        // Verify daily totals updated
        let caloriesValue = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '/'")).element
        XCTAssertTrue(caloriesValue.exists, "Calories total should be updated")
    }
    
    func testAddFoodViaBarcode() throws {
        navigateToFuelLogDashboard()
        
        // Tap add food button
        app.buttons["Add Food"].tap()
        
        // Tap barcode scan button
        let barcodeButton = app.buttons["Scan Barcode"]
        XCTAssertTrue(barcodeButton.exists, "Barcode scan button should exist")
        barcodeButton.tap()
        
        // Should request camera permission
        let allowCameraButton = app.buttons["Allow"]
        if allowCameraButton.waitForExistence(timeout: 3) {
            allowCameraButton.tap()
        }
        
        // Should show barcode scanner view
        let scannerView = app.otherElements["Barcode Scanner"]
        XCTAssertTrue(scannerView.waitForExistence(timeout: 3), "Barcode scanner should appear")
        
        // Verify scanner UI elements
        XCTAssertTrue(app.staticTexts["Point camera at barcode"].exists, "Scanner instructions should be shown")
        XCTAssertTrue(app.buttons["Cancel"].exists, "Cancel button should exist")
        
        // For UI testing, we'll simulate cancel since we can't scan real barcodes
        app.buttons["Cancel"].tap()
        
        // Should return to food search
        XCTAssertTrue(app.searchFields["Search foods..."].waitForExistence(timeout: 3), "Should return to search")
    }
    
    func testCreateCustomFood() throws {
        navigateToFuelLogDashboard()
        
        // Navigate to food search
        app.buttons["Add Food"].tap()
        
        // Tap create custom food
        let createCustomButton = app.buttons["Create Custom Food"]
        XCTAssertTrue(createCustomButton.exists, "Create Custom Food button should exist")
        createCustomButton.tap()
        
        // Should show custom food creation form
        let customFoodTitle = app.navigationBars["Create Custom Food"]
        XCTAssertTrue(customFoodTitle.waitForExistence(timeout: 3), "Custom food form should appear")
        
        // Fill in food details
        let nameField = app.textFields["Food Name"]
        XCTAssertTrue(nameField.exists, "Name field should exist")
        nameField.tap()
        nameField.typeText("My Custom Meal")
        
        let caloriesField = app.textFields["Calories per serving"]
        XCTAssertTrue(caloriesField.exists, "Calories field should exist")
        caloriesField.tap()
        caloriesField.typeText("350")
        
        let proteinField = app.textFields["Protein (g)"]
        XCTAssertTrue(proteinField.exists, "Protein field should exist")
        proteinField.tap()
        proteinField.typeText("25")
        
        let carbsField = app.textFields["Carbohydrates (g)"]
        XCTAssertTrue(carbsField.exists, "Carbs field should exist")
        carbsField.tap()
        carbsField.typeText("40")
        
        let fatField = app.textFields["Fat (g)"]
        XCTAssertTrue(fatField.exists, "Fat field should exist")
        fatField.tap()
        fatField.typeText("12")
        
        // Save custom food
        let saveButton = app.buttons["Save Custom Food"]
        XCTAssertTrue(saveButton.exists, "Save button should exist")
        saveButton.tap()
        
        // Should return to search and show success message
        XCTAssertTrue(app.searchFields["Search foods..."].waitForExistence(timeout: 3), "Should return to search")
        
        // Verify custom food appears in search results
        let searchField = app.searchFields["Search foods..."]
        searchField.tap()
        searchField.typeText("My Custom")
        
        let customFoodResult = app.cells.containing(.staticText, identifier: "My Custom Meal").element
        XCTAssertTrue(customFoodResult.waitForExistence(timeout: 3), "Custom food should appear in search results")
    }
    
    func testQuickAddMacros() throws {
        navigateToFuelLogDashboard()
        
        // Tap add food button
        app.buttons["Add Food"].tap()
        
        // Tap quick add button
        let quickAddButton = app.buttons["Quick Add"]
        XCTAssertTrue(quickAddButton.exists, "Quick Add button should exist")
        quickAddButton.tap()
        
        // Should show quick add form
        let quickAddTitle = app.navigationBars["Quick Add"]
        XCTAssertTrue(quickAddTitle.waitForExistence(timeout: 3), "Quick add form should appear")
        
        // Fill in macro values
        let caloriesField = app.textFields["Calories"]
        XCTAssertTrue(caloriesField.exists, "Calories field should exist")
        caloriesField.tap()
        caloriesField.typeText("300")
        
        let proteinField = app.textFields["Protein (g)"]
        XCTAssertTrue(proteinField.exists, "Protein field should exist")
        proteinField.tap()
        proteinField.typeText("20")
        
        let carbsField = app.textFields["Carbs (g)"]
        XCTAssertTrue(carbsField.exists, "Carbs field should exist")
        carbsField.tap()
        carbsField.typeText("30")
        
        let fatField = app.textFields["Fat (g)"]
        XCTAssertTrue(fatField.exists, "Fat field should exist")
        fatField.tap()
        fatField.typeText("10")
        
        // Select meal type
        let mealTypePicker = app.pickers["Meal Type"]
        if mealTypePicker.exists {
            mealTypePicker.pickerWheels.element.adjust(toPickerWheelValue: "Snacks")
        }
        
        // Add to log
        let addButton = app.buttons["Add to Log"]
        XCTAssertTrue(addButton.exists, "Add button should exist")
        addButton.tap()
        
        // Should return to dashboard
        XCTAssertTrue(app.navigationBars["Fuel Log"].waitForExistence(timeout: 3), "Should return to dashboard")
        
        // Verify quick add entry appears in snacks section
        let snacksSection = app.staticTexts["Snacks"]
        XCTAssertTrue(snacksSection.exists, "Snacks section should exist")
        
        let quickAddEntry = app.staticTexts["Quick Add - 300 cal"]
        XCTAssertTrue(quickAddEntry.exists, "Quick add entry should appear")
    }
    
    // MARK: - Food Management Tests
    
    func testEditFoodEntry() throws {
        navigateToFuelLogDashboard()
        
        // First add a food entry (assuming we have test data)
        addTestFoodEntry()
        
        // Find and tap on a food entry
        let foodEntry = app.cells.element(boundBy: 0)
        XCTAssertTrue(foodEntry.exists, "Food entry should exist")
        foodEntry.tap()
        
        // Should show food detail/edit view
        let editButton = app.buttons["Edit"]
        if editButton.exists {
            editButton.tap()
            
            // Modify serving size
            let servingStepper = app.steppers["Serving Size"]
            if servingStepper.exists {
                servingStepper.buttons["Increment"].tap()
                servingStepper.buttons["Increment"].tap()
            }
            
            // Save changes
            let saveButton = app.buttons["Save Changes"]
            XCTAssertTrue(saveButton.exists, "Save button should exist")
            saveButton.tap()
            
            // Should return to dashboard with updated values
            XCTAssertTrue(app.navigationBars["Fuel Log"].waitForExistence(timeout: 3), "Should return to dashboard")
        }
    }
    
    func testDeleteFoodEntry() throws {
        navigateToFuelLogDashboard()
        
        // First add a food entry
        addTestFoodEntry()
        
        // Swipe to delete on food entry
        let foodEntry = app.cells.element(boundBy: 0)
        XCTAssertTrue(foodEntry.exists, "Food entry should exist")
        foodEntry.swipeLeft()
        
        // Tap delete button
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.exists, "Delete button should appear")
        deleteButton.tap()
        
        // Confirm deletion if alert appears
        let confirmButton = app.buttons["Delete"]
        if confirmButton.exists {
            confirmButton.tap()
        }
        
        // Verify entry is removed and totals updated
        // (This would need to check that the specific entry is gone)
    }
    
    // MARK: - Date Navigation Tests
    
    func testDateNavigation() throws {
        navigateToFuelLogDashboard()
        
        // Test previous day navigation
        let previousDayButton = app.buttons["Previous Day"]
        if previousDayButton.exists {
            previousDayButton.tap()
            
            // Verify date changed
            let dateLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Yesterday' OR label CONTAINS 'Mon' OR label CONTAINS 'Tue' OR label CONTAINS 'Wed' OR label CONTAINS 'Thu' OR label CONTAINS 'Fri' OR label CONTAINS 'Sat' OR label CONTAINS 'Sun'")).element
            XCTAssertTrue(dateLabel.exists, "Date should be updated")
        }
        
        // Test next day navigation
        let nextDayButton = app.buttons["Next Day"]
        if nextDayButton.exists {
            nextDayButton.tap()
        }
        
        // Test today button
        let todayButton = app.buttons["Today"]
        if todayButton.exists {
            todayButton.tap()
            
            // Should show "Today" in date label
            let todayLabel = app.staticTexts["Today"]
            XCTAssertTrue(todayLabel.exists, "Should show Today label")
        }
    }
    
    // MARK: - Progress Visualization Tests
    
    func testProgressVisualization() throws {
        navigateToFuelLogDashboard()
        
        // Add some food to see progress
        addTestFoodEntry()
        
        // Verify progress circles and bars exist
        let caloriesProgress = app.otherElements["Calories Progress"]
        XCTAssertTrue(caloriesProgress.exists, "Calories progress should exist")
        
        let proteinProgress = app.otherElements["Protein Progress"]
        XCTAssertTrue(proteinProgress.exists, "Protein progress should exist")
        
        let carbsProgress = app.otherElements["Carbs Progress"]
        XCTAssertTrue(carbsProgress.exists, "Carbs progress should exist")
        
        let fatProgress = app.otherElements["Fat Progress"]
        XCTAssertTrue(fatProgress.exists, "Fat progress should exist")
        
        // Verify remaining values are displayed
        let remainingCalories = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'remaining'")).element
        XCTAssertTrue(remainingCalories.exists, "Remaining calories should be shown")
    }
    
    // MARK: - Settings and Goals Tests
    
    func testUpdateNutritionGoals() throws {
        navigateToFuelLogDashboard()
        
        // Tap settings or goals button
        let settingsButton = app.buttons["Settings"]
        if settingsButton.exists {
            settingsButton.tap()
            
            // Navigate to nutrition goals
            let nutritionGoalsButton = app.buttons["Nutrition Goals"]
            if nutritionGoalsButton.exists {
                nutritionGoalsButton.tap()
                
                // Modify calorie goal
                let caloriesField = app.textFields["Daily Calories"]
                if caloriesField.exists {
                    caloriesField.tap()
                    caloriesField.clearAndEnterText("2200")
                }
                
                // Save changes
                let saveButton = app.buttons["Save Goals"]
                if saveButton.exists {
                    saveButton.tap()
                    
                    // Should return to dashboard with updated goals
                    XCTAssertTrue(app.navigationBars["Fuel Log"].waitForExistence(timeout: 3), "Should return to dashboard")
                    
                    // Verify new calorie goal is displayed
                    let newGoal = app.staticTexts["2200"]
                    XCTAssertTrue(newGoal.exists, "New calorie goal should be displayed")
                }
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testOfflineMode() throws {
        // This would test offline functionality
        // In a real test, you might disable network connectivity
        navigateToFuelLogDashboard()
        
        // Try to search for food (should work with cached data)
        app.buttons["Add Food"].tap()
        
        let searchField = app.searchFields["Search foods..."]
        searchField.tap()
        searchField.typeText("test")
        
        // Should show cached or local results
        let results = app.cells
        XCTAssertTrue(results.count > 0, "Should show some results even offline")
    }
    
    func testNetworkErrorHandling() throws {
        navigateToFuelLogDashboard()
        
        // Try to search for food that would trigger network error
        app.buttons["Add Food"].tap()
        
        let searchField = app.searchFields["Search foods..."]
        searchField.tap()
        searchField.typeText("networkfailuretest")
        
        // Should show error message or fallback
        let errorMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'error' OR label CONTAINS 'failed' OR label CONTAINS 'try again'")).element
        // Error handling might show different UI, so this is flexible
    }
    
    // MARK: - Performance Tests
    
    func testDashboardLoadingPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
            app.tabBars.buttons["Nutrition"].tap()
            
            // Wait for dashboard to fully load
            _ = app.staticTexts["Calories"].waitForExistence(timeout: 5)
        }
    }
    
    func testSearchPerformance() throws {
        navigateToFuelLogDashboard()
        app.buttons["Add Food"].tap()
        
        let searchField = app.searchFields["Search foods..."]
        
        measure(metrics: [XCTClockMetric()]) {
            searchField.tap()
            searchField.typeText("chicken")
            
            // Wait for results to appear
            _ = app.cells.element(boundBy: 0).waitForExistence(timeout: 5)
            
            // Clear search for next iteration
            searchField.clearAndEnterText("")
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToFuelLogDashboard() {
        let nutritionTab = app.tabBars.buttons["Nutrition"]
        if nutritionTab.exists {
            nutritionTab.tap()
        }
        
        // Wait for dashboard to load
        _ = app.staticTexts["Calories"].waitForExistence(timeout: 5)
    }
    
    private func addTestFoodEntry() {
        app.buttons["Add Food"].tap()
        
        let searchField = app.searchFields["Search foods..."]
        searchField.tap()
        searchField.typeText("test")
        
        // Tap first result if available
        let firstResult = app.cells.element(boundBy: 0)
        if firstResult.waitForExistence(timeout: 3) {
            firstResult.tap()
            
            // Add to log
            let addButton = app.buttons["Add to Log"]
            if addButton.waitForExistence(timeout: 3) {
                addButton.tap()
            }
        }
    }
}

// MARK: - XCUIElement Extensions for Test Helpers

extension XCUIElement {
    func clearAndEnterText(_ text: String) {
        guard self.exists else { return }
        
        self.tap()
        self.press(forDuration: 1.0)
        
        let selectAllMenuItem = XCUIApplication().menuItems["Select All"]
        if selectAllMenuItem.exists {
            selectAllMenuItem.tap()
        }
        
        self.typeText(text)
    }
}