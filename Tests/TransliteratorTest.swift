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

class MyConfig: Config {
    var stopCharacter: UnicodeScalar {
        return "\\"
    }
    var schemesDirectory: URL {
        return Bundle(for: TransliteratorTest.self).bundleURL.appendingPathComponent("Mapping")
    }
    var logLevel: Level {
        return .Debug
    }
}

class TransliteratorTest: XCTestCase {
    private var factory: LiteratorFactory?
    
    override func setUp() {
        super.setUp()
        do {
            factory = try LiteratorFactory(config: MyConfig())
        }
        catch let error {
            XCTFail("Cannot initiate LiteratorFactory due to \(error)")
        }
    }
    
    func testHappyCase() throws {
        let transliterator = try factory!.transliterator(schemeName: "Barahavat", scriptName: "Hindi")
        let result: Literated = transliterator.transliterate("atreya")
        XCTAssertEqual(result.finalaizedOutput, "अत्रे")
        XCTAssertEqual(result.unfinalaizedOutput, "य")
    }
    
    func testNestedOutput() throws {
        let transliterator = try factory!.transliterator(schemeName: "Barahavat", scriptName: "Hindi")
        let result: Literated = transliterator.transliterate("aitareya")
        XCTAssertEqual(result.finalaizedOutput, "ऐतरे")
        XCTAssertEqual(result.unfinalaizedOutput, "य")
    }
    
    func testMappedNoOutput() throws {
        let transliterator = try factory!.transliterator(schemeName: "Barahavat", scriptName: "Hindi")
        let result: Literated = transliterator.transliterate("k.l")
        XCTAssertEqual(result.finalaizedOutput, "")
        XCTAssertEqual(result.unfinalaizedOutput, "क.l")
        let result1: Literated = transliterator.transliterate("u")
        XCTAssertEqual(result1.finalaizedOutput, "")
        XCTAssertEqual(result1.unfinalaizedOutput, "कॢ")
        let result2: Literated = transliterator.transliterate("pi")
        XCTAssertEqual(result2.finalaizedOutput, "कॢ")
        XCTAssertEqual(result2.unfinalaizedOutput, "पि")
    }
    
    func testNoScriptMapping() throws {
        let transliterator = try factory!.transliterator(schemeName: "Barahavat", scriptName: "Kannada")
        let result: Literated = transliterator.transliterate("Ya")
        XCTAssertEqual(result.finalaizedOutput, "Y")
        XCTAssertEqual(result.unfinalaizedOutput, "ಅ")
    }
    
    func testStopCharacter() throws {
        let transliterator = try factory!.transliterator(schemeName: "Barahavat", scriptName: "Devanagari")
        let result: Literated = transliterator.transliterate("k\\.lu")
        XCTAssertEqual(result.finalaizedOutput, "क्")
        XCTAssertEqual(result.unfinalaizedOutput, "ऌ")
        let result1: Literated = transliterator.transliterate("k\\\\.lu")
        XCTAssertEqual(result1.finalaizedOutput, "क्ऌक्\\")
        XCTAssertEqual(result1.unfinalaizedOutput, "ऌ")
        let result2: Literated = transliterator.transliterate("\\\\\\")
        XCTAssertEqual(result2.finalaizedOutput, "क्ऌक्\\ऌ\\")
        XCTAssertEqual(result2.unfinalaizedOutput, "")
    }

    func testInitPerformance() {
        self.measure {
            do {
                _ = try factory!.transliterator(schemeName: "Barahavat", scriptName: "Hindi")
            }
            catch let error {
                XCTFail(error.localizedDescription)
            }
        }
    }
}
