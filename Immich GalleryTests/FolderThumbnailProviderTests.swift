import Testing
import UIKit
@testable import Immich_Gallery

struct FolderThumbnailProviderTests {
    @Test func usesGeneratedThumbnailWhenFoldersFirstAssetIsVideo() async {
        let video = Self.makeAsset(id: "folder-video-\(UUID())", type: .video)
        let service = FolderThumbnailAssetService(defaultAsset: video)
        let provider = FolderThumbnailProvider(assetService: service)

        let thumbnail = await provider.loadCoverThumbnail(
            for: ImmichFolder(path: "/library/family"),
            mode: LockupThumbnailMode.current
        )

        #expect(thumbnail != nil)
        #expect(service.loadedAssetIDs == [video.id])
        #expect(service.requests.count == 1)
        #expect(service.requests.first?.folderPath == "/library/family")
    }

    @Test func randomFolderThumbnailUsesFolderScopedRandomSearch() async {
        let image = Self.makeAsset(id: "random-folder-image-\(UUID())", type: .image)
        let service = FolderThumbnailAssetService(defaultAsset: image)
        let provider = FolderThumbnailProvider(assetService: service)

        let thumbnail = await provider.loadCoverThumbnail(
            for: ImmichFolder(path: "/library/2025"),
            mode: LockupThumbnailMode.random
        )

        #expect(thumbnail != nil)
        #expect(service.requests.isEmpty)
        #expect(service.randomFolderPaths == ["/library/2025"])
    }

    @Test func randomSearchUsesImmichV3FilterSyntax() {
        let request = AssetService.randomSearchRequest(
            albumIds: ["album-id"],
            personIds: ["person-id"],
            tagIds: ["tag-id"],
            folderPath: "/library/2025",
            limit: 10
        )
        let filter = request["filter"] as? [String: Any]
        let albumIds = filter?["albumIds"] as? [String: [String]]
        let personIds = filter?["personIds"] as? [String: [String]]
        let tagIds = filter?["tagIds"] as? [String: [String]]
        let originalPath = filter?["originalPath"] as? [String: String]

        #expect(request["albumIds"] == nil)
        #expect(request["personIds"] == nil)
        #expect(request["tagIds"] == nil)
        #expect(request["originalPath"] == nil)
        #expect(albumIds?["any"] == ["album-id"])
        #expect(personIds?["any"] == ["person-id"])
        #expect(tagIds?["any"] == ["tag-id"])
        #expect(originalPath?["startsWith"] == "/library/2025")
    }

    private static func makeAsset(id: String, type: AssetType) -> ImmichAsset {
        ImmichAsset(
            id: id,
            deviceAssetId: nil,
            deviceId: nil,
            ownerId: "user-1",
            libraryId: nil,
            type: type,
            originalPath: "/library/\(id)",
            originalFileName: id,
            originalMimeType: type == .video ? "video/mp4" : "image/jpeg",
            resized: true,
            thumbhash: nil,
            fileModifiedAt: "2026-01-01T00:00:00.000Z",
            fileCreatedAt: "2026-01-01T00:00:00.000Z",
            localDateTime: "2026-01-01T00:00:00.000Z",
            updatedAt: "2026-01-01T00:00:00.000Z",
            isFavorite: false,
            isArchived: false,
            isOffline: false,
            isTrashed: false,
            checksum: id,
            duration: type == .video ? "0:10:00.00000" : nil,
            hasMetadata: true,
            livePhotoVideoId: nil,
            people: [],
            visibility: "timeline",
            duplicateId: nil,
            exifInfo: nil
        )
    }
}

private final class FolderThumbnailAssetService: AssetService {
    struct Request {
        let page: Int
        let folderPath: String?
    }

    private let defaultAsset: ImmichAsset

    private(set) var requests: [Request] = []
    private(set) var loadedAssetIDs: [String] = []
    private(set) var randomFolderPaths: [String?] = []

    init(defaultAsset: ImmichAsset) {
        self.defaultAsset = defaultAsset
        super.init(networkService: NetworkService(userManager: UserManager()))
    }

    override func fetchAssets(
        page: Int = 1,
        limit: Int? = nil,
        albumId: String? = nil,
        personId: String? = nil,
        tagId: String? = nil,
        city: String? = nil,
        isAllPhotos: Bool = false,
        isFavorite: Bool = false,
        folderPath: String? = nil,
        assetType: AssetType? = nil,
        filters: PhotoFilterSelection? = nil,
        sortOrder explicitSortOrder: String? = nil
    ) async throws -> SearchResult {
        requests.append(Request(page: page, folderPath: folderPath))
        return SearchResult(assets: [defaultAsset], total: 1, nextPage: nil)
    }

    override func fetchRandomAssets(
        albumIds: [String]? = nil,
        personIds: [String]? = nil,
        tagIds: [String]? = nil,
        folderPath: String? = nil,
        limit: Int = 50
    ) async throws -> SearchResult {
        randomFolderPaths.append(folderPath)
        return SearchResult(assets: [defaultAsset], total: 1, nextPage: nil)
    }

    override func loadImage(assetId: String, size: String = "thumbnail") async throws -> UIImage? {
        loadedAssetIDs.append(assetId)
        return UIImage(systemName: "photo")
    }
}
