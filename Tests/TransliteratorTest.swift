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
        let result = transliterator.transliterate("atreya")
        XCTAssertEqual(result.finalaizedOutput, "अत्रे")
        XCTAssertEqual(result.unfinalaizedOutput, "य")
    }
    
    func testTransInitPerformance() {
        self.measure {
            do {
                _ = try factory!.transliterator(schemeName: "Barahavat", scriptName: "Hindi")
            }
            catch let error {
                XCTFail(error.localizedDescription)
            }
        }
    }
    
    func testAnteInitPerformance() {
        self.measure {
            do {
                _ = try factory!.anteliterator(schemeName: "Barahavat", scriptName: "Hindi")
            }
            catch let error {
                XCTFail(error.localizedDescription)
            }
        }
    }
}
