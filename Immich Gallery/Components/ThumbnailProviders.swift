//
//  ThumbnailProviders.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-09-04.
//

import SwiftUI

// MARK: - Album Thumbnail Provider
class AlbumThumbnailProvider: ThumbnailProvider {
    private let albumService: AlbumService
    private let assetService: AssetService
    private let thumbnailCache = ThumbnailCache.shared
    
    init(albumService: AlbumService, assetService: AssetService) {
        self.albumService = albumService
        self.assetService = assetService
    }
    
    func loadThumbnails(for item: GridDisplayable) async -> [UIImage] {
        guard let album = item as? ImmichAlbum else { return [] }
        
        if shouldUseStaticThumbnail(),
           let staticThumbnail = await loadStaticThumbnail(for: album) {
            return [staticThumbnail]
        }
        
        return await loadAnimatedThumbnails(for: album)
    }
    
    private func shouldUseStaticThumbnail() -> Bool {
        return !UserDefaults.standard.enableThumbnailAnimation
    }
    
    private func loadStaticThumbnail(for album: ImmichAlbum) async -> UIImage? {
        guard let thumbnailId = album.albumThumbnailAssetId, !thumbnailId.isEmpty else {
            return nil
        }
        
        do {
            return try await thumbnailCache.getThumbnail(for: thumbnailId, size: "thumbnail") {
                try await self.assetService.loadImage(assetId: thumbnailId, size: "thumbnail")
            }
        } catch {
            print("Failed to load static thumbnail for album \(album.id): \(error)")
            return nil
        }
    }
    
    private func loadAnimatedThumbnails(for album: ImmichAlbum) async -> [UIImage] {
        do {
            let albumProvider = AlbumAssetProvider(albumService: albumService, albumId: album.id)
            let searchResult = try await albumProvider.fetchAssets(page: 1, limit: 10)
            let imageAssets = searchResult.assets.filter { $0.type == .image }
            
            var loadedThumbnails: [UIImage] = []
            
            for asset in imageAssets.prefix(10) {
                do {
                    let thumbnail = try await thumbnailCache.getThumbnail(for: asset.id, size: "thumbnail") {
                        try await self.assetService.loadImage(assetId: asset.id, size: "thumbnail")
                    }
                    if let thumbnail = thumbnail {
                        loadedThumbnails.append(thumbnail)
                    }
                } catch {
                    print("Failed to load thumbnail for asset \(asset.id): \(error)")
                }
            }
            
            return loadedThumbnails
        } catch {
            print("Failed to fetch assets for album \(album.id): \(error)")
            return []
        }
    }
}

// MARK: - People Thumbnail Provider
class PeopleThumbnailProvider: ThumbnailProvider {
    private let assetService: AssetService
    private let thumbnailCache = ThumbnailCache.shared
    
    init(assetService: AssetService) {
        self.assetService = assetService
    }
    
    func loadThumbnails(for item: GridDisplayable) async -> [UIImage] {
        guard let person = item as? Person else { return [] }
        
        do {
            let searchResult = try await assetService.fetchAssets(page: 1, limit: 10, personId: person.id)
            let imageAssets = searchResult.assets.filter { $0.type == .image }
            
            var loadedThumbnails: [UIImage] = []
            
            for asset in imageAssets.prefix(10) {
                do {
                    let thumbnail = try await thumbnailCache.getThumbnail(for: asset.id, size: "thumbnail") {
                        try await self.assetService.loadImage(assetId: asset.id, size: "thumbnail")
                    }
                    if let thumbnail = thumbnail {
                        loadedThumbnails.append(thumbnail)
                    }
                } catch {
                    print("Failed to load thumbnail for asset \(asset.id): \(error)")
                }
            }
            
            return loadedThumbnails
        } catch {
            print("Failed to fetch assets for person \(person.id): \(error)")
            return []
        }
    }
}

// MARK: - Tag Thumbnail Provider
class TagThumbnailProvider: ThumbnailProvider {
    private let assetService: AssetService
    private let thumbnailCache = ThumbnailCache.shared
    
    init(assetService: AssetService) {
        self.assetService = assetService
    }
    
    func loadThumbnails(for item: GridDisplayable) async -> [UIImage] {
        guard let tag = item as? Tag else { return [] }
        
        do {
            let searchResult = try await assetService.fetchAssets(page: 1, limit: 10, tagId: tag.id)
            let imageAssets = searchResult.assets.filter { $0.type == .image }
            
            var loadedThumbnails: [UIImage] = []
            
            for asset in imageAssets.prefix(10) {
                do {
                    let thumbnail = try await thumbnailCache.getThumbnail(for: asset.id, size: "thumbnail") {
                        try await self.assetService.loadImage(assetId: asset.id, size: "thumbnail")
                    }
                    if let thumbnail = thumbnail {
                        loadedThumbnails.append(thumbnail)
                    }
                } catch {
                    print("Failed to load thumbnail for asset \(asset.id): \(error)")
                }
            }
            
            return loadedThumbnails
        } catch {
            print("Failed to fetch assets for tag \(tag.id): \(error)")
            return []
        }
    }
}

// MARK: - Folder Thumbnail Provider
class FolderThumbnailProvider: ThumbnailProvider {
    private let assetService: AssetService
    private let thumbnailCache = ThumbnailCache.shared
    
    init(assetService: AssetService) {
        self.assetService = assetService
    }
    
    func loadThumbnails(for item: GridDisplayable) async -> [UIImage] {
        guard let folder = item as? ImmichFolder else { return [] }
        
        do {
            let searchResult = try await assetService.fetchAssets(page: 1, limit: 10, folderPath: folder.path)
            let imageAssets = searchResult.assets.filter { $0.type == .image }
            
            var loadedThumbnails: [UIImage] = []
            
            for asset in imageAssets.prefix(10) {
                do {
                    let thumbnail = try await thumbnailCache.getThumbnail(for: asset.id, size: "thumbnail") {
                        try await self.assetService.loadImage(assetId: asset.id, size: "thumbnail")
                    }
                    if let thumbnail = thumbnail {
                        loadedThumbnails.append(thumbnail)
                    }
                } catch {
                    print("Failed to load thumbnail for asset \(asset.id): \(error)")
                }
            }
            
            return loadedThumbnails
        } catch {
            print("Failed to fetch assets for folder \(folder.path): \(error)")
            return []
        }
    }
}
