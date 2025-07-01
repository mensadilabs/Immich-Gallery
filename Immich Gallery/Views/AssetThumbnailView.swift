//
//  AssetThumbnailView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct AssetThumbnailView: View {
    let asset: ImmichAsset
    @ObservedObject var immichService: ImmichService
    @State private var image: UIImage?
    @State private var isLoading = true
    let isFocused: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 320, height: 320)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 320, height: 320)
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
                        
                        // Video duration
                        if let duration = asset.duration, !duration.isEmpty {
                            HStack {
                                Spacer()
                                Text(formatVideoDuration(duration))
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(4)
                                    .padding(8)
                            }
                        }
                    }
                }
                
                // Text overlay at bottom right
                VStack(alignment: .trailing, spacing: 2) {                    
                    Text(formatDate(asset.fileCreatedAt))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.4))
                )
                .padding(8)
            }
            .shadow(color: .black.opacity(isFocused ? 0.5 : 0), radius: 15, y: 10)
        }
        .frame(width: 320)
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
    
    private func formatVideoDuration(_ durationString: String) -> String {
        // Parse duration string like "PT1M30S" (ISO 8601 duration format)
        let duration = durationString.replacingOccurrences(of: "PT", with: "")
        
        var minutes = 0
        var seconds = 0
        
        if let minuteRange = duration.range(of: "M") {
            let minuteString = String(duration[..<minuteRange.lowerBound])
            minutes = Int(minuteString) ?? 0
        }
        
        if let secondRange = duration.range(of: "S") {
            let secondString = String(duration[..<secondRange.lowerBound])
            seconds = Int(secondString) ?? 0
        }
        
        return String(format: "%d:%02d", minutes, seconds)
    }
} 