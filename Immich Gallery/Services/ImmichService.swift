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
    private let baseURL = "***REMOVED***" // Replace with your Immich server URL
    private let email = "***REMOVED***" // Replace with your email
    private let password = "***REMOVED***" // Replace with your password
    
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    @Published var currentUser: Owner?
    
    private let session = URLSession.shared
    
    init() {
        authenticate()
    }
    
    // MARK: - Authentication
    func authenticate() {
        let loginURL = URL(string: "\(baseURL)/api/auth/login")!
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
            print("Error creating login request: \(error)")
            return
        }
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Authentication error: \(error)")
                    return
                }
                
                guard let data = data else {
                    print("No data received")
                    return
                }
                
                do {
                    let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                    self?.accessToken = authResponse.accessToken
                    self?.isAuthenticated = true
                    
                    // Parse name into first and last name
                    let nameComponents = authResponse.name.components(separatedBy: "-")
                    let firstName = nameComponents.first ?? authResponse.name
                    let lastName = nameComponents.count > 1 ? nameComponents.dropFirst().joined(separator: "-") : ""
                    
                    self?.currentUser = Owner(
                        id: authResponse.userId,
                        email: authResponse.userEmail,
                        name: authResponse.name,
                        profileImagePath: authResponse.profileImagePath,
                        profileChangedAt: "",
                        avatarColor: "primary"
                    )
                    print("Authentication successful")
                } catch {
                    print("Error decoding auth response: \(error)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Response: \(responseString)")
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - Assets
    func fetchAssets(page: Int = 1, limit: Int = 50, albumId: String? = nil) async throws -> [ImmichAsset] {
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
        return searchResponse.assets.items
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
        guard let accessToken = accessToken else {
            throw ImmichError.notAuthenticated
        }
        
        let urlString = "\(baseURL)/api/assets/\(asset.id)/thumbnail?format=webp&size=\(size)"
        guard let url = URL(string: urlString) else {
            throw ImmichError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImmichError.serverError
        }
        
        return UIImage(data: data)
    }
    
    func loadFullImage(from asset: ImmichAsset) async throws -> UIImage? {
        // Handle preview assets by loading a free image from Unsplash
        if asset.id.hasPrefix("preview-") {
            return try await loadPreviewImage()
        }
        
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
    
    // MARK: - Preview Image Loading
    private func loadPreviewImage() async throws -> UIImage? {
        // Load a beautiful high-resolution image from Unsplash
        let unsplashURL = "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1920&h=1080&fit=crop&auto=format"
        
        guard let url = URL(string: unsplashURL) else {
            throw ImmichError.invalidURL
        }
        
        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImmichError.serverError
        }
        
        return UIImage(data: data)
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