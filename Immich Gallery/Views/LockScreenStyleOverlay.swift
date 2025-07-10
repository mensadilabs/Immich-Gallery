//
//  LockScreenStyleOverlay.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI



// MARK: - LockScreenStyleOverlay View
struct LockScreenStyleOverlay: View {
    let asset: ImmichAsset
    let isSlideshowMode: Bool // Determines larger font sizes for slideshow
    
    @State private var currentTime = Date()
    @State private var timeUpdateTimer: Timer?
    
    init(asset: ImmichAsset, isSlideshowMode: Bool = false) {
        self.asset = asset
        self.isSlideshowMode = isSlideshowMode
    }
    
    var body: some View {

    
        VStack(alignment: .trailing, spacing: 24) { // Increased spacing for tvOS
            // MARK: - Clock and Date Display
                if isSlideshowMode {
            VStack(alignment: .trailing, spacing: 12) { // Increased spacing
                // Current time in large text
                Text(formatCurrentTime())
                    .font(.system(size: isSlideshowMode ? 100 : 48, weight: .light, design: .default)) // Larger sizes
                    .foregroundColor(.black)
                    .shadow(color: .white.opacity(0.6), radius: 6, x: 0, y: 3) // Slightly stronger shadow
                
                // Current date
                Text(formatCurrentDate())
                    .font(.system(size: isSlideshowMode ? 32 : 22, weight: .regular, design: .default)) // Larger sizes
                    .foregroundColor(.black.opacity(0.95))
                    .shadow(color: .white.opacity(0.6), radius: 6, x: 0, y: 3)
            }
            .padding(.horizontal, 32) // Increased padding
            .padding(.vertical, 24)    // Increased padding
            .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Material.ultraThin)
                                .opacity(0.5) // <--- Add this line to control transparency (0.8 for 80% opaque)
                                .overlay( // Make sure to re-add the overlay if it was removed
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
            .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 8) // Larger, softer shadow
                }
            
            Spacer() // Pushes content to the top (or bottom if this is the only spacer)
            
            VStack(alignment: .trailing, spacing: 0) { // This VStack will get the single background and shadow
                // MARK: - Group for internal padding (all text/HStacks inside this will share the padding)
                Group {
                    // MARK: - People names with elegant styling
                    let nonEmptyNames = asset.people.map(\.name).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    
                    if !nonEmptyNames.isEmpty {
                        Text(nonEmptyNames.joined(separator: ", "))
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    }

                    // MARK: - Location with elegant styling
                    if let location = getLocationString() {
                        HStack(spacing: 0) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.85))
                            Text(location)
                                .font(.system(size: 20, weight: .regular, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }

                    // MARK: - Date with elegant styling
                    HStack(spacing: 0) {
                        Image(systemName: "calendar")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.85))
                        Text(getDisplayDate())
                            .font(.system(size: 20, weight: .regular, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 24) 
                .padding(.vertical, 12)  
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Material.ultraThin) // Frosted glass for the entire group
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
        }
        .padding(40) // Overall padding for the entire overlay to push it in from edges
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing) // Align content to top right
        .onAppear {
            if isSlideshowMode {
                startTimeUpdate()
            }
        }
        .onDisappear {
            stopTimeUpdate()
        }
    }
    
    // MARK: - Logic Functions (Unchanged)
    private func getDisplayDate() -> String {
        if let dateTimeOriginal = asset.exifInfo?.dateTimeOriginal {
            return formatDisplayDate(dateTimeOriginal)
        } else {
            return formatDisplayDate(asset.fileCreatedAt)
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
        formatter.timeZone = TimeZone(abbreviation: "UTC") // Important for 'Z' suffix
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
    
    // MARK: - Time Management for Slideshow Mode (Unchanged logic)
    
    private func formatCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm" // 24-hour format typical for digital clocks
        return formatter.string(from: currentTime)
    }
    
    private func formatCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full // e.g., "Friday, July 5, 2025"
        formatter.timeStyle = .none
        return formatter.string(from: currentTime)
    }
    
    private func startTimeUpdate() {
        // Invalidate any existing timer first to prevent duplicates
        stopTimeUpdate() 
        // Update time immediately
        currentTime = Date()
        
        // Set up timer to update every second
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }
    
    private func stopTimeUpdate() {
        timeUpdateTimer?.invalidate()
        timeUpdateTimer = nil
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
