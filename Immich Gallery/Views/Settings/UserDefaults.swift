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
    
    var enableThumbnailAnimation: Bool {
        get { 
            // Default to true if the key doesn't exist yet
            if object(forKey: UserDefaultsKeys.enableThumbnailAnimation) == nil {
                return true
            }
            return bool(forKey: UserDefaultsKeys.enableThumbnailAnimation)
        }
        set { set(newValue, forKey: UserDefaultsKeys.enableThumbnailAnimation) }
    }
    
    var enableSlideshowShuffle: Bool {
        get { bool(forKey: UserDefaultsKeys.enableSlideshowShuffle) }
        set { set(newValue, forKey: UserDefaultsKeys.enableSlideshowShuffle) }
    }
    
    var navigationStyle: String {
        get { string(forKey: UserDefaultsKeys.navigationStyle) ?? NavigationStyle.tabs.rawValue }
        set { set(newValue, forKey: UserDefaultsKeys.navigationStyle) }
    }
    
    var allPhotosSortOrder: String {
        get { string(forKey: UserDefaultsKeys.allPhotosSortOrder) ?? "desc" }
        set { set(newValue, forKey: UserDefaultsKeys.allPhotosSortOrder) }
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

    var allPhotosFilterCities: Set<String> {
        get {
            guard let data = data(forKey: UserDefaultsKeys.allPhotosFilterCities),
                  let array = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return Set(array)
        }
        set {
            if newValue.isEmpty {
                removeObject(forKey: UserDefaultsKeys.allPhotosFilterCities)
            } else {
                if let data = try? JSONEncoder().encode(Array(newValue)) {
                    set(data, forKey: UserDefaultsKeys.allPhotosFilterCities)
                }
            }
        }
    }

    var allPhotosFilterYears: Set<Int> {
        get {
            guard let data = data(forKey: UserDefaultsKeys.allPhotosFilterYears),
                  let array = try? JSONDecoder().decode([Int].self, from: data) else {
                return []
            }
            return Set(array)
        }
        set {
            if newValue.isEmpty {
                removeObject(forKey: UserDefaultsKeys.allPhotosFilterYears)
            } else {
                if let data = try? JSONEncoder().encode(Array(newValue)) {
                    set(data, forKey: UserDefaultsKeys.allPhotosFilterYears)
                }
            }
        }
    }

    var hideAllPhotosFilterAndSortButtons: Bool {
        get { bool(forKey: UserDefaultsKeys.hideAllPhotosFilterAndSortButtons) }
        set { set(newValue, forKey: UserDefaultsKeys.hideAllPhotosFilterAndSortButtons) }
    }

    var appBackgroundStyle: String {
        get { string(forKey: UserDefaultsKeys.appBackgroundStyle) ?? "ocean" }
        set { set(newValue, forKey: UserDefaultsKeys.appBackgroundStyle) }
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
