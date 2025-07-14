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
        GridItem(.fixed(500), spacing: 20),
        GridItem(.fixed(500), spacing: 20),
        GridItem(.fixed(500), spacing: 20),
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
                    LazyVGrid(columns: columns, spacing: 30) {
                        ForEach(albums) { album in
                            UIKitFocusable(action: {
                                selectedAlbum = album
                                showingAlbumDetail = true
                            }) {
                                AlbumRowView(
                                    album: album,
                                    albumService: albumService,
                                    isFocused: focusedAlbumId == album.id
                                )
                            }
                            .frame(width: 490, height: 400)
                            .focused($focusedAlbumId, equals: album.id)
                            .scaleEffect(focusedAlbumId == album.id ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: focusedAlbumId)
                            .padding(10) // ✅ adds spacing around every item
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
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @State private var thumbnailImage: UIImage?
    let isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Album thumbnail at top
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 470, height: 280)
                
                if let thumbnailImage = thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 470, height: 280)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    Image(systemName: "folder")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                }
            }
            
            // Album info at bottom
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(album.albumName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(isFocused ? .white : .gray)
                            .lineLimit(1)
                        
                        
                            Text(album.description ?? "Album")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        
                        
                        HStack(spacing: 12) {
                            Text("\(album.assetCount) photos")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            if let createdAt = formatDate(album.createdAt) {
                                Text("Created \(createdAt)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(isFocused ? Color.white.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(12)
        .shadow(color: .black.opacity(isFocused ? 0.4 : 0), radius: 15, y: 5)
        .onAppear {
            loadThumbnail()
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
                SlideshowView(assets: imageAssets, assetService: assetService)
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
    let networkService = NetworkService()
    let albumService = AlbumService(networkService: networkService)
    let authService = AuthenticationService(networkService: networkService)
    let assetService = AssetService(networkService: networkService)
    AlbumListView(albumService: albumService, authService: authService, assetService: assetService)
} 


