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

func randomString(length: Int) -> String {
    let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789`~!@#$%^&*()-_=+/?>.,<[{]}\\|"
    let len = UInt32(letters.length)
    var randomString = ""
    for _ in 0 ..< length {
        let rand = arc4random_uniform(len)
        var nextChar = letters.character(at: Int(rand))
        randomString += NSString(characters: &nextChar, length: 1) as String
    }
    return randomString
}

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
    
    func testAutoStopCharacter() throws {
        let anteliterator = try factory!.anteliterator(schemeName: "Barahavat", scriptName: "Hindi")
        let result: String = anteliterator.anteliterate("अइयउ")
        XCTAssertEqual(result, "a\\iya\\u")
    }
    
    func testTypeKeyMappedNoOutput() throws {
        let anteliterator = try factory!.anteliterator(schemeName: "Barahavat", scriptName: "Devanagari")
        let result: String = anteliterator.anteliterate("़्")
        XCTAssertEqual(result, "zq")
    }
    
    func testStopCharacter() throws {
        let anteliterator = try factory!.anteliterator(schemeName: "Barahavat", scriptName: "Devanagari")
        let result: String = anteliterator.anteliterate("=\\-")
        XCTAssertEqual(result, "=\\-")
    }
    
    func testBindingOrder() throws {
        let anteliterator = try factory!.anteliterator(schemeName: "Barahavat", scriptName: "Devanagari")
        let result: String = anteliterator.anteliterate("कई")
        XCTAssertEqual(result, "ka\\ii")
    }
    
    func testAmbiguousBackslash() throws {
        let anteliterator = try factory!.anteliterator(schemeName: "Barahavat", scriptName: "Devanagari")
        let result: String = anteliterator.anteliterate("ख्\\ओ")
        XCTAssertEqual(result, "kh\\\\o")
    }
    
    func testTrailingBackslash() throws {
        let anteliterator = try factory!.anteliterator(schemeName: "Barahavat", scriptName: "Devanagari")
        let result: String = anteliterator.anteliterate("ख्\\ओ\\")
        XCTAssertEqual(result, "kh\\\\o\\\\")
    }

    func testMappedNoOutput() throws {
        let anteliterator = try factory!.anteliterator(schemeName: "Barahavat", scriptName: "Devanagari")
        let result: String = anteliterator.anteliterate("तु.lW")
        XCTAssertEqual(result, "tu.lW")
    }
    
    func testStopCharForSucceeding() throws {
        let anteliterator = try factory!.anteliterator(schemeName: "Barahavat", scriptName: "Devanagari")
        let result: String = anteliterator.anteliterate("Rश़्~")
        XCTAssertEqual(result, "R\\shz~")
    }
    
    func testMulticodepoint() throws {
        let anteliterator = try factory!.anteliterator(schemeName: "Barahavat", scriptName: "IPA")
        let result: String = anteliterator.anteliterate("kl̪̩")
        XCTAssertEqual(result, "k\\.lu")
    }

    // Regression test for an infitite recursion bug
    func testEpochMappedOuputWithHiatus() throws {
        let anteliterator = try factory!.anteliterator(schemeName: "Barahavat", scriptName: "IPA")
        let result: String = anteliterator.anteliterate("t͡ɕ")
        XCTAssertEqual(result, "c")
    }
    
    func testNecessaryAppendage() throws {
        let anteliterator = try factory!.anteliterator(schemeName: "Barahavat", scriptName: "IPA")
        let result: String = anteliterator.anteliterate("d͡ʑt͡ɕ")
        XCTAssertEqual(result, "jc")
    }

    func XXXtestAllMappings() throws {
        let factory = try LiteratorFactory(config: MyConfig())
        for schemeName in try factory.availableSchemes() {
            for scriptName in try factory.availableScripts() {
                do {
                    let trans = try factory.transliterator(schemeName: schemeName, scriptName: scriptName)
                    let ante = try factory.anteliterator(schemeName: schemeName, scriptName: scriptName)
                    let input = randomString(length: 10)
                    let output: Literated = trans.transliterate(input)
                    let idemInput: String = ante.anteliterate(output.finalaizedOutput + output.unfinalaizedOutput)
                    _ = trans.reset()
                    let idemOutput: Literated = trans.transliterate(idemInput)
                    XCTAssertEqual(output.finalaizedOutput + output.unfinalaizedOutput, idemOutput.finalaizedOutput + idemOutput.unfinalaizedOutput, "\(schemeName) and \(scriptName) with input: \(input) and idemInput: \(idemInput)")
                }
                catch let error {
                    XCTFail(error.localizedDescription)
                }
            }
        }
    }

    func testInitPerformance() {
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
