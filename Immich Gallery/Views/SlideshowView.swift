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
    @State private var slideInterval: TimeInterval = UserDefaults.standard.slideshowInterval
    @State private var autoAdvanceTimer: Timer?
    @State private var isTransitioning = false
    @State private var slideDirection: SlideDirection = .right
    @State private var dominantColor: Color = getBackgroundColor(UserDefaults.standard.slideshowBackgroundColor)
    @State private var preloadedImages: [String: UIImage] = [:] // Cache for preloaded images
    @State private var preloadedDominantColors: [String: Color] = [:] // Cache for dominant colors
    @FocusState private var isFocused: Bool
    
    enum SlideDirection {
        case left, right, up, down, diagonal_up_left, diagonal_up_right, diagonal_down_left, diagonal_down_right, zoom_out
        
        func offset(for size: CGSize) -> CGSize {
            let w = size.width * 1.2
            let h = size.height * 1.2
            switch self {
            case .left: return CGSize(width: -w, height: 0)
            case .right: return CGSize(width: w, height: 0)
            case .up: return CGSize(width: 0, height: -h)
            case .down: return CGSize(width: 0, height: h)
            case .diagonal_up_left: return CGSize(width: -w, height: -h)
            case .diagonal_up_right: return CGSize(width: w, height: -h)
            case .diagonal_down_left: return CGSize(width: -w, height: h)
            case .diagonal_down_right: return CGSize(width: w, height: h)
            case .zoom_out: return CGSize.zero
            }
        }
        
        var scale: CGFloat {
            switch self {
            case .zoom_out: return 0.1 // Scale down to nearly invisible
            default: return 1.0 // Normal scale
            }
        }
        
        var opacity: Double {
            switch self {
            case .zoom_out: return 0.0 // Fade out
            default: return 1.0 // Normal opacity
            }
        }
    }
    
    // Global slide animation duration for both slide-in and slide-out
    private let slideAnimationDuration: Double = 1.5
    
    var body: some View {
        ZStack {
            // Use dominant color if available, otherwise fall back to user setting, and animate changes
            (UserDefaults.standard.slideshowBackgroundColor == "auto" ? dominantColor : getBackgroundColor(UserDefaults.standard.slideshowBackgroundColor))
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: dominantColor)
            
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

                        VStack(spacing: 0) {
                            // Main image with performance optimizations
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: imageWidth, height: imageHeight)
                                .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 15)
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                                .drawingGroup() // Enable hardware acceleration for smooth animations
                                .offset(isTransitioning ? slideDirection.offset(for: geometry.size) : .zero)
                                .scaleEffect(isTransitioning ? slideDirection.scale : 1.0)
                                .opacity(isTransitioning ? slideDirection.opacity : 1.0)
                                .animation(.easeInOut(duration: slideAnimationDuration), value: isTransitioning)
                                .overlay(
                                    Group {
                                        if !UserDefaults.standard.hideImageOverlay {
                                            // Calculate actual image display size within the frame
                                            GeometryReader { imageGeometry in
                                                let actualImageSize = calculateActualImageSize(
                                                    imageSize: CGSize(width: image.size.width, height: image.size.height),
                                                    containerSize: CGSize(width: imageWidth, height: imageHeight)
                                                )
                                                let screenWidth = geometry.size.width
                                                let isSmallWidth = actualImageSize.width < (screenWidth / 2)
                                                
                                                if isSmallWidth {
                                                    // For small images, show overlay outside (original behavior)
                                                    VStack {
                                                        HStack {
                                                            Spacer()
                                                            LockScreenStyleOverlay(asset: assets[currentIndex], isSlideshowMode: true)
                                                                .opacity(isTransitioning ? 0.0 : 1.0)
                                                                .animation(.easeInOut(duration: slideAnimationDuration), value: isTransitioning)
                                                        }
                                                    }
                                                } else {
                                                    // For larger images, constrain overlay inside image
                                                    let xOffset = (imageWidth - actualImageSize.width) / 2
                                                    let yOffset = (imageHeight - actualImageSize.height) / 2
                                                    
                                                    VStack {
                                                        Spacer()
                                                        HStack {
                                                            Spacer()
                                                            LockScreenStyleOverlay(asset: assets[currentIndex], isSlideshowMode: true)
                                                                .opacity(isTransitioning ? 0.0 : 1.0)
                                                                .animation(.easeInOut(duration: slideAnimationDuration), value: isTransitioning)
                                                                .padding(.trailing, 20)
                                                                .padding(.bottom, 20)
                                                        }
                                                    }
                                                    .frame(width: actualImageSize.width, height: actualImageSize.height)
                                                    .offset(x: xOffset, y: yOffset)
                                                }
                                            }
                                        }
                                    }
                                )
                                
                            // Reflection with performance optimizations
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .scaleEffect(y: -1)
                                .frame(width: imageWidth, height: imageHeight)
                                .offset(y: -imageHeight * 0.0)
                                .clipped()
                                .mask(
                                    LinearGradient(
                                        colors: [.black.opacity(0.9), .clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                                .opacity(0.4)
                                .drawingGroup() // Enable hardware acceleration for reflection
                                .offset(isTransitioning ? slideDirection.offset(for: geometry.size) : .zero)
                                .scaleEffect(isTransitioning ? slideDirection.scale : 1.0)
                                .opacity(isTransitioning ? slideDirection.opacity * 0.4 : 0.4)
                                .animation(.easeInOut(duration: slideAnimationDuration), value: isTransitioning)
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
            preloadedImages.removeAll() // Clear any existing preloaded images
            preloadedDominantColors.removeAll() // Clear any existing preloaded dominant colors
            loadCurrentImage()
        }
        .onDisappear {
            stopAutoAdvance()
            preloadedImages.removeAll() // Clear preloaded images to free memory
            preloadedDominantColors.removeAll() // Clear preloaded dominant colors to free memory
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            // Update slide interval if it changed in settings
            let newInterval = UserDefaults.standard.slideshowInterval
            slideInterval = newInterval > 0 ? newInterval : 6.0
            // No need to restart timer here; timer is managed after each image load
        }
        .onTapGesture {
            dismiss()
        }
    }
    private func loadCurrentImage() {
        guard currentIndex >= 0 && currentIndex < assets.count else { 
            print("SlideshowView: Index out of bounds - \(currentIndex), assets count: \(assets.count)")
            return 
        }
        
        let asset = assets[currentIndex]
        
        // Check if image is already preloaded
        if let preloadedImage = preloadedImages[asset.id] {
            print("SlideshowView: Using preloaded image for asset \(asset.id)")
            self.currentImage = preloadedImage
            self.isLoading = false
            
            // Use preloaded dominant color if available
            if UserDefaults.standard.slideshowBackgroundColor == "auto" {
                if let cachedColor = preloadedDominantColors[asset.id] {
                    self.dominantColor = cachedColor
                } else {
                    self.dominantColor = extractDominantColor(from: preloadedImage)
                }
            }
            
            // Ensure slide-in animation plays
            if isTransitioning {
                withAnimation(.easeInOut(duration: slideAnimationDuration)) {
                    isTransitioning = false
                }
            }
            
            // Remove from preload cache to free memory
            preloadedImages.removeValue(forKey: asset.id)
            preloadedDominantColors.removeValue(forKey: asset.id)
            
            // Preload next image
            preloadNextImage()
            // Start timer after image is loaded and shown
            startAutoAdvance()
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let image = try await assetService.loadFullImage(asset: asset)
                await MainActor.run {
                    // Clear previous image immediately to free memory before setting new one
                    self.currentImage = nil
                    
                    self.currentImage = image
                    self.isLoading = false
                    
                    // Extract dominant color from the image
                    if UserDefaults.standard.slideshowBackgroundColor == "auto" {
                        self.dominantColor = extractDominantColor(from: image!)
                    }
                    
                    // Ensure slide-in animation plays after image loads
                    if isTransitioning {
                        withAnimation(.easeInOut(duration: slideAnimationDuration)) {
                            isTransitioning = false
                        }
                    }
                    
                    // Preload next image
                    self.preloadNextImage()
                    // Start timer after image is loaded and shown
                    self.startAutoAdvance()
                }
            } catch {
                print("SlideshowView: Failed to load image for asset \(asset.id): \(error)")
                await MainActor.run {
                    self.currentImage = nil
                    self.isLoading = false
                    
                    // Still slide in even if image failed to load
                    if isTransitioning {
                        withAnimation(.easeInOut(duration: slideAnimationDuration)) {
                            isTransitioning = false
                        }
                    }
                    
                    // Still try to preload next image
                    self.preloadNextImage()
                    // Start timer even if failed to load
                    self.startAutoAdvance()
                }
            }
        }
    }
    
    private func nextImage() {
        print("SlideshowView: nextImage() called - currentIndex: \(currentIndex), assets count: \(assets.count)")
        guard currentIndex < assets.count - 1 else { 
            print("SlideshowView: nextImage() guard failed - at last image")
            return 
        }
        
        print("SlideshowView: Starting slide out animation")
        // Start slide out animation
        withAnimation(.easeInOut(duration: slideAnimationDuration)) {
            isTransitioning = true
        }
        
        // Wait for slide out to complete, then change image and direction
        DispatchQueue.main.asyncAfter(deadline: .now() + slideAnimationDuration) {
            if self.currentIndex + 1 < self.assets.count {
                print("SlideshowView: Advancing from index \(self.currentIndex) to \(self.currentIndex + 1)")
                // Set new slide direction for the incoming image
                let directions: [SlideDirection] = [.left, .right, .up, .down, .diagonal_up_left, .diagonal_up_right, .diagonal_down_left, .diagonal_down_right, .zoom_out]
                self.slideDirection = directions.randomElement() ?? .right
                self.currentIndex += 1
                self.loadCurrentImage()
            } else {
                print("SlideshowView: Cannot advance further - at last image")
            }
        }
    }
    
    private func startAutoAdvance() {
        stopAutoAdvance()
        // Start a one-shot timer after the image is loaded and visible
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: slideInterval, repeats: false) { _ in
            print("SlideshowView: Timer fired - currentIndex: \(self.currentIndex), assets count: \(self.assets.count) \(slideInterval)")
            if self.currentIndex < self.assets.count - 1 {
                print("SlideshowView: Advancing to next image")
                self.nextImage()
            } else {
                print("SlideshowView: Looping back to beginning")
                // Loop back to the beginning with slide animation
                withAnimation(.easeInOut(duration: slideAnimationDuration)) {
                    self.isTransitioning = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + slideAnimationDuration) {
                    // Set new slide direction for the incoming image
                    let directions: [SlideDirection] = [.left, .right, .up, .down, .diagonal_up_left, .diagonal_up_right, .diagonal_down_left, .diagonal_down_right, .zoom_out]
                    self.slideDirection = directions.randomElement() ?? .right
                    self.currentIndex = 0
                    self.loadCurrentImage()
                    // Slide in will be triggered in loadCurrentImage after image loads
                }
            }
        }
    }
    
    private func stopAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
    }
    
    private func preloadNextImage() {
        let nextIndex = currentIndex + 1
        
        // Handle looping back to start
        let actualNextIndex = nextIndex >= assets.count ? 0 : nextIndex
        guard actualNextIndex < assets.count else { return }
        
        let nextAsset = assets[actualNextIndex]
        
        // Don't preload if already cached
        guard preloadedImages[nextAsset.id] == nil else { return }
        
        print("SlideshowView: Starting preload for next image at index \(actualNextIndex), asset ID: \(nextAsset.id)")
        
        Task {
            do {
                let image = try await assetService.loadFullImage(asset: nextAsset)
                await MainActor.run {
                    // Only cache if we haven't moved too far ahead (avoid memory buildup)
                    if preloadedImages.count < 2 {
                        self.preloadedImages[nextAsset.id] = image
                        print("SlideshowView: Successfully preloaded image for asset \(nextAsset.id)")
                        // Extract and cache dominant color during preload
                        if UserDefaults.standard.slideshowBackgroundColor == "auto" {
                            let color = extractDominantColor(from: image!)
                            self.preloadedDominantColors[nextAsset.id] = color
                        }
                    } else {
                        print("SlideshowView: Skipped preload for asset \(nextAsset.id) - cache full")
                    }
                }
            } catch {
                print("SlideshowView: Failed to preload image for asset \(nextAsset.id): \(error)")
            }
        }
    }
    
    private func calculateActualImageSize(imageSize: CGSize, containerSize: CGSize) -> CGSize {
        let imageAspectRatio = imageSize.width / imageSize.height
        let containerAspectRatio = containerSize.width / containerSize.height
        
        if imageAspectRatio > containerAspectRatio {
            // Image is wider than container - width will be constrained
            let actualWidth = containerSize.width
            let actualHeight = actualWidth / imageAspectRatio
            return CGSize(width: actualWidth, height: actualHeight)
        } else {
            // Image is taller than container - height will be constrained
            let actualHeight = containerSize.height
            let actualWidth = actualHeight * imageAspectRatio
            return CGSize(width: actualWidth, height: actualHeight)
        }
    }
    
   private func extractDominantColor(from image: UIImage) -> Color {
    guard let cgImage = image.cgImage else {
        return .black
    }

    // Resize image to 50x50 using Core Image
    let ciImage = CIImage(cgImage: cgImage)
    let scale = CGAffineTransform(scaleX: 50.0 / ciImage.extent.width, y: 50.0 / ciImage.extent.height)
    let resizedCIImage = ciImage.transformed(by: scale)

    let context = CIContext()
    guard let resizedCGImage = context.createCGImage(resizedCIImage, from: resizedCIImage.extent) else {
        return .black
    }

    let width = resizedCGImage.width
    let height = resizedCGImage.height
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    let pixelCount = width * height

    let pixelData = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelCount * bytesPerPixel)
    defer { pixelData.deallocate() }

    guard let bitmapContext = CGContext(
        data: pixelData,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return .black
    }

    bitmapContext.draw(resizedCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    // Count quantized color frequency
    var colorCounts: [UInt32: Int] = [:]

    for i in 0..<pixelCount {
        let offset = i * bytesPerPixel
        let r = pixelData[offset]
        let g = pixelData[offset + 1]
        let b = pixelData[offset + 2]

        // Skip very dark or very bright pixels
        if r < 30 && g < 30 && b < 30 { continue }
        if r > 230 && g > 230 && b > 230 { continue }

        let reducedR = (r / 32) * 32
        let reducedG = (g / 32) * 32
        let reducedB = (b / 32) * 32

        let key = (UInt32(reducedR) << 16) | (UInt32(reducedG) << 8) | UInt32(reducedB)
        colorCounts[key, default: 0] += 1
    }

    guard let dominantColorKey = colorCounts.max(by: { $0.value < $1.value })?.key else {
        return .black
    }

    let r = Double((dominantColorKey >> 16) & 0xFF) / 255.0
    let g = Double((dominantColorKey >> 8) & 0xFF) / 255.0
    let b = Double(dominantColorKey & 0xFF) / 255.0

    // Adjust brightness for contrast (optional)
    let brightness = 0.299 * r + 0.587 * g + 0.114 * b
    let darkenFactor = brightness > 0.6 ? 0.6 : 1.0 // Darken only if it's too bright

    return Color(
        red: r * darkenFactor,
        green: g * darkenFactor,
        blue: b * darkenFactor
    )
}
}

#Preview {
    // Set the UserDefaults value before creating the view
    UserDefaults.standard.set("white", forKey: "slideshowBackgroundColor")
    UserDefaults.standard.set("10", forKey: "slideshowInterval")
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
    
   return  SlideshowView(assets: mockAssets, assetService: assetService)
}
