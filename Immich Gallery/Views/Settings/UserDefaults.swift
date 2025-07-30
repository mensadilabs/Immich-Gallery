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
        get { double(forKey: "slideshowInterval") }
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
    
    var disableReflectionsInSlideshow: Bool {
        get { bool(forKey: "disableReflectionsInSlideshow") }
        set { set(newValue, forKey: "disableReflectionsInSlideshow") }
    }
    
    var enableKenBurnsEffect: Bool {
        get { bool(forKey: "enableKenBurnsEffect") }
        set { set(newValue, forKey: "enableKenBurnsEffect") }
    }
}
