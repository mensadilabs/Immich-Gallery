//
//  FolderService.swift
//  Immich Gallery
//
//  Created by Codex on 2025-09-12.
//

import Foundation

class FolderService: ObservableObject {
    private let networkService: NetworkService
    
    init(networkService: NetworkService) {
        self.networkService = networkService
    }
    
    func fetchUniquePaths() async throws -> [ImmichFolder] {
        let paths: [String] = try await networkService.makeRequest(
            endpoint: "/api/view/folder/unique-paths",
            method: .GET,
            responseType: [String].self
        )
        
        return paths.map { ImmichFolder(path: $0) }
    }
}
