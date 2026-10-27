//
//  SimpleVideoPlayerView.swift
//  Immich Gallery
//
//  Created by Codex on 2024-09-19.
//

import SwiftUI
import AVKit

/// Lightweight video player that relies on AVPlayer.
///
/// When the server has real-time transcoding enabled, videos stream over Immich's HLS endpoint so the
/// bitrate adapts to the network. Otherwise, or if HLS fails, the stored video file is played.
struct SimpleVideoPlayerView: View {
    let asset: ImmichAsset
    @ObservedObject var assetService: AssetService
    @ObservedObject var authenticationService: AuthenticationService

    @StateObject private var playback = VideoPlaybackController()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = playback.player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear {
                        player.play()
                    }
            }

            if playback.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.3)
                    Text("Loading video…")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.title3)
                }
            }

            if let message = playback.errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    Text("Unable to play video")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text(message)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Try Again") {
                        Task {
                            await loadVideo()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .task {
            await loadVideo()
        }
        .onDisappear {
            playback.stop()
        }
    }

    private func loadVideo() async {
        await playback.load(
            asset: asset,
            assetService: assetService,
            authHeaders: authenticationService.getAuthHeaders(),
            preferTranscodedStreaming: UserDefaults.standard.preferTranscodedVideoStreaming
        )
    }
}

/// Owns the AVPlayer for `SimpleVideoPlayerView`: picks HLS or the stored file, falls back from HLS
/// when it fails, and releases the server's HLS session when playback ends.
@MainActor
final class VideoPlaybackController: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private var asset: ImmichAsset?
    private var assetService: AssetService?
    private var authHeaders: [String: String] = [:]
    private var source: VideoPlaybackSource = .progressive
    private var hlsSessionId: String?
    private var loadGeneration = 0
    private weak var handledFailureItem: AVPlayerItem?
    private var statusObservation: NSKeyValueObservation?
    private var notificationTokens: [NSObjectProtocol] = []

    func load(asset: ImmichAsset, assetService: AssetService, authHeaders: [String: String], preferTranscodedStreaming: Bool) async {
        stop()
        let generation = loadGeneration
        self.asset = asset
        self.assetService = assetService
        self.authHeaders = authHeaders
        errorMessage = nil
        isLoading = true

        var serverSupportsHLS = false
        if preferTranscodedStreaming {
            serverSupportsHLS = (try? await assetService.fetchServerFeatures())?.supportsRealtimeTranscoding ?? false
            guard generation == loadGeneration else { return }
        }
        let preferredSource = VideoPlaybackSource.preferred(
            serverSupportsHLS: serverSupportsHLS,
            userAllowsTranscodedStreaming: preferTranscodedStreaming
        )
        await start(preferredSource, resumeTime: 0, generation: generation)
    }

    func stop() {
        loadGeneration += 1
        if let item = player?.currentItem {
            recordSession(from: item)
        }
        endHLSSession()
        removeItemObservers()
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        isLoading = false
    }

    private func start(_ requestedSource: VideoPlaybackSource, resumeTime: Double, generation: Int) async {
        guard let asset, let assetService else { return }
        do {
            let url: URL
            switch requestedSource {
            case .hls:
                url = try assetService.loadVideoStreamURL(asset: asset)
            case .progressive:
                url = try await assetService.loadVideoURL(asset: asset)
            }
            guard generation == loadGeneration else { return }
            play(makeItem(url: url), from: requestedSource, resumeTime: resumeTime)
        } catch {
            guard generation == loadGeneration else { return }
            if requestedSource == .hls {
                await start(.progressive, resumeTime: resumeTime, generation: generation)
            } else {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func makeItem(url: URL) -> AVPlayerItem {
        let urlAsset = authHeaders.isEmpty
            ? AVURLAsset(url: url)
            : AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": authHeaders])
        return AVPlayerItem(asset: urlAsset)
    }

    private func play(_ item: AVPlayerItem, from newSource: VideoPlaybackSource, resumeTime: Double) {
        source = newSource
        observe(item)
        let player = self.player ?? AVPlayer()
        player.replaceCurrentItem(with: item)
        if resumeTime > 0 {
            player.seek(to: CMTime(seconds: resumeTime, preferredTimescale: 600))
        }
        self.player = player
        player.play()
        isLoading = false
    }

    private func observe(_ item: AVPlayerItem) {
        removeItemObservers()
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            guard observedItem.status == .failed else { return }
            let message = observedItem.error?.localizedDescription
            Task { @MainActor [weak self] in
                self?.handleFailure(of: observedItem, message: message)
            }
        }
        let center = NotificationCenter.default
        notificationTokens = [
            center.addObserver(forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: item, queue: .main) { [weak self] notification in
                let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
                let message = error?.localizedDescription
                Task { @MainActor [weak self] in
                    self?.handleFailure(of: item, message: message)
                }
            },
            center.addObserver(forName: AVPlayerItem.newAccessLogEntryNotification, object: item, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.recordSession(from: item)
                }
            }
        ]
    }

    private func removeItemObservers() {
        statusObservation?.invalidate()
        statusObservation = nil
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        notificationTokens.removeAll()
    }

    private func handleFailure(of item: AVPlayerItem, message: String?) {
        guard item === player?.currentItem, item !== handledFailureItem else { return }
        handledFailureItem = item
        switch VideoPlaybackRecovery.afterFailure(of: source, playbackPosition: player?.currentTime().seconds) {
        case .fallBackToProgressive(let resumeTime):
            print("SimpleVideoPlayerView: HLS playback failed (\(message ?? "unknown error")), playing the video file instead")
            recordSession(from: item)
            endHLSSession()
            let generation = loadGeneration
            Task { await self.start(.progressive, resumeTime: resumeTime, generation: generation) }
        case .fail:
            player?.pause()
            errorMessage = message ?? "The video could not be played."
            isLoading = false
        }
    }

    private func recordSession(from item: AVPlayerItem) {
        guard source == .hls, let asset,
              let sessionId = HLSStreamSession.sessionId(fromURI: item.accessLog()?.events.last?.uri, assetId: asset.id)
        else { return }
        if let previous = hlsSessionId, previous != sessionId {
            endSession(previous, assetId: asset.id)
        }
        hlsSessionId = sessionId
    }

    private func endHLSSession() {
        guard let sessionId = hlsSessionId, let asset else { return }
        hlsSessionId = nil
        endSession(sessionId, assetId: asset.id)
    }

    private func endSession(_ sessionId: String, assetId: String) {
        guard let assetService else { return }
        Task {
            try? await assetService.endVideoStreamSession(assetId: assetId, sessionId: sessionId)
        }
    }
}
