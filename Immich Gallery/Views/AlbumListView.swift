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
    @ObservedObject var userManager: UserManager
    @State private var albums: [ImmichAlbum] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var favoritesCount: Int = 0
    @State private var firstFavoriteAssetId: String?
    @State private var selectedAlbum: ImmichAlbum?
    @State private var showingAlbumDetail = false
    @FocusState private var focusedAlbumId: String?
    
    // Global animation control
    @State private var globalAnimationTimer: Timer?
    @State private var animationTrigger: Int = 0
    @AppStorage("enableThumbnailAnimation") private var enableThumbnailAnimation = true
    
    private let columns = [
        GridItem(.fixed(500), spacing: 20),
        GridItem(.fixed(500), spacing: 20),
        GridItem(.fixed(500), spacing: 20),
    ]
    
    private var allAlbums: [ImmichAlbum] {
        var result = albums
        if let favAlbums = createFavoritesAlbum() {
            result.insert(favAlbums, at: 0)
        }
        return result
    }
    
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
                        ForEach(allAlbums) { album in
                            Button(action: {
                                selectedAlbum = album
                                showingAlbumDetail = true
                            }) {
                                AlbumRowView(
                                    album: album,
                                    albumService: albumService,
                                    assetService: assetService,
                                    userManager: userManager,
                                    isFocused: focusedAlbumId == album.id,
                                    animationTrigger: animationTrigger
                                )
                            }
                            .frame(width: 490, height: 400)
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
                loadFavoritesCount()
            }
            startGlobalAnimation()
        }
        .onDisappear {
            stopGlobalAnimation()
        }
    }
    
    private func startGlobalAnimation() {
        guard enableThumbnailAnimation else { return }
        stopGlobalAnimation()
        
        globalAnimationTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            animationTrigger += 1
        }
    }
    
    private func stopGlobalAnimation() {
        globalAnimationTimer?.invalidate()
        globalAnimationTimer = nil
    }
    
    private func createFavoritesAlbum() -> ImmichAlbum?  {
        
        if let user = userManager.currentUser {
            let owner = Owner(
                id: user.id,
                email: user.email,
                name: user.name,
                profileImagePath: "",
                profileChangedAt: "",
                avatarColor: "primary"
            )
            
            return ImmichAlbum(
                id: "smart_favorites",
                albumName: "Favorites",
                description: "Collection",
                albumThumbnailAssetId: firstFavoriteAssetId,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date()),
                albumUsers: [],
                assets: [],
                assetCount: favoritesCount,
                ownerId: user.id,
                owner: owner,
                shared: false,
                hasSharedLink: false,
                isActivityEnabled: false,
                lastModifiedAssetTimestamp: nil,
                order: nil,
                startDate: nil,
                endDate: nil
            )
        }
        return nil
    }
    
    private func loadFavoritesCount() {
        guard authService.isAuthenticated else { return }
        
        Task {
            do {
                let result = try await assetService.fetchAssets(page: 1, limit: nil, isFavorite: true)
                await MainActor.run {
                    self.favoritesCount = result.total
                    self.firstFavoriteAssetId = result.assets.first?.id
                }
            } catch {
                print("Failed to fetch favorites count: \(error)")
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
    @ObservedObject var userManager: UserManager
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @State private var thumbnailImage: UIImage?
    @State private var thumbnails: [UIImage] = []
    @State private var currentThumbnailIndex = 0
    @State private var isLoadingThumbnails = false
    @State private var enableThumbnailAnimation: Bool = UserDefaults.standard.enableThumbnailAnimation
    let isFocused: Bool
    let animationTrigger: Int
    
    private func sharingText(for album: ImmichAlbum) -> String {
        let isCurrentUser = album.owner.email == userManager.currentUser?.email
        return isCurrentUser ? "shared by you" : "\(album.owner.name)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {

                 RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 470, height: 280)

                if isLoadingThumbnails {
                    ProgressView()
                        .scaleEffect(1.2)
                        .foregroundColor(.white)
                } else if !thumbnails.isEmpty {
                    // Animated thumbnails
                     ZStack {
                    ForEach(Array(thumbnails.enumerated()), id: \.offset) { index, thumbnail in
                        
                        VStack{
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 470, height: 280)
                                .clipped()
                                .opacity(index == currentThumbnailIndex ? 1.0 : 0.0)
                                .animation(.easeInOut(duration: 1.5), value: currentThumbnailIndex)
                        }
                    }
                        
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
            
             VStack(alignment: .leading) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                         HStack {
                                            HStack(spacing: 6) {
                                                if album.id.hasPrefix("smart_") {
                                                    Image(systemName: "heart.fill")
                                                         .font(.title3)
                                                    .fontWeight(.semibold)
                                                        .foregroundColor(.red)
                                                }
                                                Text(album.albumName)
                                                    .font(.title3)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(isFocused ? .white : .gray)
                                                    .lineLimit(1)
                                            }
                                            
                                            Spacer()
                                            
                                            if album.shared {
                                                HStack(spacing: 1) {
                                                    Image(systemName: "person.2.fill")
                                                        .font(.caption)
                                                        .foregroundColor(.blue)
                                                    
                                                    Text(sharingText(for: album))
                                                        .font(.caption)
                                                        .foregroundColor(.blue)
                                                }
                                            }
                                        }

                                    Text(album.description ?? "Album")
                                            .font(.caption)
                                            .lineLimit(2)
                                            .foregroundColor(.gray)

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
                .padding(.horizontal, 20)
                .padding(.vertical, 50)
            }
            .frame(width: 470, height: 160)
            .background(Color.black.opacity(0.6))

        }
        .background(isFocused ? Color.white.opacity(0.1) : Color.gray.opacity(0.1))
        .onAppear {
            loadThumbnail()
            loadAlbumThumbnails()
        }
        .onChange(of: animationTrigger) { _, _ in
            // Only animate if conditions are met
            if enableThumbnailAnimation && !isFocused && thumbnails.count > 1 {
                withAnimation(.easeInOut(duration: 1.5)) {
                    currentThumbnailIndex = (currentThumbnailIndex + 1) % thumbnails.count
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            enableThumbnailAnimation = UserDefaults.standard.enableThumbnailAnimation
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
                let albumProvider = AlbumAssetProvider(albumService: albumService, assetService: assetService, albumId: album.id)
                let searchResult = try await albumProvider.fetchAssets(page: 1, limit: 10)
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
                    // Thumbnails loaded - animation will be handled by global trigger
                }
            } catch {
                print("Failed to fetch assets for album \(album.id): \(error)")
                await MainActor.run {
                    self.isLoadingThumbnails = false
                }
            }
        }
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
                    assetProvider: createAssetProvider(for: album),
                    albumId: album.id.hasPrefix("smart_") ? nil : album.id,
                    personId: nil,
                    tagId: nil,
                    isAllPhotos: false,
                    onAssetsLoaded: { loadedAssets in
                        self.albumAssets = loadedAssets
                    },
                    deepLinkAssetId: nil
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
            SlideshowView(albumId: album.id, personId: nil, tagId: nil, startingIndex: 0)
        }
    }
    
    private func createAssetProvider(for album: ImmichAlbum) -> AssetProvider {
        if album.id == "smart_favorites" {
            return AssetProviderFactory.createProvider(
                isFavorite: true,
                assetService: assetService
            )
        } else {
            return AssetProviderFactory.createProvider(
                albumId: album.id,
                assetService: assetService,
                albumService: albumService
            )
        }
    }
    
    private func startSlideshow() {
        // Stop auto-slideshow timer before starting slideshow
        NotificationCenter.default.post(name: NSNotification.Name("stopAutoSlideshowTimer"), object: nil)
        showingSlideshow = true
    }
}

#Preview {
    let (_, userManager, authService, assetService, albumService, peopleService, _) =
         MockServiceFactory.createMockServices()
    AlbumListView(albumService: albumService, authService: authService, assetService: assetService, userManager: userManager)
}
