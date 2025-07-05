//
//  SlideshowView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct SlideshowView: View {
    let assets: [ImmichAsset]
    let immichService: ImmichService
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentIndex = 0
    @State private var currentImage: UIImage?
    @State private var isLoading = true
    @State private var slideInterval: TimeInterval = 6.0
    @State private var autoAdvanceTimer: Timer?
    @State private var isTransitioning = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black
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
                        ZStack {
                            Color.black
                                .ignoresSafeArea()
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .ignoresSafeArea()
                        .opacity(isTransitioning ? 0.0 : 1.0)
                        .animation(.easeInOut(duration: 0.8), value: isTransitioning)
                        .overlay(
                            // Lock screen style overlay in slideshow mode
                            VStack {
                                HStack {
                                    Spacer()
                                    LockScreenStyleOverlay(asset: assets[currentIndex], isSlideshowMode: true)
                                        .opacity(isTransitioning ? 0.0 : 1.0)
                                        .animation(.easeInOut(duration: 0.8), value: isTransitioning)
                                }
                            }
                        )
                        }
                    }
                    .ignoresSafeArea()
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
                let image = try await immichService.loadFullImage(from: asset)
                await MainActor.run {
                    self.currentImage = image
                    self.isLoading = false
                    
                    // Ensure fade in animation plays after image loads
                    if isTransitioning {
                        withAnimation(.easeInOut(duration: 1)) {
                            isTransitioning = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.currentImage = nil
                    self.isLoading = false
                    
                    // Still fade in even if image failed to load
                    if isTransitioning {
                        withAnimation(.easeInOut(duration: 1)) {
                            isTransitioning = false
                        }
                    }
                }
            }
        }
    }
    
    private func nextImage() {
        guard currentIndex < assets.count - 1 else { return }
        
        // Start fade out animation
        withAnimation(.easeInOut(duration: 0.5)) {
            isTransitioning = true
        }
        
        // Wait for fade out, then change image
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            currentIndex += 1
            loadCurrentImage()
            // Fade in will be triggered in loadCurrentImage after image loads
        }
    }
    
    private func startAutoAdvance() {
        stopAutoAdvance()
        
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: slideInterval, repeats: true) { _ in
            if currentIndex < assets.count - 1 {
                nextImage()
            } else {
                // Loop back to the beginning with animation
                withAnimation(.easeInOut(duration: 0.5)) {
                    isTransitioning = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    currentIndex = 0
                    loadCurrentImage()
                    // Fade in will be triggered in loadCurrentImage after image loads
                }
            }
        }
    }
    
    private func stopAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
    }
} 