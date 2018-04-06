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
    let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
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
    
    func testStopCharacter() throws {
        let anteliterator = try factory!.anteliterator(schemeName: "Barahavat", scriptName: "Hindi")
        let result: String = anteliterator.anteliterate("अइये")
        XCTAssertEqual(result, "a\\iye")
    }
    
    func XXXtestAllMappings() throws {
        let factory = try LiteratorFactory(config: MyConfig())
        for schemeName in try factory.availableSchemes() {
            for scriptName in try factory.availableScripts() {
                do {
                    let trans = try factory.transliterator(schemeName: schemeName, scriptName: scriptName)
                    let ante = try factory.anteliterator(schemeName: schemeName, scriptName: scriptName)
                    let input = randomString(length: 10)
                    let output = trans.transliterate(input)
                    let idemInput: String = ante.anteliterate(output.finalaizedOutput + output.unfinalaizedOutput)
                    let idemOutput = trans.transliterate(idemInput)
                    XCTAssertEqual(output.finalaizedOutput, idemOutput.finalaizedOutput)
                    XCTAssertEqual(output.unfinalaizedOutput, idemOutput.unfinalaizedOutput)
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
