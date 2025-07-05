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
    @State private var isPlaying = true
    @State private var slideInterval: TimeInterval = 3.0
    @State private var showingControls = true
    @State private var controlsTimer: Timer?
    @State private var autoAdvanceTimer: Timer?
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
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .ignoresSafeArea()
                        .overlay(
                            // Date and location overlay
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    DateLocationOverlay(asset: assets[currentIndex])
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
                
                // Controls overlay
                if showingControls {
                    VStack {
                        // Top controls
                        HStack {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            // Play/Pause button
                            Button(action: togglePlayPause) {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            // Settings button
                            Button(action: { showingControls = false }) {
                                Image(systemName: "gear")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        Spacer()
                        
                        // Bottom progress and navigation
                        VStack(spacing: 20) {
                            // Progress indicator
                            HStack {
                                Text("\(currentIndex + 1) of \(assets.count)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(12)
                                
                                Spacer()
                                
                                // Speed control
                                HStack(spacing: 8) {
                                    Button(action: { decreaseSpeed() }) {
                                        Image(systemName: "minus")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                    
                                    Text("\(Int(slideInterval))s")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.black.opacity(0.6))
                                        .cornerRadius(8)
                                    
                                    Button(action: { increaseSpeed() }) {
                                        Image(systemName: "plus")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            // Navigation buttons
                            HStack(spacing: 40) {
                                Button(action: previousImage) {
                                    Image(systemName: "chevron.left")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .padding(16)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .disabled(currentIndex == 0)
                                .opacity(currentIndex == 0 ? 0.5 : 1.0)
                                
                                Button(action: nextImage) {
                                    Image(systemName: "chevron.right")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .padding(16)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .disabled(currentIndex == assets.count - 1)
                                .opacity(currentIndex == assets.count - 1 ? 0.5 : 1.0)
                            }
                        }
                        .padding(.bottom, 40)
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
            startControlsTimer()
        }
        .onDisappear {
            stopAutoAdvance()
            stopControlsTimer()
        }
        .onChange(of: slideInterval) { _ in
            if isPlaying {
                startAutoAdvance()
            }
        }
        .onMoveCommand { direction in
            switch direction {
            case .left:
                previousImage()
            case .right:
                nextImage()
            case .up:
                increaseSpeed()
            case .down:
                decreaseSpeed()
            @unknown default:
                break
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingControls.toggle()
            }
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
                }
            } catch {
                await MainActor.run {
                    self.currentImage = nil
                    self.isLoading = false
                }
            }
        }
    }
    
    private func nextImage() {
        guard currentIndex < assets.count - 1 else { return }
        currentIndex += 1
        loadCurrentImage()
    }
    
    private func previousImage() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        loadCurrentImage()
    }
    
    private func togglePlayPause() {
        isPlaying.toggle()
        if isPlaying {
            startAutoAdvance()
        } else {
            stopAutoAdvance()
        }
    }
    
    private func startAutoAdvance() {
        guard isPlaying else { return }
        stopAutoAdvance()
        
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: slideInterval, repeats: true) { _ in
            if currentIndex < assets.count - 1 {
                nextImage()
            } else {
                // Loop back to the beginning
                currentIndex = 0
                loadCurrentImage()
            }
        }
    }
    
    private func stopAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
    }
    
    private func increaseSpeed() {
        slideInterval = max(1.0, slideInterval - 0.5)
        if isPlaying {
            startAutoAdvance()
        }
    }
    
    private func decreaseSpeed() {
        slideInterval = min(10.0, slideInterval + 0.5)
        if isPlaying {
            startAutoAdvance()
        }
    }
    
    private func startControlsTimer() {
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showingControls = false
            }
        }
    }
    
    private func stopControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = nil
    }
} 