/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import XCTest
@testable import LipikaEngine_OSX

class TrieTest: XCTestCase {
    
    var abcTrie = Trie<String, String>()
    
    override func setUp() {
        super.setUp()
        abcTrie["a"] = "A"
        abcTrie["ab"] = "AB"
        abcTrie["abc"] = "ABC"
        abcTrie["abcd"] = "ABCD"
        abcTrie["ax"] = "AX"
        abcTrie["axy"] = "AXY"
        abcTrie["axyz"] = "AXYZ"
        abcTrie["p"] = "P"
        abcTrie["pq"] = "PQ"
        abcTrie["pqr"] = "PQR"
        abcTrie["pqrst"] = "PQRST"
    }
    
    func testCollectionKey() {
        XCTAssertEqual(abcTrie["a"], "A")
        XCTAssertEqual(abcTrie["ab"], "AB")
        XCTAssertEqual(abcTrie["axy"], "AXY")
        XCTAssertEqual(abcTrie["p"], "P")
        XCTAssertNil(abcTrie["pqrs"])
        XCTAssertEqual(abcTrie["pqrs", default: "PQRS"], "PQRS")
    }
    
    func testElementKey() {
        let s1 = abcTrie["a" as Character]
        XCTAssertEqual(s1?.value, "A")
        let s2 = s1!["x" as Character]
        XCTAssertEqual(s2?.value, "AX")
        let s3 = s2!["q" as Character]
        XCTAssertNil(s3)
        let s4 = s2!["g" as Character, default: Trie("AXG")]
        XCTAssertEqual(s4.value, "AXG")
    }
    
    func testCollectionUpdate() {
        abcTrie["ab"] = "Ab"
        XCTAssertEqual(abcTrie["ab"], "Ab")
        XCTAssertEqual(abcTrie["abc"], "ABC")
    }

    func testElementUpdate() {
        let s1 = abcTrie["a" as Character]!["x" as Character]!["y" as Character]
        s1!["z" as Character] = Trie("AXYz")
        XCTAssertEqual(abcTrie["axyz"], "AXYz")
    }
    
    func testKey() {
        XCTAssertEqual(abcTrie["a" as Character]!.key, "a")
        XCTAssertEqual(abcTrie["a" as Character]!["x" as Character]!.key, "ax")
        XCTAssertEqual(abcTrie["a" as Character]!["x" as Character]!["y" as Character]!.key, "axy")
    }
    
    func testParentReference() {
        let digitTrie = Trie<String, String>()
        digitTrie["1"] = "1"
        digitTrie["11"] = "11"
        digitTrie["12"] = "12"
        digitTrie["111"] = "111"
        digitTrie["121"] = "121"
        abcTrie["p" as Character] = digitTrie
        XCTAssertTrue(abcTrie["a" as Character]?.root === abcTrie["p" as Character]?["1" as Character]?["2" as Character]?.parent.parent.parent)
    }
    
    func testRootUpdate() {
        let digitTrie = Trie<String, String>()
        digitTrie["1"] = "1"
        digitTrie["11"] = "11"
        digitTrie["12"] = "12"
        digitTrie["111"] = "111"
        digitTrie["121"] = "121"
        abcTrie["p" as Character] = digitTrie
        XCTAssertTrue(abcTrie["a" as Character]?.root === abcTrie["p" as Character]?["1" as Character]?["2" as Character]?.root)
    }
    
    func testMerge() {
        let anotherTrie = Trie<String, String>()
        anotherTrie["aa"] = "AA"
        anotherTrie["abc"] = "AB_C"
        anotherTrie["abcde"] = "ABCD_E"
        anotherTrie["pqrs"] = "PQRS"
        abcTrie += anotherTrie
        XCTAssertEqual(abcTrie["aa"], "AA")
        XCTAssertTrue(abcTrie["a" as Character]!["a" as Character]!.root === abcTrie.root)
        XCTAssertTrue(abcTrie["a" as Character]!["a" as Character]!.parent.parent === abcTrie.root)
        XCTAssertEqual(abcTrie["abc"], "AB_C")
        XCTAssertTrue(abcTrie["a" as Character]!["b" as Character]!["c" as Character]?.root === abcTrie.root)
        XCTAssertTrue(abcTrie["a" as Character]!["b" as Character]!["c" as Character]?.parent.parent.parent === abcTrie.root)
        XCTAssertEqual(abcTrie["abcde"], "ABCD_E")
        XCTAssertEqual(abcTrie["pqrs"], "PQRS")
        XCTAssertEqual(abcTrie["pqrst"], "PQRST")
    }
}
