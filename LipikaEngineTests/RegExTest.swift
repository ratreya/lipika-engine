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

class RegExTest: XCTestCase {
    
    func testPatternOperator() throws {
        let pattern = try RegEx(pattern: "^[a-z]+$")
        XCTAssert(pattern =~ "test")
        XCTAssertFalse(pattern =~ "1234")
    }
    
    func testMatching() throws {
        let pattern = try RegEx(pattern: "\\s[a-z]+\\s")
        let control = " lipika  board  is  awesome "
        XCTAssert(pattern =~ control)
        XCTAssertEqual(pattern.allMatching()?.count, 4)
        XCTAssertEqual(pattern.allMatching()?.joined(), control)
    }
    
    func testCaptured() throws {
        let pattern = try RegEx(pattern: "\\s([0-9]*)[a-z]+\\s")
        let control = " lipika  board  1s  awesome "
        XCTAssert(pattern =~ control)
        XCTAssertNil(pattern.captured(match: 0))
        XCTAssertNil(pattern.captured(match: 1))
        XCTAssertEqual(pattern.captured(match: 2), "1")
        XCTAssertNil(pattern.captured(match: 3))
    }
}
