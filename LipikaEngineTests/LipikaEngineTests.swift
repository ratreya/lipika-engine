//
//  LipikaEngineTests.swift
//  LipikaEngineTests
//
//  Created by Atreya Ranganath on 5/16/17.
//  Copyright © 2017 Daivajnanam. All rights reserved.
//

import XCTest
@testable import LipikaEngine

class LipikaEngineTests: XCTestCase {

    var testSchemesDirectory: URL?

    override func setUp() {
        super.setUp()
        testSchemesDirectory = Bundle(for: LipikaEngineTests.self).bundleURL.appendingPathComponent("Schemes")
        XCTAssertNotNil(testSchemesDirectory)
        XCTAssert(FileManager.default.fileExists(atPath: testSchemesDirectory!.path))
    }
    
    func testAvailabilityAPIs() throws {
        let factory = try EngineFactory(schemesDirectory: testSchemesDirectory!)
        XCTAssertEqual(try factory.availableSchemes()?.count, 1)
        XCTAssertEqual(try factory.availableScripts()?.count, 2)
    }
    
    func testHappyCase() throws {
        var engine: Engine?
        let factory = try EngineFactory(schemesDirectory: testSchemesDirectory!)
        do {
            engine = try factory.engine(schemeName: "Barahavat", scriptName: "Hindi")
        }
        catch let error {
            XCTFail(error.localizedDescription)
        }
        XCTAssertNotNil(engine)
        XCTAssertEqual(engine?.scheme.mappings["CONSONANT"]?["KHA"]?.0, "kh, K")
        XCTAssertEqual(engine?.scheme.mappings["CONSONANT"]?["KHA"]?.1, "0916")
    }
    
    func testOverrides() throws {
        var engine: Engine?
        let factory = try EngineFactory(schemesDirectory: testSchemesDirectory!)
        do {
            engine = try factory.engine(schemeName: "Barahavat", scriptName: "Hindi")
        }
        catch let error {
            XCTFail(error.localizedDescription)
        }
        XCTAssertNotNil(engine)
        XCTAssertEqual(engine?.scheme.mappings["DEPENDENT"]?["SHORT E"]?.0, "E")
        XCTAssertEqual(engine?.scheme.mappings["CONSONANT"]?["FA"]?.0, "f")
        XCTAssertEqual(engine?.scheme.mappings["SIGN"]?["UPADHMANIYA"]?.0, ".f")
    }

    
}
