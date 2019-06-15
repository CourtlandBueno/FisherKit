//
//  DataProviderTests.swift
//  FisherKit-MacOSTests
//
//  Created by Courtland Bueno on 3/12/19.
//
import XCTest
@testable import FisherKit

class DataProviderTests: XCTestCase {

    func testLocalFileDataProvider() {
        let fm = FileManager.default
        let document = try! fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let fileURL = document.appendingPathComponent("test")
        try! testImageData.write(to: fileURL)
        
        let provider = LocalFileDataProvider(fileURL: fileURL)
        XCTAssertEqual(provider.cacheKey, fileURL.absoluteString)
        XCTAssertEqual(provider.fileURL, fileURL)
        
        var syncCalled = false
        provider.data { result in
            XCTAssertEqual(result.value, testImageData)
            syncCalled = true
        }
        
        XCTAssertTrue(syncCalled)
        try! fm.removeItem(at: fileURL)
    }
    
    func testBase64DataProvider() {
        let base64String = testImageData.base64EncodedString()
        let provider = Base64DataProvider(base64String: base64String, cacheKey: "123")
        XCTAssertEqual(provider.cacheKey, "123")
        var syncCalled = false
        provider.data { result in
            XCTAssertEqual(result.value, testImageData)
            syncCalled = true
        }
        
        XCTAssertTrue(syncCalled)
    }
    static var allTests = [
        ("testLocalFileDataProvider", testLocalFileDataProvider),
        ("testBase64DataProvider", testBase64DataProvider)
    ]
    
}
