//
//  ThumbnailCache.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import Foundation
import UIKit

class ThumbnailCache: NSObject, ObservableObject {
    static let shared = ThumbnailCache()
    
    // MARK: - Cache Configuration
    private let maxMemoryCacheSize = 100 * 1024 * 1024 // 100MB memory cache
    private let maxDiskCacheSize = 500 * 1024 * 1024 // 500MB disk cache
    private let maxMemoryCacheCount = 200 // Maximum number of images in memory
    private let cacheDirectoryName = "ThumbnailCache"
    
    // MARK: - Cache Storage
    private var memoryCache = NSCache<NSString, CachedImage>()
    private let diskCacheQueue = DispatchQueue(label: "com.immich.thumbnailcache.disk", qos: .utility)
    private let cacheDirectory: URL
    
    // MARK: - Cache Statistics
    @Published var memoryCacheSize: Int = 0
    @Published var diskCacheSize: Int = 0
    @Published var memoryCacheCount: Int = 0
    
    private override init() {
        // Setup disk cache directory first - use caches directory instead of documents
        let cachesPath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesPath.appendingPathComponent(cacheDirectoryName)
        
        super.init()
        
        // Configure memory cache
        memoryCache.totalCostLimit = maxMemoryCacheSize
        memoryCache.countLimit = maxMemoryCacheCount
        memoryCache.delegate = self
        
        // Create cache directory if it doesn't exist
        do {
            if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
                try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
                print("📁 Created cache directory: \(cacheDirectory.path)")
            } else {
                print("📁 Cache directory already exists: \(cacheDirectory.path)")
            }
            
            // Verify directory is writable
            let isWritable = FileManager.default.isWritableFile(atPath: cacheDirectory.path)
            print("📁 Directory is writable: \(isWritable)")
        } catch {
            print("❌ Failed to create cache directory: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
        }
        
        // Load initial disk cache size
        calculateDiskCacheSize()
        
        // Memory cache statistics will be updated as objects are added/removed
    }
    
    // MARK: - Public Methods
    
    /// Get thumbnail from cache or load from server
    func getThumbnail(for assetId: String, size: String = "preview", loadFromServer: @escaping () async throws -> UIImage?) async throws -> UIImage? {
        let cacheKey = cacheKey(for: assetId, size: size)
        
        print("🔍 Looking for thumbnail: \(cacheKey)")
        
        // Check memory cache first
        if let cachedImage = memoryCache.object(forKey: cacheKey as NSString) {
            print("⚡ Memory cache hit: \(cacheKey)")
            return cachedImage.image
        }
        
        // Check disk cache
        if let diskImage = await loadFromDisk(cacheKey: cacheKey) {
            print("💾 Disk cache hit: \(cacheKey)")
            // Store in memory cache
            let cachedImage = CachedImage(image: diskImage, size: diskImage.jpegData(compressionQuality: 0.8)?.count ?? 0)
            memoryCache.setObject(cachedImage, forKey: cacheKey as NSString, cost: cachedImage.size)
            
            // Update memory cache statistics
            DispatchQueue.main.async {
                self.memoryCacheSize += cachedImage.size
                self.memoryCacheCount += 1
            }
            return diskImage
        }
        
        print("🌐 Loading from server: \(cacheKey)")
        // Load from server
        guard let serverImage = try await loadFromServer() else {
            print("❌ Failed to load from server: \(cacheKey)")
            return nil
        }
        
        print("💾 Caching new image: \(cacheKey)")
        // Cache the image
        await cacheImage(serverImage, for: cacheKey)
        
        return serverImage
    }
    
    /// Preload thumbnails for better performance
    func preloadThumbnails(for assets: [ImmichAsset], size: String = "preview") {
        Task {
            for asset in assets {
                let cacheKey = cacheKey(for: asset.id, size: size)
                
                // Skip if already in memory cache
                if memoryCache.object(forKey: cacheKey as NSString) != nil {
                    continue
                }
                
                // Skip if already on disk
                if await isCachedOnDisk(cacheKey: cacheKey) {
                    continue
                }
                
                // Preload in background
                Task.detached(priority: .background) {
                    do {
                        // This will be implemented to call the actual server loading
                        // For now, we'll just check if it's already cached
                        if await self.isCachedOnDisk(cacheKey: cacheKey) {
                            return
                        }
                    } catch {
                        print("Failed to preload thumbnail for asset \(asset.id): \(error)")
                    }
                }
            }
        }
    }
    
    /// Clear all caches
    func clearAllCaches() {
        // Clear memory cache
        memoryCache.removeAllObjects()
        
        // Reset memory cache statistics
        DispatchQueue.main.async {
            self.memoryCacheSize = 0
            self.memoryCacheCount = 0
        }
        
        // Clear disk cache
        diskCacheQueue.async {
            try? FileManager.default.removeItem(at: self.cacheDirectory)
            try? FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
            self.calculateDiskCacheSize()
        }
        
        // Force refresh statistics
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshCacheStatistics()
        }
    }
    
    /// Clear expired cache entries
    func clearExpiredCache() {
        diskCacheQueue.async {
            self.removeExpiredCacheEntries()
        }
        
        // Force refresh statistics after clearing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshCacheStatistics()
        }
    }
    
    /// Refresh cache statistics (call this to update the UI)
    func refreshCacheStatistics() {
        calculateDiskCacheSize()
        updateMemoryCacheStatistics()
    }
    
    // MARK: - Private Methods
    
    private func cacheKey(for assetId: String, size: String) -> String {
        return "\(assetId)_\(size).jpg"
    }
    
    private func cacheImage(_ image: UIImage, for cacheKey: String) async {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        let cachedImage = CachedImage(image: image, size: imageData.count)
        
        // Store in memory cache
        memoryCache.setObject(cachedImage, forKey: cacheKey as NSString, cost: cachedImage.size)
        
        // Update memory cache statistics
        DispatchQueue.main.async {
            self.memoryCacheSize += cachedImage.size
            self.memoryCacheCount += 1
        }
        
        // Store on disk
        await storeOnDisk(imageData: imageData, cacheKey: cacheKey)
    }
    
    private func loadFromDisk(cacheKey: String) async -> UIImage? {
        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            diskCacheQueue.async {
                // Ensure directory exists before checking for files
                self.ensureCacheDirectoryExists()
                
                let fileURL = self.cacheDirectory.appendingPathComponent(cacheKey)
                
                guard FileManager.default.fileExists(atPath: fileURL.path),
                      let imageData = try? Data(contentsOf: fileURL),
                      let image = UIImage(data: imageData) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                continuation.resume(returning: image)
            }
        }
    }
    
    private func storeOnDisk(imageData: Data, cacheKey: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            diskCacheQueue.async {
                // Ensure directory exists before writing
                self.ensureCacheDirectoryExists()
                
                let fileURL = self.cacheDirectory.appendingPathComponent(cacheKey)
                
                // Check if directory exists and is writable
                let directoryExists = FileManager.default.fileExists(atPath: self.cacheDirectory.path)
                let isWritable = FileManager.default.isWritableFile(atPath: self.cacheDirectory.path)
                print("📁 Directory exists: \(directoryExists), writable: \(isWritable)")
                print("📁 Writing to: \(fileURL.path)")
                
                do {
                    try imageData.write(to: fileURL)
                    print("✅ Cached thumbnail to disk: \(cacheKey) (\(imageData.count) bytes)")
                    print("📊 Cache directory now contains: \(try? FileManager.default.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil).count ?? 0) files")
                    self.calculateDiskCacheSize()
                    
                    // Check if we need to clean up old files
                    if self.diskCacheSize > self.maxDiskCacheSize {
                        self.cleanupDiskCache()
                    }
                } catch {
                    print("❌ Failed to store thumbnail on disk: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                }
                
                continuation.resume()
            }
        }
    }
    
    private func isCachedOnDisk(cacheKey: String) async -> Bool {
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            diskCacheQueue.async {
                // Ensure directory exists before checking for files
                self.ensureCacheDirectoryExists()
                
                let fileURL = self.cacheDirectory.appendingPathComponent(cacheKey)
                let exists = FileManager.default.fileExists(atPath: fileURL.path)
                continuation.resume(returning: exists)
            }
        }
    }
    
    private func calculateDiskCacheSize() {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            let totalSize = fileURLs.reduce(0) { total, url in
                let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return total + fileSize
            }
            
            print("📊 Disk cache calculation: \(fileURLs.count) files, \(totalSize) bytes")
            print("📊 Cache directory: \(cacheDirectory.path)")
            
            DispatchQueue.main.async {
                self.diskCacheSize = totalSize
                print("📊 Updated disk cache size: \(self.diskCacheSize) bytes")
            }
        } catch {
            print("❌ Failed to calculate disk cache size: \(error)")
            print("❌ Cache directory: \(cacheDirectory.path)")
            print("❌ Error details: \(error.localizedDescription)")
        }
    }
    
    private func cleanupDiskCache() {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            
            // Sort files by creation date (oldest first)
            let sortedFiles = fileURLs.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 < date2
            }
            
            var currentSize = diskCacheSize
            
            for fileURL in sortedFiles {
                if currentSize <= maxDiskCacheSize {
                    break
                }
                
                let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                try? FileManager.default.removeItem(at: fileURL)
                currentSize -= fileSize
            }
            
            DispatchQueue.main.async {
                self.diskCacheSize = currentSize
            }
        } catch {
            print("Failed to cleanup disk cache: \(error)")
        }
    }
    
    private func removeExpiredCacheEntries() {
        let expirationDate = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            for fileURL in fileURLs {
                if let creationDate = try? fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < expirationDate {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
            
            calculateDiskCacheSize()
        } catch {
            print("Failed to remove expired cache entries: \(error)")
        }
    }
    
    private func updateMemoryCacheStatistics() {
        // Calculate actual memory cache statistics from the NSCache
        var totalSize = 0
        var count = 0
        
        // Note: NSCache doesn't provide direct access to all objects, so we'll use our tracking
        // but also recalculate disk cache size periodically
        DispatchQueue.main.async {
            // Only log if there are significant changes or for debugging
            if self.memoryCacheSize > 0 || self.memoryCacheCount > 0 {
                print("📊 Memory cache stats - Size: \(self.memoryCacheSize), Count: \(self.memoryCacheCount)")
            }
        }
        
        // Recalculate disk cache size periodically
        calculateDiskCacheSize()
    }
    
    private func ensureCacheDirectoryExists() {
        if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
                print("📁 Created cache directory: \(cacheDirectory.path)")
            } catch {
                print("❌ Failed to create cache directory: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - CachedImage Class
class CachedImage {
    let image: UIImage
    let size: Int
    let timestamp: Date
    
    init(image: UIImage, size: Int) {
        self.image = image
        self.size = size
        self.timestamp = Date()
    }
}

// MARK: - NSCacheDelegate
extension ThumbnailCache: NSCacheDelegate {
    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        if let cachedImage = obj as? CachedImage {
            DispatchQueue.main.async {
                self.memoryCacheSize -= cachedImage.size
                self.memoryCacheCount -= 1
            }
        }
    }
} 