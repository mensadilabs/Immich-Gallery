//
//  NetworkService.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import Foundation

/// Base networking service that handles HTTP requests and authentication
class NetworkService: ObservableObject {
    // MARK: - Configuration
    @Published var baseURL: String = ""
    @Published var accessToken: String?
    
    private let session = URLSession.shared
    
    init() {
        migrateCredentialsToSharedContainer()
        loadSavedCredentials()
    }
    
    // MARK: - Credential Management
    private var sharedDefaults: UserDefaults {
        return UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? UserDefaults.standard
    }
    
    private func migrateCredentialsToSharedContainer() {
        // Check if we already have credentials in shared container
        if sharedDefaults.string(forKey: "immich_server_url") != nil {
            return // Already migrated
        }
        
        // Check if we have credentials in standard UserDefaults to migrate
        if let serverURL = UserDefaults.standard.string(forKey: "immich_server_url"),
           let accessToken = UserDefaults.standard.string(forKey: "immich_access_token") {
            print("NetworkService: Migrating credentials to shared container")
            sharedDefaults.set(serverURL, forKey: "immich_server_url")
            sharedDefaults.set(accessToken, forKey: "immich_access_token")
            
            if let email = UserDefaults.standard.string(forKey: "immich_user_email") {
                sharedDefaults.set(email, forKey: "immich_user_email")
            }
        }
    }
    
    private func loadSavedCredentials() {
        if let savedURL = sharedDefaults.string(forKey: "immich_server_url"),
           let savedToken = sharedDefaults.string(forKey: "immich_access_token") {
            baseURL = savedURL
            accessToken = savedToken
            print("NetworkService: Loaded saved credentials - baseURL: \(baseURL)")
        } else {
            print("NetworkService: No saved credentials found")
        }
    }
    
    func saveCredentials(serverURL: String, token: String) {
        print("NetworkService: Saving credentials - serverURL: \(serverURL)")
        sharedDefaults.set(serverURL, forKey: "immich_server_url")
        sharedDefaults.set(token, forKey: "immich_access_token")
        
        // Also save to standard UserDefaults for backward compatibility
        UserDefaults.standard.set(serverURL, forKey: "immich_server_url")
        UserDefaults.standard.set(token, forKey: "immich_access_token")
        
        baseURL = serverURL
        accessToken = token
    }
    
    func clearCredentials() {
        sharedDefaults.removeObject(forKey: "immich_server_url")
        sharedDefaults.removeObject(forKey: "immich_access_token")
        sharedDefaults.removeObject(forKey: "immich_user_email")
        
        // Also clear from standard UserDefaults
        UserDefaults.standard.removeObject(forKey: "immich_server_url")
        UserDefaults.standard.removeObject(forKey: "immich_access_token")
        UserDefaults.standard.removeObject(forKey: "immich_user_email")
        
        baseURL = ""
        accessToken = nil
    }
    
    // MARK: - Network Requests
    func makeRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: [String: Any]? = nil,
        responseType: T.Type
    ) async throws -> T {
        guard let accessToken = accessToken else {
            print("NetworkService: No access token available")
            throw ImmichError.notAuthenticated
        }
        
        let urlString = "\(baseURL)\(endpoint)"
        print("NetworkService: Making request to \(urlString)")
        guard let url = URL(string: urlString) else {
            print("NetworkService: Invalid URL: \(urlString)")
            throw ImmichError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                throw ImmichError.networkError
            }
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("NetworkService: Invalid HTTP response")
            throw ImmichError.serverError
        }
        
        print("NetworkService: Response status code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            print("NetworkService: Server error with status \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("NetworkService: Response body: \(responseString)")
            }
            throw ImmichError.serverError
        }
        
        do {
            let result = try JSONDecoder().decode(responseType, from: data)
            print("NetworkService: Successfully decoded response")
            return result
        } catch {
            print("NetworkService: Failed to decode response: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("NetworkService: Raw response: \(responseString)")
            }
            throw error
        }
    }
    
    func makeDataRequest(endpoint: String) async throws -> Data {
        guard let accessToken = accessToken else {
            throw ImmichError.notAuthenticated
        }
        
        let urlString = "\(baseURL)\(endpoint)"
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
        
        return data
    }
}

// MARK: - Supporting Types
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case HEAD = "HEAD"
}

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