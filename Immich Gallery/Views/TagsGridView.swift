//
//  TagsGridView.swift
//  Immich Gallery
//

import SwiftUI

struct TagsGridView: View {
    @ObservedObject var tagService: TagService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var assetService: AssetService
    @State private var tags: [Tag] = []
    @State private var selectedTag: Tag?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingTagDetail = false
    @FocusState private var focusedTagId: String?
    
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
                ProgressView("Loading tags...")
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
                        Task {
                            await loadTags()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if tags.isEmpty {
                VStack {
                    Image(systemName: "tag")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No Tags Found")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("Your tags will appear here")
                        .foregroundColor(.gray)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 30) {
                        ForEach(tags) { tag in
                            
                            Button(action: {
                                selectedTag = tag
                                showingTagDetail = true
                            }) {
                                TagRowView(
                                    tag: tag,
                                    isFocused: focusedTagId == tag.id,
                                    assetService: assetService
                                )
                            }
                            .frame(width: 490, height: 400)
                            .focused($focusedTagId, equals: tag.id)
                            .animation(.easeInOut(duration: 0.2), value: focusedTagId)
                            .padding(10)
                            .buttonStyle(CardButtonStyle())
                            
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingTagDetail) {
            if let selectedTag = selectedTag {
                TagDetailView(tag: selectedTag, assetService: assetService, authService: authService)
            }
        }
        .onAppear {
            if tags.isEmpty {
                Task {
                    await loadTags()
                }
            }
        }
    }
    
    private func loadTags() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedTags = try await tagService.fetchTags()
            await MainActor.run {
                self.tags = fetchedTags
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load tags: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

struct TagRowView: View {
    let tag: Tag
    let isFocused: Bool
    @ObservedObject var assetService: AssetService
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    
    @State private var thumbnails: [UIImage] = []
    @State private var currentThumbnailIndex = 0
    @State private var animationTimer: Timer?
    @State private var isLoadingThumbnails = false
    @State private var enableThumbnailAnimation: Bool = UserDefaults.standard.enableThumbnailAnimation
    
    var body: some View {
        VStack(spacing: 0) {
            // Tag thumbnail/visual at top
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
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 470, height: 280)
                                .clipped()
                                .opacity(index == currentThumbnailIndex ? 1.0 : 0.0)
                                .animation(.easeInOut(duration: 1.5), value: currentThumbnailIndex)
                        }
                    }
                } else {
                    // Fallback to static icon when no thumbnails
                    VStack(spacing: 20) {
                        Circle()
                            .fill(tagColor)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            )
                        
                        Text(tag.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            
            // Tag info at bottom
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tag.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(isFocused ? .white : .gray)
                            .lineLimit(1)
                        
                        if !tag.value.isEmpty && tag.value != tag.name {
                            Text(tag.value)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        } else {
                            Text("Tag")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    // Optional: Add asset count here if available
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: "photo")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(width: 470, height: 120)
            .background(Color.black.opacity(0.6))
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .shadow(color: isFocused ? .white.opacity(0.3) : .clear, radius: 8)
        )
        .onAppear {
            loadTagThumbnails()
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: isFocused) { focused in
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
    
    private var tagColor: Color {
        if let colorString = tag.color, !colorString.isEmpty {
            // Simple color mapping without custom extension
            switch colorString.lowercased() {
            case "red", "#ff0000", "#f00":
                return .red
            case "blue", "#0000ff", "#00f":
                return .blue
            case "green", "#00ff00", "#0f0":
                return .green
            case "yellow", "#ffff00", "#ff0":
                return .yellow
            case "orange", "#ffa500":
                return .orange
            case "purple", "#800080":
                return .purple
            case "pink", "#ffc0cb":
                return .pink
            default:
                return .blue
            }
        }
        return .blue
    }
    
    private func loadTagThumbnails() {
        guard !isLoadingThumbnails else { return }
        isLoadingThumbnails = true
        
        Task {
            do {
                let searchResult = try await assetService.fetchAssets(page: 1, limit: 10, tagId: tag.id)
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
                print("Failed to fetch assets for tag \(tag.id): \(error)")
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

struct TagDetailView: View {
    let tag: Tag
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                AssetGridView(assetService: assetService,
                              authService: authService,
                              assetProvider: AssetProviderFactory.createProvider(
                                tagId: tag.id,
                                assetService: assetService
                              ),
                              albumId: nil, personId: nil,
                              tagId: tag.id,
                              isAllPhotos: false,
                              onAssetsLoaded: nil,
                              deepLinkAssetId: nil)
            }
            .navigationTitle(tag.name)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let (_, authService, assetService, _, peopleService, tagService) =
    MockServiceFactory.createMockServices()
    TagsGridView(tagService: tagService, authService: authService, assetService: assetService)
}
