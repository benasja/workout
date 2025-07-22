//
//  workTests.swift
//  workTests
//
//  Created by Benas on 6/27/25.
//

import Testing
@testable import work

struct workTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
    
    @Test func validateSupplementModels() async throws {
        let results = SupplementModelValidation.runAllValidations()
        #expect(results.supplement == true, "Supplement model should be valid")
        #expect(results.supplementLog == true, "SupplementLog model should be valid")
    }

}
