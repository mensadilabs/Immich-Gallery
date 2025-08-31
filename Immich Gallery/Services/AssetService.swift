//
//  AssetService.swift
//  Immich Gallery
//

import Foundation
import UIKit

/// Service responsible for asset fetching, searching, and image loading
class AssetService: ObservableObject {
    private let networkService: NetworkService

    init(networkService: NetworkService) {
        self.networkService = networkService
    }

    func fetchAssets(page: Int = 1, limit: Int = 50, albumId: String? = nil, personId: String? = nil, tagId: String? = nil, isAllPhotos: Bool = false) async throws -> SearchResult {
        // Use separate sort order for All Photos tab vs everything else
        let sortOrder = isAllPhotos 
            ? UserDefaults.standard.allPhotosSortOrder
            : (UserDefaults.standard.string(forKey: "assetSortOrder") ?? "desc")
        var searchRequest: [String: Any] = [
            "page": page,
            "size": limit,
            "withPeople": true,
            "order": sortOrder,
            "withExif": true,
        ]
        if let albumId = albumId {
            searchRequest["albumIds"] = [albumId]
        }
        if let personId = personId {
            searchRequest["personIds"] = [personId]
        }
        if let tagId = tagId {
            searchRequest["tagIds"] = [tagId]
        }
        let result: SearchResponse = try await networkService.makeRequest(
            endpoint: "/api/search/metadata",
            method: .POST,
            body: searchRequest,
            responseType: SearchResponse.self
        )
        return SearchResult(
            assets: result.assets.items,
            total: result.assets.total,
            nextPage: result.assets.nextPage
        )
    }

    func loadImage(asset: ImmichAsset, size: String = "thumbnail") async throws -> UIImage? {
        let endpoint = "/api/assets/\(asset.id)/thumbnail?format=webp&size=\(size)"
        let data = try await networkService.makeDataRequest(endpoint: endpoint)
        return UIImage(data: data)
    }

    func loadFullImage(asset: ImmichAsset) async throws -> UIImage? {
        let originalEndpoint = "/api/assets/\(asset.id)/original"
        
        let originalData = try await networkService.makeDataRequest(endpoint: originalEndpoint)
        
        return UIImage(data: originalData)
    }

    func loadVideoURL(asset: ImmichAsset) async throws -> URL {
        guard asset.type == .video else { throw ImmichError.clientError(400) }
        let endpoint = "/api/assets/\(asset.id)/video/playback"
        guard let url = URL(string: "\(networkService.baseURL)\(endpoint)") else {
            throw ImmichError.invalidURL
        }
        // Optionally: check HEAD request for video availability
        return url
    }
    
    func fetchRandomAssets(albumIds: [String]? = nil, personIds: [String]? = nil, tagIds: [String]? = nil, limit: Int = 50) async throws -> SearchResult {
        var searchRequest: [String: Any] = [
            "size": limit,
            "withPeople": true,
            "withExif": true,
        ]
        
        if let albumIds = albumIds {
            searchRequest["albumIds"] = albumIds
        }
        if let personIds = personIds {
            searchRequest["personIds"] = personIds
        }
        if let tagIds = tagIds {
            searchRequest["tagIds"] = tagIds
        }
        
        let assets: [ImmichAsset] = try await networkService.makeRequest(
            endpoint: "/api/search/random",
            method: .POST,
            body: searchRequest,
            responseType: [ImmichAsset].self
        )
        
        return SearchResult(
            assets: assets,
            total: assets.count,
            nextPage: nil // Random endpoint doesn't have pagination
        )
    }
} 
