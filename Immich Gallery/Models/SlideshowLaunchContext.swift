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
}
