//
//  UserDefaults.swift
//  Immich Gallery
//
//  Created by Sanket Kumar on 2025-07-28.
//

import Foundation
// Extension to make overlay setting easily accessible throughout the app
extension UserDefaults {
    var hideImageOverlay: Bool {
        get { bool(forKey: "hideImageOverlay") }
        set { set(newValue, forKey: "hideImageOverlay") }
    }
    
    var slideshowInterval: TimeInterval {
        get { 
            let value = double(forKey: "slideshowInterval")
            return value > 0 ? value : 6.0
        }
        set { set(newValue, forKey: "slideshowInterval") }
    }
    
    var slideshowBackgroundColor: String {
        get { string(forKey: "slideshowBackgroundColor") ?? "black" }
        set { set(newValue, forKey: "slideshowBackgroundColor") }
    }
    
    var showTagsTab: Bool {
        get { bool(forKey: "showTagsTab") }
        set { set(newValue, forKey: "showTagsTab") }
    }
    
    var use24HourClock: Bool {
        get { bool(forKey: "use24HourClock") }
        set { set(newValue, forKey: "use24HourClock") }
    }
    
    var enableReflectionsInSlideshow: Bool {
        get { bool(forKey: "enableReflectionsInSlideshow") }
        set { set(newValue, forKey: "enableReflectionsInSlideshow") }
    }
    
    var enableKenBurnsEffect: Bool {
        get { bool(forKey: "enableKenBurnsEffect") }
        set { set(newValue, forKey: "enableKenBurnsEffect") }
    }
    
    var enableThumbnailAnimation: Bool {
        get { 
            // Default to true if the key doesn't exist yet
            if object(forKey: "enableThumbnailAnimation") == nil {
                return true
            }
            return bool(forKey: "enableThumbnailAnimation")
        }
        set { set(newValue, forKey: "enableThumbnailAnimation") }
    }
    
    var enableSlideshowShuffle: Bool {
        get { bool(forKey: "enableSlideshowShuffle") }
        set { set(newValue, forKey: "enableSlideshowShuffle") }
    }
}
