//
//  AlbumService.swift
//  Immich Gallery
//

import Foundation
import UIKit

/// Service responsible for album operations
class AlbumService: ObservableObject {
    private let networkService: NetworkService

    init(networkService: NetworkService) {
        self.networkService = networkService
    }

    func fetchAlbums() async throws -> [ImmichAlbum] {
        print("AlbumService: Fetching albums from /api/albums")
        let albums = try await networkService.makeRequest(
            endpoint: "/api/albums",
            responseType: [ImmichAlbum].self
        )

        let sharedAlbums = try await networkService.makeRequest(
            endpoint: "/api/albums?shared=true",
            responseType: [ImmichAlbum].self
        )
        print("AlbumService: Received \(albums.count) albums")
        return [albums, sharedAlbums].flatMap { $0 }
    }

    func getAlbumInfo(albumId: String, withoutAssets: Bool = false) async throws -> ImmichAlbum {
        var endpoint = "/api/albums/\(albumId)"
        if withoutAssets {
            endpoint += "?withoutAssets=true"
        }
        return try await networkService.makeRequest(
            endpoint: endpoint,
            responseType: ImmichAlbum.self
        )
    }

    func loadAlbumThumbnail(albumId: String, thumbnailAssetId: String, size: String = "thumbnail") async throws -> UIImage? {
        let endpoint = "/api/assets/\(thumbnailAssetId)/thumbnail?format=webp&size=\(size)"
        let data = try await networkService.makeDataRequest(endpoint: endpoint)
        return UIImage(data: data)
    }
} 