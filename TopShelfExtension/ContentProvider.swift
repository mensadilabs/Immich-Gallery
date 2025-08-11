//
//  ContentProvider.swift
//  TopShelfExtension
//
//  Created by mensadi-labs on 2025-08-11.
//

import TVServices
import Foundation

class ContentProvider: TVTopShelfContentProvider {

    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        print("TopShelf: loadTopShelfContent() called")
        do {
            let content = try await createTopShelfContent()
            print("TopShelf: Successfully created content with sections")
            return content
        } catch {
            print("TopShelf: Failed to load top shelf content: \(error)")
            let fallback = createFallbackContent()
            print("TopShelf: Returning fallback content")
            return fallback
        }
    }
    
    private func createTopShelfContent() async throws -> TVTopShelfContent {
        print("TopShelf: Starting to create TopShelf content")
        let assets = try await fetchFirst5Photos()
        print("TopShelf: Fetched \(assets.count) assets")
        
        let sectionItems = await withTaskGroup(of: TVTopShelfSectionedItem?.self) { group in
            for (index, asset) in assets.enumerated() {
                group.addTask {
                    print("TopShelf: Processing asset \(index + 1)/\(assets.count): \(asset.originalFileName)")
                    return await self.createTopShelfItem(for: asset)
                }
            }
            
            var items: [TVTopShelfSectionedItem] = []
            for await item in group {
                if let item = item {
                    print("TopShelf: Successfully created item: \(item.title ?? "No title")")
                    items.append(item)
                } else {
                    print("TopShelf: Failed to create item")
                }
            }
            print("TopShelf: Created \(items.count) items total")
            return items
        }
        
        let section = TVTopShelfItemCollection(items: sectionItems)
        section.title = "Recent Photos"
        
        let content = TVTopShelfSectionedContent(sections: [section])
        print("TopShelf: Created sectioned content with \(sectionItems.count) items")
        return content
    }
    
    private func createTopShelfItem(for asset: SimpleAsset) async -> TVTopShelfSectionedItem? {
        print("TopShelf: Creating item for asset: \(asset.id)")
        guard let url = URL(string: "immichgallery://asset/\(asset.id)") else { 
            print("TopShelf: Failed to create deep link URL for asset: \(asset.id)")
            return nil 
        }
        
        let item = TVTopShelfSectionedItem(identifier: asset.id)
        item.title = asset.originalFileName
        item.displayAction = TVTopShelfAction(url: url)
        print("TopShelf: Created basic item with title: \(asset.originalFileName)")
        
        // Try to download and cache the image, then use file URL
        if let cachedImageURL = await downloadAndCacheImage(for: asset) {
            print("TopShelf: Setting file image URL for asset: \(asset.id)")
            print("TopShelf: Image URL: \(cachedImageURL.absoluteString)")
            item.setImageURL(cachedImageURL, for: .screenScale1x)
            item.setImageURL(cachedImageURL, for: .screenScale2x)
        } else {
            print("TopShelf: WARNING - No cached image available for asset: \(asset.id)")
            print("TopShelf: This item will display without an image")
        }
        
        return item
    }
    
    private func createFallbackContent() -> TVTopShelfContent {
        print("TopShelf: Creating fallback content")
        let item = TVTopShelfSectionedItem(identifier: "fallback")
        item.title = "Immich Gallery"
        item.displayAction = TVTopShelfAction(url: URL(string: "immichgallery://")!)
        
        let section = TVTopShelfItemCollection(items: [item])
        section.title = "Photos"
        
        return TVTopShelfSectionedContent(sections: [section])
    }
    
    private var sharedDefaults: UserDefaults {
        let suiteName = "group.com.sanketh.dev.Immich-Gallery"
        let defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        print("TopShelf: Using UserDefaults suite: \(suiteName)")
        return defaults
    }
    
    private func fetchFirst5Photos() async throws -> [SimpleAsset] {
        print("TopShelf: Starting to fetch first 5 photos")
        
        let serverURL = sharedDefaults.string(forKey: "immich_server_url")
        let accessToken = sharedDefaults.string(forKey: "immich_access_token")
        
        print("TopShelf: Credentials check - serverURL: \(serverURL != nil ? "✓" : "✗"), accessToken: \(accessToken != nil ? "✓" : "✗")")
        if let url = serverURL { print("TopShelf: Server URL: \(url)") }
        if let token = accessToken { print("TopShelf: Access token: \(String(token.prefix(20)))...") }
        
        guard let serverURL = serverURL, let accessToken = accessToken else {
            print("TopShelf: Missing credentials!")
            throw TopShelfError.missingCredentials
        }
        
        let urlString = "\(serverURL)/api/search/metadata"
        print("TopShelf: Making request to: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("TopShelf: Invalid URL: \(urlString)")
            throw TopShelfError.invalidURL
        }
        
        let searchRequest: [String: Any] = [
            "page": 1,
            "size": 5,
            "withPeople": false,
            "order": "desc",
            "withExif": false,
        ]
        print("TopShelf: Search request: \(searchRequest)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: searchRequest)
        
        print("TopShelf: Sending API request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("TopShelf: Invalid HTTP response")
            throw TopShelfError.networkError
        }
        
        print("TopShelf: API response status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            print("TopShelf: API error - Status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("TopShelf: Error response body: \(responseString)")
            }
            throw TopShelfError.networkError
        }
        
        print("TopShelf: Decoding response...")
        let searchResponse = try JSONDecoder().decode(SimpleSearchResponse.self, from: data)
        let imageAssets = Array(searchResponse.assets.items.filter { $0.type == "IMAGE" }.prefix(5))
        print("TopShelf: Found \(imageAssets.count) image assets")
        return imageAssets
    }
    

    private func downloadAndCacheImage(for asset: SimpleAsset) async -> URL? {
        print("TopShelf: Starting image download for asset: \(asset.id)")
        guard let serverURL = sharedDefaults.string(forKey: "immich_server_url"),
              let accessToken = sharedDefaults.string(forKey: "immich_access_token") else {
            print("TopShelf: Missing credentials for image download")
            return nil
        }
        
        guard let appGroupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.sanketh.dev.Immich-Gallery") else {
            print("TopShelf: Failed to get App Group container URL")
            return nil
        }
        
        let topShelfCacheDir = appGroupContainer.appendingPathComponent("Library/Caches/TopShelfImages")
        print("TopShelf: App Group cache directory: \(topShelfCacheDir.path)")
        
        // Create cache directory if needed
        do {
            try FileManager.default.createDirectory(at: topShelfCacheDir, withIntermediateDirectories: true)
            print("TopShelf: Cache directory created/verified")
        } catch {
            print("TopShelf: ERROR - Failed to create cache directory: \(error)")
            return nil
        }
        
        let cachedImageURL = topShelfCacheDir.appendingPathComponent("\(asset.id).webp")
        
        // Return cached image if it exists and is recent (within 1 hour)
        if FileManager.default.fileExists(atPath: cachedImageURL.path),
           let attributes = try? FileManager.default.attributesOfItem(atPath: cachedImageURL.path),
           let modificationDate = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modificationDate) < 3600 {
            print("TopShelf: Using cached image for asset: \(asset.id)")
            return cachedImageURL
        }
        
        // Download image
        let thumbnailURL = "\(serverURL)/api/assets/\(asset.id)/thumbnail?format=webp&size=preview"
        print("TopShelf: Downloading image from: \(thumbnailURL)")
        guard let url = URL(string: thumbnailURL) else { 
            print("TopShelf: Invalid thumbnail URL")
            return nil 
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            print("TopShelf: Starting image download request...")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("TopShelf: Invalid image download response")
                return nil
            }
            
            print("TopShelf: Image download response status: \(httpResponse.statusCode), size: \(data.count) bytes")
            
            guard httpResponse.statusCode == 200 else {
                print("TopShelf: Image download failed with status: \(httpResponse.statusCode)")
                return nil
            }
            
            // Save to cache and return file URL
            try data.write(to: cachedImageURL)
            print("TopShelf: Image cached successfully at: \(cachedImageURL.path)")
            
            // Ensure we return the file URL properly
            print("TopShelf: Returning file URL: \(cachedImageURL.absoluteString)")
            return cachedImageURL
            
        } catch {
            print("TopShelf: Failed to download image for asset \(asset.id): \(error)")
            return nil
        }
    }
    
    private func getThumbnailURL(for asset: SimpleAsset) -> URL {
        guard let serverURL = sharedDefaults.string(forKey: "immich_server_url") else {
            return URL(string: "about:blank")!
        }
        
        let thumbnailURL = "\(serverURL)/api/assets/\(asset.id)/thumbnail?format=webp&size=preview"
        return URL(string: thumbnailURL) ?? URL(string: "about:blank")!
    }
}

struct SimpleAsset: Codable, Identifiable {
    let id: String
    let type: String
    let originalFileName: String
}

struct SimpleSearchResponse: Codable {
    let assets: SimpleAssetSection
}

struct SimpleAssetSection: Codable {
    let items: [SimpleAsset]
}

enum TopShelfError: Error {
    case missingCredentials
    case networkError
    case invalidURL
}
