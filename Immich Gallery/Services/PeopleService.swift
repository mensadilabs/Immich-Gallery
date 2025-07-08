//
//  PeopleService.swift
//  Immich Gallery
//

import Foundation
import UIKit

/// Service responsible for people/face recognition and thumbnails
class PeopleService: ObservableObject {
    private let networkService: NetworkService

    init(networkService: NetworkService) {
        self.networkService = networkService
    }

    func getAllPeople(page: Int = 1, size: Int = 100, withHidden: Bool = false) async throws -> [Person] {
        let endpoint = "/api/people?page=\(page)&size=\(size)&withHidden=\(withHidden)"
        print("PeopleService: Fetching people from \(endpoint)")
        struct PeopleResponse: Codable { let people: [Person] }
        let response: PeopleResponse = try await networkService.makeRequest(
            endpoint: endpoint,
            responseType: PeopleResponse.self
        )
        print("PeopleService: Received \(response.people.count) people")
        return response.people
    }

    func loadPersonThumbnail(personId: String) async throws -> UIImage? {
        let endpoint = "/api/people/\(personId)/thumbnail"
        let data = try await networkService.makeDataRequest(endpoint: endpoint)
        return UIImage(data: data)
    }
} 