//
//  ItemModifierType.swift
//  FisherKit
//
//  Created by Courtland Bueno on 3/10/19.
//

import Foundation

public protocol ModifierType: ItemBound {
    func modify(_ item: Item) -> Item
}

extension FisherKitManager {
    
    public struct Modifier: ModifierType {
        
        static var `default`: Modifier {
            return .init({ (item) -> Item in
                return item
            })
        }
        
        private let block: (Item) throws -> Item
        
        public init(_ block: @escaping (Item) throws -> Item) {
            self.block = block
        }
        public init<T: ModifierType>(_ m: T) where T.Item == Item {
            self.block = m.modify
        }
        
        public func modify(_ item: Item) -> Item {
            return (try? block(item)) ?? item
        }
    }
}
