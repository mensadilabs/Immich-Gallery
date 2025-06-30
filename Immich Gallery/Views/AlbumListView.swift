//
//  AlbumListView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct AlbumListView: View {
    @ObservedObject var immichService: ImmichService
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
            Color.black
                .ignoresSafeArea()
            
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
                    LazyVGrid(columns: columns, spacing: 5) {
                        ForEach(albums) { album in
                            UIKitFocusable(action: {
                                selectedAlbum = album
                                showingAlbumDetail = true
                            }) {
                                AlbumRowView(
                                    album: album,
                                    immichService: immichService,
                                    isFocused: focusedAlbumId == album.id
                                )
                            }
                            .frame(width: 490, height: 300)
                            .focused($focusedAlbumId, equals: album.id)
                            .scaleEffect(focusedAlbumId == album.id ? 1.02 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: focusedAlbumId)
                            .padding(10) // ✅ adds spacing around every item
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingAlbumDetail) {
            if let selectedAlbum = selectedAlbum {
                AlbumDetailView(album: selectedAlbum, immichService: immichService)
            }
        }
        .onAppear {
            if albums.isEmpty {
                loadAlbums()
            }
        }
    }
    
    private func loadAlbums() {
        guard immichService.isAuthenticated else {
            errorMessage = "Not authenticated. Please check your credentials."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedAlbums = try await immichService.fetchAlbums()
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
    @ObservedObject var immichService: ImmichService
    @State private var thumbnailImage: UIImage?
    let isFocused: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Album thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 150, height: 150)
                
                if let thumbnailImage = thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Image(systemName: "folder")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                }
            }
            
            // Album info
            VStack(alignment: .leading, spacing: 4) {
                Text(album.albumName)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(isFocused ? .white : .gray)
                    .lineLimit(1)
                    
                
                
                    Text(album.description ?? "")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                
                
                Text("\(album.assetCount) photos")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                if let createdAt = formatDate(album.createdAt) {
                    Text("Created \(createdAt)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            
            Image(systemName: "chevron.right")
                .foregroundColor(isFocused ? .white : .gray)
        }
        .padding()
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
                // First try to load the thumbnail directly
                let thumbnail = try await immichService.loadAlbumThumbnail(
                    albumId: album.id,
                    thumbnailAssetId: thumbnailAssetId,
                    size: "thumbnail"
                )
                await MainActor.run {
                    self.thumbnailImage = thumbnail
                }
            } catch {
                // If direct loading fails, try to get album info and find the asset
                do {
                    let albumInfo = try await immichService.getAlbumInfo(albumId: album.id, withoutAssets: false)
                    if let thumbnailAsset = albumInfo.assets.first(where: { $0.id == thumbnailAssetId }) {
                        let thumbnail = try await immichService.loadImage(from: thumbnailAsset, size: "thumbnail")
                        await MainActor.run {
                            self.thumbnailImage = thumbnail
                        }
                    }
                } catch {
                    // Thumbnail loading failed, keep default folder icon
                    print("Failed to load album thumbnail: \(error)")
                }
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
    @ObservedObject var immichService: ImmichService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAsset: ImmichAsset?
    @State private var showingFullScreen = false
    @State private var albumAssets: [ImmichAsset] = []
    @State private var isLoadingAssets = false
    @State private var assetError: String?
    @FocusState private var focusedAssetId: String?
    
    private let columns = [
        GridItem(.fixed(280), spacing: 20),
        GridItem(.fixed(280), spacing: 20),
        GridItem(.fixed(280), spacing: 20),
        GridItem(.fixed(280), spacing: 20),
        GridItem(.fixed(280), spacing: 20)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                if isLoadingAssets {
                    ProgressView("Loading photos...")
                        .foregroundColor(.white)
                        .scaleEffect(1.5)
                } else if let assetError = assetError {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        Text("Error Loading Photos")
                            .font(.title)
                            .foregroundColor(.white)
                        Text(assetError)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Retry") {
                            loadAlbumAssets()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if albumAssets.isEmpty {
                    VStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Photos in Album")
                            .font(.title)
                            .foregroundColor(.white)
                        Text("This album is empty")
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(albumAssets) { asset in
                                UIKitFocusable(action: {
                                    selectedAsset = asset
                                    showingFullScreen = true
                                }) {
                                    AssetThumbnailView(
                                        asset: asset,
                                        immichService: immichService,
                                        isFocused: focusedAssetId == asset.id
                                    )
                                }
                                .frame(width: 280, height: 340)
                                .focused($focusedAssetId, equals: asset.id)
                                .scaleEffect(focusedAssetId == asset.id ? 1.05 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: focusedAssetId)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 80)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle(album.albumName)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(albumAssets.count) photos")
                        .foregroundColor(.gray)
                }
            }
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            if let selectedAsset = selectedAsset {
                FullScreenImageView(
                    asset: selectedAsset,
                    assets: albumAssets,
                    currentIndex: albumAssets.firstIndex(of: selectedAsset) ?? 0,
                    immichService: immichService
                )
            }
        }
        .onAppear {
            loadAlbumAssets()
        }
    }
    
    private func loadAlbumAssets() {
        // Use existing assets if available, otherwise fetch them
        if !album.assets.isEmpty {
            albumAssets = album.assets
            return
        }
        
        isLoadingAssets = true
        assetError = nil
        
        Task {
            do {
                let albumInfo = try await immichService.getAlbumInfo(albumId: album.id, withoutAssets: false)
                await MainActor.run {
                    self.albumAssets = albumInfo.assets
                    self.isLoadingAssets = false
                }
            } catch {
                await MainActor.run {
                    self.assetError = error.localizedDescription
                    self.isLoadingAssets = false
                }
            }
        }
    }
}

#Preview {
    AlbumListView(immichService: ImmichService())
} 
