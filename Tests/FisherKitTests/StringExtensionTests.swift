//
//  StringExtensionTests.swift
//  FisherKit
//
//  Created by Courtland Bueno on 6/15/19.
//

import XCTest
@testable import FisherKit

class StringExtensionTests: XCTestCase {
    func testStringMD5() {
        let s = "hello"
        XCTAssertEqual(s.fk.md5, "5d41402abc4b2a76b9719d911017c592")
    }
    
    static var allTests = [
        ("testStringMD5", testStringMD5)
    ]
}
