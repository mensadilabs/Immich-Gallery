//
//  AlbumListView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct AlbumListView: View {
    @ObservedObject var albumService: AlbumService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var assetService: AssetService
    @State private var albums: [ImmichAlbum] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedAlbum: ImmichAlbum?
    @State private var showingAlbumDetail = false
    @FocusState private var focusedAlbumId: String?
    
    private let columns = [
        GridItem(.fixed(500), spacing: 100),
        GridItem(.fixed(500), spacing: 100),
        GridItem(.fixed(500), spacing: 100),
    ]
    
    var body: some View {
        ZStack {
            // Background
            SharedGradientBackground()
            
            if isLoading {
                ProgressView("Loading albums...")
                    .foregroundColor(.white)
                    .scaleEffect(1.5)
            } else if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    Text("Error")
                        .font(.title)
                        .foregroundColor(.white)
                    Text(errorMessage)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") {
                        loadAlbums()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if albums.isEmpty {
                VStack {
                    Image(systemName: "folder")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No Albums Found")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("Your albums will appear here")
                        .foregroundColor(.gray)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 100) {
                        ForEach(albums) { album in
                            Button(action: {
                                selectedAlbum = album
                                showingAlbumDetail = true
                            }) {
                                AlbumRowView(
                                    album: album,
                                    albumService: albumService,
                                    assetService: assetService,
                                    isFocused: focusedAlbumId == album.id
                                )
                            }
                            .frame(width: 530, height: 400)
                            .focused($focusedAlbumId, equals: album.id)
                            .animation(.easeInOut(duration: 0.2), value: focusedAlbumId)
                            .padding(10)
                            .buttonStyle(CardButtonStyle())
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingAlbumDetail) {
            if let selectedAlbum = selectedAlbum {
                AlbumDetailView(album: selectedAlbum, albumService: albumService, authService: authService, assetService: assetService)
            }
        }
        .onAppear {
            if albums.isEmpty {
                loadAlbums()
            }
        }
    }
    
    private func loadAlbums() {
        guard authService.isAuthenticated else {
            errorMessage = "Not authenticated. Please check your credentials."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedAlbums = try await albumService.fetchAlbums()
                await MainActor.run {
                    self.albums = fetchedAlbums
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
}

struct AlbumRowView: View {
    let album: ImmichAlbum
    @ObservedObject var albumService: AlbumService
    @ObservedObject var assetService: AssetService
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @State private var thumbnailImage: UIImage?
    @State private var thumbnails: [UIImage] = []
    @State private var currentThumbnailIndex = 0
    @State private var animationTimer: Timer?
    @State private var isLoadingThumbnails = false
    @State private var enableThumbnailAnimation: Bool = UserDefaults.standard.enableThumbnailAnimation
    let isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                if isLoadingThumbnails {
                    ProgressView()
                        .scaleEffect(1.2)
                        .foregroundColor(.white)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 500)
                } else if !thumbnails.isEmpty {
                    // Animated thumbnails
                    ForEach(Array(thumbnails.enumerated()), id: \.offset) { index, thumbnail in
                        
                        VStack{
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 430, height: 280)
                                .clipped()
                                .cornerRadius(12)
                                .opacity(index == currentThumbnailIndex ? 1.0 : 0.0)
                                .animation(.easeInOut(duration: 1.5), value: currentThumbnailIndex)
                            // Album info at bottom
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(album.albumName)
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                                .lineLimit(1)
                                            
                                            Spacer()
                                            
                                            if album.shared {
                                                HStack(spacing: 1) {
                                                    Image(systemName: "person.2.fill")
                                                        .font(.caption)
                                                        .foregroundColor(.blue)
                                                    Text(album.owner.name)
                                                        .font(.caption)
                                                        .foregroundColor(.blue)
                                                }
                                            }
                                        }
                                        
                                        Text(album.description ?? "Album")
                                            .font(.caption)
                                            .lineLimit(2)
                                        
                                        HStack(spacing: 12) {
                                            Text("\(album.assetCount) photos")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                            
                                            if let createdAt = formatDate(album.createdAt) {
                                                Text("Created \(createdAt)")
                                                    .font(.caption2)
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(width: 430)
                            .foregroundColor(isFocused ? .white : .gray)
                            .padding()
                        }.frame(width: 500)
                        
                        
                    }
                } else if let thumbnailImage = thumbnailImage {
                    // Fallback to single thumbnail
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 470, height: 280)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    // Fallback to icon
                    Image(systemName: "folder")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                }
            }
        }
        .background(isFocused ? Color.white.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(12)
        .onAppear {
            loadThumbnail()
            loadAlbumThumbnails()
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: isFocused) { _, focused in
            if focused {
                stopAnimation()
            } else if !thumbnails.isEmpty && thumbnails.count > 1 && enableThumbnailAnimation {
                startAnimation()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            let newSetting = UserDefaults.standard.enableThumbnailAnimation
            if newSetting != enableThumbnailAnimation {
                enableThumbnailAnimation = newSetting
                if enableThumbnailAnimation && !thumbnails.isEmpty && thumbnails.count > 1 && !isFocused {
                    startAnimation()
                } else {
                    stopAnimation()
                }
            }
        }
    }
    
    private func loadThumbnail() {
        guard let thumbnailAssetId = album.albumThumbnailAssetId else {
            return
        }
        
        Task {
            do {
                // Use thumbnail cache for album thumbnails
                let thumbnail = try await thumbnailCache.getThumbnail(for: thumbnailAssetId, size: "thumbnail") {
                    // Load from server if not in cache
                    try await albumService.loadAlbumThumbnail(
                        albumId: album.id,
                        thumbnailAssetId: thumbnailAssetId,
                        size: "thumbnail"
                    )
                }
                await MainActor.run {
                    self.thumbnailImage = thumbnail
                }
            } catch {
                print("Failed to load album thumbnail: \(error)")
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        
        return nil
    }
    
    private func loadAlbumThumbnails() {
        guard !isLoadingThumbnails else { return }
        isLoadingThumbnails = true
        
        Task {
            do {
                let searchResult = try await assetService.fetchAssets(page: 1, limit: 10, albumId: album.id)
                let imageAssets = searchResult.assets.filter { $0.type == .image }
                
                var loadedThumbnails: [UIImage] = []
                
                for asset in imageAssets.prefix(10) {
                    do {
                        let thumbnail = try await thumbnailCache.getThumbnail(for: asset.id, size: "thumbnail") {
                            try await assetService.loadImage(asset: asset, size: "thumbnail")
                        }
                        if let thumbnail = thumbnail {
                            loadedThumbnails.append(thumbnail)
                        }
                    } catch {
                        print("Failed to load thumbnail for asset \(asset.id): \(error)")
                    }
                }
                
                await MainActor.run {
                    self.thumbnails = loadedThumbnails
                    self.isLoadingThumbnails = false
                    if !loadedThumbnails.isEmpty && enableThumbnailAnimation {
                        self.startAnimation()
                    }
                }
            } catch {
                print("Failed to fetch assets for album \(album.id): \(error)")
                await MainActor.run {
                    self.isLoadingThumbnails = false
                }
            }
        }
    }
    
    private func startAnimation() {
        guard thumbnails.count > 1 && enableThumbnailAnimation else { return }
        stopAnimation()
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.5)) {
                currentThumbnailIndex = (currentThumbnailIndex + 1) % thumbnails.count
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

struct AlbumDetailView: View {
    let album: ImmichAlbum
    @ObservedObject var albumService: AlbumService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var assetService: AssetService
    @Environment(\.dismiss) private var dismiss
    @State private var showingSlideshow = false
    @State private var albumAssets: [ImmichAsset] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                AssetGridView(
                    assetService: assetService,
                    authService: authService,
                    albumId: album.id,
                    personId: nil,
                    tagId: nil,
                    isAllPhotos: false,
                    onAssetsLoaded: { loadedAssets in
                        self.albumAssets = loadedAssets
                    }
                )
            }
            .navigationTitle(album.albumName)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: startSlideshow) {
                        Image(systemName: "play.rectangle")
                            .foregroundColor(.white)
                    }
                    .disabled(albumAssets.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .fullScreenCover(isPresented: $showingSlideshow) {
            let imageAssets = albumAssets.filter { $0.type == .image }
            if !imageAssets.isEmpty {
                SlideshowView(assets: imageAssets, assetService: assetService, startingIndex: 0)
            }
        }
    }
    
    private func startSlideshow() {
        let imageAssets = albumAssets.filter { $0.type == .image }
        if !imageAssets.isEmpty {
            showingSlideshow = true
        }
    }
}

#Preview {
    let (_, authService, assetService, albumService, peopleService, _) =
         MockServiceFactory.createMockServices()
    AlbumListView(albumService: albumService, authService: authService, assetService: assetService)
}
