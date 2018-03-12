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

class TrieWalkerTest: XCTestCase {
    
    var abcTrie = Trie<String, String>()
    var abcWalker: TrieWalker<String, String>?
    
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
        abcTrie["pqabc"] = "PQABC"
        abcTrie["klm"] = "KLM"
        abcWalker = TrieWalker(trie: abcTrie)
    }
    
    func testHappyCase() {
        let r1 = abcWalker!.walk(input: "a")
        XCTAssertEqual(r1[0].inputs, "a")
        XCTAssertEqual(r1[0].output, "A")
        XCTAssertEqual(r1[0].isRootOutput, true)
        let r2 = abcWalker!.walk(input: "b")
        XCTAssertEqual(r2[0].inputs, "ab")
        XCTAssertEqual(r2[0].output, "AB")
        XCTAssertEqual(r2[0].isRootOutput, false)
        let r3 = abcWalker!.walk(input: "p")
        XCTAssertEqual(r3[0].inputs, "p")
        XCTAssertEqual(r3[0].output, "P")
        XCTAssertEqual(r3[0].isRootOutput, true)
        let r4 = abcWalker!.walk(input: "q")
        XCTAssertEqual(r4[0].inputs, "pq")
        XCTAssertEqual(r4[0].output, "PQ")
        XCTAssertEqual(r4[0].isRootOutput, false)
    }
    
    func testInvalidAtRoot() {
        let r1 = abcWalker!.walk(input: "k")
        XCTAssertEqual(r1[0].inputs, "k")
        XCTAssertEqual(r1[0].output, nil)
        XCTAssertEqual(r1[0].isRootOutput, true)
        let r2 = abcWalker!.walk(input: "l")
        XCTAssertEqual(r2[0].inputs, "kl")
        XCTAssertEqual(r2[0].output, nil)
        XCTAssertEqual(r2[0].isRootOutput, false)
        let r3 = abcWalker!.walk(input: "n")
        XCTAssertEqual(r3[0].inputs, "kln")
        XCTAssertEqual(r3[0].output, nil)
        XCTAssertEqual(r3[0].isRootOutput, true)
    }
    
    func testReplayValidAtRoot() {
        let r1 = abcWalker!.walk(input: "p")
        XCTAssertEqual(r1[0].inputs, "p")
        XCTAssertEqual(r1[0].output, "P")
        XCTAssertEqual(r1[0].isRootOutput, true)
        let r2 = abcWalker!.walk(input: "q")
        XCTAssertEqual(r2[0].inputs, "pq")
        XCTAssertEqual(r2[0].output, "PQ")
        XCTAssertEqual(r2[0].isRootOutput, false)
        let r3 = abcWalker!.walk(input: "a")
        XCTAssertEqual(r3[0].inputs, "pqa")
        XCTAssertEqual(r3[0].output, nil)
        XCTAssertEqual(r3[0].isRootOutput, false)
        let r4 = abcWalker!.walk(input: "b")
        XCTAssertEqual(r4[0].inputs, "pqab")
        XCTAssertEqual(r4[0].output, nil)
        XCTAssertEqual(r4[0].isRootOutput, false)
        let r5 = abcWalker!.walk(input: "p")
        XCTAssertEqual(r5[0].inputs, "a")
        XCTAssertEqual(r5[0].output, "A")
        XCTAssertEqual(r5[0].isRootOutput, true)
        XCTAssertEqual(r5[1].inputs, "ab")
        XCTAssertEqual(r5[1].output, "AB")
        XCTAssertEqual(r5[1].isRootOutput, false)
        XCTAssertEqual(r5[2].inputs, "p")
        XCTAssertEqual(r5[2].output, "P")
        XCTAssertEqual(r5[2].isRootOutput, true)
    }
    
    func testReplayInvalidAtRoot() {
        let r1 = abcWalker!.walk(input: "p")
        XCTAssertEqual(r1[0].inputs, "p")
        XCTAssertEqual(r1[0].output, "P")
        XCTAssertEqual(r1[0].isRootOutput, true)
        let r2 = abcWalker!.walk(input: "q")
        XCTAssertEqual(r2[0].inputs, "pq")
        XCTAssertEqual(r2[0].output, "PQ")
        XCTAssertEqual(r2[0].isRootOutput, false)
        let r3 = abcWalker!.walk(input: "a")
        XCTAssertEqual(r3[0].inputs, "pqa")
        XCTAssertEqual(r3[0].output, nil)
        XCTAssertEqual(r3[0].isRootOutput, false)
        let r4 = abcWalker!.walk(input: "b")
        XCTAssertEqual(r4[0].inputs, "pqab")
        XCTAssertEqual(r4[0].output, nil)
        XCTAssertEqual(r4[0].isRootOutput, false)
        let r5 = abcWalker!.walk(input: "x")
        XCTAssertEqual(r5[0].inputs, "a")
        XCTAssertEqual(r5[0].output, "A")
        XCTAssertEqual(r5[0].isRootOutput, true)
        XCTAssertEqual(r5[1].inputs, "ab")
        XCTAssertEqual(r5[1].output, "AB")
        XCTAssertEqual(r5[1].isRootOutput, false)
        XCTAssertEqual(r5[2].inputs, "x")
        XCTAssertEqual(r5[2].output, nil)
        XCTAssertEqual(r5[2].isRootOutput, true)
    }

}
