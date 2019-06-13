//
//  ProcessorType.swift
//  FisherKit
//
//  Created by Wei Wang on 2016/08/26.
//
//  Copyright (c) 2019 Wei Wang <courtland.bueno@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software

//  without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation

#if canImport(AppKit)
import AppKit
#endif

public protocol ProcessItemType: ItemBound {
    var item: Item? { get }
    var data: Data? { get }
    init (item: Item)
}

extension FisherKitManager {
    /// Represents an item which could be processed by an `ProcessorType`.
    ///
    /// - item: Input item. The processor should provide a way to apply
    ///          processing on this `item` and return the result item.
    /// - data:  Input data. The processor should provide a way to apply
    ///          processing on this `item` and return the result item.
    public enum ProcessItem: ProcessItemType {
        
        /// Input item. The processor should provide a way to apply
        /// processing on this `item` and return the result item.
        case item(Item)
        
        /// Input data. The processor should provide a way to apply
        /// processing on this `item` and return the result item.
        case data(Data)
        
        public var item: Item? {
            guard case let .item(value) = self else { return nil }
            return value
        }
        
        public var data: Data? {
            guard case let .data(value) = self else { return nil }
            return value
        }
        
        public init(item: Item) {
            self = .item(item)
        }
        
    }
    
    
}

/// An `ProcessorType` would be used to convert some downloaded data to an item.
public protocol ProcessorType: OptionBound where Item == ProcessItem.Item {
    
//    associatedtype Option: ManagedOptions
    associatedtype ProcessItem: ProcessItemType
    
    /// Identifier of the processor. It will be used to identify the processor when
    /// caching and retrieving an item. You might want to make sure that processors with
    /// same properties/functionality have the same identifiers, so correct processed items
    /// could be retrieved with proper key.
    ///
    /// - Note: Do not supply an empty string for a customized processor, which is already reserved by
    /// the `DefaultItemProcessor`. It is recommended to use a reverse domain name notation string of
    /// your own for the identifier.
    var identifier: String { get }
    
    /// Processes the input `ProcessItem` with this processor.
    ///
    /// - Parameters:
    ///   - item: Input item which will be processed by `self`.
    ///   - options: The parsed options when processing the item.
    /// - Returns: The processed item.
    ///
    /// - Note: The return value should be `nil` if processing failed while converting an input item to item.
    ///         If `nil` received by the processing caller, an error will be reported and the process flow stops.
    ///         If the processing flow is not critical for your flow, then when the input item is already an item
    ///         (`.item` case) and there is any errors in the processing, you could return the input item itself
    ///         to keep the processing pipeline continuing.
    /// - Note: Most processor only supports CG-based items. watchOS is not supported for processors containing
    ///         a filter, the input item will be returned directly on watchOS.
    func process(item: ProcessItem, options: Option.ParsedOptionsInfo) -> Item?
}

extension ProcessorType  {
    public func process(item: ProcessItem, options: Option.OptionsInfo) -> Item? {
        return process(item: item, options: Option.ParsedOptionsInfo.init(options))
    }
    
    
}

public func ==<T: ProcessorType, U: ProcessorType>(lhs: T, rhs: U) -> Bool where T.Item == U.Item {
    return lhs.identifier == rhs.identifier
}

public func !=<T: ProcessorType, U: ProcessorType>(lhs: T, rhs: U) -> Bool where T.Item == U.Item {
    return !(lhs == rhs)
}


extension FisherKitManager {

    public struct Processor: ProcessorType {
        public typealias Option = FisherKitManager.Option

        public static var `default`: Processor {
            
            return Processor(identifier: "", block: { (processItem, options) -> Item? in
                switch processItem {
                case .data:
                    return nil
                case .item(let item):
                    return item
                }
            })
        }

        public typealias ProcessorImp = (ProcessItem, Option.ParsedOptionsInfo) -> Item?
        
        public let identifier: String
        let p: ProcessorImp
        
        public init(identifier: String, block: @escaping ProcessorImp) {
            self.identifier = identifier
            self.p = block
        }
        
        public init<T: ProcessorType>(_ processor: T)
            where   T.ProcessItem == ProcessItem,
                    T.Option == Option {
            self.identifier = processor.identifier
            self.p = processor.process
        }
        
        public func process(item: ProcessItem, options: Option.ParsedOptionsInfo) -> Item? {
            return p(item, options)
        }
        
        func append<T: ProcessorType>(another: T) -> Processor
            where  T.ProcessItem == Processor.ProcessItem, T.Option == Processor.Option {
            let newIdentifier = identifier.appending("|>\(another.identifier)")
            return Processor(identifier: newIdentifier, block: { (processItem: ProcessItem, options: Option.ParsedOptionsInfo) -> Item? in
                if let item = self.process(item: processItem, options: options) {
                    return another.process(item: .item(item), options: options)
                } else {
                    return nil
                }
            })
        }
        
        static func >>(lhs: Processor, rhs: Processor) -> Processor {
            return lhs.append(another: rhs)
        }
    }
    
}


extension FisherKitManager.Processor {
    static func concatinating<A: ProcessorType, B: ProcessorType>(a: A, b: B) -> FisherKitManager.Processor
        where   A.ProcessItem == B.ProcessItem,
        A.Option == B.Option,
        A.Option == Option,
        A.ProcessItem == ProcessItem
    {
        let newIdentifier = a.identifier.appending("|>\(b.identifier)")
        return FisherKitManager.Processor(identifier: newIdentifier) { (processItem: ProcessItem, options: Option.ParsedOptionsInfo) -> Item? in
            
            if let item = a.process(item: processItem, options: options) {
                return b.process(item: .init(item: item), options: options)
            } else {
                return nil
            }
        }
        
    }
}

protocol DefaultProcessorProvider: ItemBound {
    static var defaultProcessor: FisherKitManager<Item>.Processor { get }
}

extension FisherKitManager: DefaultProcessorProvider where Item: Decodable {
    
    static var defaultProcessor: Processor {
        return Processor(identifier: "decodable", block: { (item, options) -> Item? in
            switch item {
            case .data(let data):
                switch options.decoder {
                case "JSONDecoder":
                    return try? JSONDecoder().decode(Item.self, from: data)
                case "PropertyListDecoder":
                    fallthrough
                default:
                    return try? PropertyListDecoder().decode(Item.self, from: data)
                }
            case .item(let item):
                return item
            }
        })
    }
    
}


