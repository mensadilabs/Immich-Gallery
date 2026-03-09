//
//  AssetService.swift
//  Immich Gallery
//

import Foundation
import UIKit

let maxFilterCombinations = 6

struct FilterCombo: Hashable {
    let city: String?
    let takenAfter: String?
    let takenBefore: String?
}

/// Returns the number of API combos that would result from the given selections,
/// accounting for contiguous-year collapse.
func filterComboCount(cities: Set<String>, years: Set<Int>) -> Int {
    let cityCount = max(cities.count, 1)
    guard !years.isEmpty else { return cityCount }

    // Count collapsed year ranges
    let sorted = years.sorted()
    var rangeCount = 1
    for i in 1..<sorted.count {
        if sorted[i] != sorted[i - 1] + 1 {
            rangeCount += 1
        }
    }
    return cityCount * rangeCount
}

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
        let selectedCity = city
        let selectedYear: Int? = nil
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
        if let selectedCity {
            searchRequest["city"] = selectedCity
        }
        if let selectedYear, let yearRange = makeYearRange(year: selectedYear) {
            searchRequest["takenAfter"] = yearRange.start
            searchRequest["takenBefore"] = yearRange.end
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

    func fetchAssetsMultiFilter(
        page: Int,
        limit: Int,
        cities: Set<String>,
        years: Set<Int>,
        sortOrder: String
    ) async throws -> SearchResult {
        let combos = buildFilterCombos(cities: cities, years: years)

        // Fast path: single combo uses existing fetch directly
        if combos.count <= 1 {
            let combo = combos.first
            return try await fetchAssetsSingleCombo(
                page: page, limit: limit, city: combo?.city,
                takenAfter: combo?.takenAfter, takenBefore: combo?.takenBefore,
                sortOrder: sortOrder
            )
        }

        let cappedCombos = Array(combos.prefix(maxFilterCombinations))
        let perComboLimit = max(limit / cappedCombos.count, 20)

        // Parallel fetch
        let allResults: [SearchResult] = try await withThrowingTaskGroup(of: SearchResult.self) { group in
            for combo in cappedCombos {
                group.addTask {
                    try await self.fetchAssetsSingleCombo(
                        page: page, limit: perComboLimit, city: combo.city,
                        takenAfter: combo.takenAfter, takenBefore: combo.takenBefore,
                        sortOrder: sortOrder
                    )
                }
            }
            var results: [SearchResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }

        // Merge + dedup on current (background) context
        var seenIds = Set<String>()
        var merged: [ImmichAsset] = []
        merged.reserveCapacity(limit)
        for result in allResults {
            for asset in result.assets {
                if seenIds.insert(asset.id).inserted {
                    merged.append(asset)
                }
            }
        }

        // Sort by date
        let ascending = sortOrder == "asc"
        merged.sort { a, b in
            if ascending { return a.localDateTime < b.localDateTime }
            return a.localDateTime > b.localDateTime
        }

        // Aggregate nextPage: non-nil if ANY sub-result has more
        let hasNext = allResults.contains { $0.nextPage != nil }

        return SearchResult(
            assets: merged,
            total: merged.count,
            nextPage: hasNext ? String(page + 1) : nil
        )
    }

    private func fetchAssetsSingleCombo(
        page: Int, limit: Int, city: String?,
        takenAfter: String?, takenBefore: String?,
        sortOrder: String
    ) async throws -> SearchResult {
        var searchRequest: [String: Any] = [
            "page": page,
            "size": limit,
            "withPeople": true,
            "order": sortOrder,
            "withExif": true,
        ]
        if let city { searchRequest["city"] = city }
        if let takenAfter { searchRequest["takenAfter"] = takenAfter }
        if let takenBefore { searchRequest["takenBefore"] = takenBefore }

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

    func buildFilterCombos(cities: Set<String>, years: Set<Int>) -> [FilterCombo] {
        let yearRanges = collapseContiguousYears(years)

        if cities.isEmpty && yearRanges.isEmpty {
            return [FilterCombo(city: nil, takenAfter: nil, takenBefore: nil)]
        }
        if cities.isEmpty {
            return yearRanges.map { FilterCombo(city: nil, takenAfter: $0.start, takenBefore: $0.end) }
        }
        if yearRanges.isEmpty {
            return cities.sorted().map { FilterCombo(city: $0, takenAfter: nil, takenBefore: nil) }
        }

        // Cartesian product
        var combos: [FilterCombo] = []
        for city in cities.sorted() {
            for range in yearRanges {
                combos.append(FilterCombo(city: city, takenAfter: range.start, takenBefore: range.end))
            }
        }
        return combos
    }

    private func collapseContiguousYears(_ years: Set<Int>) -> [(start: String, end: String)] {
        guard !years.isEmpty else { return [] }
        let sorted = years.sorted()
        var ranges: [(start: Int, end: Int)] = []
        var rangeStart = sorted[0]
        var rangeEnd = sorted[0]

        for i in 1..<sorted.count {
            if sorted[i] == rangeEnd + 1 {
                rangeEnd = sorted[i]
            } else {
                ranges.append((rangeStart, rangeEnd))
                rangeStart = sorted[i]
                rangeEnd = sorted[i]
            }
        }
        ranges.append((rangeStart, rangeEnd))

        return ranges.compactMap { range in
            guard let yr = makeYearRange(startYear: range.start, endYear: range.end) else { return nil }
            return yr
        }
    }

    private func makeYearRange(startYear: Int, endYear: Int) -> (start: String, end: String)? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        guard let startDate = calendar.date(from: DateComponents(year: startYear, month: 1, day: 1)),
              let endDate = calendar.date(from: DateComponents(year: endYear + 1, month: 1, day: 1)) else {
            return nil
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return (formatter.string(from: startDate), formatter.string(from: endDate))
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

    func fetchAllYears() async throws -> [Int] {
        let endpoint = "/api/timeline/buckets?isTrashed=false"

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

    private func makeYearRange(year: Int) -> (start: String, end: String)? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        guard let startDate = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let endDate = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        return (formatter.string(from: startDate), formatter.string(from: endDate))
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
