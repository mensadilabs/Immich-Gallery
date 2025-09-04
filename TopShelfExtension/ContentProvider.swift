//
//  ContentProvider.swift
//  TopShelfExtension
//
//  Created by mensadi-labs on 2025-08-11.
//

import TVServices
import Foundation

class ContentProvider: TVTopShelfContentProvider {
    
    let TOTAL_ITEMS_COUNT = 10
    private let storage = HybridUserStorage()
           
    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        print("TopShelf: loadTopShelfContent() called")
        
        // Check if Top Shelf is enabled in settings (default to true if not set)
        let isTopShelfEnabled = sharedDefaults.bool(forKey: UserDefaultsKeys.enableTopShelf)
        print("TopShelf: Top Shelf enabled in settings: \(isTopShelfEnabled)")
        
        if !isTopShelfEnabled {
            print("TopShelf: Top Shelf is disabled, returning nil")
            return nil
        }
        
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
        let assets = try await fetchPhotos()
        print("TopShelf: Fetched \(assets.count) assets")
        
        // Check user preference for TopShelf style
        let topShelfStyle = sharedDefaults.string(forKey: UserDefaultsKeys.topShelfStyle) ?? "carousel"
        print("TopShelf: Using style: \(topShelfStyle)")
        
        if topShelfStyle == "sectioned" {
            return try await createSectionedContent(assets: assets)
        } else {
            return try await createCarouselContent(assets: assets)
        }
    }
    
    private func createCarouselContent(assets: [SimpleAsset]) async throws -> TVTopShelfContent {
        print("TopShelf: Starting to create TopShelf carousel content")
        
        let carouselItems = await withTaskGroup(of: (Int, TVTopShelfCarouselItem?).self) { group in
            for (index, asset) in assets.enumerated() {
                group.addTask {
                    print("TopShelf: Processing asset \(index + 1)/\(assets.count): \(asset.originalFileName)")
                    let item = await self.createTopShelfCarouselItem(for: asset)
                    return (index, item)
                }
            }
            
            var indexedItems: [(Int, TVTopShelfCarouselItem)] = []
            for await (index, item) in group {
                if let item = item {
                    print("TopShelf: Successfully created carousel item: \(item.title ?? "No title")")
                    indexedItems.append((index, item))
                } else {
                    print("TopShelf: Failed to create carousel item at index \(index)")
                }
            }
            
            // Sort by original index to preserve order
            indexedItems.sort { $0.0 < $1.0 }
            let items = indexedItems.map { $0.1 }
            
            print("TopShelf: Created \(items.count) carousel items total in correct order")
            return items
        }
        
        let content = TVTopShelfCarouselContent(style: .details, items: carouselItems)
        print("TopShelf: Created carousel content with \(carouselItems.count) items")
        return content
    }
    
    private func createSectionedContent(assets: [SimpleAsset]) async throws -> TVTopShelfContent {
        print("TopShelf: Starting to create TopShelf sectioned content")
        
        let sectionItems = await withTaskGroup(of: (Int, TVTopShelfSectionedItem?).self) { group in
            for (index, asset) in assets.enumerated() {
                group.addTask {
                    print("TopShelf: Processing asset \(index + 1)/\(assets.count): \(asset.originalFileName)")
                    let item = await self.createTopShelfSectionedItem(for: asset)
                    return (index, item)
                }
            }
            
            var indexedItems: [(Int, TVTopShelfSectionedItem)] = []
            for await (index, item) in group {
                if let item = item {
                    print("TopShelf: Successfully created sectioned item: \(item.title ?? "No title")")
                    indexedItems.append((index, item))
                } else {
                    print("TopShelf: Failed to create sectioned item at index \(index)")
                }
            }
            
            // Sort by original index to preserve order
            indexedItems.sort { $0.0 < $1.0 }
            let items = indexedItems.map { $0.1 }
            
            print("TopShelf: Created \(items.count) sectioned items total in correct order")
            return items
        }
        
        let section = TVTopShelfItemCollection(items: sectionItems)
        section.title = "Recent Photos"
        
        let content = TVTopShelfSectionedContent(sections: [section])
        print("TopShelf: Created sectioned content with \(sectionItems.count) items")
        return content
    }
    
    private func createTopShelfCarouselItem(for asset: SimpleAsset) async -> TVTopShelfCarouselItem? {
        print("TopShelf: Creating carousel item for asset: \(asset.id)")
        guard let url = URL(string: "immichgallery://asset/\(asset.id)") else { 
            print("TopShelf: Failed to create deep link URL for asset: \(asset.id)")
            return nil 
        }
        
        let item = TVTopShelfCarouselItem(identifier: asset.id)
        item.title = asset.originalFileName
        item.displayAction = TVTopShelfAction(url: url)
        print("TopShelf: Created basic carousel item with title: \(asset.originalFileName)")
        
        // Download and process image without long-term caching
        if let imageURL = await downloadImageWithoutCaching(for: asset) {
            print("TopShelf: Setting processed image URL for carousel item: \(asset.id)")
            print("TopShelf: Image URL: \(imageURL.absoluteString)")
            item.setImageURL(imageURL, for: .screenScale1x)
            item.setImageURL(imageURL, for: .screenScale2x)
        } else {
            print("TopShelf: WARNING - No image available for asset: \(asset.id)")
            print("TopShelf: This carousel item will display without an image")
        }
        
        return item
    }
    
    private func createTopShelfSectionedItem(for asset: SimpleAsset) async -> TVTopShelfSectionedItem? {
        print("TopShelf: Creating sectioned item for asset: \(asset.id)")
        guard let url = URL(string: "immichgallery://asset/\(asset.id)") else { 
            print("TopShelf: Failed to create deep link URL for asset: \(asset.id)")
            return nil 
        }
        
        let item = TVTopShelfSectionedItem(identifier: asset.id)
        item.title = asset.originalFileName
        item.displayAction = TVTopShelfAction(url: url)
        print("TopShelf: Created basic sectioned item with title: \(asset.originalFileName)")
        
        // Download and process image without long-term caching
        if let imageURL = await downloadImageWithoutCaching(for: asset) {
            print("TopShelf: Setting processed image URL for sectioned item: \(asset.id)")
            print("TopShelf: Image URL: \(imageURL.absoluteString)")
            item.setImageURL(imageURL, for: .screenScale1x)
            item.setImageURL(imageURL, for: .screenScale2x)
        } else {
            print("TopShelf: WARNING - No image available for asset: \(asset.id)")
            print("TopShelf: This sectioned item will display without an image")
        }
        
        return item
    }
    
    private func createFallbackContent() -> TVTopShelfContent {
        let topShelfStyle = sharedDefaults.string(forKey: UserDefaultsKeys.topShelfStyle) ?? "carousel"
        print("TopShelf: Creating fallback content with style: \(topShelfStyle)")
        
        if topShelfStyle == "sectioned" {
            let item = TVTopShelfSectionedItem(identifier: "fallback")
            item.title = "Immich Gallery"
            item.displayAction = TVTopShelfAction(url: URL(string: "immichgallery://")!)
            
            let section = TVTopShelfItemCollection(items: [item])
            section.title = "Photos"
            
            return TVTopShelfSectionedContent(sections: [section])
        } else {
            let item = TVTopShelfCarouselItem(identifier: "fallback")
            item.title = "Immich Gallery"
            item.displayAction = TVTopShelfAction(url: URL(string: "immichgallery://")!)
            
            return TVTopShelfCarouselContent(style: .details, items: [item])
        }
    }
    
    private var sharedDefaults: UserDefaults {
        let suiteName = AppConstants.appGroupIdentifier
        let defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        print("TopShelf: Using UserDefaults suite: \(suiteName)")
        print(defaults)
        return defaults
    }
    
    private func fetchPhotos() async throws -> [SimpleAsset] {
        print("TopShelf: Starting to fetch \(TOTAL_ITEMS_COUNT) photos")
        
        let (serverURL, accessToken, authType) = getCurrentUserCredentials()
        let isTopShelfEnabledFromDefaults = sharedDefaults.bool(forKey: UserDefaultsKeys.enableTopShelf)
        let imageSelection = sharedDefaults.string(forKey: UserDefaultsKeys.topShelfImageSelection) ?? "recent"
        
        print("TopShelf: enabled=\(isTopShelfEnabledFromDefaults), imageSelection=\(imageSelection)")
        
        print("TopShelf: Credentials check - serverURL: \(serverURL), accessToken: \(accessToken != nil ? "✓" : "✗"), authType: \(authType?.rawValue ?? "nil")")
        if let url = serverURL { print("TopShelf: Server URL: \(url)") }
        if let token = accessToken { 
            print("TopShelf: Access token: \(String(token.prefix(20)))... (length: \(token.count))")
        }
        
        guard let serverURL = serverURL, let accessToken = accessToken, let authType = authType else {
            print("TopShelf: Missing credentials!")
            throw TopShelfError.missingCredentials
        }
        
        // Test token validity first
        try await testTokenValidity(serverURL: serverURL, accessToken: accessToken, authType: authType)
        
        if imageSelection == "random" {
            return try await fetchRandomPhotos(serverURL: serverURL, accessToken: accessToken, authType: authType)
        } else {
            return try await fetchRecentPhotos(serverURL: serverURL, accessToken: accessToken, authType: authType)
        }
    }
    
    private func fetchRecentPhotos(serverURL: String, accessToken: String, authType: SavedUser.AuthType) async throws -> [SimpleAsset] {
        let urlString = "\(serverURL)/api/search/metadata"
        print("TopShelf: Making request to: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("TopShelf: Invalid URL: \(urlString)")
            throw TopShelfError.invalidURL
        }
        
        let searchRequest: [String: Any] = [
            "page": 1,
            "size": TOTAL_ITEMS_COUNT,
            "withPeople": false,
            "order": "desc",
            "withExif": false,
        ]
        print("TopShelf: Search request: \(searchRequest)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Set authentication header based on auth type
        if authType == .apiKey {
            request.setValue(accessToken, forHTTPHeaderField: "x-api-key")
        } else {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
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
        let imageAssets = Array(searchResponse.assets.items.filter { $0.type == "IMAGE" }.prefix(TOTAL_ITEMS_COUNT))
        print("TopShelf: Found \(imageAssets.count) recent image assets")
        return imageAssets
    }
    
    private func fetchRandomPhotos(serverURL: String, accessToken: String, authType: SavedUser.AuthType) async throws -> [SimpleAsset] {
        let urlString = "\(serverURL)/api/assets/random"
        print("TopShelf: Making request to: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("TopShelf: Invalid URL: \(urlString)")
            throw TopShelfError.invalidURL
        }
        
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = [
            URLQueryItem(name: "count", value: String(TOTAL_ITEMS_COUNT))
        ]
        
        guard let finalURL = urlComponents?.url else {
            print("TopShelf: Failed to construct URL with query parameters")
            throw TopShelfError.invalidURL
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        
        // Set authentication header based on auth type
        if authType == .apiKey {
            request.setValue(accessToken, forHTTPHeaderField: "x-api-key")
        } else {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        print("TopShelf: Sending random API request...")
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
        
        print("TopShelf: Decoding random response...")
        let randomAssets = try JSONDecoder().decode([SimpleAsset].self, from: data)
        let imageAssets = Array(randomAssets.filter { $0.type == "IMAGE" }.prefix(TOTAL_ITEMS_COUNT))
        print("TopShelf: Found \(imageAssets.count) random image assets")
        return imageAssets
    }
    

    private func downloadImageWithoutCaching(for asset: SimpleAsset) async -> URL? {
        print("TopShelf: Starting image download (no caching) for asset: \(asset.id)")
        let (serverURL, accessToken, authType) = getCurrentUserCredentials()
        
        guard let serverURL = serverURL, let accessToken = accessToken, let authType = authType else {
            print("TopShelf: Missing credentials for image download")
            return nil
        }
        
        guard let appGroupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier) else {
            print("TopShelf: Failed to get App Group container URL")
            return nil
        }
        
        let tempDir = appGroupContainer.appendingPathComponent("Library/Caches/TopShelfTemp")
        
        // Create temp directory if needed
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            print("TopShelf: ERROR - Failed to create temp directory: \(error)")
            return nil
        }
        
        // Use a temporary file that gets overwritten each time
        let tempImageURL = tempDir.appendingPathComponent("\(asset.id)_temp.webp")
        
        // Download image
        let thumbnailURL = "\(serverURL)/api/assets/\(asset.id)/thumbnail?format=webp&size=preview"
        print("TopShelf: Downloading image from: \(thumbnailURL)")
        guard let url = URL(string: thumbnailURL) else { 
            print("TopShelf: Invalid thumbnail URL")
            return nil 
        }
        
        var request = URLRequest(url: url)
        
        // Set authentication header based on auth type
        if authType == .apiKey {
            request.setValue(accessToken, forHTTPHeaderField: "x-api-key")
        } else {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
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
                if let responseString = String(data: data, encoding: .utf8) {
                    print("TopShelf: Error response body: \(responseString)")
                }
                return nil
            }
            
            // Save to temp file and return file URL
            try data.write(to: tempImageURL)
            print("TopShelf: Image saved to temp file: \(tempImageURL.path)")
            
            return tempImageURL
            
        } catch {
            print("TopShelf: Failed to download image for asset \(asset.id): \(error)")
            return nil
        }
    }
    
    private func testTokenValidity(serverURL: String, accessToken: String, authType: SavedUser.AuthType = .jwt) async throws {
        print("TopShelf: Testing token validity...")
        let testURL = "\(serverURL)/api/users/me"
        guard let url = URL(string: testURL) else {
            print("TopShelf: Invalid test URL")
            throw TopShelfError.invalidURL
        }
        
        var request = URLRequest(url: url)
        
        // Set authentication header based on auth type
        if authType == .apiKey {
            request.setValue(accessToken, forHTTPHeaderField: "x-api-key")
        } else {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("TopShelf: Invalid test response")
            throw TopShelfError.networkError
        }
        
        print("TopShelf: Token test response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 401 {
            print("TopShelf: Token is invalid or expired!")
            if let responseString = String(data: data, encoding: .utf8) {
                print("TopShelf: Token test error response: \(responseString)")
            }
            throw TopShelfError.invalidToken
        } else if httpResponse.statusCode == 200 {
            print("TopShelf: Token is valid!")
        } else {
            print("TopShelf: Unexpected token test response: \(httpResponse.statusCode)")
        }
    }
    
    // MARK: - Current User Credential Access
    
    private func getCurrentUserCredentials() -> (serverURL: String?, accessToken: String?, authType: SavedUser.AuthType?) {
        // Debug: Show what's in shared defaults
        
        // Get current user ID
        guard let currentUserId = sharedDefaults.string(forKey: "currentActiveUserId") else {
            print("TopShelf: No current user ID found")
            return (nil, nil, nil)
        }
        
        print("TopShelf: Found current user ID: \(currentUserId)")
        
        // Load user data
        guard let userData = sharedDefaults.data(forKey: "\(UserDefaultsKeys.userPrefix)\(currentUserId)"),
              let user = try? JSONDecoder().decode(SavedUser.self, from: userData) else {
            print("TopShelf: Failed to load user data for ID: \(currentUserId)")
            return (nil, nil, nil)
        }
        
        // Load token from keychain via HybridUserStorage
        guard let token = storage.getToken(forUserId: currentUserId) else {
            print("TopShelf: Failed to load token from keychain for user ID: \(currentUserId)")
            return (nil, nil, nil)
        }
        
        print("TopShelf: Loaded current user credentials - \(user.email) on \(user.serverURL) with \(user.authType)")
        return (user.serverURL, token, user.authType)
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
    case invalidToken
}
