//
//  AppConstants.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-08-12.
//

import Foundation

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
    static let slideshowInterval = "slideshowInterval"
    static let autoSlideshowTimeout = "autoSlideshowTimeout" // in minutes, 0 = off
    static let slideshowBackgroundColor = "slideshowBackgroundColor"
    static let showTagsTab = "showTagsTab"
    static let use24HourClock = "use24HourClock"
    static let enableReflectionsInSlideshow = "enableReflectionsInSlideshow"
    static let enableKenBurnsEffect = "enableKenBurnsEffect"
    static let enableThumbnailAnimation = "enableThumbnailAnimation"
    static let enableSlideshowShuffle = "enableSlideshowShuffle"
    static let allPhotosSortOrder = "allPhotosSortOrder"
    static let enableTopShelf = "enableTopShelf"
    static let topShelfStyle = "topShelfStyle"
    static let defaultStartupTab = "defaultStartupTab"
    static let lastSeenVersion = "lastSeenVersion"
    static let assetSortOrder = "assetSortOrder"
    
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
    static let startAutoSlideshow = "startAutoSlideshow"
}
