//
//  ExifInfoOverlay.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

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