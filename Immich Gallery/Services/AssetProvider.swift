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
        city: String? = nil,
        isAllPhotos: Bool = false,
        isFavorite: Bool = false,
        folderPath: String? = nil,
        assetService: AssetService,
        albumService: AlbumService? = nil,
        config: SlideshowConfig? = nil
    ) -> AssetProvider {
        
        if let albumId = albumId, let albumService = albumService {
            return AlbumAssetProvider(albumService: albumService, albumId: albumId)
        } else {
            return GeneralAssetProvider(
                assetService: assetService,
                personId: personId,
                tagId: tagId,
                city: city,
                isAllPhotos: isAllPhotos,
                isFavorite: isFavorite,
                folderPath: folderPath,
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
    private let albumId: String
    private var cachedAssets: [ImmichAsset]?

    init(albumService: AlbumService, albumId: String) {
        self.albumService = albumService
        self.albumId = albumId
    }

    private func loadAlbumAssets() async throws -> [ImmichAsset] {
        if let cachedAssets {
            return cachedAssets
        }

        // Fetch the album with full asset list; Immich includes assets unless withoutAssets is true
        let album = try await albumService.getAlbumInfo(albumId: albumId, withoutAssets: false)
        cachedAssets = album.assets
        return album.assets
    }
    
    func fetchAssets(page: Int, limit: Int) async throws -> SearchResult {
        let assets = try await loadAlbumAssets()
        guard !assets.isEmpty else {
            return SearchResult(assets: [], total: 0, nextPage: nil)
        }

        let pageSize = max(limit, 1)
        let startIndex = max((page - 1) * pageSize, 0)
        let endIndex = min(startIndex + pageSize, assets.count)

        let pageAssets: [ImmichAsset]
        if startIndex < endIndex {
            pageAssets = Array(assets[startIndex..<endIndex])
        } else {
            pageAssets = []
        }

        let nextPage: String? = endIndex < assets.count ? String(page + 1) : nil

        return SearchResult(
            assets: pageAssets,
            total: assets.count,
            nextPage: nextPage
        )
    }
    
    func fetchRandomAssets(limit: Int) async throws -> SearchResult {
        let assets = try await loadAlbumAssets()
        guard !assets.isEmpty else {
            return SearchResult(assets: [], total: 0, nextPage: nil)
        }

        let sampleCount = min(limit, assets.count)
        let shuffledAssets = Array(assets.shuffled().prefix(sampleCount))

        return SearchResult(
            assets: shuffledAssets,
            total: assets.count,
            nextPage: nil
        )
    }
}

class GeneralAssetProvider: AssetProvider {
    private let assetService: AssetService
    private let personId: String?
    private let tagId: String?
    private let city: String?
    private let isAllPhotos: Bool
    private let isFavorite: Bool
    private let config: SlideshowConfig?
    private let folderPath: String?
    
    init(assetService: AssetService, personId: String? = nil, tagId: String? = nil, city: String? = nil, isAllPhotos: Bool = false, isFavorite: Bool = false, folderPath: String? = nil, config: SlideshowConfig? = nil) {
        self.assetService = assetService
        self.personId = personId
        self.tagId = tagId
        self.city = city
        self.isAllPhotos = isAllPhotos
        self.isFavorite = isFavorite
        self.config = config
        self.folderPath = folderPath
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
                city: city,
                isAllPhotos: isAllPhotos,
                isFavorite: isFavorite,
                folderPath: folderPath
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
                folderPath: folderPath,
                limit: limit
            )
        }
    }
}
