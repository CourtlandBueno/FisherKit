//
//  Cache+Processor.swift
//  FisherKit
//
//  Created by Courtland Bueno on 3/8/19.
//

import Foundation

extension FisherKitManager.Cache {
    
    public struct Serializer: CacheSerializerType {
        
        public typealias Option = FisherKitManager.Option
        
        public typealias SerializationImp = (Item, Data?, Option.ParsedOptionsInfo) -> Data?
        public typealias DeserializationImp = (Data, Option.ParsedOptionsInfo) -> Item?
        
        public let identifier: String
        private let _serializationImp: SerializationImp
        private let _deserializationImp: DeserializationImp
        
        public static var `default`: Serializer {
            return Serializer()
        }
        
        public init(identifier: String ,
                    serialization: @escaping SerializationImp,
                    deserialization: @escaping DeserializationImp) {
            self.identifier = identifier
            self._serializationImp = serialization
            self._deserializationImp = deserialization
        }
        
        public init<CacheSerializer: CacheSerializerType>(_ serializer: CacheSerializer)
            where   CacheSerializer.Item == Item,
                    CacheSerializer.Option == Option {
            self.identifier = serializer.identifier
            self._serializationImp = serializer.data
            self._deserializationImp = serializer.item
        }
        
        init() {
            self.init(identifier: "",
                      serialization: { item, original, options in return original },
                      deserialization: { data, options in return nil } )
            
        }
        
        public func item(with data: Data, options: Option.ParsedOptionsInfo) -> Item? {
            return _deserializationImp(data, options)
        }
        
        public func data(with item: Item, original: Data?, options: Option.ParsedOptionsInfo) -> Data? {
            return _serializationImp(item, original, options)
        }
        
        public static func ==(lhs: Serializer, rhs: Serializer) -> Bool {
            return lhs.identifier == rhs.identifier
        }
        public static func !=(lhs: Serializer, rhs: Serializer) -> Bool {
            return !(lhs == rhs)
        }
    }
}

protocol DefaultSerializerProvider: ItemBound {
    static var defaultSerializer: FisherKitManager<Item>.Cache.Serializer { get }
}

extension FisherKitManager: DefaultSerializerProvider where Item: Codable {
    static var defaultSerializer: Cache.Serializer {
        return Cache.Serializer.init(
            identifier: "codable",
            serialization: { (item, originalData, options) -> Data? in
            switch options.encoder {
            case "JSONEncoder":
               return try? JSONEncoder().encode(item)
            case "PropertyListEncoder":
                fallthrough
            default:
                return try? PropertyListEncoder().encode(item)
            }
            
        }, deserialization: { data, options -> Item? in
            switch options.decoder {
            case "JSONDecoder":
                return try? JSONDecoder().decode(Item.self, from: data)
            case "PropertyListDecoder":
                fallthrough
            default:
                return try? PropertyListDecoder().decode(Item.self, from: data)
            }
        })
    }
}
