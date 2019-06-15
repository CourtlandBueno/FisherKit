//
//  FisherKitItemType.swift
//  FisherKit
//
//  Created by Courtland Bueno on 6/15/19.
//

import Foundation

public protocol FisherKitItemType: CacheCostCalculable, FisherKitCompatible {
    static var itemTypeDescription: String { get }
}

public extension FisherKitItemType {
    static var itemTypeDescription: String {
        return String(describing: type(of: Self.self))
    }
}

public protocol ItemBound {
    associatedtype Item: FisherKitItemType
    
    static var itemType: Item.Type { get }
}

extension ItemBound {
    public static var itemType: Item.Type {
        return Item.self
    }
}


extension String: FisherKitItemType {
    public static var itemTypeDescription: String {
        return "String"
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
