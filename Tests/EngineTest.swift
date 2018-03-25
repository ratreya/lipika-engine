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

class EngineTest: XCTestCase {
    var engine: Engine?

    override func setUp() {
        super.setUp()
        let testSchemesDirectory = Bundle(for: EngineTest.self).bundleURL.appendingPathComponent("Mapping")
        XCTAssertNotNil(testSchemesDirectory)
        XCTAssert(FileManager.default.fileExists(atPath: testSchemesDirectory.path))
        do {
            engine = try EngineFactory(schemesDirectory: testSchemesDirectory).engine(schemeName: "Barahavat", scriptName: "Hindi")
        }
        catch let error {
            XCTFail(error.localizedDescription)
        }
        XCTAssertNotNil(engine)
    }
    
    override func tearDown() {
        engine?.reset()
        super.tearDown()
    }
    
    func testHappyCase() throws {
        let r1 = engine?.execute(input: "k")
        XCTAssertEqual(r1?[0].input, "k")
        XCTAssertEqual(r1?[0].output, "क")
        XCTAssertEqual(r1?[0].isPreviousFinal, true)
        let r2 = engine?.execute(input: "k")
        XCTAssertEqual(r2?[0].input, "kk")
        XCTAssertEqual(r2?[0].output, "क्क")
        XCTAssertEqual(r2?[0].isPreviousFinal, false)
        let r3 = engine?.execute(input: "a")
        XCTAssertEqual(r3?[0].input, "kka")
        XCTAssertEqual(r3?[0].output, "क्क")
        XCTAssertEqual(r3?[0].isPreviousFinal, false)
        let r4 = engine?.execute(input: "u")
        XCTAssertEqual(r4?[0].input, "kkau")
        XCTAssertEqual(r4?[0].output, "क्कौ")
        XCTAssertEqual(r4?[0].isPreviousFinal, false)
    }
    
    func testPreviousFinal() throws {
        let r1 = engine?.execute(input: "k")
        XCTAssertEqual(r1?[0].input, "k")
        XCTAssertEqual(r1?[0].output, "क")
        XCTAssertEqual(r1?[0].isPreviousFinal, true)
        let r2 = engine?.execute(input: "u")
        XCTAssertEqual(r2?[0].input, "ku")
        XCTAssertEqual(r2?[0].output, "कु")
        XCTAssertEqual(r2?[0].isPreviousFinal, false)
        let r3 = engine?.execute(input: "m")
        XCTAssertEqual(r3?[0].input, "m")
        XCTAssertEqual(r3?[0].output, "म")
        XCTAssertEqual(r3?[0].isPreviousFinal, true)
        let r4 = engine?.execute(input: "a")
        XCTAssertEqual(r4?[0].input, "ma")
        XCTAssertEqual(r4?[0].output, "म")
        XCTAssertEqual(r4?[0].isPreviousFinal, false)
        let r5 = engine?.execute(input: "a")
        XCTAssertEqual(r5?[0].input, "maa")
        XCTAssertEqual(r5?[0].output, "मा")
        XCTAssertEqual(r5?[0].isPreviousFinal, false)
        let r6 = engine?.execute(input: "r")
        XCTAssertEqual(r6?[0].input, "r")
        XCTAssertEqual(r6?[0].output, "र")
        XCTAssertEqual(r6?[0].isPreviousFinal, true)
    }
    
    func testMappedNoOutput() throws {
        let r1 = engine?.execute(input: "k")
        XCTAssertEqual(r1?[0].input, "k")
        XCTAssertEqual(r1?[0].output, "क")
        XCTAssertEqual(r1?[0].isPreviousFinal, true)
        let r2 = engine?.execute(input: ".")
        // TODO: Fix!
//        XCTAssertEqual(r2?[0].input, "k.")
//        XCTAssertEqual(r2?[0].output, "क.")
        XCTAssertEqual(r2?[0].isPreviousFinal, false)
        let r3 = engine?.execute(input: "l")
//        XCTAssertEqual(r3?[0].input, "k.l")
//        XCTAssertEqual(r3?[0].output, "क.l")
        XCTAssertEqual(r3?[0].isPreviousFinal, false)
        let r4 = engine?.execute(input: "u")
        XCTAssertEqual(r4?[0].input, "k.lu")
        XCTAssertEqual(r4?[0].output, "कॢ")
        XCTAssertEqual(r4?[0].isPreviousFinal, false)
        let r5 = engine?.execute(input: "p")
        XCTAssertEqual(r5?[0].input, "p")
        XCTAssertEqual(r5?[0].output, "प")
        XCTAssertEqual(r5?[0].isPreviousFinal, true)
        let r6 = engine?.execute(input: "i")
        XCTAssertEqual(r6?[0].input, "pi")
        XCTAssertEqual(r6?[0].output, "पि")
        XCTAssertEqual(r6?[0].isPreviousFinal, false)
    }
    
    func testNoMappedOutput() throws {
        let r1 = engine?.execute(input: "(")
        XCTAssertEqual(r1?[0].input, "(")
        XCTAssertEqual(r1?[0].output, "(")
        XCTAssertEqual(r1?[0].isPreviousFinal, true)
        let r2 = engine?.execute(input: ")")
        XCTAssertEqual(r2?[0].input, ")")
        XCTAssertEqual(r2?[0].output, ")")
        XCTAssertEqual(r2?[0].isPreviousFinal, true)
        let r3 = engine?.execute(input: ",")
        XCTAssertEqual(r3?[0].input, ",")
        XCTAssertEqual(r3?[0].output, ",")
        XCTAssertEqual(r3?[0].isPreviousFinal, true)
        _ = engine?.execute(inputs: "ma")
        let r4 = engine?.execute(input: ";")
        XCTAssertEqual(r4?[0].input, ";")
        XCTAssertEqual(r4?[0].output, ";")
        XCTAssertEqual(r4?[0].isPreviousFinal, true)
    }
}
