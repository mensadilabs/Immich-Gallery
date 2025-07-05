//
//  LockScreenStyleOverlay.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct LockScreenStyleOverlay: View {
    let asset: ImmichAsset
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            // People names with elegant styling
            let nonEmptyNames = asset.people.map(\.name).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            
            if !nonEmptyNames.isEmpty {
                Text(nonEmptyNames.joined(separator: ", "))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.4))
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            }

            // Location with elegant styling
            if let location = getLocationString() {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                    Text(location)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.4))
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            }

            // Date with elegant styling
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                Text(getDisplayDate())
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.4))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
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