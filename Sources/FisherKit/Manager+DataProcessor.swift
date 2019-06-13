//
//  DataProcessor.swift
//  FisherKit
//
//  Created by Wei Wang on 2018/10/11.
//
//  Copyright (c) 2019 Wei Wang <courtland.bueno@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
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

private let sharedProcessingQueue: CallbackQueue =
    .dispatch(DispatchQueue(label: "com.courtlandbueno.FisherKit.Downloader.Process"))

extension FisherKitManager {
    // Handles item processing work on an own process queue.
    class DataProcessor {
        let source: URL
        let data: Data
        let callbacks: [SessionDataTask.TaskCallback]
        let queue: CallbackQueue
        // Note: We have an optimization choice there, to reduce queue dispatch by checking callback
        // queue settings in each option...
        let onItemProcessed = Delegate<(Result<Item, Error>, SessionDataTask.TaskCallback), Void>()
        
        init(source: URL, data: Data, callbacks: [SessionDataTask.TaskCallback], processingQueue: CallbackQueue?) {
            self.source = source
            self.data = data
            self.callbacks = callbacks
            self.queue = processingQueue ?? sharedProcessingQueue
        }
        
        func process() {
            
            queue.execute(doProcess)
        }
        
        private func doProcess() {
            var processedItems = [String: Item]()
            for callback in callbacks {
                let processor = callback.options.processor
                
                var item = processedItems[processor.identifier]
                if item == nil {
                    item = processor.process(item: .data(data), options: callback.options)
                    processedItems[processor.identifier] = item
                }
                let result: Result<Item, Error>
                if let item = item {
                    var finalItem = item
                    if let modifier = callback.options.modifier {
                        finalItem = modifier.modify(item)
                    }
                    if callback.options.backgroundDecode {
                        finalItem = finalItem.fk.decoded
                    }
                    result = .success(finalItem)
                } else {
                    let error = Error.processorError(
                        reason: .processingFailed(processor: processor, item: .data(data)))
                    result = .failure(error)
                }
                onItemProcessed.call((result, callback))
            }
        }
    }

}
