//
//  SharedGridView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-09-04.
//

import SwiftUI

// MARK: - Grid Item Protocol
protocol GridDisplayable: Identifiable {
    var id: String { get }
    var primaryTitle: String { get }
    var secondaryTitle: String? { get }
    var description: String? { get }
    var thumbnailId: String? { get }
    var itemCount: Int? { get }
    var gridCreatedAt: String? { get }
    var isFavorite: Bool? { get }
    var isShared: Bool? { get }
    var sharingText: String? { get }
    var iconName: String { get }
    var gridColor: Color? { get }
}

// MARK: - Grid Configuration
struct GridConfig {
    let columns: [GridItem]
    let itemWidth: CGFloat
    let itemHeight: CGFloat
    let spacing: CGFloat
    let loadingText: String
    let emptyStateText: String
    let emptyStateDescription: String
    
    static let albumStyle = GridConfig(
        columns: [
            GridItem(.fixed(500), spacing: 20),
            GridItem(.fixed(500), spacing: 20),
            GridItem(.fixed(500), spacing: 20)
        ],
        itemWidth: 490,
        itemHeight: 400,
        spacing: 100,
        loadingText: "Loading albums...",
        emptyStateText: "No Albums Found",
        emptyStateDescription: "Your albums will appear here"
    )
    
    static let peopleStyle = GridConfig(
        columns: [
            GridItem(.fixed(400), spacing: 20),
            GridItem(.fixed(400), spacing: 20),
            GridItem(.fixed(400), spacing: 20),
            GridItem(.fixed(400), spacing: 20)
        ],
        itemWidth: 400,
        itemHeight: 450,
        spacing: 50,
        loadingText: "Loading people...",
        emptyStateText: "No People Found",
        emptyStateDescription: "People detected in your photos will appear here"
    )
    
    static let tagsStyle = GridConfig(
        columns: [
            GridItem(.fixed(500), spacing: 20),
            GridItem(.fixed(500), spacing: 20),
            GridItem(.fixed(500), spacing: 20)
        ],
        itemWidth: 490,
        itemHeight: 400,
        spacing: 100,
        loadingText: "Loading tags...",
        emptyStateText: "No Tags Found",
        emptyStateDescription: "Your tags will appear here"
    )
}

// MARK: - Thumbnail Provider Protocol
protocol ThumbnailProvider {
    func loadThumbnails(for item: GridDisplayable) async -> [UIImage]
}

// MARK: - Main Grid View
struct SharedGridView<Item: GridDisplayable>: View {
    let items: [Item]
    let config: GridConfig
    let thumbnailProvider: ThumbnailProvider
    let isLoading: Bool
    let errorMessage: String?
    let onItemSelected: (Item) -> Void
    let onRetry: () -> Void
    
    @FocusState private var focusedItemId: String?
    @State private var globalAnimationTimer: Timer?
    @State private var animationTrigger: Int = 0
    @AppStorage("enableThumbnailAnimation") private var enableThumbnailAnimation = true
    
    var body: some View {
        ZStack {
            SharedGradientBackground()
            
            if isLoading {
                ProgressView(config.loadingText)
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
                        onRetry()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if items.isEmpty {
                VStack {
                    Image(systemName: config.emptyStateText.contains("Album") ? "folder" : config.emptyStateText.contains("People") ? "person.crop.circle" : "tag")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text(config.emptyStateText)
                        .font(.title)
                        .foregroundColor(.white)
                    Text(config.emptyStateDescription)
                        .foregroundColor(.gray)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: config.columns, spacing: config.spacing) {
                        ForEach(items) { item in
                            Button(action: {
                                onItemSelected(item)
                            }) {
                                SharedGridItemView(
                                    item: item,
                                    config: config,
                                    thumbnailProvider: thumbnailProvider,
                                    isFocused: focusedItemId == item.id,
                                    animationTrigger: animationTrigger
                                )
                            }
                            .frame(width: config.itemWidth, height: config.itemHeight)
                            .focused($focusedItemId, equals: item.id)
                            .animation(.easeInOut(duration: 0.2), value: focusedItemId)
                            .padding(10)
                            .buttonStyle(CardButtonStyle())
                        }
                    }
                }
            }
        }
        .onAppear {
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
}

// MARK: - Grid Item View
struct SharedGridItemView<Item: GridDisplayable>: View {
    let item: Item
    let config: GridConfig
    let thumbnailProvider: ThumbnailProvider
    let isFocused: Bool
    let animationTrigger: Int
    
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @State private var thumbnails: [UIImage] = []
    @State private var currentThumbnailIndex = 0
    @State private var isLoadingThumbnails = false
    @State private var enableThumbnailAnimation: Bool = UserDefaults.standard.enableThumbnailAnimation
    
    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail section
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: config.itemWidth - 20, height: 280)
                
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
                                .frame(width: config.itemWidth - 20, height: 280)
                                .clipped()
                                .cornerRadius(12)
                                .opacity(index == currentThumbnailIndex ? 1.0 : 0.0)
                                .animation(.easeInOut(duration: 1.5), value: currentThumbnailIndex)
                        }
                    }
                } else {
                    // Fallback content
                    VStack(spacing: 12) {
                        if let color = item.gridColor {
                            Circle()
                                .fill(color)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: item.iconName)
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                )
                        } else {
                            Image(systemName: item.iconName)
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        }
                        
                        Text(item.primaryTitle)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            
            // Info section
            VStack(alignment: .leading) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            // Special icons for different types
                            if item.id.hasPrefix("smart_") {
                                Image(systemName: "heart.fill")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                            }
                            
                            Text(item.primaryTitle)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(isFocused ? .white : .gray)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            // Favorite indicator
                            if let isFavorite = item.isFavorite, isFavorite {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                            }
                            
                            // Shared indicator
                            if let isShared = item.isShared, isShared, let sharingText = item.sharingText {
                                HStack(spacing: 1) {
                                    Image(systemName: "person.2.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text(sharingText)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        // Secondary title or description
                        if let secondaryTitle = item.secondaryTitle {
                            Text(secondaryTitle)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        } else if let description = item.description {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        }
                        
                        // Bottom info row
                        HStack(spacing: 12) {
                            if let itemCount = item.itemCount {
                                Text("\(itemCount) photos")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            if let createdAt = item.gridCreatedAt, let formattedDate = formatDate(createdAt) {
                                Text("Created \(formattedDate)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, config.itemHeight > 360 ? 50 : 16)
            }
            .frame(width: config.itemWidth - 20, height: config.itemHeight > 360 ? 160 : 120)
            .background(Color.black.opacity(0.6))
        }
        .background(isFocused ? Color.white.opacity(0.1) : Color.gray.opacity(0.1))
        .onAppear {
            loadThumbnails()
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
    
    private func loadThumbnails() {
        guard !isLoadingThumbnails else { return }
        isLoadingThumbnails = true
        
        Task {
            let loadedThumbnails = await thumbnailProvider.loadThumbnails(for: item)
            await MainActor.run {
                self.thumbnails = loadedThumbnails
                self.isLoadingThumbnails = false
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
        
        // Try alternative format
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        
        return nil
    }
}
