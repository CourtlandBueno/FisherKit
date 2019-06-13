//
//  ImageDrawingTests.swift
//  FisherKit-MacOSTests
//
//  Created by Courtland Bueno on 3/12/19.
//

import XCTest
@testable import FisherKit

class ImageDrawingTests: XCTestCase {
    
    func testImageResizing() {
        let result = testImage.fk.resize(to: CGSize(width: 20, height: 20))
        XCTAssertEqual(result.size, CGSize(width: 20, height: 20))
    }
    
    func testImageCropping() {
        let result = testImage.fk.crop(to: CGSize(width: 20, height: 20), anchorOn: .zero)
        XCTAssertEqual(result.size, CGSize(width: 20, height: 20))
    }
    
    func testImageScaling() {
        XCTAssertEqual(testImage.fk.scale, 1)
        let result = testImage.fk.scaled(to: 2.0)
        #if os(macOS)
        // No scale supported on macOS.
        XCTAssertEqual(result.fk.scale, 1)
        XCTAssertEqual(result.size.height, testImage.size.height)
        #else
        XCTAssertEqual(result.fk.scale, 2)
        XCTAssertEqual(result.size.height, testImage.size.height / 2)
        #endif
    }
}
