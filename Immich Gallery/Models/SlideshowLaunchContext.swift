import Foundation

/// The complete All Photos query to continue when a user starts a slideshow.
/// It is intentionally separate from the auto-slideshow configuration album.
struct SlideshowLaunchContext: Equatable {
    /// The exact focused asset to locate in the slideshow's own query results.
    let startingAsset: ImmichAsset
    let filters: PhotoFilterSelection
    let favoritesOnly: Bool
    let assetType: AssetType?
    let sortOrder: String

    /// Creates an All Photos launch request from the exact tvOS-focused image.
    static func focused(
        focusedAssetID: String?,
        in assets: [ImmichAsset],
        filters: PhotoFilterSelection,
        favoritesOnly: Bool,
        assetType: AssetType?,
        sortOrder: String
    ) -> Self? {
        guard
            let focusedIndex = assets.index(forFocusedAssetID: focusedAssetID),
            assets[focusedIndex].type == .image
        else { return nil }

        return Self(
            startingAsset: assets[focusedIndex],
            filters: filters,
            favoritesOnly: favoritesOnly,
            assetType: assetType,
            sortOrder: sortOrder
        )
    }
}

struct SlideshowAssetPage<Element> {
    let items: [Element]
    let hasMore: Bool
}

struct LocatedSlideshowAssetPage<Element> {
    let page: Int
    let offset: Int
    let items: [Element]
    let hasMore: Bool
}

/// Searches the slideshow's own paginated results for its focused asset.
enum SlideshowStartPosition {
    static func find<Element>(
        assetID: String,
        fetchPage: (Int) async throws -> SlideshowAssetPage<Element>,
        id: (Element) -> String
    ) async throws -> LocatedSlideshowAssetPage<Element>? {
        var pageNumber = 1
        while true {
            try Task.checkCancellation()
            let page = try await fetchPage(pageNumber)
            if let offset = page.items.firstIndex(where: { id($0) == assetID }) {
                return LocatedSlideshowAssetPage(page: pageNumber, offset: offset, items: page.items, hasMore: page.hasMore)
            }
            guard page.hasMore else { return nil }
            pageNumber += 1
        }
    }
}
