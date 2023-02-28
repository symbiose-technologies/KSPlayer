//
//  SimpleResourceLoaderDelegate.swift
//  DownloadMediaDemo
//
//  Created by Sezorus
//  Copyright © 2018 Sezorus. All rights reserved.
//

import Foundation
import AVFoundation

extension DispatchQueue {
    public static let ksVideoBg = DispatchQueue(label: "KS_VIDEO_BG", qos: .default)
}

class VideoAssetResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate, URLSessionDataDelegate, URLSessionTaskDelegate {

    typealias Completion = (URL?) -> Void
    
    private static let SchemeSuffix = "-streaming"
    
    // MARK: - Properties
    // MARK: Public
    
    var completion: Completion?
    
    lazy var streamingAssetURL: URL = {
        guard var components = URLComponents(url: self.url, resolvingAgainstBaseURL: false) else {
            fatalError()
        }
        components.scheme = (components.scheme ?? "") + VideoAssetResourceLoaderDelegate.SchemeSuffix
        guard let retURL = components.url else {
            fatalError()
        }
        return retURL
    }()
    
    // MARK: Private
    private let accessQueue: DispatchQueue
    private let url:            URL
    private var infoResponse:   URLResponse?
    private var urlSession:     URLSession?
    private lazy var mediaData  = Data()
    private var loadingRequests = [AVAssetResourceLoadingRequest]()
    
    let id: String
    // MARK: - Life Cycle Methods
    
    init(withURL url: URL) {
        self.url = url
        let id =  UUID().uuidString
        self.id = id
        self.accessQueue = DispatchQueue(label: "asset-\(id)", qos: .default)
        super.init()
    }
    
    deinit {
        print("VideoAssetResourceLoaderDelegate deinit")
    }
    // MARK: - Public Methods
    
    func invalidate() {
        accessQueue.async() {
            self.loadingRequests.forEach { $0.finishLoading() }
        }
        self.invalidateURLSession()
    }
    
    // MARK: - AVAssetResourceLoaderDelegate
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        if self.urlSession == nil {
            self.urlSession = self.createURLSession()
            let task = self.urlSession!.dataTask(with: self.url)
            task.resume()
        }
        accessQueue.async() {
            self.loadingRequests.append(loadingRequest)
        }
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        accessQueue.async() {
            if let index = self.loadingRequests.firstIndex(of: loadingRequest) {
                self.loadingRequests.remove(at: index)
            }
        }
    }
    
    // MARK: - URLSessionTaskDelegate
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        var localFileURL: URL? = nil
        if let error = error {
            print("Failed to download media file with error: \(error)")
        } else {
            localFileURL = self.saveMediaDataToLocalFile()
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.completion?(localFileURL)
            self?.invalidateURLSession()
        }
    }
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.infoResponse = response
        self.processRequests()
        
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.mediaData.append(data)
        self.processRequests()
    }
    
    // MARK: - Private Methods
    
    private func createURLSession() -> URLSession {
        let config = URLSessionConfiguration.default
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        return URLSession(configuration: config,
                          delegate: self,
                          delegateQueue: operationQueue)
    }
    
    private func invalidateURLSession() {
        self.urlSession?.invalidateAndCancel()
        self.urlSession = nil
    }
    
    private func isInfo(request: AVAssetResourceLoadingRequest) -> Bool {
        return request.contentInformationRequest != nil
    }

    private func fillInfoRequest(request: inout AVAssetResourceLoadingRequest, response: URLResponse) {
        request.contentInformationRequest?.isByteRangeAccessSupported = true
        request.contentInformationRequest?.contentType = response.mimeType
        request.contentInformationRequest?.contentLength = response.expectedContentLength
    }
    
    private func processRequests() {
        var finishedRequests = Set<AVAssetResourceLoadingRequest>()
        accessQueue.async() {
            self.loadingRequests.forEach {
                var request = $0
                if self.isInfo(request: request), let response = self.infoResponse {
                    self.fillInfoRequest(request: &request, response: response)
                }
                if let dataRequest = request.dataRequest, self.checkAndRespond(forRequest: dataRequest) {
                    finishedRequests.insert(request)
                    request.finishLoading()
                }
            }
            self.loadingRequests = self.loadingRequests.filter { !finishedRequests.contains($0) }
        }
    }
    
    private func checkAndRespond(forRequest dataRequest: AVAssetResourceLoadingDataRequest) -> Bool {
        let downloadedData          = self.mediaData
        let downloadedDataLength    = Int64(downloadedData.count)
        
        let requestRequestedOffset  = dataRequest.requestedOffset
        let requestRequestedLength  = Int64(dataRequest.requestedLength)
        let requestCurrentOffset    = dataRequest.currentOffset
        
        if downloadedDataLength < requestCurrentOffset {
            return false
        }
        
        let downloadedUnreadDataLength  = downloadedDataLength - requestCurrentOffset
        let requestUnreadDataLength     = requestRequestedOffset + requestRequestedLength - requestCurrentOffset
        let respondDataLength           = min(requestUnreadDataLength, downloadedUnreadDataLength)

        dataRequest.respond(with: downloadedData.subdata(in: Range(NSMakeRange(Int(requestCurrentOffset), Int(respondDataLength)))!))
        
        let requestEndOffset = requestRequestedOffset + requestRequestedLength
        
        return requestCurrentOffset >= requestEndOffset
    }
    
    private func saveMediaDataToLocalFile() -> URL? {
        return writeCachedVideoData(self.mediaData,
                                    networkURL: self.url)
    }
    
}


