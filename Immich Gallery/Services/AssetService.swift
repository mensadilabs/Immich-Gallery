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

    func fetchAssets(page: Int = 1, limit: Int? = nil, albumId: String? = nil, personId: String? = nil, tagId: String? = nil, city: String? = nil, isAllPhotos: Bool = false, isFavorite: Bool = false, folderPath: String? = nil) async throws -> SearchResult {
        // Use separate sort order for All Photos tab vs everything else
        let sortOrder = isAllPhotos 
            ? UserDefaults.standard.allPhotosSortOrder
            : (UserDefaults.standard.string(forKey: "assetSortOrder") ?? "desc")
        var searchRequest: [String: Any] = [
            "page": page,
            "withPeople": true,
            "order": sortOrder,
            "withExif": true,
        ]

        if let limit = limit {
            searchRequest["size"] = limit
        }

        if let albumId = albumId {
            searchRequest["albumIds"] = [albumId]
        }
        if let personId = personId {
            searchRequest["personIds"] = [personId]
        }
        if let tagId = tagId {
            searchRequest["tagIds"] = [tagId]
        }
        if isFavorite {
            searchRequest["isFavorite"] = true
        }
        if let city = city {
            searchRequest["city"] = city
        }
        if let folderPath = folderPath, !folderPath.isEmpty {
            searchRequest["originalPath"] = folderPath
            searchRequest["path"] = folderPath
            searchRequest["originalPathPrefix"] = folderPath
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
    
    /// Fetches assets using slideshow configuration
    func fetchAssets(config: SlideshowConfig, page: Int = 1, limit: Int = 50, isAllPhotos: Bool = false) async throws -> SearchResult {
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
        
        // Apply config parameters if they exist
        if !config.albumIds.isEmpty {
            searchRequest["albumIds"] = config.albumIds
            searchRequest["type"] = "IMAGE"
        }
        if !config.personIds.isEmpty {
            searchRequest["personIds"] = config.personIds
            searchRequest["type"] = "IMAGE"
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

    func loadImage(assetId: String, size: String = "thumbnail") async throws -> UIImage? {
        let endpoint = "/api/assets/\(assetId)/thumbnail?format=webp&size=\(size)"
        let data = try await networkService.makeDataRequest(endpoint: endpoint)
        return UIImage(data: data)
    }

    func loadFullImage(asset: ImmichAsset) async throws -> UIImage? {
        // Check if it's a RAW format before loading
        if let mimeType = asset.originalMimeType, isRawFormat(mimeType) {
            print("AssetService: Detected RAW format (\(mimeType)), using server-converted version")
            if let convertedImage = try await loadConvertedImage(asset: asset) {
                return convertedImage
            }
        }
        
        // Standard processing for non-RAW formats
        let originalEndpoint = "/api/assets/\(asset.id)/original"
        let originalData = try await networkService.makeDataRequest(endpoint: originalEndpoint)
        
        if let image = UIImage(data: originalData) {
            print("AssetService: Successfully loaded image for asset \(asset.id)")
            return image
        }
        
        print("AssetService: Failed to load image for asset \(asset.id)")
        return nil
    }
    
    private func isRawFormat(_ mimeType: String) -> Bool {
        let rawMimeTypes = [
            // Standard MIME types
            "image/x-adobe-dng",
            "image/x-canon-cr2",
            "image/x-canon-crw", 
            "image/x-nikon-nef",
            "image/x-sony-arw",
            "image/x-panasonic-raw",
            "image/x-olympus-orf",
            "image/x-fuji-raf",
            
            // Simplified types (what your logs show)
            "image/nef",
            "image/dng",
            "image/cr2",
            "image/arw",
            "image/orf",
            "image/raf",
            
            // Alternative formats
            "image/x-panasonic-rw2",
            "image/x-kodak-dcr",
            "image/x-sigma-x3f"
        ]
        return rawMimeTypes.contains(mimeType.lowercased())
    }
    
    private func loadConvertedImage(asset: ImmichAsset) async throws -> UIImage? {
        // Use preview size for best quality RAW conversion
        let endpoint = "/api/assets/\(asset.id)/thumbnail?format=webp&size=preview"
        
        do {
            let data = try await networkService.makeDataRequest(endpoint: endpoint)
            if let image = UIImage(data: data) {
                print("AssetService: Loaded converted RAW image: \(image.size)")
                return image
            }
        } catch {
            print("AssetService: Failed to load converted RAW image: \(error)")
        }
        
        return nil
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
    
    func fetchRandomAssets(albumIds: [String]? = nil, personIds: [String]? = nil, tagIds: [String]? = nil, folderPath: String? = nil, limit: Int = 50) async throws -> SearchResult {
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
        if let folderPath = folderPath, !folderPath.isEmpty {
            searchRequest["originalPath"] = folderPath
            searchRequest["path"] = folderPath
            searchRequest["originalPathPrefix"] = folderPath
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
    
    /// Fetches random assets using slideshow configuration
    func fetchRandomAssets(config: SlideshowConfig, limit: Int = 50) async throws -> SearchResult {
        let albumIds = config.albumIds.isEmpty ? nil : config.albumIds
        let personIds = config.personIds.isEmpty ? nil : config.personIds
        return try await fetchRandomAssets(albumIds: albumIds, personIds: personIds, limit: limit)
    }
} 
