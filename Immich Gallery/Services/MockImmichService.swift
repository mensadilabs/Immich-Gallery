//
//  MockImmichService.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import Foundation
import UIKit

// MARK: - Mock Network Service
class MockNetworkService: NetworkService {
    override init() {
        super.init()
        // Set up mock authentication state
        self.baseURL = "https://mock-immich-server.com"
        self.accessToken = "mock-access-token"
    }
}

// MARK: - Mock Authentication Service
class MockAuthenticationService: AuthenticationService {
    override init(networkService: NetworkService) {
        super.init(networkService: networkService)
        // Set up mock authentication state
        self.isAuthenticated = true
        self.currentUser = Owner(
            id: "mock-user-id",
            email: "mock@example.com",
            name: "Mock User",
            profileImagePath: "",
            profileChangedAt: "2023-01-01",
            avatarColor: "primary"
        )
    }
}

// MARK: - Mock Asset Service
class MockAssetService: AssetService {
    override init(networkService: NetworkService) {
        super.init(networkService: networkService)
    }
    
    override func fetchAssets(page: Int = 1, limit: Int = 50, albumId: String? = nil, personId: String? = nil) async throws -> SearchResult {
        // Return mock assets
        let mockAssets = [
            ImmichAsset(
                id: "mock-asset-1",
                deviceAssetId: "mock-device-1",
                deviceId: "mock-device",
                ownerId: "mock-owner",
                libraryId: nil,
                type: .image,
                originalPath: "/mock/path1",
                originalFileName: "mock1.jpg",
                originalMimeType: "image/jpeg",
                resized: false,
                thumbhash: nil,
                fileModifiedAt: "2023-01-01",
                fileCreatedAt: "2023-01-01",
                localDateTime: "2023-01-01",
                updatedAt: "2023-01-01",
                isFavorite: false,
                isArchived: false,
                isOffline: false,
                isTrashed: false,
                checksum: "mock-checksum-1",
                duration: nil,
                hasMetadata: false,
                livePhotoVideoId: nil,
                people: [],
                visibility: "public",
                duplicateId: nil,
                exifInfo: nil
            ),
            ImmichAsset(
                id: "mock-asset-2",
                deviceAssetId: "mock-device-2",
                deviceId: "mock-device",
                ownerId: "mock-owner",
                libraryId: nil,
                type: .video,
                originalPath: "/mock/path2",
                originalFileName: "mock2.mp4",
                originalMimeType: "video/mp4",
                resized: false,
                thumbhash: nil,
                fileModifiedAt: "2023-01-02",
                fileCreatedAt: "2023-01-02",
                localDateTime: "2023-01-02",
                updatedAt: "2023-01-02",
                isFavorite: true,
                isArchived: false,
                isOffline: false,
                isTrashed: false,
                checksum: "mock-checksum-2",
                duration: "PT1M30S",
                hasMetadata: false,
                livePhotoVideoId: nil,
                people: [],
                visibility: "public",
                duplicateId: nil,
                exifInfo: nil
            )
        ]
        
        return SearchResult(
            assets: mockAssets,
            total: mockAssets.count,
            nextPage: nil
        )
    }
    
    override func loadImage(asset: ImmichAsset, size: String = "thumbnail") async throws -> UIImage? {
        // Fetch a random image from picsum.photos
        let url = URL(string: "https://picsum.photos/300/300")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)
    }
    
    override func loadFullImage(asset: ImmichAsset) async throws -> UIImage? {
        // Fetch a random full-size image from picsum.photos
        let url = URL(string: "https://picsum.photos/1920/1080")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)
    }
    
    override func loadVideoURL(asset: ImmichAsset) async throws -> URL {
        // Return a mock video URL
        return URL(string: "https://mock-video-url.com/video.mp4")!
    }
}

// MARK: - Mock Album Service
class MockAlbumService: AlbumService {
    override init(networkService: NetworkService) {
        super.init(networkService: networkService)
    }
    
    override func fetchAlbums() async throws -> [ImmichAlbum] {
        // Return mock albums
        let mockAlbums = [
            ImmichAlbum(
                id: "mock-album-1",
                albumName: "Mock Album 1",
                description: "This is a mock album for testing",
                albumThumbnailAssetId: "mock-asset-1",
                createdAt: "2023-01-01",
                updatedAt: "2023-01-01",
                albumUsers: [],
                assets: [],
                assetCount: 5,
                ownerId: "mock-owner",
                owner: Owner(
                    id: "mock-owner",
                    email: "mock@example.com",
                    name: "Mock Owner",
                    profileImagePath: "",
                    profileChangedAt: "2023-01-01",
                    avatarColor: "primary"
                ),
                shared: false,
                hasSharedLink: false,
                isActivityEnabled: true,
                lastModifiedAssetTimestamp: "2023-01-01",
                order: "desc",
                startDate: "2023-01-01",
                endDate: "2023-01-31"
            )
        ]
        
        return mockAlbums
    }
    
    override func loadAlbumThumbnail(albumId: String, thumbnailAssetId: String, size: String = "thumbnail") async throws -> UIImage? {
        // Fetch a random album thumbnail from picsum.photos
        let url = URL(string: "https://picsum.photos/300/300")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)
    }
}

// MARK: - Mock People Service
class MockPeopleService: PeopleService {
    override init(networkService: NetworkService) {
        super.init(networkService: networkService)
    }
    
    override func getAllPeople(page: Int = 1, size: Int = 100, withHidden: Bool = false) async throws -> [Person] {
        // Return mock people
        let mockPeople = [
            Person(
                id: "mock-person-1",
                name: "Mock Person 1",
                birthDate: "1990-01-01",
                thumbnailPath: "",
                isHidden: false,
                isFavorite: false,
                updatedAt: "2023-01-01",
                color: "primary"
            ),
            Person(
                id: "mock-person-2",
                name: "Mock Person 2",
                birthDate: "1995-05-15",
                thumbnailPath: "",
                isHidden: false,
                isFavorite: true,
                updatedAt: "2023-01-02",
                color: "secondary"
            )
        ]
        
        return mockPeople
    }
    
    override func loadPersonThumbnail(personId: String) async throws -> UIImage? {
        // Fetch a random person thumbnail from picsum.photos
        let url = URL(string: "https://picsum.photos/300/300")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)
    }
}

// MARK: - Convenience Factory
class MockServiceFactory {
    static func createMockServices() -> (NetworkService, AuthenticationService, AssetService, AlbumService, PeopleService) {
        let networkService = MockNetworkService()
        let authService = MockAuthenticationService(networkService: networkService)
        let assetService = MockAssetService(networkService: networkService)
        let albumService = MockAlbumService(networkService: networkService)
        let peopleService = MockPeopleService(networkService: networkService)
        
        return (networkService, authService, assetService, albumService, peopleService)
    }
} 