//
//  FullScreenImageView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct FullScreenImageView: View {
    let asset: ImmichAsset
    let assets: [ImmichAsset]
    let currentIndex: Int
    @ObservedObject var immichService: ImmichService
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var isLoading = true

    @State private var currentAssetIndex: Int
    @State private var currentAsset: ImmichAsset
    @State private var showingSwipeHint = false
    
    init(asset: ImmichAsset, assets: [ImmichAsset], currentIndex: Int, immichService: ImmichService) {
        self.asset = asset
        self.assets = assets
        self.currentIndex = currentIndex
        self.immichService = immichService
        self._currentAssetIndex = State(initialValue: currentIndex)
        self._currentAsset = State(initialValue: asset)
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if currentAsset.type == .video {
                // Use VideoPlayerView for videos
                VideoPlayerView(asset: currentAsset, immichService: immichService)
            } else {
                // Use image view for photos
                if isLoading {
                    ProgressView("Loading...")
                        .foregroundColor(.white)
                        .scaleEffect(1.5)
                } else if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .ignoresSafeArea()
                        .overlay(
                            // Date and location overlay in bottom right
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    DateLocationOverlay(asset: currentAsset)
                                        .padding(.trailing, 5)
                                        .padding(.bottom, 5)
                                }
                            }
                        )
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
            

            

            

            
            // Swipe hint overlay
            if showingSwipeHint && assets.count > 1 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            HStack(spacing: 20) {
                                Image(systemName: "arrow.left")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("Swipe to navigate")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Image(systemName: "arrow.right")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(20)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 100)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            if currentAsset.type != .video {
                loadFullImage()
            }
            if assets.count > 1 {
                showingSwipeHint = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showingSwipeHint = false
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismiss()
        }

        .overlay(
            // Only show swipe gestures for non-video content. Doesn't work for videos.
            Group {
                if currentAsset.type != .video {
                    SwipeGestureView(
                        onSwipeLeft: {
                            print("FullScreenImageView: Left navigation triggered (current: \(currentAssetIndex), total: \(assets.count))")
                            if currentAssetIndex > 0 {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    navigateToImage(at: currentAssetIndex - 1)
                                }
                            } else {
                                print("FullScreenImageView: Already at first photo, cannot navigate further")
                            }
                        },
                        onSwipeRight: {
                            print("FullScreenImageView: Right navigation triggered (current: \(currentAssetIndex), total: \(assets.count))")
                            if currentAssetIndex < assets.count - 1 {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    navigateToImage(at: currentAssetIndex + 1)
                                }
                            } else {
                                print("FullScreenImageView: Already at last photo, cannot navigate further")
                            }
                        }
                    )
                }
            }
        )
    }
    
    private func navigateToImage(at index: Int) {
        print("FullScreenImageView: Attempting to navigate to image at index \(index) (total assets: \(assets.count))")
        guard index >= 0 && index < assets.count else { 
            print("FullScreenImageView: Navigation failed - index \(index) out of bounds")
            return 
        }
        
        print("FullScreenImageView: Navigating to asset ID: \(assets[index].id)")
        currentAssetIndex = index
        currentAsset = assets[index]
        
        if currentAsset.type != .video {
            image = nil
            isLoading = true
            loadFullImage()
        }
    }
    
    private func loadFullImage() {
        Task {
            do {
                let fullImage = try await immichService.loadFullImage(from: currentAsset)
                await MainActor.run {
                    self.image = fullImage
                    self.isLoading = false
                }
            } catch {
                print("Failed to load full image for asset \(currentAsset.id): \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
} 