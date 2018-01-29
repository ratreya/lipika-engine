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
    var rules: Rules?
    
    override func setUp() {
        super.setUp()
        let testSchemesDirectory = Bundle(for: RulesTests.self).bundleURL.appendingPathComponent("Mapping")
        XCTAssertNotNil(testSchemesDirectory)
        XCTAssert(FileManager.default.fileExists(atPath: testSchemesDirectory.path))
        do {
            let factory = try EngineFactory(schemesDirectory: testSchemesDirectory)
            rules = try factory.rules(schemeName: "Barahavat", scriptName: "Hindi")
        }
        catch let error {
            XCTFail(error.localizedDescription)
        }
        XCTAssertNotNil(rules)
    }
    
    func testHappyCase() {
        XCTAssertEqual(rules?.rulesTrie[RuleInput(type: "CONSONANT")]?.value?.generate(intermediates: ["A"]), "A")
        XCTAssertEqual(rules?.rulesTrie[RuleInput(type: "CONSONANT")]?[RuleInput(type: "CONSONANT")]?.value?.generate(intermediates: ["A", "A"]), "A्A")
    }
    
    func testDeepNesting() throws {
        XCTAssertEqual(rules?.rulesTrie[RuleInput(type: "CONSONANT")]?[RuleInput(type: "CONSONANT")]?[RuleInput(type: "SIGN", key: "NUKTA")]?[RuleInput(type: "DEPENDENT")]?.value?.generate(intermediates: ["A", "B", "C", "D"]), "A्BCD")
    }
    
    func testClassSpecificNextState() throws {
        let s1 = rules?.rulesTrie[RuleInput(type: "CONSONANT", key: "KA")]
        XCTAssertNotNil(s1)
        let s2 = s1?[RuleInput(type: "CONSONANT", key: "KA")]
        XCTAssertEqual(s2?.value?.generate(intermediates: ["A", "A"]), "A्A")
    }
    
    func testMultipleForwardMappings() throws {
        let result = rules?.forwardTrie["a"]
        XCTAssertEqual(result?.count, 2)
    }
    
    func testMostSpecificNextState() throws {
        let s1 = rules?.rulesTrie[RuleInput(type: "CONSONANT", key: "KA")]
        XCTAssertNotNil(s1)
        let s2 = s1?[RuleInput(type: "CONSONANT", key: "KA")]
        XCTAssertNotNil(s2)
        let s3 = s2?[RuleInput(type: "SIGN", key: "NUKTA")]
        XCTAssertNotNil(s3)
        let s4 = s3?[RuleInput(type: "DEPENDENT", key: "I")]
        XCTAssertNotNil(s4)
        XCTAssertEqual(s4?.value?.generate(intermediates: ["A", "B", "C", "D"]), "A्BCD")
    }
}
