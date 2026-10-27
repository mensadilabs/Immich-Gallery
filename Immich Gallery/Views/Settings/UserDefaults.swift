//
//  UserDefaults.swift
//  Immich Gallery
//
//  Created by mensadi labs on 2025-07-28.
//

import Foundation
// Extension to make overlay setting easily accessible throughout the app
extension UserDefaults {
    var autoSlideshowTimeout: Int {
        get {
            let value = integer(forKey: UserDefaultsKeys.autoSlideshowTimeout)
            return value >= 0 ? value : 0 // 0 = off
        }
        set { set(newValue, forKey: UserDefaultsKeys.autoSlideshowTimeout) }
    }
    var hideImageOverlay: Bool {
        get { bool(forKey: UserDefaultsKeys.hideImageOverlay) }
        set { set(newValue, forKey: UserDefaultsKeys.hideImageOverlay) }
    }

    var showCurrentTimeWidget: Bool {
        get {
            if object(forKey: UserDefaultsKeys.showCurrentTimeWidget) == nil { return true }
            return bool(forKey: UserDefaultsKeys.showCurrentTimeWidget)
        }
        set { set(newValue, forKey: UserDefaultsKeys.showCurrentTimeWidget) }
    }

    var photoDateDisplayMode: String {
        get { string(forKey: UserDefaultsKeys.photoDateDisplayMode) ?? "dateAndTime" }
        set { set(newValue, forKey: UserDefaultsKeys.photoDateDisplayMode) }
    }

    var showLocationOverlay: Bool {
        get {
            if object(forKey: UserDefaultsKeys.showLocationOverlay) == nil { return true }
            return bool(forKey: UserDefaultsKeys.showLocationOverlay)
        }
        set { set(newValue, forKey: UserDefaultsKeys.showLocationOverlay) }
    }

    var preferTranscodedVideoStreaming: Bool {
        get {
            if object(forKey: UserDefaultsKeys.preferTranscodedVideoStreaming) == nil { return true }
            return bool(forKey: UserDefaultsKeys.preferTranscodedVideoStreaming)
        }
        set { set(newValue, forKey: UserDefaultsKeys.preferTranscodedVideoStreaming) }
    }
    
    var slideshowInterval: TimeInterval {
        get { 
            let value = double(forKey: UserDefaultsKeys.slideshowInterval)
            return value > 0 ? value : 6.0
        }
        set { set(newValue, forKey: UserDefaultsKeys.slideshowInterval) }
    }
    
    var slideshowBackgroundColor: String {
        get { string(forKey: UserDefaultsKeys.slideshowBackgroundColor) ?? "black" }
        set { set(newValue, forKey: UserDefaultsKeys.slideshowBackgroundColor) }
    }
    
    var showTagsTab: Bool {
        get { bool(forKey: UserDefaultsKeys.showTagsTab) }
        set { set(newValue, forKey: UserDefaultsKeys.showTagsTab) }
    }
    
    var showFoldersTab: Bool {
        get { bool(forKey: UserDefaultsKeys.showFoldersTab) }
        set { set(newValue, forKey: UserDefaultsKeys.showFoldersTab) }
    }
    
    var use24HourClock: Bool {
        get { bool(forKey: UserDefaultsKeys.use24HourClock) }
        set { set(newValue, forKey: UserDefaultsKeys.use24HourClock) }
    }
    
    var enableReflectionsInSlideshow: Bool {
        get { bool(forKey: UserDefaultsKeys.enableReflectionsInSlideshow) }
        set { set(newValue, forKey: UserDefaultsKeys.enableReflectionsInSlideshow) }
    }
    
    var enableKenBurnsEffect: Bool {
        get { bool(forKey: UserDefaultsKeys.enableKenBurnsEffect) }
        set { set(newValue, forKey: UserDefaultsKeys.enableKenBurnsEffect) }
    }

    var enableDynamicTransitions: Bool {
        get { bool(forKey: UserDefaultsKeys.enableDynamicTransitions) }
        set { set(newValue, forKey: UserDefaultsKeys.enableDynamicTransitions) }
    }
    
    var enableSlideshowShuffle: Bool {
        get { bool(forKey: UserDefaultsKeys.enableSlideshowShuffle) }
        set { set(newValue, forKey: UserDefaultsKeys.enableSlideshowShuffle) }
    }

    var reverseFullscreenHorizontalNavigation: Bool {
        get { bool(forKey: UserDefaultsKeys.reverseFullscreenHorizontalNavigation) }
        set { set(newValue, forKey: UserDefaultsKeys.reverseFullscreenHorizontalNavigation) }
    }
    
    var navigationStyle: String {
        get { string(forKey: UserDefaultsKeys.navigationStyle) ?? NavigationStyle.tabs.rawValue }
        set { set(newValue, forKey: UserDefaultsKeys.navigationStyle) }
    }
    
    var photosViewMode: String {
        get { string(forKey: UserDefaultsKeys.photosViewMode) ?? "timeline" }
        set { set(newValue, forKey: UserDefaultsKeys.photosViewMode) }
    }

    var lockupThumbnailMode: String {
        get { string(forKey: UserDefaultsKeys.lockupThumbnailMode) ?? LockupThumbnailMode.current.rawValue }
        set { set(newValue, forKey: UserDefaultsKeys.lockupThumbnailMode) }
    }

    var allPhotosSortOrder: String {
        get { string(forKey: UserDefaultsKeys.allPhotosSortOrder) ?? "desc" }
        set { set(newValue, forKey: UserDefaultsKeys.allPhotosSortOrder) }
    }

    var assetSortOrder: String {
        get { string(forKey: UserDefaultsKeys.assetSortOrder) ?? "desc" }
        set { set(newValue, forKey: UserDefaultsKeys.assetSortOrder) }
    }

    var allPhotosFilterCity: String? {
        get { string(forKey: UserDefaultsKeys.allPhotosFilterCity) }
        set {
            if let value = newValue, !value.isEmpty {
                set(value, forKey: UserDefaultsKeys.allPhotosFilterCity)
            } else {
                removeObject(forKey: UserDefaultsKeys.allPhotosFilterCity)
            }
        }
    }

    var allPhotosFilterState: String? {
        get { optionalFilterString(forKey: UserDefaultsKeys.allPhotosFilterState) }
        set { setOptionalFilterString(newValue, forKey: UserDefaultsKeys.allPhotosFilterState) }
    }

    var allPhotosFilterCountry: String? {
        get { optionalFilterString(forKey: UserDefaultsKeys.allPhotosFilterCountry) }
        set { setOptionalFilterString(newValue, forKey: UserDefaultsKeys.allPhotosFilterCountry) }
    }

    var allPhotosFilterCameraMake: String? {
        get { optionalFilterString(forKey: UserDefaultsKeys.allPhotosFilterCameraMake) }
        set { setOptionalFilterString(newValue, forKey: UserDefaultsKeys.allPhotosFilterCameraMake) }
    }

    var allPhotosFilterCameraModel: String? {
        get { optionalFilterString(forKey: UserDefaultsKeys.allPhotosFilterCameraModel) }
        set { setOptionalFilterString(newValue, forKey: UserDefaultsKeys.allPhotosFilterCameraModel) }
    }

    var allPhotosFilterLensModel: String? {
        get { optionalFilterString(forKey: UserDefaultsKeys.allPhotosFilterLensModel) }
        set { setOptionalFilterString(newValue, forKey: UserDefaultsKeys.allPhotosFilterLensModel) }
    }

    var allPhotosFilterYear: Int? {
        get { object(forKey: UserDefaultsKeys.allPhotosFilterYear) as? Int }
        set {
            if let value = newValue {
                set(value, forKey: UserDefaultsKeys.allPhotosFilterYear)
            } else {
                removeObject(forKey: UserDefaultsKeys.allPhotosFilterYear)
            }
        }
    }

    var appBackgroundStyle: String {
        get { string(forKey: UserDefaultsKeys.appBackgroundStyle) ?? "graphite" }
        set { set(newValue, forKey: UserDefaultsKeys.appBackgroundStyle) }
    }

    private func optionalFilterString(forKey key: String) -> String? {
        string(forKey: key)
    }

    private func setOptionalFilterString(_ value: String?, forKey key: String) {
        if let value, !value.isEmpty {
            set(value, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }
    
    var artModeLevel: String {
        get { string(forKey: UserDefaultsKeys.artModeLevel) ?? "off" }
        set { set(newValue, forKey: UserDefaultsKeys.artModeLevel) }
    }
    
    var artModeAutomatic: Bool {
        get { bool(forKey: UserDefaultsKeys.artModeAutomatic) }
        set { set(newValue, forKey: UserDefaultsKeys.artModeAutomatic) }
    }
    
    var artModeDayStart: Int {
        get { integer(forKey: UserDefaultsKeys.artModeDayStart) != 0 ? integer(forKey: UserDefaultsKeys.artModeDayStart) : 7 } // Default 7 AM
        set { set(newValue, forKey: UserDefaultsKeys.artModeDayStart) }
    }
    
    var artModeNightStart: Int {
        get { integer(forKey: UserDefaultsKeys.artModeNightStart) != 0 ? integer(forKey: UserDefaultsKeys.artModeNightStart) : 20 } // Default 8 PM
        set { set(newValue, forKey: UserDefaultsKeys.artModeNightStart) }
    }
}
