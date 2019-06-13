//
//  FisherKitManagerTests.swift
//  FisherKit-MacOSTests
//
//  Created by Courtland Bueno on 3/10/19.
//

import XCTest
@testable import FisherKit

struct TestItem {
    let key: String
    let value: String
}
extension TestItem: FisherKitItemType {
    static var itemTypeDescription: String {
        return "test_item"
    }
    
    var cacheCost: Int {
        return key.count * 8 + value.count * 8
    }
}

struct CodableTestItem: Codable {
    let key: String
    let value: String
}

extension CodableTestItem: FisherKitItemType {
    static var itemTypeDescription: String {
        return "codable_test_item"
    }
    
    var cacheCost: Int {
        return key.count * 8 + value.count * 8
    }
}
class FisherKitManagerTests: XCTestCase {
    
//    var manager: FisherKitManager<TestItem>!
    
    override func setUp() {
        super.setUp()
//        let uuid = UUID()
//        let downloader = FisherKitManager<TestItem>.Downloader(name: "test.managerr.\(uuid.uuidString)")
//        let cache = FisherKitManager<TestItem>.Cache(name: "test.manager.\(uuid.uuidString)")
//        manager = .init(downloader: downloader, cache: cache)
    }
    
    func testManagerInitializaationWithDefaultItem() {
        let uuid = UUID()
        let downloader = FisherKitManager<TestItem>.Downloader(name: "test.managerr.\(uuid.uuidString)")
        let cache = FisherKitManager<TestItem>.Cache(name: "test.manager.\(uuid.uuidString)")
        let manager = FisherKitManager<TestItem>.init(downloader: downloader, cache: cache)
        
        
        let options = FisherKitManager<TestItem>.Option.parse(manager.defaultOptions)
        XCTAssert(options.processor == FisherKitManager<TestItem>.Processor.default)
        
        XCTAssert(options.cacheSerializer == FisherKitManager<TestItem>.Cache.Serializer.default)
        
        
        
        clearCaches([manager.cache])
        
        super.tearDown()
    }
    func testManagerInitilizationWithCodableItem() {
       
        let manager = FisherKitManager<CodableTestItem>.init()
        
        
        let options = FisherKitManager<CodableTestItem>.Option.parse(manager.defaultOptions)
        XCTAssert(options.processor == FisherKitManager<CodableTestItem>.defaultProcessor)
        
        XCTAssert(options.cacheSerializer == FisherKitManager<CodableTestItem>.defaultSerializer)
        
        
        
        clearCaches([manager.cache])
        
        super.tearDown()
    }
    
    override func tearDown() {
//        clearCaches([manager.cache])
//        manager = nil
        super.tearDown()
    }
    
    static var allTests = [
        ("testManagerInitializaationWithDefaultItem", testManagerInitializaationWithDefaultItem),
        ("testManagerInitilizationWithCodableItem", testManagerInitilizationWithCodableItem)
    ]
}
