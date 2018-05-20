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

class CustomFactoryTest: XCTestCase {
    private var customFactory: CustomFactory?
    
    override func setUp() {
        super.setUp()
        do {
            customFactory = try CustomFactory(mappingDirectory: Bundle(for: CustomFactoryTest.self).bundleURL.appendingPathComponent("CustomTestMapping"))
        }
        catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testAvailableCustomMappings() throws {
        XCTAssertEqual(try customFactory?.availableCustomMappings().count, 2)
        XCTAssertEqual(try customFactory?.availableCustomMappings()[0], "TestBarahavat")
        XCTAssertEqual(try customFactory?.availableCustomMappings()[1], "TestKsharanam")
    }
    
    func testBarahavat() throws {
        let customEngine = try customFactory?.customEngine(customMapping: "TestBarahavat")
        XCTAssertNotNil(customEngine)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
