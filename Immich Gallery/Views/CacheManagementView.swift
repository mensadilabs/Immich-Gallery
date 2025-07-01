//
//  CacheManagementView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct CacheManagementView: View {
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @State private var showingClearCacheAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Cache Statistics") {
                    HStack {
                        Text("Memory Cache")
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(formatBytes(thumbnailCache.memoryCacheSize))
                                .font(.headline)
                            Text("\(thumbnailCache.memoryCacheCount) images")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Disk Cache")
                        Spacer()
                        Text(formatBytes(thumbnailCache.diskCacheSize))
                            .font(.headline)
                    }
                    
                    HStack {
                        Text("Total Cache")
                        Spacer()
                        Text(formatBytes(thumbnailCache.memoryCacheSize + thumbnailCache.diskCacheSize))
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                }
                
                Section("Cache Management") {
                    Button(action: {
                        showingClearCacheAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear All Cache")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Button(action: {
                        thumbnailCache.clearExpiredCache()
                    }) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.orange)
                            Text("Clear Expired Cache")
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Section("Cache Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Memory Cache Limit: \(formatBytes(100 * 1024 * 1024))")
                        Text("Disk Cache Limit: \(formatBytes(500 * 1024 * 1024))")
                        Text("Max Memory Images: 200")
                        Text("Cache Expiration: 7 days")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Cache Management")
            .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    thumbnailCache.clearAllCaches()
                }
            } message: {
                Text("This will remove all cached thumbnails from both memory and disk. Images will be re-downloaded when needed.")
            }
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#Preview {
    CacheManagementView()
} 