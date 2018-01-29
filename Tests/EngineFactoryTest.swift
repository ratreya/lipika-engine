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
        testSchemesDirectory = Bundle(for: EngineFactoryTests.self).bundleURL.appendingPathComponent("Mapping")
        XCTAssertNotNil(testSchemesDirectory)
        XCTAssert(FileManager.default.fileExists(atPath: testSchemesDirectory!.path))
    }
    
    func testAvailabilityAPIs() throws {
        let factory = try EngineFactory(schemesDirectory: testSchemesDirectory!)
        XCTAssertEqual(try factory.availableSchemes()?.count, 1)
        XCTAssertEqual(try factory.availableScripts()?.count, 2)
    }
    
    func testMappingsHappyCase() throws {
        do {
            let factory = try EngineFactory(schemesDirectory: testSchemesDirectory!)
            let parsed = try factory.parse(schemeName: "Barahavat", scriptName: "Hindi")
            XCTAssertEqual((parsed.mappings["CONSONANT"]?["KHA"]?.0)!, ["kh", "K"])
            XCTAssertEqual(parsed.mappings["CONSONANT"]?["KHA"]?.1, "ख")
        }
        catch let error {
            XCTFail(error.localizedDescription)
            return
        }
    }
    
    func testMappingOverrides() throws {
        do {
            let factory = try EngineFactory(schemesDirectory: testSchemesDirectory!)
            let parsed = try factory.parse(schemeName: "Barahavat", scriptName: "Hindi")
            XCTAssertEqual((parsed.mappings["DEPENDENT"]?["SHORT E"]?.0)!, ["E"])
            XCTAssertEqual((parsed.mappings["CONSONANT"]?["FA"]?.0)!, ["f"])
            XCTAssertEqual((parsed.mappings["SIGN"]?["UPADHMANIYA"]?.0)!, [".f"])
        }
        catch let error {
            XCTFail(error.localizedDescription)
            return
        }
    }

    func testStartupPerformance() {
        self.measure {
            do {
                let factory = try EngineFactory(schemesDirectory: testSchemesDirectory!)
                let engine = try factory.engine(schemeName: "Barahavat", scriptName: "Hindi")
                XCTAssertNotNil(engine)
            }
            catch let error {
                XCTFail(error.localizedDescription)
            }
        }
    }
}
