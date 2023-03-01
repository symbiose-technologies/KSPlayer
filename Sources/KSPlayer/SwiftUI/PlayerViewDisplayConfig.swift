//
//  File.swift
//  
//
//  Created by Ryan Mckinney on 3/1/23.
//

import Foundation

public struct PlayerViewDisplayConfig: Equatable, Hashable {
    
    var keyboardShortcutsEnabled: Bool
    var setNavigationInfo: Bool
    var swipeToSeekEnabled: Bool
    var macDoubleTapFullScreen: Bool
    var acceptDroppedURL: Bool
    var showCloseBtn: Bool
    var playOnAppear: Bool
    var pauseOnDisappear: Bool
    var autoMute: Bool
}



public extension PlayerViewDisplayConfig {
    
    static func justThePlayer() -> PlayerViewDisplayConfig {
        return PlayerViewDisplayConfig(keyboardShortcutsEnabled: false,
                                       setNavigationInfo: false,
                                       swipeToSeekEnabled: false,
                                       macDoubleTapFullScreen: false,
                                       acceptDroppedURL: false,
                                       showCloseBtn: false,
                                       playOnAppear: false,
                                       pauseOnDisappear: false,
                                       autoMute: true
        )
    }
}
