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
        assetService: AssetService,
        albumService: AlbumService? = nil
    ) -> AssetProvider {
        
        if let albumId = albumId, let albumService = albumService {
            return AlbumAssetProvider(albumService: albumService, albumId: albumId)
        } else {
            return GeneralAssetProvider(
                assetService: assetService,
                personId: personId,
                tagId: tagId,
                isAllPhotos: isAllPhotos
            )
        }
    }
}

protocol AssetProvider {
    func fetchAssets(page: Int, limit: Int) async throws -> SearchResult
}

class AlbumAssetProvider: AssetProvider {
    private let albumService: AlbumService
    private let albumId: String
    private var cachedAlbum: ImmichAlbum?
    
    init(albumService: AlbumService, albumId: String) {
        self.albumService = albumService
        self.albumId = albumId
    }
    
    func fetchAssets(page: Int, limit: Int) async throws -> SearchResult {
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
}

class GeneralAssetProvider: AssetProvider {
    private let assetService: AssetService
    private let personId: String?
    private let tagId: String?
    private let isAllPhotos: Bool
    
    init(assetService: AssetService, personId: String? = nil, tagId: String? = nil, isAllPhotos: Bool = false) {
        self.assetService = assetService
        self.personId = personId
        self.tagId = tagId
        self.isAllPhotos = isAllPhotos
    }
    
    func fetchAssets(page: Int, limit: Int) async throws -> SearchResult {
        return try await assetService.fetchAssets(
            page: page,
            limit: limit,
            albumId: nil,
            personId: personId,
            tagId: tagId,
            isAllPhotos: isAllPhotos
        )
    }
}