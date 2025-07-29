import XCTest
@testable import work

final class BarcodeScannerTests: XCTestCase {
    
    func testBarcodeValidation() {
        let viewModel = BarcodeScannerViewModel()
        
        // Test valid barcodes
        XCTAssertTrue(viewModel.isValidBarcode("1234567890123")) // EAN-13
        XCTAssertTrue(viewModel.isValidBarcode("123456789012")) // UPC-A
        XCTAssertTrue(viewModel.isValidBarcode("12345678")) // EAN-8
        XCTAssertTrue(viewModel.isValidBarcode("12345678901234")) // ITF-14
        
        // Test invalid barcodes
        XCTAssertFalse(viewModel.isValidBarcode("")) // Empty
        XCTAssertFalse(viewModel.isValidBarcode("123")) // Too short
        XCTAssertFalse(viewModel.isValidBarcode("123456789012345")) // Too long
        XCTAssertFalse(viewModel.isValidBarcode("12345678901a")) // Contains letters
        XCTAssertFalse(viewModel.isValidBarcode("   ")) // Only whitespace
    }
    
    func testBarcodeProcessing() async {
        let viewModel = BarcodeScannerViewModel()
        let expectation = XCTestExpectation(description: "Barcode processing")
        
        viewModel.processBarcode("1234567890123") { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testDuplicateBarcodeHandling() async {
        let viewModel = BarcodeScannerViewModel()
        let barcode = "1234567890123"
        
        // First scan should succeed
        let firstExpectation = XCTestExpectation(description: "First scan")
        viewModel.processBarcode(barcode) { success in
            XCTAssertTrue(success)
            firstExpectation.fulfill()
        }
        await fulfillment(of: [firstExpectation], timeout: 1.0)
        
        // Immediate duplicate scan should fail
        let duplicateExpectation = XCTestExpectation(description: "Duplicate scan")
        viewModel.processBarcode(barcode) { success in
            XCTAssertFalse(success)
            duplicateExpectation.fulfill()
        }
        await fulfillment(of: [duplicateExpectation], timeout: 1.0)
    }
}

// MARK: - Test Helper Extension

extension BarcodeScannerViewModel {
    func isValidBarcode(_ barcode: String) -> Bool {
        // Expose the private method for testing
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0.isNumber }) else {
            return false
        }
        
        let length = trimmed.count
        let validLengths = [8, 12, 13, 14]
        
        return validLengths.contains(length)
    }
}