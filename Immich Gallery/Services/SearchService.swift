//
//  SearchService.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-08-09.
//

import Foundation

/// Service responsible for smart search functionality
class SearchService: ObservableObject {
    private let networkService: NetworkService

    init(networkService: NetworkService) {
        self.networkService = networkService
    }

    func searchAssets(query: String, page: Int = 1) async throws -> SearchResult {
        let searchRequest: [String: Any] = [
            "page": page,
            "withExif": true,
            "isVisible": true,
            "language": "en-CA",
            "query": query
        ]
        
        let result: SearchResponse = try await networkService.makeRequest(
            endpoint: "/api/search/smart",
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
}