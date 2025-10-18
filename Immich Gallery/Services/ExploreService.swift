//
//  ExploreService.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-09-05.
//

import Foundation

class ExploreService: ObservableObject {
    private let networkService: NetworkService
    
    init(networkService: NetworkService) {
        self.networkService = networkService
    }
    
    func fetchExploreData() async throws -> [ImmichAsset] {
        let result: [ImmichAsset] = try await networkService.makeRequest(
            endpoint: "/api/search/cities",
            method: .GET,
            responseType: [ImmichAsset].self
        )
        
        return result
    }
}