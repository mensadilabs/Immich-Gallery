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
                FullScreenImageView(asset: selectedAsset, immichService: immichService)
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
    @ObservedObject var immichService: ImmichService
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var showingExifInfo = false
    
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
                    // .padding()
                    .overlay(
                        // Date and location overlay in bottom right
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                DateLocationOverlay(asset: asset)
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
                    
                    ExifInfoOverlay(asset: asset)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            loadFullImage()
        }
        .onTapGesture {
            dismiss()
        }
        .animation(.easeInOut(duration: 0.3), value: showingExifInfo)
    }
    
    private func loadFullImage() {
        Task {
            do {
                let fullImage = try await immichService.loadFullImage(from: asset)
                await MainActor.run {
                    self.image = fullImage
                    self.isLoading = false
                }
            } catch {
                print("Failed to load full image for asset \(asset.id): \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
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

#Preview {
    AssetGridView(immichService: ImmichService())
}

#Preview("FullScreenImageView") {
    // Create a mock asset for preview
    let mockAsset = ImmichAsset(
        id: "preview-asset-1",
        deviceAssetId: "preview-device-1",
        deviceId: "preview-device",
        ownerId: "preview-owner",
        libraryId: nil,
        type: .image,
        originalPath: "/preview/image.jpg",
        originalFileName: "preview-image.jpg",
        originalMimeType: "image/jpeg",
        resized: false,
        thumbhash: nil,
        fileModifiedAt: "2024-01-01T12:00:00.000Z",
        fileCreatedAt: "2024-01-01T12:00:00.000Z",
        localDateTime: "2024-01-01T12:00:00.000Z",
        updatedAt: "2024-01-01T12:00:00.000Z",
        isFavorite: false,
        isArchived: false,
        isOffline: false,
        isTrashed: false,
        checksum: "preview-checksum",
        duration: nil,
        hasMetadata: true,
        livePhotoVideoId: nil,
        people: [],
        visibility: "VISIBLE",
        duplicateId: nil,
        exifInfo: ExifInfo(
            make: "Apple",
            model: "iPhone 15 Pro",
            imageName: "IMG_1234",
            exifImageWidth: 4032,
            exifImageHeight: 3024,
            dateTimeOriginal: "2024:01:01 12:00:00",
            modifyDate: "2024:01:01 12:00:00",
            lensModel: "iPhone 15 Pro back triple camera 6.86mm f/1.78",
            fNumber: 1.78,
            focalLength: 6.86,
            iso: 100,
            exposureTime: "1/120",
            latitude: 37.7749,
            longitude: -122.4194,
            city: "San Francisco",
            state: "California",
            country: "United States",
            timeZone: "America/Los_Angeles",
            description: "A beautiful sunset",
            fileSizeInByte: 5242880,
            orientation: "1",
            projectionType: nil,
            rating: 5
        )
    )
    
    // Create a mock service that loads a free image
    let mockService = ImmichService()
    
    return FullScreenImageView(asset: mockAsset, immichService: mockService)
} 
