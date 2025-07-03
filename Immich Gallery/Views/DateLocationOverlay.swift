//
//  DateLocationOverlay.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct DateLocationOverlay: View {
    let asset: ImmichAsset
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {

            // People names
let nonEmptyNames = asset.people.map(\.name).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

if !nonEmptyNames.isEmpty {
    Text(nonEmptyNames.joined(separator: ", "))
        .font(.caption)
        .foregroundColor(.white)
        .padding(8)
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