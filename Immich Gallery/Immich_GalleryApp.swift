//
//  Immich_GalleryApp.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

@main
struct Immich_GalleryApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }
    
    private func handleURL(_ url: URL) {
        guard url.scheme == AppSchemes.immichGallery else { return }
        
        if url.host == "asset", url.pathComponents.count > 1 {
            let assetId = url.pathComponents[1]
            
            NotificationCenter.default.post(
                name: NSNotification.Name(NotificationNames.openAsset),
                object: nil,
                userInfo: ["assetId": assetId]
            )
        }
    }
}
