//
//  SlideshowView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct SlideshowView: View {
    let assets: [ImmichAsset]
    let assetService: AssetService
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentIndex = 0
    @State private var currentImage: UIImage?
    @State private var isLoading = true
    @State private var slideInterval: TimeInterval = 6.0
    @State private var autoAdvanceTimer: Timer?
    @State private var isTransitioning = false
    @State private var slideDirection: SlideDirection = .right
    @FocusState private var isFocused: Bool
    
    enum SlideDirection {
        case left, right, up, down
        
        var offset: CGSize {
            switch self {
            case .left: return CGSize(width: -1000, height: 0)
            case .right: return CGSize(width: 1000, height: 0)
            case .up: return CGSize(width: 0, height: -1000)
            case .down: return CGSize(width: 0, height: 1000)
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            if assets.isEmpty {
                VStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No images to display")
                        .font(.title)
                        .foregroundColor(.white)
                }
            } else {
                // Main image display
                if isLoading {
                    ProgressView("Loading...")
                        .foregroundColor(.white)
                        .scaleEffect(1.5)
                } else if let image = currentImage {
                    GeometryReader { geometry in
                        let imageWidth = geometry.size.width * 0.9
                        let imageHeight = geometry.size.height * 0.9

                        VStack(spacing: 20) {
                            // Main image
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: imageWidth, height: imageHeight)
                                .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 15)
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                                .offset(isTransitioning ? slideDirection.offset : .zero)
                                .opacity(isTransitioning ? 0.0 : 1.0)
                                .animation(.easeInOut(duration: 1.2), value: isTransitioning)
                                .animation(.easeInOut(duration: 1.2), value: slideDirection)
                                .overlay(
                                    Group {
                                        if !UserDefaults.standard.hideImageOverlay {
                                            VStack {
                                                HStack {
                                                    Spacer()
                                                    LockScreenStyleOverlay(asset: assets[currentIndex], isSlideshowMode: true)
                                                        .opacity(isTransitioning ? 0.0 : 1.0)
                                                        .animation(.easeInOut(duration: 1.2), value: isTransitioning)
                                                }
                                            }
                                        }
                                    }
                                )
                                
                            // Reflection
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .scaleEffect(y: -1)
                                .frame(width: imageWidth, height: imageHeight)
                                .offset(y: -imageHeight * 0.2)
                                .clipped()
                                .mask(
                                    LinearGradient(
                                        colors: [.black.opacity(0.9), .clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                                .opacity(0.4)
                                .offset(isTransitioning ? slideDirection.offset : .zero)
                                .opacity(isTransitioning ? 0.0 : 0.4)
                                .animation(.easeInOut(duration: 1.2), value: isTransitioning)
                                .animation(.easeInOut(duration: 1.2), value: slideDirection)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Failed to load image")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .focusable(true)
        .focused($isFocused)
        .onAppear {
            isFocused = true
            loadCurrentImage()
            startAutoAdvance()
        }
        .onDisappear {
            stopAutoAdvance()
        }
        .onTapGesture {
            dismiss()
        }
    }
    
    private func loadCurrentImage() {
        guard currentIndex < assets.count else { return }
        
        let asset = assets[currentIndex]
        isLoading = true
        
        Task {
            do {
                let image = try await assetService.loadFullImage(asset: asset)
                await MainActor.run {
                    self.currentImage = image
                    self.isLoading = false
                    
                    // Ensure slide-in animation plays after image loads
                    if isTransitioning {
                        withAnimation(.easeInOut(duration: 1.2)) {
                            isTransitioning = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.currentImage = nil
                    self.isLoading = false
                    
                    // Still slide in even if image failed to load
                    if isTransitioning {
                        withAnimation(.easeInOut(duration: 1.2)) {
                            isTransitioning = false
                        }
                    }
                }
            }
        }
    }
    
    private func nextImage() {
        guard currentIndex < assets.count - 1 else { return }
        
        // Randomly select slide direction for variety
        let directions: [SlideDirection] = [.left, .right, .up, .down]
        slideDirection = directions.randomElement() ?? .right
        
        // Start slide out animation
        withAnimation(.easeInOut(duration: 0.8)) {
            isTransitioning = true
        }
        
        // Wait for slide out, then change image
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            currentIndex += 1
            loadCurrentImage()
            // Slide in will be triggered in loadCurrentImage after image loads
        }
    }
    
    private func startAutoAdvance() {
        stopAutoAdvance()
        
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: slideInterval, repeats: true) { _ in
            if currentIndex < assets.count - 1 {
                nextImage()
            } else {
                // Loop back to the beginning with slide animation
                let directions: [SlideDirection] = [.left, .right, .up, .down]
                slideDirection = directions.randomElement() ?? .right
                
                withAnimation(.easeInOut(duration: 0.8)) {
                    isTransitioning = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    currentIndex = 0
                    loadCurrentImage()
                    // Slide in will be triggered in loadCurrentImage after image loads
                }
            }
        }
    }
    
    private func stopAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
    }
}

#Preview {
    let (_, _, assetService, _, _) = MockServiceFactory.createMockServices()
    
    // Create mock assets for preview
    let mockAssets = [
        ImmichAsset(
            id: "mock-1",
            deviceAssetId: "mock-device-1",
            deviceId: "mock-device",
            ownerId: "mock-owner",
            libraryId: nil,
            type: .image,
            originalPath: "/mock/path1",
            originalFileName: "mock1.jpg",
            originalMimeType: "image/jpeg",
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
            checksum: "mock-checksum-1",
            duration: nil,
            hasMetadata: false,
            livePhotoVideoId: nil,
            people: [],
            visibility: "public",
            duplicateId: nil,
            exifInfo: nil
        )
    ]
    
    SlideshowView(assets: mockAssets, assetService: assetService)
}
