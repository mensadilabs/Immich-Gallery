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

/// Finds the focused item in the slideshow's own paginated query results.
enum SlideshowStartPosition {
    static func locate(assetID: String, pages: [[String]]) -> (page: Int, offset: Int)? {
        for (page, ids) in pages.enumerated() {
            if let offset = ids.firstIndex(of: assetID) {
                return (page: page + 1, offset: offset)
            }
        }
        return nil
    }
}
