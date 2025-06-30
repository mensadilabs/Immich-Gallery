//
//  AssetGridView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct AssetGridView: View {
    @ObservedObject var immichService: ImmichService
    @State private var assets: [ImmichAsset] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedAsset: ImmichAsset?
    @State private var showingFullScreen = false
    @FocusState private var focusedAssetId: String?
    
    private let columns = [
        GridItem(.fixed(280), spacing: 20),
        GridItem(.fixed(280), spacing: 20),
        GridItem(.fixed(280), spacing: 20),
        GridItem(.fixed(280), spacing: 20),
        GridItem(.fixed(280), spacing: 20)
    ]
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView("Loading photos...")
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
                        loadAssets()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if assets.isEmpty {
                VStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No Photos Found")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("Your photos will appear here")
                        .foregroundColor(.gray)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(assets) { asset in
                            UIKitFocusable(action: {
                                print("Asset selected: \(asset.id)")
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
        .fullScreenCover(isPresented: $showingFullScreen) {
            if let selectedAsset = selectedAsset {
                FullScreenImageView(asset: selectedAsset, assets: assets, currentIndex: assets.firstIndex(of: selectedAsset) ?? 0, immichService: immichService)
            }
        }
        .onAppear {
            if assets.isEmpty {
                loadAssets()
            }
        }
    }
    
    private func loadAssets() {
        guard immichService.isAuthenticated else {
            errorMessage = "Not authenticated. Please check your credentials."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedAssets = try await immichService.fetchAssets(page: 1, limit: 100)
                await MainActor.run {
                    self.assets = fetchedAssets
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

struct AssetThumbnailView: View {
    let asset: ImmichAsset
    @ObservedObject var immichService: ImmichService
    @State private var image: UIImage?
    @State private var isLoading = true
    let isFocused: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 280, height: 280)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 280, height: 280)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
                
                // Video indicator
                if asset.type == .video {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                                .padding(8)
                        }
                        Spacer()
                    }
                }
            }
            .shadow(color: .black.opacity(isFocused ? 0.5 : 0), radius: 15, y: 10)
            
            // Asset info
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.originalFileName)
                    .font(.caption)
                    .foregroundColor(isFocused ? .white : .gray)
                    .lineLimit(1)
                
                Text(formatDate(asset.fileCreatedAt))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: 280, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .frame(width: 280)
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        Task {
            do {
                let thumbnail = try await immichService.loadImage(from: asset, size: "preview")
                await MainActor.run {
                    self.image = thumbnail
                    self.isLoading = false
                }
            } catch {
                print("Failed to load thumbnail for asset \(asset.id): \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

struct FullScreenImageView: View {
    let asset: ImmichAsset
    let assets: [ImmichAsset]
    let currentIndex: Int
    @ObservedObject var immichService: ImmichService
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var showingExifInfo = false
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
                                    .padding(.trailing, 20)
                                    .padding(.bottom, 20)
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
            
            // Top controls
            VStack {
                HStack {
                    Spacer()
                    
                    // EXIF Info toggle button
                    Button(action: {
                        showingExifInfo.toggle()
                    }) {
                        HStack {
                            Image(systemName: showingExifInfo ? "info.circle.fill" : "info.circle")
                                .font(.title2)
                            Text("Info")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(20)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .focusable()
                    .onTapGesture {
                        showingExifInfo.toggle()
                    }
                    
                }
                .padding()
                
                Spacer()
            }
            
            // EXIF Info overlay
            if showingExifInfo {
                VStack {
                    Spacer()
                    
                    ExifInfoOverlay(asset: currentAsset)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
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
            loadFullImage()
            if assets.count > 1 {
                showingSwipeHint = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showingSwipeHint = false
                    }
                }
            }
        }
        .onTapGesture {
            dismiss()
        }
        .animation(.easeInOut(duration: 0.3), value: showingExifInfo)
        .overlay(
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
        image = nil
        isLoading = true
        loadFullImage()
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

// UIKit wrapper for tvOS directional pad navigation using UITapGestureRecognizer
struct SwipeGestureView: UIViewRepresentable {
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        view.isUserInteractionEnabled = true
        
        print("SwipeGestureView: Creating UIView with user interaction enabled")
        
        // Try a simpler approach - just use basic tap gestures for all directions
        let leftGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLeft))
        leftGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue)]
        view.addGestureRecognizer(leftGesture)
        print("SwipeGestureView: Added LEFT gesture recognizer")
        
        let rightGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRight))
        rightGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.rightArrow.rawValue)]
        view.addGestureRecognizer(rightGesture)
        print("SwipeGestureView: Added RIGHT gesture recognizer")
        
        // Add swipe gestures for touchpad
        let leftSwipe = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLeft))
        leftSwipe.direction = .left
        view.addGestureRecognizer(leftSwipe)
        print("SwipeGestureView: Added LEFT swipe gesture recognizer")
        
        let rightSwipe = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRight))
        rightSwipe.direction = .right
        view.addGestureRecognizer(rightSwipe)
        print("SwipeGestureView: Added RIGHT swipe gesture recognizer")
        
        // Test tap gesture
        let testTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.testTap))
        view.addGestureRecognizer(testTap)
        print("SwipeGestureView: Added test tap gesture recognizer")
        
        print("SwipeGestureView: All gesture recognizers added for tvOS navigation")
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onSwipeLeft: onSwipeLeft, onSwipeRight: onSwipeRight)
    }
    
    class Coordinator: NSObject {
        let onSwipeLeft: () -> Void
        let onSwipeRight: () -> Void
        
        init(onSwipeLeft: @escaping () -> Void, onSwipeRight: @escaping () -> Void) {
            self.onSwipeLeft = onSwipeLeft
            self.onSwipeRight = onSwipeRight
            print("SwipeGestureView.Coordinator: Initialized with navigation callbacks")
        }
        
        @objc func handleLeft(_ gesture: UIGestureRecognizer) {
            print("SwipeGestureView: LEFT gesture detected (type: \(type(of: gesture))) - navigating to next photo")
            onSwipeLeft()
        }
        
        @objc func handleRight(_ gesture: UIGestureRecognizer) {
            print("SwipeGestureView: RIGHT gesture detected (type: \(type(of: gesture))) - navigating to previous photo")
            onSwipeRight()
        }
        
        @objc func testTap(_ gesture: UITapGestureRecognizer) {
            print("SwipeGestureView: Test tap detected - view is receiving touch events!")
        }
    }
}

struct ExifInfoOverlay: View {
    let asset: ImmichAsset
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Photo Information")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.bottom, 4)
            
            // Date and time
            if let dateTimeOriginal = asset.exifInfo?.dateTimeOriginal {
                InfoRow(label: "Date", value: formatDateTime(dateTimeOriginal))
            } else {
                InfoRow(label: "Date", value: formatDate(asset.fileCreatedAt))
            }
            
            // Camera info
            if let make = asset.exifInfo?.make, let model = asset.exifInfo?.model {
                InfoRow(label: "Camera", value: "\(make) \(model)")
            }
            
            // Lens info
            if let lensModel = asset.exifInfo?.lensModel {
                InfoRow(label: "Lens", value: lensModel)
            }
            
            // Technical details
            HStack(spacing: 20) {
                if let fNumber = asset.exifInfo?.fNumber {
                    InfoRow(label: "f/", value: String(format: "%.1f", fNumber))
                }
                
                if let focalLength = asset.exifInfo?.focalLength {
                    InfoRow(label: "Focal Length", value: "\(Int(focalLength))mm")
                }
                
                if let iso = asset.exifInfo?.iso {
                    InfoRow(label: "ISO", value: "\(iso)")
                }
                
                if let exposureTime = asset.exifInfo?.exposureTime {
                    InfoRow(label: "Exposure", value: exposureTime)
                }
            }
            
            // Resolution
            if let width = asset.exifInfo?.exifImageWidth, let height = asset.exifInfo?.exifImageHeight {
                InfoRow(label: "Resolution", value: "\(width) × \(height)")
            }
            
            // Location
            if let city = asset.exifInfo?.city, let state = asset.exifInfo?.state, let country = asset.exifInfo?.country {
                InfoRow(label: "Location", value: "\(city), \(state), \(country)")
            } else if let city = asset.exifInfo?.city, let country = asset.exifInfo?.country {
                InfoRow(label: "Location", value: "\(city), \(country)")
            } else if let country = asset.exifInfo?.country {
                InfoRow(label: "Location", value: country)
            }
            
            // File info
            if let fileSize = asset.exifInfo?.fileSizeInByte {
                InfoRow(label: "File Size", value: formatFileSize(fileSize))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
    
    private func formatDateTime(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .long
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .long
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

struct DateLocationOverlay: View {
    let asset: ImmichAsset
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Date
            if let dateTimeOriginal = asset.exifInfo?.dateTimeOriginal {
                Text(formatDisplayDate(dateTimeOriginal))
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
            } else {
                Text(formatDisplayDate(asset.fileCreatedAt))
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
            }
            
            // Location
            if let location = getLocationString() {
                Text(location)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
            }
            

            // Location
            if let name = asset.people.first?.name {
                Text(name)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
            }
        }
    }
    
    private func formatDisplayDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        
        // Try EXIF date format first
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        // Try ISO date format
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
    
    private func getLocationString() -> String? {
        if let city = asset.exifInfo?.city, let state = asset.exifInfo?.state, let country = asset.exifInfo?.country {
            return "\(city), \(state), \(country)"
        } else if let city = asset.exifInfo?.city, let country = asset.exifInfo?.country {
            return "\(city), \(country)"
        } else if let country = asset.exifInfo?.country {
            return country
        }
        return nil
    }
}
