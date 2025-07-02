//
//  CacheManagementView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct CacheManagementView: View {
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @ObservedObject var immichService: ImmichService
    @State private var showingClearCacheAlert = false
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.3),
                        Color.purple.opacity(0.2),
                        Color.gray.opacity(0.4)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Account Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Account")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            if let user = immichService.currentUser {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(user.name)
                                            .font(.headline)
                                        Text(user.email)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding()
                                
                                .cornerRadius(12)
                                
                                HStack {
                                    Image(systemName: "server.rack")
                                        .foregroundColor(.green)
                                    Text("Server")
                                    Spacer()
                                    Text(immichService.baseURL)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                showingSignOutAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .foregroundColor(.red)
                                    Text("Sign Out")
                                        .foregroundColor(.red)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Cache Management Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Cache Management")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Button(action: {
                                showingClearCacheAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                    Text("Clear All Cache")
                                        .foregroundColor(.red)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
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
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Cache Information Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Cache Information")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                // Cache Limits
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Cache Limits")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    HStack {
                                        Text("Memory Cache Limit")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(formatBytes(100 * 1024 * 1024))
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    HStack {
                                        Text("Disk Cache Limit")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(formatBytes(500 * 1024 * 1024))
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    HStack {
                                        Text("Max Memory Images")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("200")
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    HStack {
                                        Text("Cache Expiration")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("7 days")
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                    }
                                }
                                
                                Divider()
                                
                                // Current Usage
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Current Usage")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
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
                            }
                            .padding()
                            
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
        }
        .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    thumbnailCache.clearAllCaches()
                }
            } message: {
                Text("This will remove all cached thumbnails from both memory and disk. Images will be re-downloaded when needed.")
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    immichService.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out? You'll need to sign in again to access your photos.")
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
    CacheManagementView(immichService: ImmichService())
} 
