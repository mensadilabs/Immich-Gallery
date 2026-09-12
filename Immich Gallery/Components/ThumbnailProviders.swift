//
//  ThumbnailProviders.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-09-04.
//

import SwiftUI

private func loadSingleThumbnail(
    assetService: AssetService,
    thumbnailCache: ThumbnailCache,
    personId: String? = nil,
    tagId: String? = nil,
    folderPath: String? = nil,
    mode: LockupThumbnailMode = .current
) async -> UIImage? {
    do {
        let searchResult: SearchResult
        if mode == .random {
            searchResult = try await assetService.fetchRandomAssets(
                personIds: personId.map { [$0] },
                tagIds: tagId.map { [$0] },
                folderPath: folderPath,
                limit: 10
            )
        } else {
            searchResult = try await assetService.fetchAssets(
                page: 1,
                limit: 1,
                personId: personId,
                tagId: tagId,
                folderPath: folderPath
            )
        }

        guard let asset = searchResult.assets.first else {
            return nil
        }

        return try await thumbnailCache.getThumbnail(for: asset.id, size: "thumbnail") {
            try await assetService.loadImage(assetId: asset.id, size: "thumbnail")
        }
    } catch {
        print("Failed to load \(mode.rawValue) lockup thumbnail: \(error)")
        return nil
    }
}

private func selectedLockupThumbnailMode() -> LockupThumbnailMode {
    LockupThumbnailMode(rawValue: UserDefaults.standard.lockupThumbnailMode) ?? .current
}

// MARK: - Album Thumbnail Provider
class AlbumThumbnailProvider {
    private let albumService: AlbumService
    private let assetService: AssetService
    private let thumbnailCache = ThumbnailCache.shared
    
    init(albumService: AlbumService, assetService: AssetService) {
        self.albumService = albumService
        self.assetService = assetService
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
    
    func loadCoverThumbnail(for album: ImmichAlbum) async -> UIImage? {
        guard album.id != "smart_locked" else { return nil }

        if selectedLockupThumbnailMode() == .random,
           !album.id.hasPrefix("smart_"),
           let randomThumbnail = await loadRandomThumbnail(for: album) {
            return randomThumbnail
        }

        if let staticThumbnail = await loadStaticThumbnail(for: album) {
            return staticThumbnail
        }

        do {
            let albumProvider = AlbumAssetProvider(assetService: assetService, albumId: album.id)
            let searchResult = try await albumProvider.fetchAssets(page: 1, limit: 1)
            guard let asset = searchResult.assets.first(where: { $0.type == .image }) else {
                return nil
            }

            return try await thumbnailCache.getThumbnail(for: asset.id, size: "thumbnail") {
                try await self.assetService.loadImage(assetId: asset.id, size: "thumbnail")
            }
        } catch {
            print("Failed to load cover thumbnail for album \(album.id): \(error)")
            return nil
        }
    }

    private func loadRandomThumbnail(for album: ImmichAlbum) async -> UIImage? {
        do {
            let searchResult = try await assetService.fetchRandomAssets(albumIds: [album.id], limit: 10)
            guard let asset = searchResult.assets.first(where: { $0.type == .image }) else {
                return nil
            }

            return try await thumbnailCache.getThumbnail(for: asset.id, size: "thumbnail") {
                try await self.assetService.loadImage(assetId: asset.id, size: "thumbnail")
            }
        } catch {
            print("Failed to load random cover thumbnail for album \(album.id): \(error)")
            return nil
        }
    }
}

// MARK: - People Thumbnail Provider
class PeopleThumbnailProvider {
    private let assetService: AssetService
    private let thumbnailCache = ThumbnailCache.shared
    
    init(assetService: AssetService) {
        self.assetService = assetService
    }
    
    func loadCoverThumbnail(for person: Person) async -> UIImage? {
        if selectedLockupThumbnailMode() == .random,
           let randomThumbnail = await loadThumbnail(for: person, mode: .random) {
            return randomThumbnail
        }

        return await loadThumbnail(for: person, mode: .current)
    }

    private func loadThumbnail(for person: Person, mode: LockupThumbnailMode) async -> UIImage? {
        let thumbnail = await loadSingleThumbnail(
            assetService: assetService,
            thumbnailCache: thumbnailCache,
            personId: person.id,
            mode: mode
        )
        if thumbnail == nil {
            print("Failed to load \(mode.rawValue) thumbnail for person \(person.id)")
        }
        return thumbnail
    }
}

// MARK: - Tag Thumbnail Provider
class TagThumbnailProvider {
    private let assetService: AssetService
    private let thumbnailCache = ThumbnailCache.shared
    
    init(assetService: AssetService) {
        self.assetService = assetService
    }
    
    func loadCoverThumbnail(for tag: Tag) async -> UIImage? {
        if selectedLockupThumbnailMode() == .random,
           let randomThumbnail = await loadThumbnail(for: tag, mode: .random) {
            return randomThumbnail
        }

        return await loadThumbnail(for: tag, mode: .current)
    }

    private func loadThumbnail(for tag: Tag, mode: LockupThumbnailMode) async -> UIImage? {
        let thumbnail = await loadSingleThumbnail(
            assetService: assetService,
            thumbnailCache: thumbnailCache,
            tagId: tag.id,
            mode: mode
        )
        if thumbnail == nil {
            print("Failed to load \(mode.rawValue) thumbnail for tag \(tag.id)")
        }
        return thumbnail
    }
}

// MARK: - Folder Thumbnail Provider
class FolderThumbnailProvider {
    private let assetService: AssetService
    private let thumbnailCache = ThumbnailCache.shared
    private let coordinator = FolderThumbnailCoordinator(maxConcurrentLoads: 4)

    init(assetService: AssetService) {
        self.assetService = assetService
    }

    func loadCoverThumbnail(for folder: ImmichFolder) async -> UIImage? {
        await loadCoverThumbnail(for: folder, mode: selectedLockupThumbnailMode())
    }

    func loadCoverThumbnail(for folder: ImmichFolder, mode: LockupThumbnailMode) async -> UIImage? {
        let key = "\(mode.rawValue)-\(folder.path)"
        if let inFlight = await coordinator.inFlightTask(for: key) {
            return await inFlight.value
        }

        let task = Task<UIImage?, Never> {
            await coordinator.acquireSlot()
            let thumbnail = await loadSingleThumbnail(
                assetService: assetService,
                thumbnailCache: thumbnailCache,
                folderPath: folder.path,
                mode: mode
            )
            await coordinator.releaseSlot()
            return thumbnail
        }

        await coordinator.setInFlightTask(task, for: key)
        let thumbnail = await task.value
        await coordinator.clearInFlightTask(for: key)
        return thumbnail
    }
}

private actor FolderThumbnailCoordinator {
    private let maxConcurrentLoads: Int
    private var activeLoads = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var inFlightByPath: [String: Task<UIImage?, Never>] = [:]

    init(maxConcurrentLoads: Int) {
        self.maxConcurrentLoads = maxConcurrentLoads
    }

    func inFlightTask(for path: String) -> Task<UIImage?, Never>? {
        inFlightByPath[path]
    }

    func setInFlightTask(_ task: Task<UIImage?, Never>, for path: String) {
        inFlightByPath[path] = task
    }

    func clearInFlightTask(for path: String) {
        inFlightByPath[path] = nil
    }

    func acquireSlot() async {
        if activeLoads < maxConcurrentLoads {
            activeLoads += 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
        activeLoads += 1
    }

    func releaseSlot() {
        activeLoads = max(0, activeLoads - 1)
        if !waiters.isEmpty, activeLoads < maxConcurrentLoads {
            let waiter = waiters.removeFirst()
            waiter.resume()
        }
    }
}
