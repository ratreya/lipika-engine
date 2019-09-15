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

class MyConfig: Config {
    private let mappingDirectoryName: String
    private let customDirectoryName: String
    private let baseURL = Bundle(for: TransliteratorTest.self).bundleURL.appendingPathComponent("Contents", isDirectory: true).appendingPathComponent("Resources", isDirectory: true)
    
    init(mappingDirectoryName: String = "Mapping", customDirectoryName: String = "Custom") {
        self.mappingDirectoryName = mappingDirectoryName
        self.customDirectoryName = customDirectoryName
    }
    override var stopCharacter: UnicodeScalar {
        return "\\"
    }
    override var mappingDirectory: URL {
        return baseURL.appendingPathComponent(mappingDirectoryName)
    }
    override var customMappingDirectory: URL {
        return baseURL.appendingPathComponent(customDirectoryName)
    }
    override var logLevel: Logger.Level {
        return .debug
    }
}

class TransliteratorTest: XCTestCase {
    private var factory: LiteratorFactory?
    
    override func setUp() {
        super.setUp()
        do {
            factory = try LiteratorFactory(config: MyConfig())
        }
        catch {
            XCTFail("Cannot initiate LiteratorFactory due to \(error)")
        }
    }
    
    func testHappyCase() throws {
        let transliterator = try factory!.transliterator(schemeName: "Barahavat", scriptName: "Hindi")
        let result: Literated = transliterator.transliterate("atreya")
        XCTAssertEqual(result.finalaizedOutput, "अ")
        XCTAssertEqual(result.unfinalaizedOutput, "त्रेय")
    }
    
    func testNestedOutput() throws {
        let transliterator = try factory!.transliterator(schemeName: "Barahavat", scriptName: "Hindi")
        let result: Literated = transliterator.transliterate("aitareya")
        XCTAssertEqual(result.finalaizedOutput, "ऐत")
        XCTAssertEqual(result.unfinalaizedOutput, "रेय")
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
        XCTAssertEqual(result2.finalaizedOutput, "")
        XCTAssertEqual(result2.unfinalaizedOutput, "कॢपि")
    }
    
    func testNoScriptMapping() throws {
        let transliterator = try factory!.transliterator(schemeName: "Barahavat", scriptName: "Kannada")
        let result: Literated = transliterator.transliterate("Ya")
        XCTAssertEqual(result.finalaizedOutput, "")
        XCTAssertEqual(result.unfinalaizedOutput, "Yಅ")
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
    
    func testEscapeCharacter() throws {
        let transliterator = try factory!.transliterator(schemeName: "Baraha", scriptName: "Kannada")
        let result: Literated = transliterator.transliterate("r`!`zoonT`}`zeeE")
        XCTAssertEqual(result.finalaizedOutput, "ರ್!಼ಊನ್ಟ್}಼")
        XCTAssertEqual(result.finalaizedInput, "r`!`zoonT`}`z")
        XCTAssertEqual(result.unfinalaizedOutput, "ಈಏ")
        XCTAssertEqual(result.unfinalaizedInput, "eeE")
    }
    
    func testPartialReplayWithRetroactiveRemoval() throws {
        let transliterator = try factory!.transliterator(schemeName: "Baraha", scriptName: "Kannada")
        let result: Literated = transliterator.transliterate("sUr^^ya")
        XCTAssertEqual(result.finalaizedInput, "sUr")
        XCTAssertEqual(result.unfinalaizedInput, "^^ya")
    }
    
    func testSeriesOfMappedNoOutputs() throws {
        let transliterator = try factory!.transliterator(schemeName: "Barahavat", scriptName: "Devanagari")
        let result: Literated = transliterator.transliterate(".l")
        XCTAssertEqual(result.unfinalaizedInput, ".l")
        XCTAssertEqual(result.unfinalaizedOutput, ".l")
    }
    
    func testSameEpochDoubleRuleMappedNoOutput() throws {
        let transliterator = try factory!.transliterator(schemeName: "Baraha", scriptName: "Gurmukhi")
        let idemResult: Literated = transliterator.transliterate("V\\ch")
        XCTAssertEqual(idemResult.finalaizedOutput + idemResult.unfinalaizedOutput, "Vਛ")
    }

    func testRuleMappedNoOutputs() throws {
        factory = try LiteratorFactory(config: MyConfig(mappingDirectoryName: "LipikaTestMapping"))
        let transliterator = try factory!.transliterator(schemeName: "Test", scriptName: "Test")
        let result1: [Result] = transliterator.transliterate("a")
        XCTAssertEqual(result1[0].output, "a")
        let result2: [Result] = transliterator.transliterate("1")
        XCTAssertEqual(result2[0].output, "क")
        let result3: [Result] = transliterator.transliterate("b")
        XCTAssertEqual(result3[0].output, "क")
        XCTAssertEqual(result3[1].output, "b")
        let result4: [Result] = transliterator.transliterate("4")
        XCTAssertEqual(result4[0].output, "कघ")
        let result5: [Result] = transliterator.transliterate("c")
        XCTAssertEqual(result5[0].output, "कघ")
        XCTAssertEqual(result5[1].output, "c")
        let result6: [Result] = transliterator.transliterate("7")
        XCTAssertEqual(result6[0].output, "छघक")
    }
    
    func testRuleMappedNoOutputsMappedOuputNoMappedOutput() throws {
        factory = try LiteratorFactory(config: MyConfig(mappingDirectoryName: "LipikaTestMapping"))
        let transliterator = try factory!.transliterator(schemeName: "Test", scriptName: "Test")
        let result: [Result] = transliterator.transliterate("a1b4c7W")
        XCTAssertEqual(result[0].output, "छघक")
        XCTAssertEqual(result[1].output, "W")
    }

    func testRuleMappedNoOutputsNoMappedOutput() throws {
        factory = try LiteratorFactory(config: MyConfig(mappingDirectoryName: "LipikaTestMapping"))
        let transliterator = try factory!.transliterator(schemeName: "Test", scriptName: "Test")
        let result: [Result] = transliterator.transliterate("a1b4cW")
        XCTAssertEqual(result[0].output, "कघ")
        XCTAssertEqual(result[1].output, "c")
        XCTAssertEqual(result[2].output, "W")
    }

    func testRuleMappedOutputMappedNoOutputs() throws {
        factory = try LiteratorFactory(config: MyConfig(mappingDirectoryName: "LipikaTestMapping"))
        let transliterator = try factory!.transliterator(schemeName: "Test", scriptName: "Test")
        let result1: [Result] = transliterator.transliterate("c")
        XCTAssertEqual(result1[0].output, "c")
        let result2: [Result] = transliterator.transliterate("7")
        XCTAssertEqual(result2[0].output, "ङ")
        let result3: [Result] = transliterator.transliterate("b")
        XCTAssertEqual(result3[0].output, "ङ")
        XCTAssertEqual(result3[1].output, "b")
        let result4: [Result] = transliterator.transliterate("4")
        XCTAssertEqual(result4[0].output, "ङघ")
        let result5: [Result] = transliterator.transliterate("a")
        XCTAssertEqual(result5[0].output, "ङघ")
        XCTAssertEqual(result5[1].output, "a")
        let result6: [Result] = transliterator.transliterate("1")
        XCTAssertEqual(result6[0].output, "कघछ")
    }

    func testRuleMappedOutputMappedNoOutputsMappedOutputNoMappedOutput() throws {
        factory = try LiteratorFactory(config: MyConfig(mappingDirectoryName: "LipikaTestMapping"))
        let transliterator = try factory!.transliterator(schemeName: "Test", scriptName: "Test")
        let result: [Result] = transliterator.transliterate("c7b4a1W")
        XCTAssertEqual(result[0].output, "कघछ")
        XCTAssertEqual(result[1].output, "W")
    }

    func testRuleMappedOutputMappedNoOutputsNoMappedOuput() throws {
        factory = try LiteratorFactory(config: MyConfig(mappingDirectoryName: "LipikaTestMapping"))
        let transliterator = try factory!.transliterator(schemeName: "Test", scriptName: "Test")
        let result: [Result] = transliterator.transliterate("c7b4aW")
        XCTAssertEqual(result[0].output, "ङघ")
        XCTAssertEqual(result[1].output, "a")
        XCTAssertEqual(result[2].output, "W")
    }
    
    func testSameEpochMappedOutputMappedNoOutput() throws {
        let transliterator = try factory!.transliterator(schemeName: "ITRANS", scriptName: "IPA")
        let idemResult: Literated = transliterator.transliterate("L^|")
        XCTAssertEqual(idemResult.finalaizedOutput + idemResult.unfinalaizedOutput, "L^|")
    }
    
    func testStepBackToNonParent() throws {
        let transliterator = try factory!.transliterator(schemeName: "ITRANS", scriptName: "Devanagari")
        let idemResult: Literated = transliterator.transliterate("kRRI")
        XCTAssertEqual(idemResult.finalaizedOutput + idemResult.unfinalaizedOutput, "कॄ")
    }
    
    func testConvertPosition() throws {
        let transliterator = try factory!.transliterator(schemeName: "Barahavat", scriptName: "Devanagari")
        let result: Literated = transliterator.transliterate("aatreya")
        XCTAssertEqual(result.finalaizedOutput, "आत्")
        XCTAssertEqual(result.unfinalaizedOutput, "रेय")
        let pos1 = transliterator.convertPosition(position: 7, fromUnits: .input, toUnits: .outputScalar)
        XCTAssertEqual(pos1, 6)
        let pos2 = transliterator.convertPosition(position: 2, fromUnits: .input, toUnits: .outputChar)
        XCTAssertEqual(pos2, 1)
        let pos3 = transliterator.convertPosition(position: 2, fromUnits: .outputScalar, toUnits: .input)
        XCTAssertEqual(pos3, 3)
        _ = transliterator.delete()
        let pos4 = transliterator.convertPosition(position: 6, fromUnits: .input, toUnits: .outputScalar)
        XCTAssertEqual(pos4, 7)
    }

    func testInitPerformance() {
        self.measure {
            do {
                _ = try factory!.transliterator(schemeName: "Barahavat", scriptName: "Hindi")
            }
            catch {
                XCTFail(error.localizedDescription)
            }
        }
    }
}
