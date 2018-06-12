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

class EngineFactoryTests: XCTestCase {
    var testSchemesDirectory: URL?

    override func setUp() {
        super.setUp()
        testSchemesDirectory = MyConfig().mappingDirectory
        XCTAssertNotNil(testSchemesDirectory)
        XCTAssert(FileManager.default.fileExists(atPath: testSchemesDirectory!.path))
    }
    
    func testAvailabilityAPIs() throws {
        let factory = try EngineFactory(schemesDirectory: testSchemesDirectory!)
        XCTAssertEqual(try factory.availableSchemes().count, 5)
        XCTAssertEqual(try factory.availableScripts().count, 13)
    }
    
    func testMappingsHappyCase() throws {
        do {
            let factory = try EngineFactory(schemesDirectory: testSchemesDirectory!)
            let parsed = try factory.parse(schemeName: "Barahavat", scriptName: "Hindi")
            XCTAssertEqual((parsed.mappings["CONSONANT"]?["KHA"]?.0)!, ["kh", "K"])
            XCTAssertEqual(parsed.mappings["CONSONANT"]?["KHA"]?.1, "ख")
        }
        catch {
            XCTFail(error.localizedDescription)
            return
        }
    }
    
    func testMappingOverrides() throws {
        do {
            let factory = try EngineFactory(schemesDirectory: testSchemesDirectory!)
            let parsed = try factory.parse(schemeName: "Barahavat", scriptName: "Hindi")
            XCTAssertEqual((parsed.mappings["DEPENDENT"]?["SHORT E"]?.0)!, ["E"])
            XCTAssertEqual((parsed.mappings["CONSONANT"]?["FA"]?.0)!, ["f"])
            XCTAssertEqual((parsed.mappings["SIGN"]?["UPADHMANIYA"]?.0)!, [".f"])
        }
        catch {
            XCTFail(error.localizedDescription)
            return
        }
    }
    
    func testSchemeOverrides() throws {
        let factory = try LiteratorFactory(config: MyConfig())
        let transliterator = try factory.transliterator(schemeName: "Ksharanam", scriptName: "Tamil")
        let result1: Literated = transliterator.transliterate("c")
        XCTAssertEqual(result1.unfinalaizedOutput, "ச்")
        _ = transliterator.reset()
        let result2: Literated = transliterator.transliterate("j")
        XCTAssertEqual(result2.unfinalaizedOutput, "ச்")
    }
    
    func testFactoryPerformance() {
        self.measure {
            do {
                let factory = try EngineFactory(schemesDirectory: testSchemesDirectory!)
                let engine = try factory.engine(schemeName: "Barahavat", scriptName: "Hindi")
                XCTAssertNotNil(engine)
            }
            catch {
                XCTFail(error.localizedDescription)
            }
        }
    }
}
