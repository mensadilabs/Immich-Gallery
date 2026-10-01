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
        isLocked: Bool = false,
        folderPath: String? = nil,
        assetService: AssetService,
        albumService: AlbumService? = nil,
        config: SlideshowConfig? = nil,
        slideshowContext: SlideshowLaunchContext? = nil
    ) -> AssetProvider {
        if isLocked {
            return LockedAssetProvider(assetService: assetService)
        }

        if let albumId = albumId, albumService != nil {
            return AlbumAssetProvider(assetService: assetService, albumId: albumId)
        } else {
            return GeneralAssetProvider(
                assetService: assetService,
                personId: personId,
                tagId: tagId,
                city: city,
                isAllPhotos: isAllPhotos,
                isFavorite: isFavorite,
                folderPath: folderPath,
                config: config,
                slideshowContext: slideshowContext
            )
        }
    }
}

protocol AssetProvider {
    func fetchAssets(page: Int, limit: Int, assetType: AssetType?) async throws -> SearchResult
    func fetchRandomAssets(limit: Int) async throws -> SearchResult
    func fetchAllCities() async throws -> [String]
    func fetchAllYears() async throws -> [Int]
}

extension AssetProvider {
    func fetchAssets(page: Int, limit: Int) async throws -> SearchResult {
        try await fetchAssets(page: page, limit: limit, assetType: nil)
    }
}

/// Adapts one compact timeline month bucket to the paginated AssetProvider
/// interface used by AssetGridView.
final class TimelineMonthAssetProvider: AssetProvider {
    private let assetService: AssetService
    private let timeBucket: String
    private let order: String
    private let cache: TimelineMonthAssetCache

    init(
        assetService: AssetService,
        timeBucket: String,
        order: String,
        cache: TimelineMonthAssetCache
    ) {
        self.assetService = assetService
        self.timeBucket = timeBucket
        self.order = order
        self.cache = cache
    }

    private func loadAssets() async throws -> [ImmichAsset] {
        try await cache.assets(
            timeBucket: timeBucket,
            order: order,
            assetService: assetService
        )
    }

    func fetchAssets(page: Int, limit: Int, assetType: AssetType?) async throws -> SearchResult {
        let loadedAssets = try await loadAssets()
        let assets = assetType.map { type in
            loadedAssets.filter { $0.type == type }
        } ?? loadedAssets
        let pageSize = max(limit, 1)
        let startIndex = max((page - 1) * pageSize, 0)
        let endIndex = min(startIndex + pageSize, assets.count)
        let pageAssets = startIndex < endIndex ? Array(assets[startIndex..<endIndex]) : []
        let nextPage = endIndex < assets.count ? String(page + 1) : nil

        return SearchResult(assets: pageAssets, total: assets.count, nextPage: nextPage)
    }

    func fetchRandomAssets(limit: Int) async throws -> SearchResult {
        let assets = try await loadAssets()
        let result = Array(assets.shuffled().prefix(max(limit, 0)))
        return SearchResult(assets: result, total: assets.count, nextPage: nil)
    }

    func fetchAllCities() async throws -> [String] {
        let assets = try await loadAssets()
        return Array(Set(assets.compactMap(\.exifInfo?.city).filter { !$0.isEmpty })).sorted()
    }

    func fetchAllYears() async throws -> [Int] {
        let assets = try await loadAssets()
        return Array(Set(assets.compactMap { Int($0.localDateTime.prefix(4)) })).sorted(by: >)
    }
}

class AlbumAssetProvider: AssetProvider {
    private let assetService: AssetService
    private let albumId: String
    private var cachedAssets: [ImmichAsset]?
    private let albumPageSize = 200

    init(assetService: AssetService, albumId: String) {
        self.assetService = assetService
        self.albumId = albumId
    }

    private func loadAlbumAssets() async throws -> [ImmichAsset] {
        if let cachedAssets {
            return cachedAssets
        }

        var nextPage: Int? = 1
        var allAssets: [ImmichAsset] = []
        var seenAssetIds = Set<String>()

        while let page = nextPage {
            let result = try await assetService.fetchAssets(page: page, limit: albumPageSize, albumId: albumId)
            for asset in result.assets where seenAssetIds.insert(asset.id).inserted {
                allAssets.append(asset)
            }

            nextPage = nextPageNumber(from: result.nextPage, after: page)
        }

        cachedAssets = allAssets
        return allAssets
    }
    
    func fetchAssets(page: Int, limit: Int, assetType: AssetType?) async throws -> SearchResult {
        try await assetService.fetchAssets(
            page: page,
            limit: limit,
            albumId: albumId,
            assetType: assetType
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

    func fetchAllCities() async throws -> [String] {
        let assets = try await loadAlbumAssets()
        let cities = assets.compactMap { asset in
            if let city = asset.exifInfo?.city, !city.isEmpty {
                return city
            }
            return nil
        }
        return Array(Set(cities)).sorted()
    }

    func fetchAllYears() async throws -> [Int] {
        let assets = try await loadAlbumAssets()
        let years = assets.compactMap { asset -> Int? in
            let yearString = asset.localDateTime.prefix(4)
            return Int(yearString)
        }
        return Array(Set(years)).sorted(by: >)
    }

    private func nextPageNumber(from nextPage: String?, after currentPage: Int) -> Int? {
        guard let nextPage, !nextPage.isEmpty else { return nil }

        if let pageNumber = Int(nextPage) {
            return pageNumber
        }

        if let url = URL(string: nextPage),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let pageParam = components.queryItems?.first(where: { $0.name == "page" }),
           let pageNumber = Int(pageParam.value ?? "") {
            return pageNumber
        }

        return currentPage + 1
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
    private let slideshowContext: SlideshowLaunchContext?
    
    init(assetService: AssetService, personId: String? = nil, tagId: String? = nil, city: String? = nil, isAllPhotos: Bool = false, isFavorite: Bool = false, folderPath: String? = nil, config: SlideshowConfig? = nil, slideshowContext: SlideshowLaunchContext? = nil) {
        self.assetService = assetService
        self.personId = personId
        self.tagId = tagId
        self.city = city
        self.isAllPhotos = isAllPhotos
        self.isFavorite = isFavorite
        self.config = config
        self.folderPath = folderPath
        self.slideshowContext = slideshowContext
    }
    
    func fetchAssets(page: Int, limit: Int, assetType: AssetType?) async throws -> SearchResult {
        // If config is provided, use it; otherwise fall back to individual parameters
        if let config = config {
            let result = try await assetService.fetchAssets(
                config: config,
                page: page,
                limit: limit,
                isAllPhotos: isAllPhotos,
                assetType: assetType
            )
            return result
        } else if let slideshowContext {
            return try await assetService.fetchAssets(
                page: page,
                limit: limit,
                isAllPhotos: true,
                isFavorite: slideshowContext.favoritesOnly,
                assetType: slideshowContext.assetType,
                filters: slideshowContext.filters,
                sortOrder: slideshowContext.sortOrder
            )
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
                folderPath: folderPath,
                assetType: assetType
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

    func fetchAllCities() async throws -> [String] {
        return try await assetService.fetchAllCities()
    }

    func fetchAllYears() async throws -> [Int] {
        return try await assetService.fetchAllYears()
    }
}

class LockedAssetProvider: AssetProvider {
    private let assetService: AssetService
    private var cachedAssets: [ImmichAsset]?
    private var cachedSortOrder: String?

    init(assetService: AssetService) {
        self.assetService = assetService
    }

    private func loadLockedAssets() async throws -> [ImmichAsset] {
        let sortOrder = UserDefaults.standard.assetSortOrder
        if let cachedAssets, cachedSortOrder == sortOrder {
            return cachedAssets
        }

        let result = try await assetService.fetchLockedAssets(page: 1, limit: nil)
        cachedAssets = result.assets
        cachedSortOrder = sortOrder
        return result.assets
    }

    func fetchAssets(page: Int, limit: Int, assetType: AssetType?) async throws -> SearchResult {
        let loadedAssets = try await loadLockedAssets()
        let assets = assetType.map { type in
            loadedAssets.filter { $0.type == type }
        } ?? loadedAssets
        let pageSize = max(limit, 1)
        let startIndex = max((page - 1) * pageSize, 0)
        let endIndex = min(startIndex + pageSize, assets.count)

        let pageAssets = startIndex < endIndex ? Array(assets[startIndex..<endIndex]) : []
        let nextPage = endIndex < assets.count ? String(page + 1) : nil

        return SearchResult(assets: pageAssets, total: assets.count, nextPage: nextPage)
    }

    func fetchRandomAssets(limit: Int) async throws -> SearchResult {
        let assets = try await loadLockedAssets()
        guard !assets.isEmpty else {
            return SearchResult(assets: [], total: 0, nextPage: nil)
        }

        let sampleCount = min(limit, assets.count)
        return SearchResult(
            assets: Array(assets.shuffled().prefix(sampleCount)),
            total: assets.count,
            nextPage: nil
        )
    }

    func fetchAllCities() async throws -> [String] {
        let assets = try await loadLockedAssets()
        let cities = assets.compactMap { asset in
            if let city = asset.exifInfo?.city, !city.isEmpty {
                return city
            }
            return nil
        }
        return Array(Set(cities)).sorted()
    }

    func fetchAllYears() async throws -> [Int] {
        let assets = try await loadLockedAssets()
        let years = assets.compactMap { asset in
            Int(asset.localDateTime.prefix(4))
        }
        return Array(Set(years)).sorted(by: >)
    }
}
