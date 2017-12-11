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

class RulesTests: XCTestCase {
    var engine: Engine?
    
    override func setUp() {
        super.setUp()
        let testSchemesDirectory = Bundle(for: EngineFactoryTests.self).bundleURL.appendingPathComponent("Schemes")
        XCTAssertNotNil(testSchemesDirectory)
        XCTAssert(FileManager.default.fileExists(atPath: testSchemesDirectory.path))
        do {
            let factory = try EngineFactory(schemesDirectory: testSchemesDirectory)
            engine = try factory.engine(schemeName: "Barahavat", scriptName: "Hindi")
        }
        catch let error {
            XCTFail(error.localizedDescription)
        }
        XCTAssertNotNil(engine)
    }
    
    func testHappyCase() {
        XCTAssertNotNil(engine?.rules.state)
        XCTAssertEqual(engine?.rules.rulesTrie["CONSONANT"]?.value?.generate(intermediates: ["A"]), "A")
        XCTAssertEqual(engine?.rules.rulesTrie["CONSONANT"]?["CONSONANT"]?.value?.generate(intermediates: ["A", "A"]), "A्A")
    }
    
    func testDeepNesting() throws {
        XCTAssertNotNil(engine?.rules.state)
        XCTAssertEqual(engine?.rules.rulesTrie["CONSONANT"]?["CONSONANT"]?["SIGN/NUKTA"]?["DEPENDENT"]?.value?.generate(intermediates: ["A", "B", "C", "D"]), "A्BCD")
    }
    
    func testClassSpecificNextState() throws {
        let s1 = engine?.rules.state(for: ("CONSONANT", "KA"))
        XCTAssertNotNil(s1)
        let s2 = engine?.rules.state(for: ("CONSONANT", "KA"), at: s1)
        XCTAssertEqual(s2?.value?.generate(intermediates: ["A", "A"]), "A्A")
    }
    
    func testMostSpecificNextState() throws {
        let s1 = engine?.rules.state(for: ("CONSONANT", "KA"))
        XCTAssertNotNil(s1)
        let s2 = engine?.rules.state(for: ("CONSONANT", "KA"), at: s1)
        XCTAssertNotNil(s2)
        let s3 = engine?.rules.state(for: ("SIGN", "NUKTA"), at: s2)
        XCTAssertNotNil(s3)
        let s4 = engine?.rules.state(for: ("DEPENDENT", "I"), at: s3)
        XCTAssertNotNil(s4)
        XCTAssertEqual(s4?.value?.generate(intermediates: ["A", "B", "C", "D"]), "A्BCD")
    }
}
