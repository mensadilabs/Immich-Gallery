//
//  ImmichService.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import Foundation
import UIKit

class ImmichService: ObservableObject {
    // MARK: - Configuration
    @Published var baseURL: String = ""
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    @Published var currentUser: Owner?
    
    private let session = URLSession.shared
    
    init() {
        print("🚀 ImmichService initializing...")
        // Check if we have saved credentials
        loadSavedCredentials()
    }
    
    // MARK: - Credential Management
    private func loadSavedCredentials() {
        print("🔍 Loading saved credentials...")
        
        if let savedURL = UserDefaults.standard.string(forKey: "immich_server_url"),
           let savedToken = UserDefaults.standard.string(forKey: "immich_access_token") {
            print("✅ Found saved credentials:")
            print("   Server URL: \(savedURL)")
            print("   Token: \(String(savedToken.prefix(20)))...")
            
            baseURL = savedURL
            accessToken = savedToken
            isAuthenticated = true
            
            // Try to validate the token by making a test request
            validateToken()
        } else {
            print("❌ No saved credentials found")
            print("   Saved URL: \(UserDefaults.standard.string(forKey: "immich_server_url") ?? "nil")")
            print("   Saved Token: \(UserDefaults.standard.string(forKey: "immich_access_token") != nil ? "exists" : "nil")")
        }
    }
    
    private func saveCredentials(serverURL: String, token: String) {
        print("💾 Saving credentials...")
        print("   Server URL: \(serverURL)")
        print("   Token: \(String(token.prefix(20)))...")
        UserDefaults.standard.set(serverURL, forKey: "immich_server_url")
        UserDefaults.standard.set(token, forKey: "immich_access_token")
        print("✅ Credentials saved to UserDefaults")
    }
    
    private func clearCredentials() {
        print("🧹 Clearing saved credentials...")
        UserDefaults.standard.removeObject(forKey: "immich_server_url")
        UserDefaults.standard.removeObject(forKey: "immich_access_token")
        UserDefaults.standard.removeObject(forKey: "immich_user_email")
        print("✅ Credentials cleared from UserDefaults")
    }
    
    private func validateToken() {
        print("🔐 Starting token validation...")
        // Make a simple API call to validate the token and fetch user details
        Task {
            // Add a small delay to ensure the app is fully initialized
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            do {
                print("📡 Making API call to validate token...")
                // Try to fetch user info to validate token and get user details
                try await fetchUserInfo()
                print("✅ Token validation successful")
            } catch {
                print("❌ Token validation failed: \(error)")
                print("   Error details: \(error.localizedDescription)")
                // Token is invalid, clear credentials
                DispatchQueue.main.async {
                    print("🚪 Signing out due to token validation failure")
                    self.signOut()
                }
            }
        }
    }
    
    // MARK: - Authentication
    func signIn(serverURL: String, email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        let loginURL = URL(string: "\(serverURL)/api/auth/login")!
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let loginData = [
            "email": email,
            "password": password
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: loginData)
        } catch {
            completion(false, "Error creating login request: \(error.localizedDescription)")
            return
        }
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "Invalid response from server")
                    return
                }
                
                guard let data = data else {
                    completion(false, "No data received from server")
                    return
                }
                
                print("🔐 Authentication response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
                    // Try to parse error message
                    if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = errorResponse["message"] as? String {
                        print("❌ Authentication error: \(message)")
                        completion(false, message)
                    } else {
                        print("❌ Authentication failed with status: \(httpResponse.statusCode)")
                        completion(false, "Authentication failed (Status: \(httpResponse.statusCode))")
                    }
                    return
                }
                
                do {
                    let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                    print("✅ Authentication successful for user: \(authResponse.userEmail)")
                    self?.baseURL = serverURL
                    self?.accessToken = authResponse.accessToken
                    self?.isAuthenticated = true
                    
                    // Save credentials
                    self?.saveCredentials(serverURL: serverURL, token: authResponse.accessToken)
                    UserDefaults.standard.set(email, forKey: "immich_user_email")
                    
                    // Fetch user details from the server
                    Task {
                        do {
                            try await self?.fetchUserInfo()
                            print("✅ User details fetched successfully")
                        } catch {
                            print("⚠️ Failed to fetch user details: \(error)")
                            // Create a basic user object from auth response as fallback
                            self?.currentUser = Owner(
                                id: authResponse.userId,
                                email: authResponse.userEmail,
                                name: authResponse.name,
                                profileImagePath: authResponse.profileImagePath,
                                profileChangedAt: "",
                                avatarColor: "primary"
                            )
                        }
                    }
                    
                    print("Authentication successful")
                    completion(true, nil)
                } catch {
                    print("❌ Error decoding auth response: \(error)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📄 Raw response data: \(responseString)")
                    }
                    completion(false, "Invalid response format from server")
                }
            }
        }.resume()
    }
    
    func signOut() {
        print("🚪 Signing out user...")
        clearCredentials()
        baseURL = ""
        accessToken = nil
        currentUser = nil
        isAuthenticated = false
        print("✅ Sign out completed")
    }
    
    func switchUser(serverURL: String, accessToken: String, email: String, name: String) {
        print("🔄 Switching to user: \(email)")
        
        // Update service properties
        self.baseURL = serverURL
        self.accessToken = accessToken
        self.isAuthenticated = true
        
        // Create temporary user object
        self.currentUser = Owner(
            id: "",
            email: email,
            name: name,
            profileImagePath: "",
            profileChangedAt: "",
            avatarColor: "primary"
        )
        
        // Update UserDefaults
        UserDefaults.standard.set(serverURL, forKey: "immich_server_url")
        UserDefaults.standard.set(accessToken, forKey: "immich_access_token")
        UserDefaults.standard.set(email, forKey: "immich_user_email")
        
        print("✅ User switched to: \(email)")
    }
    
    // MARK: - Assets
    func fetchAssets(page: Int = 1, limit: Int = 50, albumId: String? = nil, personId: String? = nil) async throws -> SearchResult {
        guard let accessToken = accessToken else {
            throw ImmichError.notAuthenticated
        }
        
        let urlString = "\(baseURL)/api/search/metadata"
        guard let url = URL(string: urlString) else {
            throw ImmichError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create search request body
        var searchRequest: [String: Any] = [
            "page": page,
            "size": limit,
            "withPeople": true,
            "order": "desc",
            "withExif": true
        ]
        
        // Add album filter if provided
        if let albumId = albumId {
            searchRequest["albumIds"] = [albumId]
        }
        
        // Add person filter if provided
        if let personId = personId {
            searchRequest["personIds"] = [personId]
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: searchRequest)
        } catch {
            throw ImmichError.networkError
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImmichError.serverError
        }
        
        let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
        return SearchResult(
            assets: searchResponse.assets.items,
            total: searchResponse.assets.total,
            nextPage: searchResponse.assets.nextPage
        )
    }
    
    // MARK: - User Info
    func fetchUserInfo() async throws {
        guard let accessToken = accessToken else {
            print("❌ No access token available")
            throw ImmichError.notAuthenticated
        }
        
        let urlString = "\(baseURL)/api/users/me"
        print("📡 Fetching user info from: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            throw ImmichError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("🔑 Making request with token: \(String(accessToken.prefix(20)))...")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid HTTP response")
            throw ImmichError.serverError
        }
        
        print("📊 User info response status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            print("❌ User info request failed with status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Error response: \(responseString)")
            }
            throw ImmichError.serverError
        }
        
        let user = try JSONDecoder().decode(User.self, from: data)
        
        // Convert User to Owner for compatibility
        let owner = Owner(
            id: user.id,
            email: user.email,
            name: user.name,
            profileImagePath: user.profileImagePath,
            profileChangedAt: user.profileChangedAt,
            avatarColor: user.avatarColor
        )
        
        DispatchQueue.main.async {
            self.currentUser = owner
        }
    }
    
    // MARK: - Albums
    func fetchAlbums() async throws -> [ImmichAlbum] {
        guard let accessToken = accessToken else {
            throw ImmichError.notAuthenticated
        }
        
        let urlString = "\(baseURL)/api/albums"
        guard let url = URL(string: urlString) else {
            throw ImmichError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImmichError.serverError
        }
        
        let albums = try JSONDecoder().decode([ImmichAlbum].self, from: data)
        return albums
    }
    
    
    // MARK: - Get Album Info
    func getAlbumInfo(albumId: String, withoutAssets: Bool = false) async throws -> ImmichAlbum {
        guard let accessToken = accessToken else {
            throw ImmichError.notAuthenticated
        }
        
        var urlString = "\(baseURL)/api/albums/\(albumId)"
        if withoutAssets {
            urlString += "?withoutAssets=true"
        }
        
        print("🔍 Fetching album info from: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            throw ImmichError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImmichError.serverError
        }
        
        print("📡 Album API Response Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Album API Error Response: \(responseString)")
            }
            throw ImmichError.serverError
        }
        
        // Log the raw JSON response
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 Raw Album API Response:")
            print(responseString)
        }
        
        let album = try JSONDecoder().decode(ImmichAlbum.self, from: data)
        print("✅ Successfully decoded album: \(album.albumName) with \(album.assets.count) assets")
        return album
    }
    
    // MARK: - Album Thumbnail
    func loadAlbumThumbnail(albumId: String, thumbnailAssetId: String, size: String = "thumbnail") async throws -> UIImage? {
        guard let accessToken = accessToken else {
            throw ImmichError.notAuthenticated
        }
        
        let urlString = "\(baseURL)/api/assets/\(thumbnailAssetId)/thumbnail?format=webp&size=\(size)"
        print("Loading thumbnail from: \(urlString)")
        guard let url = URL(string: urlString) else {
            throw ImmichError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("image/webp", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImmichError.serverError
        }
        
        print("Thumbnail response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("Thumbnail error response: \(responseString)")
            }
            throw ImmichError.serverError
        }
        
        return UIImage(data: data)
    }
    
    // MARK: - Image Loading
    func loadImage(from asset: ImmichAsset, size: String = "thumbnail") async throws -> UIImage? {
        return try await ThumbnailCache.shared.getThumbnail(for: asset.id, size: size) {
            // Load from server closure
            guard let accessToken = self.accessToken else {
                throw ImmichError.notAuthenticated
            }
            
            let urlString = "\(self.baseURL)/api/assets/\(asset.id)/thumbnail?format=webp&size=\(size)"
            guard let url = URL(string: urlString) else {
                throw ImmichError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await self.session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw ImmichError.serverError
            }
            
            return UIImage(data: data)
        }
    }
    
    func loadFullImage(from asset: ImmichAsset) async throws -> UIImage? {
        
        guard let accessToken = accessToken else {
            throw ImmichError.notAuthenticated
        }
        
        let urlString = "\(baseURL)/api/assets/\(asset.id)/original"
        guard let url = URL(string: urlString) else {
            throw ImmichError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("Full image load failed - Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            print("URL: \(urlString)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
            }
            throw ImmichError.serverError
        }
        
        return UIImage(data: data)
    }
    
    // MARK: - Video Loading
    func loadVideoURL(from asset: ImmichAsset) async throws -> URL {
        guard let accessToken = accessToken else {
            throw ImmichError.notAuthenticated
        }
        
        // Use the dedicated video playback endpoint for streaming
        let urlString = "\(baseURL)/api/assets/\(asset.id)/video/playback"
        guard let url = URL(string: urlString) else {
            throw ImmichError.invalidURL
        }
        
        // Return the direct URL - we'll handle authentication in the VideoPlayerView
        return url
    }
    
    // Helper method to get authentication headers for video requests
    func getVideoAuthHeaders() -> [String: String] {
        guard let accessToken = accessToken else {
            return [:]
        }
        
        return [
            "Authorization": "Bearer \(accessToken)",
            "Accept": "application/octet-stream"
        ]
    }
   
    
    // MARK: - Person Thumbnail Loading
    func loadPersonThumbnail(personId: String) async throws -> UIImage? {
        guard let accessToken = accessToken else {
            throw ImmichError.notAuthenticated
        }
        
        let urlString = "\(baseURL)/api/people/\(personId)/thumbnail"
        guard let url = URL(string: urlString) else {
            throw ImmichError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImmichError.serverError
        }
        
        return UIImage(data: data)
    }
    
    // MARK: - People
    func getAllPeople(page: Int = 1, size: Int = 100, withHidden: Bool = false) async throws -> [Person] {
        guard let accessToken = accessToken else {
            throw ImmichError.notAuthenticated
        }
        let urlString = "\(baseURL)/api/people?page=\(page)&size=\(size)&withHidden=\(withHidden)"
        print("🔍 Fetching people from: \(urlString)")
        guard let url = URL(string: urlString) else {
            throw ImmichError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImmichError.serverError
        }
        print("📡 People API Response Status: \(httpResponse.statusCode)")
        if httpResponse.statusCode != 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ People API Error Response: \(responseString)")
            }
            throw ImmichError.serverError
        }
        // Log the raw JSON response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 Raw People API Response:")
            print(responseString)
        }
        struct PeopleResponse: Codable {
            let people: [Person]
        }
        let peopleResponse = try JSONDecoder().decode(PeopleResponse.self, from: data)
        print("✅ Successfully decoded \(peopleResponse.people.count) people")
        return peopleResponse.people
    }
}

// MARK: - Errors
enum ImmichError: Error, LocalizedError {
    case notAuthenticated
    case invalidURL
    case serverError
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please log in."
        case .invalidURL:
            return "Invalid URL"
        case .serverError:
            return "Server error occurred"
        case .networkError:
            return "Network error occurred"
        }
    }
} 