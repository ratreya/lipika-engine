/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import XCTest
@testable import LipikaEngine

class EngineFactoryTests: XCTestCase {
    var testSchemesDirectory: URL?

    override func setUp() {
        super.setUp()
        testSchemesDirectory = Bundle(for: EngineFactoryTests.self).bundleURL.appendingPathComponent("Schemes")
        XCTAssertNotNil(testSchemesDirectory)
        XCTAssert(FileManager.default.fileExists(atPath: testSchemesDirectory!.path))
    }
    
    func testAvailabilityAPIs() throws {
        let factory = try EngineFactory(schemesDirectory: testSchemesDirectory!)
        XCTAssertEqual(try factory.availableSchemes()?.count, 1)
        XCTAssertEqual(try factory.availableScripts()?.count, 2)
    }
    
    func testMappingsHappyCase() throws {
        var rules: Rules?
        let factory = try EngineFactory(schemesDirectory: testSchemesDirectory!)
        do {
            rules = try factory.rules(schemeName: "Barahavat", scriptName: "Hindi")
        }
        catch let error {
            XCTFail(error.localizedDescription)
        }
        XCTAssertNotNil(rules)
        XCTAssertEqual((rules?.scheme.mappings["CONSONANT"]?["KHA"]?.0)!, ["kh", "K"])
        XCTAssertEqual(rules?.scheme.mappings["CONSONANT"]?["KHA"]?.1, "ख")
    }
    
    func testMappingOverrides() throws {
        var rules: Rules?
        let factory = try EngineFactory(schemesDirectory: testSchemesDirectory!)
        do {
            rules = try factory.rules(schemeName: "Barahavat", scriptName: "Hindi")
        }
        catch let error {
            XCTFail(error.localizedDescription)
        }
        XCTAssertNotNil(rules)
        XCTAssertEqual((rules?.scheme.mappings["DEPENDENT"]?["SHORT E"]?.0)!, ["E"])
        XCTAssertEqual((rules?.scheme.mappings["CONSONANT"]?["FA"]?.0)!, ["f"])
        XCTAssertEqual((rules?.scheme.mappings["SIGN"]?["UPADHMANIYA"]?.0)!, [".f"])
    }
}
