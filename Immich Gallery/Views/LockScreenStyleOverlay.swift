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
    
    @AppStorage("timeZone") private var timeZoneIdentifier: String = TimeZone.current.identifier
    
    private var use24HourClock: Bool {
        UserDefaults.standard.bool(forKey: "use24HourClock")
    }
    
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
                .padding(.horizontal, 48)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.6)))
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
                    let assetDate = asset.exifInfo?.dateTimeOriginal ?? asset.fileCreatedAt
                    HStack(spacing: 0) {
                        Image(systemName: "calendar")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.85))
                        Text(TimeZoneService.convertToLocalTime(
                            isoString: assetDate,
                            timeZoneIdentifier: timeZoneIdentifier,
                            format: use24HourClock ? "yyyy-MM-dd HH:mm" : "yyyy-MM-dd h:mm a"
                        ))
                        .font(.system(size: 20, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.6)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .onAppear { if isSlideshowMode { startTimeUpdate() } }
        .onDisappear { stopTimeUpdate() }
    }
    
    // MARK: - Helpers
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
    
    // MARK: - Time Management for Slideshow Mode
    private func formatCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = use24HourClock ? "HH:mm" : "h:mm a"
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        return formatter.string(from: currentTime)
    }
    
    private func formatCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full // e.g., "Friday, July 5, 2025"
        formatter.timeStyle = .none
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
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
    let (_, _, _, assetService, _, _, _, _) = MockServiceFactory.createMockServices()

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

    SlideshowView(albumId: nil, personId: nil, tagId: nil, startingIndex: 0, isFavorite: false)
}
