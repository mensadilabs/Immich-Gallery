//
//  ImmichModels.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import Foundation
import SwiftUI

// MARK: - Asset Models
struct ImmichAsset: Codable, Identifiable, Equatable {
    let id: String
    let deviceAssetId: String?
    let deviceId: String?
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
    let stack: Stack?
    
    enum CodingKeys: String, CodingKey {
        case id, deviceAssetId, deviceId, ownerId, libraryId, type, originalPath, originalFileName
        case originalMimeType, resized, thumbhash, fileModifiedAt, fileCreatedAt, localDateTime, updatedAt
        case isFavorite, isArchived, isOffline, isTrashed, checksum, duration, hasMetadata, livePhotoVideoId
        case people, visibility, duplicateId, exifInfo, stack
    }

    init(
        id: String,
        deviceAssetId: String?,
        deviceId: String?,
        ownerId: String,
        libraryId: String?,
        type: AssetType,
        originalPath: String,
        originalFileName: String,
        originalMimeType: String?,
        resized: Bool?,
        thumbhash: String?,
        fileModifiedAt: String,
        fileCreatedAt: String,
        localDateTime: String,
        updatedAt: String,
        isFavorite: Bool,
        isArchived: Bool,
        isOffline: Bool,
        isTrashed: Bool,
        checksum: String,
        duration: String?,
        hasMetadata: Bool,
        livePhotoVideoId: String?,
        people: [Person],
        visibility: String,
        duplicateId: String?,
        exifInfo: ExifInfo?,
        stack: Stack? = nil
    ) {
        self.id = id
        self.deviceAssetId = deviceAssetId
        self.deviceId = deviceId
        self.ownerId = ownerId
        self.libraryId = libraryId
        self.type = type
        self.originalPath = originalPath
        self.originalFileName = originalFileName
        self.originalMimeType = originalMimeType
        self.resized = resized
        self.thumbhash = thumbhash
        self.fileModifiedAt = fileModifiedAt
        self.fileCreatedAt = fileCreatedAt
        self.localDateTime = localDateTime
        self.updatedAt = updatedAt
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.isOffline = isOffline
        self.isTrashed = isTrashed
        self.checksum = checksum
        self.duration = duration
        self.hasMetadata = hasMetadata
        self.livePhotoVideoId = livePhotoVideoId
        self.people = people
        self.visibility = visibility
        self.duplicateId = duplicateId
        self.exifInfo = exifInfo
        self.stack = stack
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        deviceAssetId = try container.decodeIfPresent(String.self, forKey: .deviceAssetId)
        deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
        ownerId = try container.decode(String.self, forKey: .ownerId)
        libraryId = try container.decodeIfPresent(String.self, forKey: .libraryId)
        type = try container.decode(AssetType.self, forKey: .type)
        originalPath = try container.decode(String.self, forKey: .originalPath)
        originalFileName = try container.decode(String.self, forKey: .originalFileName)
        originalMimeType = try container.decodeIfPresent(String.self, forKey: .originalMimeType)
        resized = try container.decodeIfPresent(Bool.self, forKey: .resized)
        thumbhash = try container.decodeIfPresent(String.self, forKey: .thumbhash)
        fileModifiedAt = try container.decode(String.self, forKey: .fileModifiedAt)
        fileCreatedAt = try container.decode(String.self, forKey: .fileCreatedAt)
        localDateTime = try container.decode(String.self, forKey: .localDateTime)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        isArchived = try container.decode(Bool.self, forKey: .isArchived)
        isOffline = try container.decode(Bool.self, forKey: .isOffline)
        isTrashed = try container.decode(Bool.self, forKey: .isTrashed)
        checksum = try container.decode(String.self, forKey: .checksum)
        if let stringDuration = try? container.decodeIfPresent(String.self, forKey: .duration) {
            duration = stringDuration
        } else if let intDuration = try? container.decodeIfPresent(Int.self, forKey: .duration) {
            duration = String(intDuration)
        } else {
            duration = nil
        }
        hasMetadata = try container.decode(Bool.self, forKey: .hasMetadata)
        livePhotoVideoId = try container.decodeIfPresent(String.self, forKey: .livePhotoVideoId)
        people = try container.decodeIfPresent([Person].self, forKey: .people) ?? []
        visibility = try container.decodeIfPresent(String.self, forKey: .visibility) ?? "timeline"
        duplicateId = try container.decodeIfPresent(String.self, forKey: .duplicateId)
        exifInfo = try container.decodeIfPresent(ExifInfo.self, forKey: .exifInfo)
        stack = try container.decodeIfPresent(Stack.self, forKey: .stack)
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

struct StackResponse: Codable {
    let id: String
    let primaryAssetId: String
    let assets: [ImmichAsset]
}

struct Owner: Codable {
    let id: String
    let email: String
    let name: String
    let profileImagePath: String
    let profileChangedAt: String
    let avatarColor: String
}

// MARK: - User Model for /api/users/me endpoint
struct User: Codable {
    let id: String
    let email: String
    let name: String
    let profileImagePath: String
    let profileChangedAt: String
    let avatarColor: String
    let createdAt: String
    let updatedAt: String
    let deletedAt: String?
    let isAdmin: Bool
    let shouldChangePassword: Bool
    let status: String
    let storageLabel: String?
    let oauthId: String?
    let quotaSizeInBytes: Int64?
    let quotaUsageInBytes: Int64?
    let license: UserLicense?
    
    enum CodingKeys: String, CodingKey {
        case id, email, name, profileImagePath, profileChangedAt, avatarColor
        case createdAt, updatedAt, deletedAt, isAdmin, shouldChangePassword, status
        case storageLabel, oauthId, quotaSizeInBytes, quotaUsageInBytes, license
    }
}

struct UserLicense: Codable {
    let activatedAt: String?
    let activationKey: String?
    let licenseKey: String?
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
    let ownerId: String?
    let owner: Owner?
    let shared: Bool
    let hasSharedLink: Bool
    let isActivityEnabled: Bool
    let lastModifiedAssetTimestamp: String?
    let order: String?
    let startDate: String?
    let endDate: String?

    enum CodingKeys: String, CodingKey {
        case id, albumName, description, albumThumbnailAssetId, createdAt, updatedAt, albumUsers
        case assets, assetCount, ownerId, owner, shared, hasSharedLink, isActivityEnabled
        case lastModifiedAssetTimestamp, order, startDate, endDate
    }

    init(
        id: String,
        albumName: String,
        description: String?,
        albumThumbnailAssetId: String?,
        createdAt: String,
        updatedAt: String,
        albumUsers: [AlbumUser],
        assets: [ImmichAsset],
        assetCount: Int,
        ownerId: String?,
        owner: Owner?,
        shared: Bool,
        hasSharedLink: Bool,
        isActivityEnabled: Bool,
        lastModifiedAssetTimestamp: String?,
        order: String?,
        startDate: String?,
        endDate: String?
    ) {
        self.id = id
        self.albumName = albumName
        self.description = description
        self.albumThumbnailAssetId = albumThumbnailAssetId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.albumUsers = albumUsers
        self.assets = assets
        self.assetCount = assetCount
        self.ownerId = ownerId
        self.owner = owner
        self.shared = shared
        self.hasSharedLink = hasSharedLink
        self.isActivityEnabled = isActivityEnabled
        self.lastModifiedAssetTimestamp = lastModifiedAssetTimestamp
        self.order = order
        self.startDate = startDate
        self.endDate = endDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        albumName = try container.decode(String.self, forKey: .albumName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        albumThumbnailAssetId = try container.decodeIfPresent(String.self, forKey: .albumThumbnailAssetId)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        albumUsers = try container.decodeIfPresent([AlbumUser].self, forKey: .albumUsers) ?? []
        assets = try container.decodeIfPresent([ImmichAsset].self, forKey: .assets) ?? []
        assetCount = try container.decode(Int.self, forKey: .assetCount)
        let decodedOwner = try container.decodeIfPresent(Owner.self, forKey: .owner)
        owner = decodedOwner ?? albumUsers.first?.user
        ownerId = try container.decodeIfPresent(String.self, forKey: .ownerId) ?? owner?.id
        shared = try container.decodeIfPresent(Bool.self, forKey: .shared) ?? !albumUsers.isEmpty
        hasSharedLink = try container.decodeIfPresent(Bool.self, forKey: .hasSharedLink) ?? false
        isActivityEnabled = try container.decodeIfPresent(Bool.self, forKey: .isActivityEnabled) ?? false
        lastModifiedAssetTimestamp = try container.decodeIfPresent(String.self, forKey: .lastModifiedAssetTimestamp)
        order = try container.decodeIfPresent(String.self, forKey: .order)
        startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(String.self, forKey: .endDate)
    }
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

struct AssetStatistics: Codable {
    let images: Int
    let total: Int
    let videos: Int
}
// MARK: Moved by Human

import SwiftUI

// MARK: - Folder Model
struct ImmichFolder: Identifiable, Equatable, Hashable {
    let path: String
    
    var id: String { path }
    var primaryTitle: String {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmed.isEmpty {
            return path
        }
        return trimmed.components(separatedBy: "/").last ?? trimmed
    }
    var secondaryTitle: String? { path }
    var description: String? { nil }
    var thumbnailId: String? { nil }
    var itemCount: Int? { nil }
    var gridCreatedAt: String? { nil }
    var isFavorite: Bool? { nil }
    var isShared: Bool? { nil }
    var sharingText: String? { nil }
    var iconName: String { "folder.fill" }
    var gridColor: Color? { Color.blue.opacity(0.5) }
}



// MARK: - Explore Data Models
struct ExploreAsset: Identifiable {
    let asset: ImmichAsset
    
    var id: String { asset.id }
    var primaryTitle: String { 
        asset.exifInfo?.city ?? ""
    }
    var secondaryTitle: String? { 
        if let state = asset.exifInfo?.state, let country = asset.exifInfo?.country {
            return "\(state), \(country)"
        }
        return asset.exifInfo?.state ?? asset.exifInfo?.country
    }
    var description: String? { nil }
    var thumbnailId: String? { asset.id }
    var itemCount: Int? { nil }
    var gridCreatedAt: String? { asset.fileCreatedAt }
    var isFavorite: Bool? { asset.isFavorite }
    var isShared: Bool? { false }
    var sharingText: String? { nil }
    var iconName: String { "photo" }
    var gridColor: Color? { nil }
} 

extension ImmichAsset {
    /// Video length for display on thumbnails, e.g. "0:12" or "1:02:03".
    /// Nil for images and for durations that are missing, zero, or unparseable.
    var displayDuration: String? {
        guard type == .video, let duration else { return nil }
        return Self.formatDuration(duration)
    }

    /// Formats Immich's "H:MM:SS.ffffff" duration string.
    static func formatDuration(_ raw: String) -> String? {
        let parts = raw.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 3 else { return nil }
        let seconds = parts.reduce(0) { $0 * 60 + $1 }
        guard seconds > 0 else { return nil }
        return Duration.seconds(max(1, seconds.rounded()))
            .formatted(.time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
    }
}
