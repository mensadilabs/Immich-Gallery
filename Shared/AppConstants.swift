//
//  AppConstants.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-08-12.
//
//⁠‌‌​​​​‌​‌​‌​‌​​‌​‌‌​‌‌​‌​‌‌​​‌​‌​‌‌​‌‌‌​​‌‌‌​​‌‌​‌‌​​​​‌​‌‌​​‌​​​‌‌​‌​​‌​‌‌​‌‌​​​‌‌​​​​‌​‌‌​​​‌​​‌‌‌​​‌‌⁠

import Foundation

/// Lightweight logger that compiles to a no-op in release builds.
/// Use for diagnostic logging that should not ship to production.
func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}

struct AppConstants {
    static let appGroupIdentifier = "group.com.sanketh.dev.Immich-Gallery"
    static let configAlbumName = "immich-gallery-config"
}

struct UserDefaultsKeys {
    // Immich credentials
    static let serverURL = "immich_server_url"
    static let accessToken = "immich_access_token"
    static let userEmail = "immich_user_email"
    static let userPrefix = "immich_user_"
    
    // Settings
    static let hideImageOverlay = "hideImageOverlay"
    static let showCurrentTimeWidget = "showCurrentTimeWidget"
    static let photoDateDisplayMode = "photoDateDisplayMode" // "dateAndTime" | "dateOnly" | "none"
    static let showLocationOverlay = "showLocationOverlay"
    static let slideshowInterval = "slideshowInterval"
    static let autoSlideshowTimeout = "autoSlideshowTimeout" // in minutes, 0 = off
    static let launchIntoSlideshow = "launchIntoSlideshow" // start slideshow automatically on app launch
    static let slideshowBackgroundColor = "slideshowBackgroundColor"
    static let showTagsTab = "showTagsTab"
    static let showFoldersTab = "showFoldersTab"
    static let showPhotosTab = "showPhotosTab"
    static let showAlbumsTab = "showAlbumsTab"
    static let showPeopleTab = "showPeopleTab"
    static let showExploreTab = "showExploreTab"
    static let showSearchTab = "showSearchTab"
    static let folderNameSortOrder = "folderNameSortOrder"
    static let use24HourClock = "use24HourClock"
    static let enableReflectionsInSlideshow = "enableReflectionsInSlideshow"
    static let enableKenBurnsEffect = "enableKenBurnsEffect"
    static let enableDynamicTransitions = "enableDynamicTransitions"
    static let enableThumbnailAnimation = "enableThumbnailAnimation"
    static let enableSlideshowShuffle = "enableSlideshowShuffle"
    static let reverseFullscreenHorizontalNavigation = "reverseFullscreenHorizontalNavigation"
    static let photosViewMode = "photosViewMode" // "grid" | "timeline"
    static let lockupThumbnailMode = "lockupThumbnailMode" // "current" | "random"
    static let allPhotosSortOrder = "allPhotosSortOrder"
    static let allPhotosFilterCity = "allPhotosFilterCity"
    static let allPhotosFilterState = "allPhotosFilterState"
    static let allPhotosFilterCountry = "allPhotosFilterCountry"
    static let allPhotosFilterCameraMake = "allPhotosFilterCameraMake"
    static let allPhotosFilterCameraModel = "allPhotosFilterCameraModel"
    static let allPhotosFilterLensModel = "allPhotosFilterLensModel"
    static let allPhotosFilterYear = "allPhotosFilterYear"
    static let appBackgroundStyle = "appBackgroundStyle"
    static let navigationStyle = "navigationStyle"
    static let enableTopShelf = "enableTopShelf"
    static let topShelfStyle = "topShelfStyle"
    static let topShelfImageSelection = "topShelfImageSelection"
    static let defaultStartupTab = "defaultStartupTab"
    static let lastSeenVersion = "lastSeenVersion"
    static let assetSortOrder = "assetSortOrder"
    static let showDiagnosticsOverlay = "showDiagnosticsOverlay"
    static let preferTranscodedVideoStreaming = "preferTranscodedVideoStreaming"

    // Art Mode settings
    static let artModeLevel = "artModeLevel"
    static let artModeAutomatic = "artModeAutomatic"
    static let artModeDayStart = "artModeDayStart"
    static let artModeNightStart = "artModeNightStart"
}

struct AppSchemes {
    static let immichGallery = "immichgallery"
}

struct NotificationNames {
    static let openAsset = "OpenAsset"
    static let refreshAllTabs = "refreshAllTabs"
    static let pauseInactivityMonitoring = "pauseInactivityMonitoring"
    static let resumeInactivityMonitoring = "resumeInactivityMonitoring"
}
