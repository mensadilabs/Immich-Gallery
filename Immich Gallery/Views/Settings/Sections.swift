//
//  CacheSection.swift
//  Immich Gallery
//
//  Created by Sanket Kumar on 2025-07-28.
//

import Foundation
import SwiftUI
// MARK: - Cache Section Component

struct CacheSection: View {
    @ObservedObject var thumbnailCache: ThumbnailCache
    @Binding var showingClearCacheAlert: Bool
    
    var body: some View {
        SettingsSection(title: "Cache") {
            AnyView(VStack(spacing: 16) {
                // Cache Actions
                HStack(spacing: 16) {
                    ActionButton(
                        icon: "clock.arrow.circlepath",
                        title: "Clear Expired",
                        color: .orange
                    ) {
                        thumbnailCache.clearExpiredCache()
                    }
                    
                    ActionButton(
                        icon: "trash",
                        title: "Clear All",
                        color: .red
                    ) {
                        showingClearCacheAlert = true
                    }
                }
                
                // Cache Information
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Usage")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Memory Cache")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatBytes(thumbnailCache.memoryCacheSize))
                                .font(.caption)
                                .foregroundColor(.primary)
                            Text("\(thumbnailCache.memoryCacheCount) images")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Disk Cache")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatBytes(thumbnailCache.diskCacheSize))
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("Total Cache")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(formatBytes(thumbnailCache.memoryCacheSize + thumbnailCache.diskCacheSize))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
                .padding(16)
                .background(Color.gray.opacity(0.03))
                .cornerRadius(12)
                
                // Cache Limits
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cache Limits")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Memory Limit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatBytes(100 * 1024 * 1024))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Disk Limit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatBytes(500 * 1024 * 1024))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Expiration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("7 days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
                .background(Color.gray.opacity(0.03))
                .cornerRadius(12)
            })
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct SettingsSection: View {
    let title: String
    let content: () -> AnyView
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                content()
            }
        }
    }
}


struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
