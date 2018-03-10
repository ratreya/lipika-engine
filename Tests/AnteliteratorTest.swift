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

class AnteliteratorTest: XCTestCase {
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
        let anteliterator = try factory!.anteliterator(schemeName: "Barahavat", scriptName: "Hindi")
        let result: String = anteliterator.anteliterate("अत्रेय")
        XCTAssertEqual(result, "atreya")
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
