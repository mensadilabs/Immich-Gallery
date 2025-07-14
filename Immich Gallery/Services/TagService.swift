//
//  TagService.swift
//  Immich Gallery
//

import Foundation

class TagService: ObservableObject {
    private let networkService: NetworkService
    
    init(networkService: NetworkService) {
        self.networkService = networkService
    }
    
    func fetchTags() async throws -> [Tag] {
        let result: [Tag] = try await networkService.makeRequest(
            endpoint: "/api/tags",
            method: .GET,
            responseType: [Tag].self
        )
        return result
    }
}