//
//  VideoPlayerView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI
import AVKit

class VideoPlayerViewModel: NSObject, ObservableObject, AVAssetResourceLoaderDelegate {
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var player: AVPlayer?
    
    let asset: ImmichAsset
    let immichService: ImmichService
    
    init(asset: ImmichAsset, immichService: ImmichService) {
        self.asset = asset
        self.immichService = immichService
        super.init()
    }
    
    func loadVideo() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let videoURL = try await immichService.loadVideoURL(from: asset)
                print("🎥 Video URL created: \(videoURL)")
                
                await MainActor.run {
                    // Create AVPlayer with authenticated URL
                    let playerItem = AVPlayerItem(url: videoURL)
                    
                    // Set up authentication delegate for the asset
                    if let asset = playerItem.asset as? AVURLAsset {
                        asset.resourceLoader.setDelegate(self, queue: .main)
                    }
                    
                    self.player = AVPlayer(playerItem: playerItem)
                    self.isLoading = false
                    
                    // Start playback
                    self.player?.play()
                    print("▶️ Video playback started")
                }
            } catch {
                print("❌ Failed to load video: \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func cleanup() {
        player?.pause()
        player = nil
        print("🧹 Video player cleaned up")
    }
    
    // MARK: - AVAssetResourceLoaderDelegate
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        print("🔐 Handling authentication request for video")
        
        guard let url = loadingRequest.request.url else {
            loadingRequest.finishLoading(with: NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL, userInfo: nil))
            return false
        }
        
        // Get authentication headers
        let authHeaders = immichService.getVideoAuthHeaders()
        
        // Create authenticated request
        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0
        
        // Copy range headers for proper streaming
        if let rangeHeader = loadingRequest.request.value(forHTTPHeaderField: "Range") {
            request.setValue(rangeHeader, forHTTPHeaderField: "Range")
        }
        
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Perform the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    loadingRequest.finishLoading(with: error)
                    return
                }
                
                guard let response = response as? HTTPURLResponse else {
                    let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse, userInfo: nil)
                    loadingRequest.finishLoading(with: error)
                    return
                }
                
                if response.statusCode != 200 && response.statusCode != 206 {
                    let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse, userInfo: [NSLocalizedDescriptionKey: "Server returned status \(response.statusCode)"])
                    loadingRequest.finishLoading(with: error)
                    return
                }
                
                // Set response information
                loadingRequest.response = response
                
                // Set content type if available
                if let mimeType = response.mimeType {
                    loadingRequest.contentInformationRequest?.contentType = mimeType
                }
                
                // Set content length if available
                if response.expectedContentLength > 0 {
                    loadingRequest.contentInformationRequest?.contentLength = response.expectedContentLength
                }
                
                // Set data
                if let data = data {
                    loadingRequest.dataRequest?.respond(with: data)
                }
                
                // Finish loading
                loadingRequest.finishLoading()
            }
        }
        
        task.resume()
        return true
    }
}

struct VideoPlayerView: View {
    let asset: ImmichAsset
    @ObservedObject var immichService: ImmichService
    @StateObject private var viewModel: VideoPlayerViewModel
    
    init(asset: ImmichAsset, immichService: ImmichService) {
        self.asset = asset
        self.immichService = immichService
        self._viewModel = StateObject(wrappedValue: VideoPlayerViewModel(asset: asset, immichService: immichService))
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView("Loading video...")
                    .foregroundColor(.white)
                    .scaleEffect(1.5)
            } else if let errorMessage = viewModel.errorMessage {
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
                        viewModel.loadVideo()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if let player = viewModel.player {
                SimpleVideoPlayerView(player: player)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            viewModel.loadVideo()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}

// MARK: - Simple Video Player for tvOS
struct SimpleVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
} 