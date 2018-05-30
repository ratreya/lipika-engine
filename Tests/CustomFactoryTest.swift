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

class CustomFactoryTest: XCTestCase {
    private var customFactory: CustomFactory?
    
    override func setUp() {
        super.setUp()
        do {
            customFactory = try CustomFactory(mappingDirectory: MyConfig(customDirectory: "CustomTestMapping").customMappingsDirectory)
        }
        catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testAvailableCustomMappings() throws {
        XCTAssertEqual(try customFactory?.availableCustomMappings().count, 2)
        XCTAssertEqual(try customFactory?.availableCustomMappings()[0], "TestBarahavat")
        XCTAssertEqual(try customFactory?.availableCustomMappings()[1], "TestKsharanam")
    }
    
    func testSimpleMapping() throws {
        let customEngine = try customFactory?.customEngine(customMapping: "TestBarahavat")
        XCTAssertNotNil(customEngine)
        XCTAssertEqual(customEngine?.execute(input: "a").first!.output, "अ")
        XCTAssertEqual(customEngine?.execute(input: "a").first!.output, "आ")
    }
    
    func testClassMapping() throws {
        let customEngine = try customFactory?.customEngine(customMapping: "TestBarahavat")
        XCTAssertNotNil(customEngine)
        XCTAssertEqual(customEngine?.execute(input: "k").first!.output, "क्")
        XCTAssertEqual(customEngine?.execute(input: "a").first!.output, "क")
        XCTAssertEqual(customEngine?.execute(input: "u").first!.output, "कौ")
    }
    
    func testNoMappedOutput() throws {
        let customEngine = try customFactory?.customEngine(customMapping: "TestBarahavat")
        XCTAssertNotNil(customEngine)
        XCTAssertEqual(customEngine?.execute(input: "W").first!.output, "W")
        XCTAssertEqual(customEngine?.execute(input: "Q").first!.output, "Q")
        XCTAssertEqual(customEngine?.execute(input: "F").first!.output, "F")
    }
    
    func testMappedNoOutput() throws {
        let customEngine = try customFactory?.customEngine(customMapping: "TestBarahavat")
        XCTAssertNotNil(customEngine)
        XCTAssertEqual(customEngine?.execute(input: "k").first!.output, "क्")
        XCTAssertEqual(customEngine?.execute(input: "L").first!.output, "क्L")
        XCTAssertEqual(customEngine?.execute(input: "u").first!.output, "कॢ")
    }
    
    func testPostWildcardMapping() throws {
        let customEngine = try customFactory?.customEngine(customMapping: "TestKsharanam")
        XCTAssertNotNil(customEngine)
        XCTAssertEqual(customEngine?.execute(input: "k").first!.output, "क्")
        XCTAssertEqual(customEngine?.execute(input: "R").first!.output, "क्R")
        XCTAssertEqual(customEngine?.execute(input: "w").first!.output, "कॄ")
    }
    
    func testMappedNoOutputToNoMappedOutput() throws {
        let customEngine = try customFactory?.customEngine(customMapping: "TestKsharanam")
        XCTAssertNotNil(customEngine)
        XCTAssertEqual(customEngine?.execute(input: "k").first!.output, "क्")
        XCTAssertEqual(customEngine?.execute(input: "R").first!.output, "क्R")
        XCTAssertEqual(customEngine?.execute(input: "W").first!.output, "W")
    }

    func testCustomFactoryPerformance() {
        self.measure {
            do {
                _ = try customFactory?.customEngine(customMapping: "TestBarahavat")
            }
            catch {
                XCTFail(error.localizedDescription)
            }
        }
    }
}
