//
//  ProcessorTests.swift
//  FisherKit-MacOSTests
//
//  Created by Courtland Bueno on 3/8/19.
//

import XCTest
@testable import FisherKit

extension String: FisherKitItemType {
    public static var itemTypeDescription: String {
        return "string"
    }
    
    public var cacheCost: Int {
        return 8 * count
    }
}

extension String: DataTransformable {
    public func toData() throws -> Data {
        return self.data(using: .utf8)!
    }
    
    public static func fromData(_ data: Data) throws -> String {
        return String(data: data, encoding: .utf8)!
    }
    
    public static var empty: String {
        return ""
    }
    
    
}

class ProcessorTests: XCTestCase {
    
    var manager: FisherKitManager<String>!
    
    override func setUp() {
        super.setUp()
        let uuid = UUID()
        let downloader = FisherKitManager<String>.Downloader(name: "test.processor.\(uuid.uuidString)")
        let cache = FisherKitManager<String>.Cache(name: "test.processor.\(uuid.uuidString)")
        manager = .init(downloader: downloader, cache: cache)
    }

    override func tearDown() {
        clearCaches([manager.cache])
        manager = nil
        super.tearDown()
    }
    static var allTests: [(String, (FisherKitTests) -> () -> ())] = []
}
