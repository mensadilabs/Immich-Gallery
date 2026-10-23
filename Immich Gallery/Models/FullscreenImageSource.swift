//
//  FullscreenImageSource.swift
//  Immich Gallery
//

/// Which image the slideshow and fullscreen viewer load for photos.
enum FullscreenImageSource: String {
    /// The original file, downsampled on device to the screen size.
    case original
    /// Immich's server-generated preview (WebP, resized by the server).
    case preview
}
