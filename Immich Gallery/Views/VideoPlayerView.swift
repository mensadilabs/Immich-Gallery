//
//  VideoPlayerView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let asset: ImmichAsset
    @ObservedObject var immichService: ImmichService
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView("Loading video...")
                    .foregroundColor(.white)
                    .scaleEffect(1.5)
            } else if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    Text("Error Loading Video")
                        .font(.title)
                        .foregroundColor(.white)
                    Text(errorMessage)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") {
                        loadVideo()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            loadVideo()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    private func loadVideo() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let videoURL = try await immichService.loadVideoURL(from: asset)
                
                await MainActor.run {
                    // Create AVPlayer with authenticated URL
                    let playerItem = AVPlayerItem(url: videoURL)
                    self.player = AVPlayer(playerItem: playerItem)
                    
                    self.isLoading = false
                    
                    // Auto-play video
                    self.player?.play()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func cleanup() {
        player?.pause()
        player = nil
    }
} 