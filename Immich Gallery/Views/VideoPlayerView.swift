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
    @Published var playerItem: AVPlayerItem?
    @Published var isReadyToPlay = false
    
    let asset: ImmichAsset
    let assetService: AssetService
    let authenticationService: AuthenticationService
    
    init(asset: ImmichAsset, assetService: AssetService, authenticationService: AuthenticationService) {
        self.asset = asset
        self.assetService = assetService
        self.authenticationService = authenticationService
        super.init()
    }
    
    func loadVideo() {
        isLoading = true
        errorMessage = nil
        isReadyToPlay = false
        
        // Log asset information for debugging
        print("🎬 Loading video for asset:")
        print("   ID: \(asset.id)")
        print("   Type: \(asset.type)")
        print("   File: \(asset.originalFileName)")
        print("   MIME: \(asset.originalMimeType ?? "unknown")")
        print("   Duration: \(asset.duration ?? "unknown")")
        
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
        
        // Add observers for player item status
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: nil)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp), options: [.old, .new], context: nil)
        
        // Create player
        let player = AVPlayer(playerItem: playerItem)
        
        // Store references
        self.playerItem = playerItem
        self.player = player
        
        // Set up periodic time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            // This helps keep the player active
        }
        
        // Add error observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemFailedToPlay),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem
        )
        
        print("▶️ Video player setup completed")
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
    
    @objc private func playerItemFailedToPlay(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("❌ Player item failed to play to end: \(error)")
                self?.errorMessage = "Video playback failed: \(error.localizedDescription)"
                self?.isLoading = false
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let playerItem = object as? AVPlayerItem else { return }
        
        switch keyPath {
        case #keyPath(AVPlayerItem.status):
            DispatchQueue.main.async { [weak self] in
                self?.handlePlayerItemStatusChange(playerItem)
            }
        case #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp):
            DispatchQueue.main.async { [weak self] in
                self?.handlePlaybackLikelyToKeepUpChange(playerItem)
            }
        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    private func handlePlayerItemStatusChange(_ playerItem: AVPlayerItem) {
        switch playerItem.status {
        case .readyToPlay:
            print("✅ Player item is ready to play")
            isLoading = false
            isReadyToPlay = true
            // Auto-play when opened from thumbnail view
            player?.play()
        case .failed:
            let error = playerItem.error?.localizedDescription ?? "Unknown error"
            print("❌ Player item failed: \(error)")
            isLoading = false
            
            // Provide more specific error messages
            if error.contains("HTTP") || error.contains("404") {
                errorMessage = "Video not found or access denied"
            } else if error.contains("format") || error.contains("codec") {
                errorMessage = "Video format not supported"
            } else if error.contains("network") || error.contains("connection") {
                errorMessage = "Network error - check your connection"
            } else {
                errorMessage = "Video failed to load: \(error)"
            }
        case .unknown:
            print("⏳ Player item status unknown")
        @unknown default:
            break
        }
    }
    
    private func handlePlaybackLikelyToKeepUpChange(_ playerItem: AVPlayerItem) {
        if playerItem.isPlaybackLikelyToKeepUp {
            print("✅ Playback likely to keep up")
        } else {
            print("⚠️ Playback may not keep up")
        }
    }
    
    func cleanup() {
        // Remove notification observers
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: nil)
        
        if let playerItem = playerItem {
            playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
            playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp))
        }
        
        player?.pause()
        player = nil
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

struct VideoPlayerView: View {
    let asset: ImmichAsset
    @ObservedObject var assetService: AssetService
    @ObservedObject var authenticationService: AuthenticationService
    @StateObject private var viewModel: VideoPlayerViewModel
    
    init(asset: ImmichAsset, assetService: AssetService, authenticationService: AuthenticationService) {
        self.asset = asset
        self.assetService = assetService
        self.authenticationService = authenticationService
        self._viewModel = StateObject(wrappedValue: VideoPlayerViewModel(asset: asset, assetService: assetService, authenticationService: authenticationService))
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Loading video...")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            } else if let errorMessage = viewModel.errorMessage {
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
                        viewModel.loadVideo()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if let player = viewModel.player, viewModel.isReadyToPlay {
                ImprovedVideoPlayerView(player: player)
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

#Preview {
    let networkService = NetworkService()
    let authenticationService = AuthenticationService(networkService: networkService)
    let assetService = AssetService(networkService: networkService)
    
    // Create mock video asset for preview
    let mockVideoAsset = ImmichAsset(
        id: "mock-video-id",
        deviceAssetId: "mock-device-video-id",
        deviceId: "mock-device",
        ownerId: "mock-owner",
        libraryId: nil,
        type: .video,
        originalPath: "/mock/video/path",
        originalFileName: "mock.mp4",
        originalMimeType: "video/mp4",
        resized: false,
        thumbhash: nil,
        fileModifiedAt: "2023-01-01",
        fileCreatedAt: "2023-01-01",
        localDateTime: "2023-01-01",
        updatedAt: "2023-01-01",
        isFavorite: false,
        isArchived: false,
        isOffline: false,
        isTrashed: false,
        checksum: "mock-video-checksum",
        duration: "PT1M30S",
        hasMetadata: false,
        livePhotoVideoId: nil,
        people: [],
        visibility: "public",
        duplicateId: nil,
        exifInfo: nil
    )
    
    VideoPlayerView(asset: mockVideoAsset, assetService: assetService, authenticationService: authenticationService)
} 
