//
//  AssetProvider.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-08-19.
//

import Foundation

struct AssetProviderFactory {
    static func createProvider(
        albumId: String? = nil,
        personId: String? = nil,
        tagId: String? = nil,
        isAllPhotos: Bool = false,
        isFavorite: Bool = false,
        assetService: AssetService,
        albumService: AlbumService? = nil,
        config: SlideshowConfig? = nil
    ) -> AssetProvider {
        
        if let albumId = albumId, let albumService = albumService {
            return AlbumAssetProvider(albumService: albumService, assetService: assetService, albumId: albumId)
        } else {
            return GeneralAssetProvider(
                assetService: assetService,
                personId: personId,
                tagId: tagId,
                isAllPhotos: isAllPhotos,
                isFavorite: isFavorite,
                config: config
            )
        }
    }
}

protocol AssetProvider {
    func fetchAssets(page: Int, limit: Int) async throws -> SearchResult
    func fetchRandomAssets(limit: Int) async throws -> SearchResult
}

class AlbumAssetProvider: AssetProvider {
    private let albumService: AlbumService
    private let assetService: AssetService
    private let albumId: String
    private var cachedAlbum: ImmichAlbum?
    
    init(albumService: AlbumService, assetService: AssetService, albumId: String) {
        self.albumService = albumService
        self.assetService = assetService
        self.albumId = albumId
    }
    
    func fetchAssets(page: Int, limit: Int) async throws -> SearchResult {
        print("fetching assets")
        if page == 1 {
            let album = try await albumService.getAlbumInfo(albumId: albumId, withoutAssets: false)
            cachedAlbum = album
            
            let totalAssets = album.assets.count
            let endIndex = min(limit, totalAssets)
            let pageAssets = Array(album.assets.prefix(endIndex))
            
            let nextPage = totalAssets > limit ? "2" : nil
            return SearchResult(assets: pageAssets, total: album.assets.count, nextPage: nextPage)
        } else {
            guard let album = cachedAlbum else {
                let album = try await albumService.getAlbumInfo(albumId: albumId, withoutAssets: false)
                cachedAlbum = album
                return try await fetchAssets(page: page, limit: limit)
            }
            
            let startIndex = (page - 1) * limit
            let endIndex = min(startIndex + limit, album.assets.count)
            
            guard startIndex < album.assets.count else {
                return SearchResult(assets: [], total: album.assets.count, nextPage: nil)
            }
            
            let pageAssets = Array(album.assets[startIndex..<endIndex])
            let nextPage = endIndex < album.assets.count ? String(page + 1) : nil
            
            return SearchResult(assets: pageAssets, total: album.assets.count, nextPage: nextPage)
        }
    }
    
    func fetchRandomAssets(limit: Int) async throws -> SearchResult {
        return try await assetService.fetchRandomAssets(
            albumIds: [albumId],
            personIds: nil,
            tagIds: nil,
            limit: limit
        )
    }
}

class GeneralAssetProvider: AssetProvider {
    private let assetService: AssetService
    private let personId: String?
    private let tagId: String?
    private let isAllPhotos: Bool
    private let isFavorite: Bool
    private let config: SlideshowConfig?
    
    init(assetService: AssetService, personId: String? = nil, tagId: String? = nil, isAllPhotos: Bool = false, isFavorite: Bool = false, config: SlideshowConfig? = nil) {
        self.assetService = assetService
        self.personId = personId
        self.tagId = tagId
        self.isAllPhotos = isAllPhotos
        self.isFavorite = isFavorite
        self.config = config
    }
    
    func fetchAssets(page: Int, limit: Int) async throws -> SearchResult {
        // If config is provided, use it; otherwise fall back to individual parameters
        if let config = config {
            return try await assetService.fetchAssets(config: config, page: page, limit: limit, isAllPhotos: isAllPhotos)
        } else {
            return try await assetService.fetchAssets(
                page: page,
                limit: limit,
                albumId: nil,
                personId: personId,
                tagId: tagId,
                isAllPhotos: isAllPhotos,
                isFavorite: isFavorite
            )
        }
    }
    
    func fetchRandomAssets(limit: Int) async throws -> SearchResult {
        // If config is provided, use it; otherwise fall back to individual parameters
        if let config = config {
            return try await assetService.fetchRandomAssets(config: config, limit: limit)
        } else {
            return try await assetService.fetchRandomAssets(
                albumIds: nil,
                personIds: personId != nil ? [personId!] : nil,
                tagIds: tagId != nil ? [tagId!] : nil,
                limit: limit
            )
        }
    }
}

