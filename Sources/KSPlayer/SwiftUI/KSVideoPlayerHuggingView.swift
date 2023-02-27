//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2022/1/29.
//
import AVFoundation
import AVKit
import SwiftUI
@available(iOS 15, tvOS 15, macOS 12, *)
public struct KSVideoPlayerHuggingView: View {
    @StateObject public var subtitleModel = SubtitleModel()
    @StateObject public var playerCoordinator = KSVideoPlayer.Coordinator()
    @State public var url: URL
    private let subtitleURLs: [URL]
    public let options: KSOptions
    @State var isMaskShow = true
    @State private var model = ControllerTimeModel()

    @State var videoNaturalSize: CGSize = CGSize(width: 1, height: 1)
    
    public init(url: URL, options: KSOptions,
                subtitleURLs: [URL] = [URL]()) {
        _url = .init(initialValue: url)
        self.options = options
        self.subtitleURLs = subtitleURLs
    }

    
    
    public var body: some View {
        KSVideoPlayer(coordinator: playerCoordinator,
                      url: url,
                      options: options).onPlay { current, total in
            model.currentTime = Int(current)
            model.totalTime = Int(max(max(0, total), current))
            if let subtile = subtitleModel.selectedSubtitle {
                let time = current + options.subtitleDelay
                if let part = subtile.search(for: time) {
                    subtitleModel.part = part
                } else {
                    if let part = subtitleModel.part, part.end > part.start, time > part.end {
                        subtitleModel.part = nil
                    }
                }
            } else {
                subtitleModel.part = nil
            }
        }
        .onStateChanged { playerLayer, state in
            print("[KSVideoPlayerHuggingView] onStateChanged")
            let layerNaturalSize = playerLayer.naturalSize
            if layerNaturalSize != self.videoNaturalSize {
                self.videoNaturalSize = layerNaturalSize
            }
            if !playerCoordinator.isMuted {
                playerCoordinator.isMuted = true
            }
            if state == .readyToPlay {
                
            } else if state == .bufferFinished {
                
            } else {
                if !isMaskShow { isMaskShow = true }
            }
        }
        .onAppear {
            if let playerLayer = playerCoordinator.playerLayer {
                if !playerLayer.player.isPlaying && options.isAutoPlay {
                    playerCoordinator.playerLayer?.play()
                }
            }
        }
        .onDisappear {
            if let playerLayer = playerCoordinator.playerLayer {
                if !playerLayer.isPipActive {
                    playerCoordinator.playerLayer?.pause()
                    playerCoordinator.playerLayer = nil
                }
            }
        }
//        .edgesIgnoringSafeArea(.all)
        // Setting opacity to 0 will still update the View. so that's all
        .overlay(alignment: .bottom) {
            if isMaskShow {
                VideoTimeShowHuggingView(config: playerCoordinator, model: $model)
            }
//            Text("NaturalSize  \(Int(videoNaturalSize.width))x\(Int(videoNaturalSize.height))")
//                .background(.white)
        }
        .aspectRatio(videoNaturalSize, contentMode: .fill)
        #if os(macOS)
            .onTapGesture(count: 2) {
                print("[KSVideoPlayerHuggingView] onDoubleTap")
//                NSApplication.shared.keyWindow?.toggleFullScreen(self)
            }
        #endif
        
    }

    public func openURL(_ url: URL) {
        if url.isAudio || url.isMovie {
            self.url = url
            try? FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil).forEach {
                if $0.isSubtitle {
                    subtitleModel.addSubtitle(info: URLSubtitleInfo(url: url))
                }
            }
            subtitleModel.selectedSubtitleInfo = subtitleModel.subtitleInfos.first
        } else {
            let info = URLSubtitleInfo(url: url)
            subtitleModel.selectedSubtitleInfo = info
            subtitleModel.addSubtitle(info: info)
        }
    }
}

@available(iOS 15, tvOS 15, macOS 12, *)
extension KSVideoPlayerHuggingView: Equatable {
    public static func == (lhs: KSVideoPlayerHuggingView, rhs: KSVideoPlayerHuggingView) -> Bool {
        lhs.url == rhs.url
    }
}

@available(iOS 15, tvOS 15, macOS 12, *)
internal struct VideoTimeShowHuggingView: View {
    @StateObject internal var config: KSVideoPlayer.Coordinator
    @Binding internal var model: ControllerTimeModel
    public var body: some View {
        VStack {
            Slider(value: Binding {
                Double(model.currentTime)
            } set: { newValue, _ in
                model.currentTime = Int(newValue)
            }, in: 0 ... Double(model.totalTime)) { onEditingChanged in
                if onEditingChanged {
                    config.isPlay = false
                } else {
                    config.seek(time: TimeInterval(model.currentTime))
                }
            }
            .frame(maxHeight: 20)
            HStack(alignment: .bottom) {
                Text(model.currentTime.toString(for: .minOrHour)).font(.caption2.monospacedDigit())
                Spacer()
                Text("-" + (model.totalTime - model.currentTime).toString(for: .minOrHour)).font(.caption2.monospacedDigit())
            }
        }
        .padding()
        .background(Material.ultraThin.opacity(0.75))
        .foregroundColor(.white)
    }
}
