//
//  SimpleVideoPlayerView.swift
//  Immich Gallery
//
//  Created by Codex on 2024-09-19.
//

import SwiftUI
import AVKit

/// Lightweight video player that relies on AVPlayer without custom observers.
struct SimpleVideoPlayerView: View {
    let asset: ImmichAsset
    @ObservedObject var assetService: AssetService
    @ObservedObject var authenticationService: AuthenticationService

    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasAttemptedLoad = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear {
                        player.play()
                    }
            }

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.3)
                    Text("Loading video…")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.title3)
                }
            }

            if let message = errorMessage {
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
                            await loadVideoIfNeeded(force: true)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .task {
            await loadVideoIfNeeded()
        }
        .onDisappear {
            player?.pause()
            player = nil
            hasAttemptedLoad = false
        }
    }

    private func loadVideoIfNeeded(force: Bool = false) async {
        guard (!hasAttemptedLoad || force) else { return }

        await MainActor.run {
            hasAttemptedLoad = true
            isLoading = true
            errorMessage = nil
        }

        do {
            let videoURL = try await assetService.loadVideoURL(asset: asset)
            let headers = authenticationService.getAuthHeaders()

            let urlAsset: AVURLAsset
            if headers.isEmpty {
                urlAsset = AVURLAsset(url: videoURL)
            } else {
                urlAsset = AVURLAsset(
                    url: videoURL,
                    options: ["AVURLAssetHTTPHeaderFieldsKey": headers]
                )
            }

            let playerItem = AVPlayerItem(asset: urlAsset)
            let player = AVPlayer(playerItem: playerItem)

            await MainActor.run {
                self.player = player
                self.player?.play()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
