//
//  VideoCache.swift
//  
//
//  Created by Ryan Mckinney on 2/27/23.
//

import Foundation
import AVKit
import AVFoundation

/// Returns an AVURLAsset that is automatically cached. If already cached
/// then returns the cached asset.
func cachedOrCachingAsset(_ URL: Foundation.URL,
                          assetOptions: [String: Any]? = nil,
                          queue: DispatchQueue = DispatchQueue.main) -> AVURLAsset {
    if let localURL = getCachedVideoIfPossible(URL) {
        let asset = AVURLAsset(url: localURL, options: assetOptions)
        return asset
    } else {
        let assetLoader = VideoAssetResourceLoaderDelegate(withURL: URL)
        let asset = AVURLAsset(url: assetLoader.streamingAssetURL)
        asset.resourceLoader.setDelegate(assetLoader, queue: queue)
        objc_setAssociatedObject(asset, "assetLoader", assetLoader, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        // debugLog("\(asset)")
        assetLoader.completion = { localFileURL in
            if let localFileURL = localFileURL {
                print("Media file saved to: \(localFileURL)")
            } else {
                print("Failed to download media file.")
            }
        }
        return asset
    }
    
    
}



func getCachedVideoIfPossible(_ networkURL: URL) -> URL? {
    let fileManager = FileManager.default
    
    guard let localURL = localURLForNetworkURL(networkURL) else { return nil }
    
    if fileManager.fileExists(atPath: localURL.path) == false {
        return nil
    }
//    print("[VideoCache] found local file at: \(localURL) for network URL: \(networkURL)")

    guard let _ = try? Data(contentsOf: localURL) else {
        return nil
    }
    
    return localURL
}


func writeCachedVideoData(_ data: Data, networkURL: URL) -> URL? {
    let fileManager = FileManager.default
    
    guard let fileURL = localURLForNetworkURL(networkURL) else { return nil }
    
    let basePath = fileURL.deletingLastPathComponent()
    
    
    if fileManager.fileExists(atPath: fileURL.path) {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print("Failed to delete file with error: \(error)")
        }
    }
    
    
    do {
        try fileManager.createDirectory(atPath: basePath.path, withIntermediateDirectories: true)
    } catch {
        print("Failed to create directory: \(error)")
        return nil
    }

    let success = fileManager.createFile(atPath: fileURL.path,
                                         contents: data)
//    print("[VideoCache] writeCachedvideoData filePath: \(fileURL.path) success: \(success)")
    
    return fileURL
}


func localURLForNetworkURL(_ network: URL) -> URL? {
    let fileManager = FileManager.default
    
    guard let docFolderURL = fileManager.urls(for: .cachesDirectory,
                                              in: .userDomainMask).first else {
        return nil
    }
    
    guard let components = URLComponents(url: network, resolvingAgainstBaseURL: false) else { return nil }
    
    let fileNetworkPath = "VideoCache\(components.path)"
    print("[FileNetworkPath] \(fileNetworkPath)")
    
    let fileURL = docFolderURL.appendingPathComponent(fileNetworkPath, isDirectory: false)
    print("[Created FileURL] \(fileURL)")
    return fileURL
}

