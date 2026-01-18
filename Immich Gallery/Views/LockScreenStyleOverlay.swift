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
    let isSlideshowMode: Bool
    
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
        VStack(alignment: .trailing, spacing: 24) {
            // MARK: - Clock and Date Display
            if isSlideshowMode {
                VStack(alignment: .trailing, spacing: 12) {
                    // Current time in large text
                    Text(formatCurrentTime())
                        .font(.system(size: isSlideshowMode ? 100 : 48, weight: .light, design: .default))
                        .foregroundColor(.black)
                        .shadow(color: .white.opacity(0.6), radius: 6, x: 0, y: 3)
                    
                    // Current date
                    Text(formatCurrentDate())
                        .font(.system(size: isSlideshowMode ? 32 : 22, weight: .regular, design: .default))
                        .foregroundColor(.black.opacity(0.95))
                        .shadow(color: .white.opacity(0.6), radius: 6, x: 0, y: 3)
                }
                .padding(.horizontal, 48)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.6)))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 0) {
                Group {
                    // People names
                    let nonEmptyNames = asset.people.map(\.name).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    
                    if !nonEmptyNames.isEmpty {
                        Text(nonEmptyNames.joined(separator: ", "))
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    // Location
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
                    
                    // Date
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
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        return formatter.string(from: currentTime)
    }
    
    private func startTimeUpdate() {
        stopTimeUpdate()
        currentTime = Date()
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }
    
    private func stopTimeUpdate() {
        timeUpdateTimer?.invalidate()
        timeUpdateTimer = nil
    }
}

