import Foundation

/// The complete All Photos query to continue when a user starts a slideshow.
/// It is intentionally separate from the auto-slideshow configuration album.
struct SlideshowLaunchContext: Equatable {
    /// The exact focused asset is queued first instead of relying solely on a
    /// cross-endpoint index calculation.
    let startingAsset: ImmichAsset
    let startingIndex: Int
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

        let startingAsset = assets[focusedIndex]
        let imageIndex = assets.prefix(focusedIndex + 1).filter { $0.type == .image }.count - 1
        return Self(
            startingAsset: startingAsset,
            startingIndex: imageIndex,
            filters: filters,
            favoritesOnly: favoritesOnly,
            assetType: assetType,
            sortOrder: sortOrder
        )
    }
}
