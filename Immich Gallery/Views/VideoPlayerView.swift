//
//  VideoPlayerView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI
import AVKit
import Combine


class PlayerManager: NSObject, ObservableObject, AVAssetResourceLoaderDelegate {
    @Published var player = AVPlayer()
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var isReadyToPlay = false
    @Published var isPlaybackBufferEmpty = false
    @Published var playbackRate: Float = 0.0
    
    private var playerItem: AVPlayerItem?
    private var cancellables = Set<AnyCancellable>()
    
    let asset: ImmichAsset
    let assetService: AssetService
    let authenticationService: AuthenticationService
    
    init(asset: ImmichAsset, assetService: AssetService, authenticationService: AuthenticationService) {
        self.asset = asset
        self.assetService = assetService
        self.authenticationService = authenticationService
        super.init()
    }
    
    func initializePlayer() {
        isLoading = true
        errorMessage = nil
        isReadyToPlay = false
        
        print("🎬 Loading video for asset: \(asset.id)")
        
        Task {
            do {
                let videoURL = try await assetService.loadVideoURL(asset: asset)
                print("🎥 Video URL created: \(videoURL)")
                
                await MainActor.run {
                    self.setupPlayer(with: videoURL)
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
    
    private func setupPlayer(with url: URL) {
        // Determine MIME type based on asset properties
        let mimeType = determineVideoMimeType()
        
        // Create AVURLAsset with custom options
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetOutOfBandMIMETypeKey": mimeType,
            "AVURLAssetHTTPHeaderFieldsKey": getVideoAuthHeaders()
        ])
        
        // Set up authentication delegate
        asset.resourceLoader.setDelegate(self, queue: DispatchQueue.main)
        
        // Create player item with the asset
        let playerItem = AVPlayerItem(asset: asset)
        self.playerItem = playerItem
        
        // Watch for buffer issues (from Medium article)
        playerItem.publisher(for: \.isPlaybackBufferEmpty)
            .sink { [weak self] bufferEmpty in
                DispatchQueue.main.async {
                    self?.isPlaybackBufferEmpty = bufferEmpty
                    if bufferEmpty {
                        print("⚠️ Buffer is empty. Expect a hiccup on screen.")
                    }
                }
            }
            .store(in: &cancellables)
        
        // Keep an eye on playback rate (from Medium article)
        player.publisher(for: \.rate)
            .sink { [weak self] rate in
                DispatchQueue.main.async {
                    self?.playbackRate = rate
                    print("▶️ Playback rate: \(rate)")
                }
            }
            .store(in: &cancellables)
        
        // Observe overall status (from Medium article)
        playerItem.publisher(for: \.status)
            .sink { [weak self] status in
                DispatchQueue.main.async {
                    self?.handlePlayerItemStatusChange(status)
                }
            }
            .store(in: &cancellables)
        
        // Optionally track if playback stalls (from Medium article)
        NotificationCenter.default.publisher(for: .AVPlayerItemPlaybackStalled, object: playerItem)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    print("⚠️ Playback stalled. Possibly a slow connection.")
                    self?.errorMessage = "Playback stalled - check your connection"
                }
            }
            .store(in: &cancellables)
        
        // Add error observer
        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
            .sink { [weak self] notification in
                DispatchQueue.main.async {
                    self?.handlePlaybackFailure(notification)
                }
            }
            .store(in: &cancellables)
        
        // Replace current item
        player.replaceCurrentItem(with: playerItem)
        
        print("▶️ Video player setup completed")
    }
    
    private func handlePlayerItemStatusChange(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            print("✅ Ready to play!")
            isReadyToPlay = true
            isLoading = false
            // Auto-play when ready after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
                self?.player.play()
            }
        case .failed:
            print("❌ Something went wrong with playback.")
            isLoading = false
            errorMessage = "Video failed to load"
        case .unknown:
            print("⏳ Status changed: \(status.rawValue)")
        @unknown default:
            break
        }
    }
    
    private func handlePlaybackFailure(_ notification: Notification) {
        if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
            print("❌ Player item failed to play to end: \(error)")
            errorMessage = "Video playback failed: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func determineVideoMimeType() -> String {
        // Try to determine MIME type from asset properties
        if let mimeType = asset.originalMimeType {
            // Validate that it's a video MIME type
            if mimeType.hasPrefix("video/") {
                return mimeType
            }
        }
        
        // Fallback to common video formats
        let fileName = asset.originalFileName.lowercased()
        if fileName.hasSuffix(".mp4") {
            return "video/mp4"
        } else if fileName.hasSuffix(".mov") {
            return "video/quicktime"
        } else if fileName.hasSuffix(".avi") {
            return "video/x-msvideo"
        } else if fileName.hasSuffix(".mkv") {
            return "video/x-matroska"
        } else if fileName.hasSuffix(".webm") {
            return "video/webm"
        } else {
            // Default to MP4
            return "video/mp4"
        }
    }
    
    
    func cleanup() {
        // Remove all cancellables
        cancellables.removeAll()
        
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        
        player.pause()
        player = AVPlayer()
        playerItem = nil
        
        print("🧹 Video player cleaned up")
    }
    
    private func getVideoAuthHeaders() -> [String: String] {
        guard let accessToken = authenticationService.accessToken else {
            return [:]
        }
        return ["Authorization": "Bearer \(accessToken)"]
    }
    
    // MARK: - AVAssetResourceLoaderDelegate
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        print("🔐 Handling authentication request for video")
        
        guard let url = loadingRequest.request.url else {
            loadingRequest.finishLoading(with: NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL, userInfo: nil))
            return false
        }
        
        // Get authentication headers
        let authHeaders = getVideoAuthHeaders()
        
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
                    print("❌ Video request failed: \(error)")
                    loadingRequest.finishLoading(with: error)
                    return
                }
                
                guard let response = response as? HTTPURLResponse else {
                    let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse, userInfo: nil)
                    loadingRequest.finishLoading(with: error)
                    return
                }
                
                print("📡 Video response status: \(response.statusCode)")
                
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
                print("✅ Video request completed successfully")
            }
        }
        
        task.resume()
        return true
    }
}

// MARK: - Main Video Player View
struct VideoPlayerView: View {
    let asset: ImmichAsset
    @ObservedObject var assetService: AssetService
    @ObservedObject var authenticationService: AuthenticationService
    @StateObject private var playerManager: PlayerManager
    
    init(asset: ImmichAsset, assetService: AssetService, authenticationService: AuthenticationService) {
        self.asset = asset
        self.assetService = assetService
        self.authenticationService = authenticationService
        self._playerManager = StateObject(wrappedValue: PlayerManager(asset: asset, assetService: assetService, authenticationService: authenticationService))
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if playerManager.isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Loading video...")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            } else if let errorMessage = playerManager.errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    Text("Error Loading Video")
                        .font(.title)
                        .foregroundColor(.white)
                    Text(errorMessage)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Retry") {
                        playerManager.initializePlayer()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if playerManager.isReadyToPlay {
                ImprovedVideoPlayerView(player: playerManager.player)
                    .ignoresSafeArea()
                
                // Optional: Show buffer status overlay
                if playerManager.isPlaybackBufferEmpty {
                    let _ = print(playerManager.isPlaybackBufferEmpty)
                    VStack {
                        Spacer()
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Buffering...")
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .padding(.bottom, 50)
                    }
                }
            }
        }
        .onAppear {
            playerManager.initializePlayer()
        }
        .onDisappear {
            playerManager.cleanup()
        }
    }
}

// MARK: - Improved Video Player for tvOS
struct ImprovedVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        
        // Configure for better tvOS experience
        controller.allowsPictureInPicturePlayback = true
        
        // Set up custom styling to avoid layout conflicts
        controller.view.backgroundColor = UIColor.black
        
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Only update player if it's different to avoid unnecessary reloads
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
}
