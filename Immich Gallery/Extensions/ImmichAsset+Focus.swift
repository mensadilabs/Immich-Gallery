//
//  ImmichAsset+Focus.swift
//  Immich Gallery
//

import Foundation

extension Array where Element == ImmichAsset {
    /// Resolves a tvOS focus identity to its position in the currently loaded
    /// asset ordering.
    func index(forFocusedAssetID focusedAssetID: String?) -> Int? {
        guard let focusedAssetID else { return nil }
        return firstIndex { $0.id == focusedAssetID }
    }
}
