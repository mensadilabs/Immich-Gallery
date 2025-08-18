//
//  SlideshowView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI
import UIKit

struct SlideshowView: View {
    let albumId: String?
    let personId: String?
    let tagId: String?
    let assetService: AssetService
    let startingIndex: Int
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
    @State private var slideshowBackgroundColor: String = UserDefaults.standard.slideshowBackgroundColor
    @State private var hideImageOverlay: Bool = UserDefaults.standard.hideImageOverlay
    @State private var enableReflectionsInSlideshow: Bool = UserDefaults.standard.enableReflectionsInSlideshow
    @State private var enableKenBurnsEffect: Bool = UserDefaults.standard.enableKenBurnsEffect
    @State private var dimensionMultiplier:Double = UserDefaults.standard.enableReflectionsInSlideshow ?  0.9 : 1.0
    @State private var kenBurnsScale: CGFloat = 1.0
    @State private var kenBurnsOffset: CGSize = .zero
    @State private var enableShuffle: Bool = UserDefaults.standard.enableSlideshowShuffle
    @State private var assets: [ImmichAsset] = []
    @State private var hasMoreAssets = true
    @State private var currentPage = 1
    @State private var isLoadingAssets = false
    @State private var loadAssetsTask: Task<Void, Never>?
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
    
    // Computed property to get current assets array
    private var currentAssets: [ImmichAsset] {
        assets
    }
    
    var body: some View {
        ZStack {
            // Use dominant color if available, otherwise fall back to user setting, and animate changes
            (slideshowBackgroundColor == "auto" ? dominantColor : getBackgroundColor(slideshowBackgroundColor))
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: dominantColor)
            
            if currentAssets.isEmpty {
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
                        let imageWidth = geometry.size.width * dimensionMultiplier
                        let imageHeight = geometry.size.height * dimensionMultiplier

                        VStack(spacing: 0) {
                            // Main image with performance optimizations
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: imageWidth, height: imageHeight)
                                .drawingGroup() // Enable hardware acceleration for smooth animations
                                .offset(isTransitioning ? slideDirection.offset(for: geometry.size) : kenBurnsOffset)
                                .scaleEffect(isTransitioning ? slideDirection.scale : kenBurnsScale)
                                .opacity(isTransitioning ? slideDirection.opacity : 1.0)
                                .animation(.easeInOut(duration: slideAnimationDuration), value: isTransitioning)
                                .animation(.linear(duration: slideInterval), value: kenBurnsScale)
                                .animation(.linear(duration: slideInterval), value: kenBurnsOffset)
                                .overlay(
                                    Group {
                                        if !hideImageOverlay {
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
                                                            LockScreenStyleOverlay(asset: currentAssets[currentIndex], isSlideshowMode: true)
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
                                                            LockScreenStyleOverlay(asset: currentAssets[currentIndex], isSlideshowMode: true)
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
                            if enableReflectionsInSlideshow {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .scaleEffect(y: -1)
                                    .frame(width: imageWidth, height: imageHeight)
                                    .offset(y: -imageHeight * 0.0)
                                    .clipped()
                                    .mask(
                                        ZStack {
                                            // Base gradient mask for reflection fade
                                            LinearGradient(
                                                colors: [.black.opacity(0.9), .clear],
                                                startPoint: .top,
                                                endPoint: .center
                                            )
                                            
                                            // When Ken Burns is active, add mask to prevent overlap with main image
                                            if enableKenBurnsEffect {
                                                Rectangle()
                                                    .fill(.clear)
                                                    .background(
                                                        Rectangle()
                                                            .fill(.black)
                                                            .scaleEffect(isTransitioning ? slideDirection.scale : kenBurnsScale)
                                                            .offset(
                                                                x: -(isTransitioning ? slideDirection.offset(for: geometry.size).width : kenBurnsOffset.width),
                                                                y: -(isTransitioning ? slideDirection.offset(for: geometry.size).height : kenBurnsOffset.height) - imageHeight
                                                            )
                                                            .blendMode(.destinationOut)
                                                    )
                                            }
                                        }
                                        .compositingGroup()
                                    )
                                    .opacity(0.4)
                                    .drawingGroup() // Enable hardware acceleration for reflection
                                    .offset(isTransitioning ? slideDirection.offset(for: geometry.size) : kenBurnsOffset)
                                    .scaleEffect(isTransitioning ? slideDirection.scale : kenBurnsScale)
                                    .opacity(isTransitioning ? slideDirection.opacity * 0.4 : 0.4)
                                    .animation(.easeInOut(duration: slideAnimationDuration), value: isTransitioning)
                                    .animation(.linear(duration: slideInterval), value: kenBurnsScale)
                                    .animation(.linear(duration: slideInterval), value: kenBurnsOffset)
                            }
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
            
            // Prevent display from sleeping during slideshow
            UIApplication.shared.isIdleTimerDisabled = true
            print("SlideshowView: Display sleep disabled")
            
            // Load initial assets
            loadInitialAssets()
        }
        .onDisappear {
            // Cancel any ongoing tasks first
            loadAssetsTask?.cancel()
            loadAssetsTask = nil
            
            stopAutoAdvance()
            preloadedImages.removeAll() // Clear preloaded images to free memory
            preloadedDominantColors.removeAll() // Clear preloaded dominant colors to free memory
            
            // Re-enable display sleep when slideshow ends
            UIApplication.shared.isIdleTimerDisabled = false
            print("SlideshowView: Display sleep re-enabled")
            
            // Restart auto-slideshow timer when slideshow ends
            NotificationCenter.default.post(name: NSNotification.Name("restartAutoSlideshowTimer"), object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // Re-enable display sleep when app goes to background
            UIApplication.shared.isIdleTimerDisabled = false
            print("SlideshowView: Display sleep re-enabled (app backgrounded)")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Re-disable display sleep when app becomes active again (if slideshow is still running)
            UIApplication.shared.isIdleTimerDisabled = true
            print("SlideshowView: Display sleep disabled (app foregrounded)")
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            // Update all settings if they changed
            slideInterval = UserDefaults.standard.slideshowInterval
            
            let newBackgroundColor = UserDefaults.standard.slideshowBackgroundColor
            let previousBackgroundColor = slideshowBackgroundColor
            slideshowBackgroundColor = newBackgroundColor
            
            hideImageOverlay = UserDefaults.standard.hideImageOverlay
            enableReflectionsInSlideshow = UserDefaults.standard.enableReflectionsInSlideshow
            enableKenBurnsEffect = UserDefaults.standard.enableKenBurnsEffect
            
            // Update dominant color if background color setting changed to/from auto
            if newBackgroundColor != previousBackgroundColor {
                if newBackgroundColor == "auto", let currentImage = currentImage {
                    Task {
                        let color = await extractDominantColorAsync(from: currentImage)
                        await MainActor.run {
                            self.dominantColor = color
                        }
                    }
                } else if newBackgroundColor != "auto" {
                    dominantColor = getBackgroundColor(newBackgroundColor)
                }
            }
        }
        .onTapGesture {
            // Re-enable display sleep before dismissing
            UIApplication.shared.isIdleTimerDisabled = false
            print("SlideshowView: Display sleep re-enabled (tap dismiss)")
            dismiss()
        }
    }
    private func loadCurrentImage() {
        guard currentIndex >= 0 && currentIndex < currentAssets.count else { 
            print("SlideshowView: Index out of bounds - \(currentIndex), assets count: \(currentAssets.count)")
            return 
        }
        
        let asset = currentAssets[currentIndex]
        
        // Check if image is already preloaded
        if let preloadedImage = preloadedImages[asset.id] {
            print("SlideshowView: Using preloaded image for asset \(asset.id)")
            self.currentImage = preloadedImage
            self.isLoading = false
            
            // Use preloaded dominant color if available
            if slideshowBackgroundColor == "auto" {
                if let cachedColor = preloadedDominantColors[asset.id] {
                    self.dominantColor = cachedColor
                } else {
                    Task {
                        let color = await extractDominantColorAsync(from: preloadedImage)
                        await MainActor.run {
                            self.dominantColor = color
                        }
                    }
                }
            }
            
            // Ensure slide-in animation plays
            if isTransitioning {
                withAnimation(.easeInOut(duration: slideAnimationDuration)) {
                    isTransitioning = false
                }
            }
            
            // Start Ken Burns effect for this image
            startKenBurnsEffect()
            
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
                    
                    // Extract dominant color from the image asynchronously
                    if slideshowBackgroundColor == "auto" {
                        Task {
                            let color = await extractDominantColorAsync(from: image!)
                            await MainActor.run {
                                self.dominantColor = color
                            }
                        }
                    }
                    
                    // Ensure slide-in animation plays after image loads
                    if isTransitioning {
                        withAnimation(.easeInOut(duration: slideAnimationDuration)) {
                            isTransitioning = false
                        }
                    }
                    
                    // Start Ken Burns effect for this image
                    self.startKenBurnsEffect()
                    
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
        print("SlideshowView: nextImage() called - currentIndex: \(currentIndex), assets count: \(currentAssets.count)")
        
        // Check if we can advance to next asset in current batch
        guard currentIndex < currentAssets.count - 1 else { 
            print("SlideshowView: At last image in batch, loading more assets")
            loadMoreAssets()
            return 
        }
        
        print("SlideshowView: Starting slide out animation")
        // Start slide out animation
        withAnimation(.easeInOut(duration: slideAnimationDuration)) {
            isTransitioning = true
        }
        
        // Wait for slide out to complete, then change image and direction
        DispatchQueue.main.asyncAfter(deadline: .now() + slideAnimationDuration) {
            print("SlideshowView: Advancing from index \(self.currentIndex) to \(self.currentIndex + 1)")
            // Set new slide direction for the incoming image
            let directions: [SlideDirection] = [.left, .right, .up, .down, .diagonal_up_left, .diagonal_up_right, .diagonal_down_left, .diagonal_down_right, .zoom_out]
            self.slideDirection = directions.randomElement() ?? .right
            self.currentIndex += 1
            self.loadCurrentImage()
        }
    }
    
    private func startAutoAdvance() {
        stopAutoAdvance()
        // Start a one-shot timer after the image is loaded and visible
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: slideInterval, repeats: false) { _ in
            print("SlideshowView: Timer fired - currentIndex: \(self.currentIndex), assets count: \(self.currentAssets.count) \(slideInterval)")
            if self.currentIndex < self.currentAssets.count - 1 {
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
        let actualNextIndex = nextIndex >= currentAssets.count ? 0 : nextIndex
        guard actualNextIndex < currentAssets.count else { return }
        
        let nextAsset = currentAssets[actualNextIndex]
        
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
                        // Extract and cache dominant color during preload asynchronously
                        if slideshowBackgroundColor == "auto" {
                            Task {
                                let color = await extractDominantColorAsync(from: image!)
                                await MainActor.run {
                                    self.preloadedDominantColors[nextAsset.id] = color
                                }
                            }
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
    
   private func extractDominantColorAsync(from image: UIImage) async -> Color {
    return await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cgImage = image.cgImage else {
                continuation.resume(returning: .black)
                return
            }

            // Resize image to 50x50 using Core Image
            let ciImage = CIImage(cgImage: cgImage)
            let scale = CGAffineTransform(scaleX: 50.0 / ciImage.extent.width, y: 50.0 / ciImage.extent.height)
            let resizedCIImage = ciImage.transformed(by: scale)

            let context = CIContext()
            guard let resizedCGImage = context.createCGImage(resizedCIImage, from: resizedCIImage.extent) else {
                continuation.resume(returning: .black)
                return
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
                continuation.resume(returning: .black)
                return
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
                continuation.resume(returning: .black)
                return
            }

            let r = Double((dominantColorKey >> 16) & 0xFF) / 255.0
            let g = Double((dominantColorKey >> 8) & 0xFF) / 255.0
            let b = Double(dominantColorKey & 0xFF) / 255.0

            // Adjust brightness for contrast (optional)
            let brightness = 0.299 * r + 0.587 * g + 0.114 * b
            let darkenFactor = brightness > 0.6 ? 0.6 : 1.0 // Darken only if it's too bright

            let color = Color(
                red: r * darkenFactor,
                green: g * darkenFactor,
                blue: b * darkenFactor
            )
            
            continuation.resume(returning: color)
        }
    }
}
    
    private func startKenBurnsEffect() {
        guard enableKenBurnsEffect else {
            // Reset to default values if Ken Burns is disabled
            kenBurnsScale = 1.0
            kenBurnsOffset = .zero
            return
        }
        
        // Generate random Ken Burns parameters
        let zoomDirections = [true, false] // true = zoom in, false = zoom out
        let shouldZoomIn = zoomDirections.randomElement() ?? true
        
        let startScale: CGFloat = shouldZoomIn ? 1.0 : 1.2
        let endScale: CGFloat = shouldZoomIn ? 1.2 : 1.0
        
        // Random pan direction
        let maxOffset: CGFloat = 20
        let startOffset = CGSize(
            width: CGFloat.random(in: -maxOffset...maxOffset),
            height: CGFloat.random(in: -maxOffset...maxOffset)
        )
        let endOffset = CGSize(
            width: CGFloat.random(in: -maxOffset...maxOffset),
            height: CGFloat.random(in: -maxOffset...maxOffset)
        )
        
        // Set initial values
        kenBurnsScale = startScale
        kenBurnsOffset = startOffset
        
        // Animate to end values over the slide duration
        withAnimation(.linear(duration: slideInterval)) {
            kenBurnsScale = endScale
            kenBurnsOffset = endOffset
        }
    }
    
    // MARK: - Asset Loading Methods
    
    private func loadInitialAssets() {
        isLoadingAssets = true
        loadAssetsTask = Task {
            do {
                let searchResult: SearchResult
                if enableShuffle {
                    // For shuffle mode, get initial random assets
                    searchResult = try await assetService.fetchRandomAssets(
                        albumIds: albumId != nil ? [albumId!] : nil,
                        personIds: personId != nil ? [personId!] : nil,
                        tagIds: tagId != nil ? [tagId!] : nil,
                        limit: 50
                    )
                } else {
                    // For normal mode, get paginated assets
                    searchResult = try await assetService.fetchAssets(
                        page: currentPage,
                        limit: 50,
                        albumId: albumId,
                        personId: personId,
                        tagId: tagId
                    )
                }
                
                // Check if task was cancelled
                try Task.checkCancellation()
                
                await MainActor.run {
                    let imageAssets = searchResult.assets.filter { $0.type == .image }
                    self.assets = imageAssets
                    self.hasMoreAssets = searchResult.nextPage != nil || enableShuffle // Always has more for shuffle
                    self.currentIndex = max(0, min(startingIndex, imageAssets.count - 1))
                    self.isLoadingAssets = false
                    
                    if !imageAssets.isEmpty {
                        self.loadCurrentImage()
                    } else {
                        print("SlideshowView: No image assets found")
                        self.isLoading = false
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    print("SlideshowView: Initial asset loading cancelled")
                    self.isLoading = false
                    self.isLoadingAssets = false
                }
            } catch {
                await MainActor.run {
                    print("SlideshowView: Failed to load initial assets: \(error)")
                    self.isLoading = false
                    self.isLoadingAssets = false
                }
            }
        }
    }
    
    private func loadMoreAssets() {
        // Prevent multiple simultaneous loads
        guard !isLoadingAssets else {
            print("SlideshowView: Already loading assets, skipping")
            return
        }
        
        isLoadingAssets = true
        loadAssetsTask?.cancel() // Cancel any existing task
        
        loadAssetsTask = Task {
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                let searchResult: SearchResult
                if enableShuffle {
                    // For shuffle mode, get more random assets
                    searchResult = try await assetService.fetchRandomAssets(
                        albumIds: albumId != nil ? [albumId!] : nil,
                        personIds: personId != nil ? [personId!] : nil,
                        tagIds: tagId != nil ? [tagId!] : nil,
                        limit: 50
                    )
                } else {
                    // For non-shuffle mode, get next page of sequential assets
                    await MainActor.run {
                        self.currentPage += 1
                    }
                    searchResult = try await assetService.fetchAssets(
                        page: currentPage,
                        limit: 50,
                        albumId: albumId,
                        personId: personId,
                        tagId: tagId
                    )
                }
                
                // Check if task was cancelled before updating UI
                try Task.checkCancellation()
                
                await MainActor.run {
                    let imageAssets = searchResult.assets.filter { $0.type == .image }
                    self.assets.append(contentsOf: imageAssets)
                    self.hasMoreAssets = searchResult.nextPage != nil || enableShuffle // Always has more for shuffle
                    self.isLoadingAssets = false
                    
                    // Start slide out animation, then continue with next image
                    withAnimation(.easeInOut(duration: slideAnimationDuration)) {
                        self.isTransitioning = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + slideAnimationDuration) {
                        // Check if view still exists before continuing
                        guard !Task.isCancelled else { return }
                        
                        let directions: [SlideDirection] = [.left, .right, .up, .down, .diagonal_up_left, .diagonal_up_right, .diagonal_down_left, .diagonal_down_right, .zoom_out]
                        self.slideDirection = directions.randomElement() ?? .right
                        self.currentIndex += 1
                        self.loadCurrentImage()
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    print("SlideshowView: Asset loading cancelled")
                    self.isLoadingAssets = false
                }
            } catch {
                await MainActor.run {
                    print("SlideshowView: Failed to load more assets: \(error)")
                    self.isLoadingAssets = false
                    // For shuffle mode, always try again; for sequential, mark as no more
                    self.hasMoreAssets = enableShuffle
                }
            }
        }
    }
    
    
}

#Preview {
    // Set the UserDefaults value before creating the view
    UserDefaults.standard.set("auto", forKey: "slideshowBackgroundColor")
    UserDefaults.standard.set("10", forKey: "slideshowInterval")
    UserDefaults.standard.set(true, forKey: "hideImageOverlay")
    UserDefaults.standard.set(true, forKey: "enableReflectionsInSlideshow")
    UserDefaults.standard.set(true, forKey: "enableKenBurnsEffect")
    let (_, _, assetService, _, _, _) = MockServiceFactory.createMockServices()
    
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
    
     return SlideshowView(albumId: nil, personId: nil, tagId: nil, assetService: assetService, startingIndex: 0)
}
