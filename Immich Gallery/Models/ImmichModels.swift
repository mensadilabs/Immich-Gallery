//
//  ImmichModels.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import Foundation

// MARK: - Asset Models
struct ImmichAsset: Codable, Identifiable, Equatable {
    let id: String
    let deviceAssetId: String
    let deviceId: String
    let ownerId: String
    let libraryId: String?
    let type: AssetType
    let originalPath: String
    let originalFileName: String
    let originalMimeType: String?
    let resized: Bool?
    let thumbhash: String?
    let fileModifiedAt: String
    let fileCreatedAt: String
    let localDateTime: String
    let updatedAt: String
    let isFavorite: Bool
    let isArchived: Bool
    let isOffline: Bool
    let isTrashed: Bool
    let checksum: String
    let duration: String?
    let hasMetadata: Bool
    let livePhotoVideoId: String?
    let people: [Person]
    let visibility: String
    let duplicateId: String?
    let exifInfo: ExifInfo?
    
    enum CodingKeys: String, CodingKey {
        case id, deviceAssetId, deviceId, ownerId, libraryId, type, originalPath, originalFileName
        case originalMimeType, resized, thumbhash, fileModifiedAt, fileCreatedAt, localDateTime, updatedAt
        case isFavorite, isArchived, isOffline, isTrashed, checksum, duration, hasMetadata, livePhotoVideoId
        case people, visibility, duplicateId, exifInfo
    }
    
    // Equatable conformance - compare by id since it should be unique
    static func == (lhs: ImmichAsset, rhs: ImmichAsset) -> Bool {
        return lhs.id == rhs.id
    }
}

enum AssetType: String, Codable {
    case image = "IMAGE"
    case video = "VIDEO"
    case audio = "AUDIO"
    case other = "OTHER"
}

struct ExifInfo: Codable {
    let make: String?
    let model: String?
    let imageName: String?
    let exifImageWidth: Int?
    let exifImageHeight: Int?
    let dateTimeOriginal: String?
    let modifyDate: String?
    let lensModel: String?
    let fNumber: Double?
    let focalLength: Double?
    let iso: Int?
    let exposureTime: String?
    let latitude: Double?
    let longitude: Double?
    let city: String?
    let state: String?
    let country: String?
    let timeZone: String?
    let description: String?
    let fileSizeInByte: Int64?
    let orientation: String?
    let projectionType: String?
    let rating: Int?
    
    enum CodingKeys: String, CodingKey {
        case make, model, imageName, exifImageWidth, exifImageHeight, dateTimeOriginal, modifyDate
        case lensModel, fNumber, focalLength, iso, exposureTime, latitude, longitude, city, state, country
        case timeZone, description, fileSizeInByte, orientation, projectionType, rating
    }
}

struct Tag: Codable, Identifiable {
    let id: String
    let name: String
    let value: String
    let color: String?
    let createdAt: String
    let updatedAt: String
    let parentId: String?
}

struct Person: Codable, Identifiable {
    let id: String
    let name: String
    let birthDate: String?
    let thumbnailPath: String
    let isHidden: Bool
    let isFavorite: Bool?
    let updatedAt: String?
    let color: String?
    let faces: [Face]
}

struct Face: Codable, Identifiable {
    let id: String
    let boundingBoxX1: Int
    let boundingBoxY1: Int
    let boundingBoxX2: Int
    let boundingBoxY2: Int
    let imageWidth: Int
    let imageHeight: Int
    let sourceType: String?
}

struct Stack: Codable {
    let id: String
    let primaryAssetId: String
    let assetCount: Int
}

struct Owner: Codable {
    let id: String
    let email: String
    let name: String
    let profileImagePath: String
    let profileChangedAt: String
    let avatarColor: String
}

// MARK: - Album Models
struct ImmichAlbum: Codable, Identifiable {
    let id: String
    let albumName: String
    let description: String?
    let albumThumbnailAssetId: String?
    let createdAt: String
    let updatedAt: String
    let albumUsers: [AlbumUser]
    let assets: [ImmichAsset]
    let assetCount: Int
    let ownerId: String
    let owner: Owner
    let shared: Bool
    let hasSharedLink: Bool
    let isActivityEnabled: Bool
    let lastModifiedAssetTimestamp: String?
    let order: String?
    let startDate: String?
    let endDate: String?
}

struct AlbumUser: Codable {
    let role: String
    let user: Owner
}

// MARK: - API Response Models
struct SearchResponse: Codable {
    let albums: AlbumSection
    let assets: AssetSection
}

struct AlbumSection: Codable {
    let total: Int
    let count: Int
    let items: [ImmichAlbum]
    let facets: [Facet]
}

struct AssetSection: Codable {
    let total: Int
    let count: Int
    let items: [ImmichAsset]
    let facets: [Facet]
    let nextPage: String?
}

struct Facet: Codable {
    let fieldName: String
    let counts: [FacetCount]
}

struct FacetCount: Codable {
    let count: Int
    let value: String
}

struct AlbumsResponse: Codable {
    let albums: [ImmichAlbum]
}

// MARK: - Search Result Model
struct SearchResult: Codable {
    let assets: [ImmichAsset]
    let total: Int
    let nextPage: String?
}

struct AuthResponse: Codable {
    let accessToken: String
    let userId: String
    let userEmail: String
    let name: String
    let isAdmin: Bool
    let profileImagePath: String
    let shouldChangePassword: Bool
    let isOnboarded: Bool
} 