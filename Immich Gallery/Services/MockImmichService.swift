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
    override init(networkService: NetworkService, userManager: UserManager) {
        super.init(networkService: networkService, userManager: userManager)
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
    
    override func fetchAssets(page: Int = 1, limit: Int = 50, albumId: String? = nil, personId: String? = nil, tagId: String? = nil, isAllPhotos: Bool = false) async throws -> SearchResult {
        // Generate different mock assets based on tagId for animation preview
        let baseId = tagId ?? "default"
        let mockAssets = (1...limit).map { index in
            ImmichAsset(
                id: "mock-asset-\(baseId)-\(index)",
                deviceAssetId: "mock-device-\(index)",
                deviceId: "mock-device",
                ownerId: "mock-owner",
                libraryId: nil,
                type: .image,
                originalPath: "/mock/path\(index)",
                originalFileName: "mock\(index).jpg",
                originalMimeType: "image/jpeg",
                resized: false,
                thumbhash: nil,
                fileModifiedAt: "2023-01-\(String(format: "%02d", index))",
                fileCreatedAt: "2023-01-\(String(format: "%02d", index))",
                localDateTime: "2023-01-\(String(format: "%02d", index))",
                updatedAt: "2023-01-\(String(format: "%02d", index))",
                isFavorite: index % 3 == 0,
                isArchived: false,
                isOffline: false,
                isTrashed: false,
                checksum: "mock-checksum-\(baseId)-\(index)",
                duration: nil,
                hasMetadata: false,
                livePhotoVideoId: nil,
                people: [],
                visibility: "public",
                duplicateId: nil,
                exifInfo: nil
            )
        }
        
        return SearchResult(
            assets: mockAssets,
            total: mockAssets.count,
            nextPage: nil
        )
    }
    
    override func loadImage(asset: ImmichAsset, size: String = "thumbnail") async throws -> UIImage? {
        // Generate different colored images based on asset ID for visual variety
        let hash = abs(asset.id.hashValue)
        let seed = hash % 1000
        let url = URL(string: "https://picsum.photos/seed/\(seed)/300/300")!
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
            ),
            ImmichAlbum(
                id: "mock-album-2",
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

// MARK: - Mock tag service
class MockTagService: TagService {
    override init(networkService: NetworkService) {
        super.init(networkService: networkService)
    }
    
    override func fetchTags() async throws -> [Tag] {
        // Return mock tags
        let mockTags = [
            Tag(
                id: "1",
                name: "Nature",
                value: "nature",
                color: "green",
                createdAt: "2023-01-01",
                updatedAt: "2023-01-01",
                parentId: nil
            ),
            Tag(
                id: "2",
                name: "Travel",
                value: "travel",
                color: "blue",
                createdAt: "2023-01-02",
                updatedAt: "2023-01-02",
                parentId: nil
            ),
            Tag(
                id: "3",
                name: "Family",
                value: "family",
                color: "red",
                createdAt: "2023-01-03",
                updatedAt: "2023-01-03",
                parentId: nil
            ),
            Tag(
                id: "4",
                name: "Work",
                value: "work",
                color: "orange",
                createdAt: "2023-01-04",
                updatedAt: "2023-01-04",
                parentId: nil
            )
        ]
        
        return mockTags
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
    static func createMockServices() -> (NetworkService, UserManager, AuthenticationService, AssetService, AlbumService, PeopleService, TagService) {
        let networkService = MockNetworkService()
        let userManager = UserManager()
        let authService = MockAuthenticationService(networkService: networkService, userManager: userManager)
        let assetService = MockAssetService(networkService: networkService)
        let albumService = MockAlbumService(networkService: networkService)
        let peopleService = MockPeopleService(networkService: networkService)
        let tagService = MockTagService(networkService: networkService)
        
        return (networkService, userManager, authService, assetService, albumService, peopleService, tagService)
    }
} 
