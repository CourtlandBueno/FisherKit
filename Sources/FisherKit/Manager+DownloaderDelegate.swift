//
//  Manager+DownloaderDelegate.swift
//  FisherKit
//
//  Created by Courtland Bueno on 3/8/19.
//

import Foundation

extension FisherKitManager {
    open class AnyDownloaderDelegate {
        
        typealias WillDownloadItemForURLImp = (Downloader, URL, URLRequest?) -> Void
        typealias DidFinishDownloadingItemImp = (Downloader, URL, URLResponse?, Swift.Error?) -> Void
        typealias DidDownloadDataImp = (Downloader, Data, URL) -> Data?
        typealias DidDownloadItemImp = (Downloader, Item, URL, URLResponse?) -> Void
        typealias IsValidStatusCodeImp = (Int,Downloader) -> Bool
        
        private let _willDownloadItemForURL: WillDownloadItemForURLImp
        private let _didFinishDownloadingItemForURL: DidFinishDownloadingItemImp
        private let _didDownloadDataForURL: DidDownloadDataImp
        private let _didDownloadItemForURLWithResponse: DidDownloadItemImp
        private let _isValidStatusCode: IsValidStatusCodeImp
        
        private init(willDownloadItemForURL: @escaping WillDownloadItemForURLImp,
                     didFinishDownloadingItem: @escaping DidFinishDownloadingItemImp,
                     didDownloadData:  @escaping DidDownloadDataImp,
                     didDownloadItem: @escaping DidDownloadItemImp,
                     isValidStatusCode: @escaping IsValidStatusCodeImp) {
            
            self._willDownloadItemForURL = willDownloadItemForURL
            self._didFinishDownloadingItemForURL = didFinishDownloadingItem
            self._didDownloadDataForURL = didDownloadData
            self._didDownloadItemForURLWithResponse = didDownloadItem
            self._isValidStatusCode = isValidStatusCode
        }
        
        init<Delegate: DownloaderDelegate>(_ delegate: Delegate) where Delegate.Item == Item {
            self._willDownloadItemForURL = delegate.downloader
            self._didFinishDownloadingItemForURL = delegate.downloader
            self._didDownloadDataForURL = delegate.downloader
            self._didDownloadItemForURLWithResponse = delegate.downloader
            self._isValidStatusCode = delegate.isValidStatusCode
        }
        
        convenience init() {
            self.init(willDownloadItemForURL: {_,_,_ in },
                      didFinishDownloadingItem: { (_, _, _, _) in },
                      didDownloadData: { (_, data, _) -> Data? in return data },
                      didDownloadItem: { (_, _, _, _) in },
                      isValidStatusCode: { (code, _) -> Bool in return (200..<400).contains(code) })
        }
        
        func downloader(_ downloader: Downloader, didDownload data: Data, for url: URL) -> Data? {
            return _didDownloadDataForURL(downloader,data,url) ?? data
        }
        func downloader(_ downloader: Downloader, willDownloadItemForURL url: URL, with request: URLRequest?) {
            _willDownloadItemForURL(downloader, url, request)
        }
        
        func downloader(_ downloader: Downloader, didDownload item: Item, for url: URL, with response: URLResponse?) {
            _didDownloadItemForURLWithResponse(downloader, item, url, response)
        }
        func downloader(_ downloader: Downloader, didFinishDownloadingItemForURL url: URL, with response: URLResponse?, error: Swift.Error?) {
            _didFinishDownloadingItemForURL(downloader, url, response, error)
        }
        func isValidStatusCode(_ code: Int, for downloader: Downloader) -> Bool {
            return _isValidStatusCode(code, downloader)
        }
    }
}
