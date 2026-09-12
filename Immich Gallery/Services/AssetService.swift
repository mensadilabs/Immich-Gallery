//
//  AssetService.swift
//  Immich Gallery
//

import Foundation
import UIKit

enum SearchSuggestionType: String, CaseIterable {
    static let nullValue = "__immich_gallery_null_suggestion__"

    case country
    case state
    case city
    case cameraMake = "camera-make"
    case cameraModel = "camera-model"
    case cameraLensModel = "camera-lens-model"
}

/// Service responsible for asset fetching, searching, and image loading
class AssetService: ObservableObject {
    private let networkService: NetworkService

    init(networkService: NetworkService) {
        self.networkService = networkService
    }

    func fetchAssets(page: Int = 1, limit: Int? = nil, albumId: String? = nil, personId: String? = nil, tagId: String? = nil, city: String? = nil, isAllPhotos: Bool = false, isFavorite: Bool = false, folderPath: String? = nil, assetType: AssetType? = nil) async throws -> SearchResult {
        // Use separate sort order for All Photos tab vs everything else
        let sortOrder = isAllPhotos 
            ? UserDefaults.standard.allPhotosSortOrder
            : UserDefaults.standard.assetSortOrder
        let selectedCity = isAllPhotos ? UserDefaults.standard.allPhotosFilterCity : city
        let selectedState = isAllPhotos ? UserDefaults.standard.allPhotosFilterState : nil
        let selectedCountry = isAllPhotos ? UserDefaults.standard.allPhotosFilterCountry : nil
        let selectedCameraMake = isAllPhotos ? UserDefaults.standard.allPhotosFilterCameraMake : nil
        let selectedCameraModel = isAllPhotos ? UserDefaults.standard.allPhotosFilterCameraModel : nil
        let selectedLensModel = isAllPhotos ? UserDefaults.standard.allPhotosFilterLensModel : nil
        let selectedYear = isAllPhotos ? UserDefaults.standard.allPhotosFilterYear : nil
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
        if let assetType {
            searchRequest["type"] = assetType.rawValue
        }
        if let value = Self.metadataFilterValue(selectedCity) { searchRequest["city"] = value }
        if let value = Self.metadataFilterValue(selectedState) { searchRequest["state"] = value }
        if let value = Self.metadataFilterValue(selectedCountry) { searchRequest["country"] = value }
        if let value = Self.metadataFilterValue(selectedCameraMake) { searchRequest["make"] = value }
        if let value = Self.metadataFilterValue(selectedCameraModel) { searchRequest["model"] = value }
        if let value = Self.metadataFilterValue(selectedLensModel) { searchRequest["lensModel"] = value }
        if let selectedYear, let yearRange = makeYearRange(year: selectedYear) {
            searchRequest["takenAfter"] = yearRange.start
            searchRequest["takenBefore"] = yearRange.end
        }
        if let folderPath = folderPath, !folderPath.isEmpty {
            searchRequest["originalPath"] = folderPath
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

    func fetchAllCities() async throws -> [String] {
        let assets: [ImmichAsset] = try await networkService.makeRequest(
            endpoint: "/api/search/cities",
            method: .GET,
            responseType: [ImmichAsset].self
        )

        let cities = assets.compactMap { asset in
            if let city = asset.exifInfo?.city, !city.isEmpty {
                return city
            }
            return nil
        }
        
        return Array(Set(cities)).sorted()
    }

    func fetchSearchSuggestions(
        type: SearchSuggestionType,
        country: String? = nil,
        state: String? = nil,
        cameraMake: String? = nil,
        cameraModel: String? = nil,
        lensModel: String? = nil
    ) async throws -> [String] {
        var components = URLComponents()
        components.path = "/api/search/suggestions"
        var queryItems = [
            URLQueryItem(name: "includeNull", value: "true"),
            URLQueryItem(name: "type", value: type.rawValue),
        ]
        if let country = Self.queryFilterValue(country) { queryItems.append(URLQueryItem(name: "country", value: country)) }
        if let state = Self.queryFilterValue(state) { queryItems.append(URLQueryItem(name: "state", value: state)) }
        if let cameraMake = Self.queryFilterValue(cameraMake) { queryItems.append(URLQueryItem(name: "make", value: cameraMake)) }
        if let cameraModel = Self.queryFilterValue(cameraModel) { queryItems.append(URLQueryItem(name: "model", value: cameraModel)) }
        if let lensModel = Self.queryFilterValue(lensModel) { queryItems.append(URLQueryItem(name: "lensModel", value: lensModel)) }
        components.queryItems = queryItems

        let suggestions: [String?] = try await networkService.makeRequest(
            endpoint: components.string ?? "/api/search/suggestions?includeNull=true&type=\(type.rawValue)",
            method: .GET,
            responseType: [String?].self
        )
        let values = suggestions.compactMap { value -> String? in
            guard let value else { return SearchSuggestionType.nullValue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return Array(Set(values)).sorted { left, right in
            if left == SearchSuggestionType.nullValue { return false }
            if right == SearchSuggestionType.nullValue { return true }
            return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
        }
    }

    func fetchAllYears() async throws -> [Int] {
        let endpoint = Self.timelineBucketsEndpoint()

        struct Bucket: Codable {
            let timeBucket: String
        }

        let response: [Bucket] = try await networkService.makeRequest(
            endpoint: endpoint,
            method: .GET,
            responseType: [Bucket].self
        )

        let years = response.compactMap { bucket in
            let yearString = bucket.timeBucket.prefix(4)
            return Int(yearString)
        }

        return Array(Set(years)).sorted(by: >)
    }

    // MARK: - Timeline (sectioned-by-month view)

    /// Fetches the list of monthly buckets (month + asset count) for the whole
    /// library in a single lightweight request. Used to build the timeline's
    /// section spine without loading any assets.
    func fetchTimelineBuckets(
        order requestedOrder: String? = nil,
        isFavorite: Bool = false
    ) async throws -> [TimelineBucket] {
        let order = requestedOrder ?? UserDefaults.standard.allPhotosSortOrder
        let endpoint = Self.timelineBucketsEndpoint(
            order: order,
            withStacked: true,
            isFavorite: isFavorite
        )
        return try await networkService.makeRequest(
            endpoint: endpoint,
            method: .GET,
            responseType: [TimelineBucket].self
        )
    }

    /// Fetches the assets for a single month bucket. The server returns a
    /// compact columnar payload which is mapped into ImmichAsset values so the
    /// existing thumbnail/fullscreen views can render them.
    func fetchBucketAssets(
        timeBucket: String,
        order requestedOrder: String? = nil,
        isFavorite: Bool = false
    ) async throws -> [ImmichAsset] {
        let order = requestedOrder ?? UserDefaults.standard.allPhotosSortOrder
        let endpoint = Self.timelineBucketEndpoint(
            timeBucket: timeBucket,
            order: order,
            isFavorite: isFavorite
        )
        let response: TimeBucketAssetResponse = try await networkService.makeRequest(
            endpoint: endpoint,
            method: .GET,
            responseType: TimeBucketAssetResponse.self
        )
        return response.toAssets()
    }

    static func timelineBucketsEndpoint(
        order: String? = nil,
        withStacked: Bool = false,
        isFavorite: Bool = false
    ) -> String {
        var queryItems = isFavorite
            ? []
            : ["visibility=timeline", "withPartners=true"]
        if let order {
            queryItems.append("order=\(order)")
        }
        if withStacked {
            queryItems.append("withStacked=true")
        }
        if isFavorite {
            queryItems.append("isFavorite=true")
        }
        return "/api/timeline/buckets?\(queryItems.joined(separator: "&"))"
    }

    static func timelineBucketEndpoint(
        timeBucket: String,
        order: String,
        isFavorite: Bool = false
    ) -> String {
        let encoded = timeBucket.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? timeBucket
        var queryItems = ["timeBucket=\(encoded)"]
        if !isFavorite {
            queryItems.append(contentsOf: ["visibility=timeline", "withPartners=true"])
        }
        queryItems.append(contentsOf: ["order=\(order)", "withStacked=true"])
        if isFavorite {
            queryItems.append("isFavorite=true")
        }
        return "/api/timeline/bucket?\(queryItems.joined(separator: "&"))"
    }

    /// Filtered Timeline requests use the stable metadata search endpoint,
    /// because the bucket API cannot filter by media type, capture date, or EXIF.
    func fetchFilteredTimelineAssets(
        page: Int,
        size: Int,
        order: String,
        city: String?,
        state: String? = nil,
        country: String? = nil,
        cameraMake: String? = nil,
        cameraModel: String? = nil,
        lensModel: String? = nil,
        year: Int?,
        isFavorite: Bool = false,
        assetType: AssetType? = nil
    ) async throws -> SearchResult {
        let request = Self.timelineSearchRequest(
            page: page,
            size: size,
            order: order,
            city: city,
            state: state,
            country: country,
            cameraMake: cameraMake,
            cameraModel: cameraModel,
            lensModel: lensModel,
            year: year,
            isFavorite: isFavorite,
            assetType: assetType
        )
        let response: SearchResponse = try await networkService.makeRequest(
            endpoint: "/api/search/metadata",
            method: .POST,
            body: request,
            responseType: SearchResponse.self
        )
        return SearchResult(
            assets: response.assets.items,
            total: response.assets.total,
            nextPage: response.assets.nextPage
        )
    }

    static func timelineSearchRequest(
        page: Int,
        size: Int,
        order: String,
        city: String?,
        state: String? = nil,
        country: String? = nil,
        cameraMake: String? = nil,
        cameraModel: String? = nil,
        lensModel: String? = nil,
        year: Int?,
        isFavorite: Bool = false,
        assetType: AssetType? = nil
    ) -> [String: Any] {
        var request: [String: Any] = [
            "page": page,
            "size": size,
            "order": order,
            "visibility": "timeline",
            "withExif": true,
        ]

        if let value = metadataFilterValue(city) { request["city"] = value }
        if let value = metadataFilterValue(state) { request["state"] = value }
        if let value = metadataFilterValue(country) { request["country"] = value }
        if let value = metadataFilterValue(cameraMake) { request["make"] = value }
        if let value = metadataFilterValue(cameraModel) { request["model"] = value }
        if let value = metadataFilterValue(lensModel) { request["lensModel"] = value }
        if isFavorite { request["isFavorite"] = true }
        if let assetType { request["type"] = assetType.rawValue }
        if let year, let range = makeYearRange(year: year) {
            request["takenAfter"] = range.start
            request["takenBefore"] = range.end
        }

        return request
    }

    private static func metadataFilterValue(_ value: String?) -> Any? {
        guard let value else { return nil }
        return value == SearchSuggestionType.nullValue ? NSNull() : value
    }

    private static func queryFilterValue(_ value: String?) -> String? {
        guard value != SearchSuggestionType.nullValue else { return nil }
        return value
    }

    /// Fetches one full asset record, including EXIF, on demand. Timeline tiles
    /// intentionally use the compact bucket payload, so fullscreen can hydrate
    /// only the selected asset instead of loading metadata for every tile.
    func fetchAssetDetails(assetId: String) async throws -> ImmichAsset {
        try await networkService.makeRequest(
            endpoint: "/api/assets/\(assetId)",
            method: .GET,
            responseType: ImmichAsset.self
        )
    }

    func fetchStack(stackId: String) async throws -> StackResponse {
        try await networkService.makeRequest(
            endpoint: "/api/stacks/\(stackId)",
            method: .GET,
            responseType: StackResponse.self
        )
    }

    func fetchLockedAssets(page: Int = 1, limit: Int? = nil) async throws -> SearchResult {
        let order = UserDefaults.standard.assetSortOrder
        let buckets = try await fetchLockedTimelineBuckets(order: order)
        let total = buckets.reduce(0) { $0 + $1.count }
        guard total > 0 else {
            return SearchResult(assets: [], total: 0, nextPage: nil)
        }

        let bucketAssets = try await fetchLockedBucketAssets(for: buckets, order: order)
        let assets = bucketAssets.flatMap { $0 }
        let pageSize = max(limit ?? assets.count, 1)
        let startIndex = max((page - 1) * pageSize, 0)
        let endIndex = min(startIndex + pageSize, assets.count)

        let pageAssets: [ImmichAsset]
        if startIndex < endIndex {
            pageAssets = Array(assets[startIndex..<endIndex])
        } else {
            pageAssets = []
        }

        let nextPage = endIndex < assets.count ? String(page + 1) : nil
        return SearchResult(assets: pageAssets, total: total, nextPage: nextPage)
    }

    private func fetchLockedTimelineBuckets(order: String) async throws -> [TimelineBucket] {
        let endpoint = "/api/timeline/buckets?visibility=locked&order=\(order)&withStacked=true"
        return try await networkService.makeRequest(
            endpoint: endpoint,
            method: .GET,
            responseType: [TimelineBucket].self
        )
    }

    private func fetchLockedBucketAssets(for buckets: [TimelineBucket], order: String) async throws -> [[ImmichAsset]] {
        var result: [[ImmichAsset]] = []
        result.reserveCapacity(buckets.count)

        for bucket in buckets {
            result.append(try await fetchLockedBucketAssets(timeBucket: bucket.timeBucket, order: order))
        }

        return result
    }

    private func fetchLockedBucketAssets(timeBucket: String, order: String) async throws -> [ImmichAsset] {
        let encoded = timeBucket.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? timeBucket
        let endpoint = "/api/timeline/bucket?timeBucket=\(encoded)&visibility=locked&order=\(order)&withStacked=true"
        let response: TimeBucketAssetResponse = try await networkService.makeRequest(
            endpoint: endpoint,
            method: .GET,
            responseType: TimeBucketAssetResponse.self
        )
        return response.toAssets()
    }

    /// Fetches assets using slideshow configuration
    func fetchAssets(
        config: SlideshowConfig,
        page: Int = 1,
        limit: Int = 50,
        isAllPhotos: Bool = false,
        assetType: AssetType? = nil
    ) async throws -> SearchResult {
        // Use separate sort order for All Photos tab vs everything else
        let sortOrder = isAllPhotos
            ? UserDefaults.standard.allPhotosSortOrder
            : UserDefaults.standard.assetSortOrder
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
        if let assetType {
            searchRequest["type"] = assetType.rawValue
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
        guard asset.type == .image else {
            print("AssetService: Skipping full image load for non-image asset \(asset.id)")
            return nil
        }

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

    private static func makeYearRange(year: Int) -> (start: String, end: String)? {
        guard (1...9999).contains(year) else { return nil }
        return (
            "\(year)-01-01T00:00:00.000Z",
            "\(year)-12-31T23:59:59.999Z"
        )
    }

    private func makeYearRange(year: Int) -> (start: String, end: String)? {
        Self.makeYearRange(year: year)
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
        let searchRequest = Self.randomSearchRequest(
            albumIds: albumIds,
            personIds: personIds,
            tagIds: tagIds,
            folderPath: folderPath,
            limit: limit
        )
        
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
    
    static func randomSearchRequest(
        albumIds: [String]? = nil,
        personIds: [String]? = nil,
        tagIds: [String]? = nil,
        folderPath: String? = nil,
        limit: Int
    ) -> [String: Any] {
        var request: [String: Any] = [
            "size": limit,
            "withPeople": true,
            "withExif": true,
        ]
        var filter: [String: Any] = [:]
        if let albumIds { filter["albumIds"] = ["any": albumIds] }
        if let personIds { filter["personIds"] = ["any": personIds] }
        if let tagIds { filter["tagIds"] = ["any": tagIds] }
        if let folderPath, !folderPath.isEmpty {
            filter["originalPath"] = ["startsWith": folderPath]
        }
        if !filter.isEmpty {
            request["filter"] = filter
        }
        return request
    }

    /// Fetches random assets using slideshow configuration
    func fetchRandomAssets(config: SlideshowConfig, limit: Int = 50) async throws -> SearchResult {
        let albumIds = config.albumIds.isEmpty ? nil : config.albumIds
        let personIds = config.personIds.isEmpty ? nil : config.personIds
        return try await fetchRandomAssets(albumIds: albumIds, personIds: personIds, limit: limit)
    }
} 
