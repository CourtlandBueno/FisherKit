//
//  CodableSerialization.swift
//  FisherKit
//
//  Created by Courtland Bueno on 6/15/19.
//

import Foundation

public protocol CodableEncoder {
    func encode<T: Encodable>(_ value: T) throws -> Data
}

public protocol CodableDecoder {
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}

extension PropertyListEncoder: CodableEncoder { }
extension PropertyListDecoder: CodableDecoder { }

extension JSONEncoder: CodableEncoder { }
extension JSONDecoder: CodableDecoder { }

extension FisherKitManager where Item: Codable {
    public convenience init(encoder: String = "JSONEncoder", decoder: String = "JSONDecoder") {
        self.init(downloader: .default, cache: .default)
        self.defaultOptions = [
            .processor(FisherKitManager.defaultProcessor),
            .cacheSerializer(FisherKitManager.defaultSerializer),
            .dataProcessingInfo(["encoder": encoder, "decoder" : decoder])
        ]
        
    }
}
