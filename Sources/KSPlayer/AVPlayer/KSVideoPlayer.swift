//
//  KSVideoPlayer.swift
//  KSPlayer
//
//  Created by kintan on 2023/2/11.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#else
import AppKit
public typealias UIViewRepresentable = NSViewRepresentable
#endif

public struct KSVideoPlayer {
    public let coordinator: Coordinator
    public let url: URL
    public let options: KSOptions
    public init(coordinator: Coordinator, url: URL, options: KSOptions) {
        self.coordinator = coordinator
        self.url = url
        self.options = options
    }
}

extension KSVideoPlayer: UIViewRepresentable {
    public func makeCoordinator() -> Coordinator {
        coordinator
    }

    #if canImport(UIKit)
    public typealias UIViewType = KSPlayerLayer
    public func makeUIView(context: Context) -> UIViewType {
        let view = context.coordinator.makeView(url: url, options: options)
        let swipeDown = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipeGestureAction(_:)))
        swipeDown.direction = .down
        view.addGestureRecognizer(swipeDown)
        let swipeLeft = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipeGestureAction(_:)))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)
        let swipeRight = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipeGestureAction(_:)))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
        let swipeUp = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipeGestureAction(_:)))
        swipeUp.direction = .up
        view.addGestureRecognizer(swipeUp)
        return view
    }

    public func updateUIView(_ uiView: UIViewType, context: Context) {
        updateView(uiView, context: context)
    }

    public static func dismantleUIView(_: UIViewType, coordinator: Coordinator) {
        #if os(tvOS)
        coordinator.playerLayer?.delegate = nil
        coordinator.playerLayer?.pause()
        coordinator.playerLayer = nil
        #endif
    }
    #else
    public typealias NSViewType = KSPlayerLayer
    public func makeNSView(context: Context) -> NSViewType {
        context.coordinator.makeView(url: url, options: options)
    }

    public func updateNSView(_ uiView: NSViewType, context: Context) {
        updateView(uiView, context: context)
    }

    public static func dismantleNSView(_: NSViewType, coordinator _: Coordinator) {}
    #endif

    private func updateView(_ view: KSPlayerLayer, context: Context) {
        if view.url != url {
            view.delegate = nil
            view.set(url: url, options: options)
            view.delegate = context.coordinator
        }
    }

    public final class Coordinator: ObservableObject {
        @Published public var isPlay: Bool = false {
            didSet {
                if isPlay != oldValue {
                    isPlay ? playerLayer?.play() : playerLayer?.pause()
                }
            }
        }
        
        
        @Published public var isMuted: Bool = false {
            didSet {
                playerLayer?.player.isMuted = isMuted
            }
        }

        @Published public var isScaleAspectFill = false {
            didSet {
                playerLayer?.player.contentMode = isScaleAspectFill ? .scaleAspectFill : .scaleAspectFit
            }
        }

        @Published public var isLoading = true
        public var selectedAudioTrack: MediaPlayerTrack? {
            didSet {
                if oldValue?.trackID != selectedAudioTrack?.trackID {
                    if let track = selectedAudioTrack {
                        playerLayer?.player.select(track: track)
                        playerLayer?.player.isMuted = false
                    } else {
                        playerLayer?.player.isMuted = true
                    }
                }
            }
        }

        public var selectedVideoTrack: MediaPlayerTrack? {
            didSet {
                if oldValue?.trackID != selectedVideoTrack?.trackID {
                    if let track = selectedVideoTrack {
                        playerLayer?.player.select(track: track)
                        playerLayer?.options.videoDisable = false
                    } else {
                        oldValue?.setIsEnabled(false)
                        playerLayer?.options.videoDisable = true
                    }
                }
            }
        }

        // In SplitView mode, makeUIView will be called first when entering for the second time.
        // Then call the previous dismantleUIView. So if the same View is entered, the playerLayer will be cleared. The most accurate way is to clear the playerLayer in onDisappear
        public var playerLayer: KSPlayerLayer?
        public var audioTracks = [MediaPlayerTrack]()
        public var videoTracks = [MediaPlayerTrack]()
        fileprivate var onPlay: ((TimeInterval, TimeInterval) -> Void)?
        fileprivate var onFinish: ((KSPlayerLayer, Error?) -> Void)?
        fileprivate var onStateChanged: ((KSPlayerLayer, KSPlayerState) -> Void)?
        fileprivate var onBufferChanged: ((Int, TimeInterval) -> Void)?
        #if canImport(UIKit)
        fileprivate var onSwipe: ((UISwipeGestureRecognizer.Direction) -> Void)?
        @objc fileprivate func swipeGestureAction(_ recognizer: UISwipeGestureRecognizer) {
            onSwipe?(recognizer.direction)
        }
        #endif

        public init() {}

        public func makeView(url: URL, options: KSOptions) -> KSPlayerLayer {
            if let playerLayer {
                playerLayer.set(url: url, options: options)
                playerLayer.delegate = self
                isPlay = options.isAutoPlay
                return playerLayer
            } else {
                let playerLayer = KSPlayerLayer(url: url, options: options)
                playerLayer.delegate = self
                self.playerLayer = playerLayer
                return playerLayer
            }
        }

        public func skip(interval: Int) {
            if let playerLayer {
                seek(time: playerLayer.player.currentPlaybackTime + TimeInterval(interval))
            }
        }

        public func seek(time: TimeInterval) {
            playerLayer?.seek(time: TimeInterval(time))
        }
    }
}

extension KSVideoPlayer.Coordinator: KSPlayerLayerDelegate {
    public func player(layer: KSPlayerLayer, state: KSPlayerState) {
        if state == .prepareToPlay {
            isPlay = layer.options.isAutoPlay
        } else if state == .readyToPlay {
            videoTracks = layer.player.tracks(mediaType: .video)
            audioTracks = layer.player.tracks(mediaType: .audio)
        } else {
            isLoading = state == .buffering
            isPlay = state.isPlaying
        }
        onStateChanged?(layer, state)
    }

    public func player(layer _: KSPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        onPlay?(currentTime, totalTime)
    }

    public func player(layer: KSPlayerLayer, finish error: Error?) {
        onFinish?(layer, error)
    }

    public func player(layer _: KSPlayerLayer, bufferedCount: Int, consumeTime: TimeInterval) {
        onBufferChanged?(bufferedCount, consumeTime)
    }
}

extension KSVideoPlayer: Equatable {
    public static func == (lhs: KSVideoPlayer, rhs: KSVideoPlayer) -> Bool {
        lhs.url == rhs.url
    }
}

public extension KSVideoPlayer {
    func onBufferChanged(_ handler: @escaping (Int, TimeInterval) -> Void) -> Self {
        coordinator.onBufferChanged = handler
        return self
    }

    /// Playing to the end.
    func onFinish(_ handler: @escaping (KSPlayerLayer, Error?) -> Void) -> Self {
        coordinator.onFinish = handler
        return self
    }

    func onPlay(_ handler: @escaping (TimeInterval, TimeInterval) -> Void) -> Self {
        coordinator.onPlay = handler
        return self
    }

    /// Playback status changes, such as from play to pause.
    func onStateChanged(_ handler: @escaping (KSPlayerLayer, KSPlayerState) -> Void) -> Self {
        coordinator.onStateChanged = handler
        return self
    }

    #if canImport(UIKit)
    func onSwipe(_ handler: @escaping (UISwipeGestureRecognizer.Direction) -> Void) -> Self {
        coordinator.onSwipe = handler
        return self
    }
    #endif
}
