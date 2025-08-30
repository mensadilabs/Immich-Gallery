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
    @Published var currentAuthType: SavedUser.AuthType = .jwt
    
    private let session = URLSession.shared
    private weak var userManager: UserManager?
    
    init(userManager: UserManager) {
        self.userManager = userManager
        loadCurrentUserCredentials()
    }
    
    // MARK: - Current User Credential Loading
    private func loadCurrentUserCredentials() {
        guard let userManager = userManager else {
            print("NetworkService: No UserManager available")
            return
        }
        
        if let serverURL = userManager.currentUserServerURL,
           let token = userManager.currentUserToken,
           let authType = userManager.currentUserAuthType {
            
            DispatchQueue.main.async {
                self.baseURL = serverURL
                self.accessToken = token
                self.currentAuthType = authType
            }
            
            print("NetworkService: Loaded current user credentials - baseURL: \(serverURL), authType: \(authType)")
        } else {
            print("NetworkService: No current user credentials found")
            DispatchQueue.main.async {
                self.baseURL = ""
                self.accessToken = nil
                self.currentAuthType = .jwt
            }
        }
    }
    
    /// Updates the network service with the current user's credentials
    func updateCredentialsFromCurrentUser() {
        loadCurrentUserCredentials()
    }
    
    /// Clears all credentials when user logs out
    func clearCredentials() {
        DispatchQueue.main.async {
            self.baseURL = ""
            self.accessToken = nil
            self.currentAuthType = .jwt
        }
        print("NetworkService: Cleared all credentials")
    }
    
    // MARK: - Network Requests
    func makeRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: [String: Any]? = nil,
        responseType: T.Type
    ) async throws -> T {
        guard let accessToken = accessToken, !baseURL.isEmpty else {
            print("NetworkService: No access token or server URL available")
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
        
        // Set authentication header based on auth type
        if currentAuthType == .apiKey {
            request.setValue(accessToken, forHTTPHeaderField: "x-api-key")
        } else {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                throw ImmichError.networkError
            }
        }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            print("NetworkService: Network error occurred: \(error)")
            // Handle network connectivity issues (timeouts, connection refused, DNS failures, etc.)
            throw ImmichError.networkError
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("NetworkService: Invalid HTTP response")
            throw ImmichError.networkError
        }
        
        print("NetworkService: Response status code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            print("NetworkService: HTTP error with status \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("NetworkService: Response body: \(responseString)")
            }
            
            // Classify HTTP status codes into appropriate ImmichError types
            switch httpResponse.statusCode {
            case 401:
                throw ImmichError.notAuthenticated
            case 403:
                throw ImmichError.forbidden
            case 500...599:
                throw ImmichError.serverError(httpResponse.statusCode)
            case 400...499:
                throw ImmichError.clientError(httpResponse.statusCode)
            default:
                // For any other status codes, treat as server error
                throw ImmichError.serverError(httpResponse.statusCode)
            }
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
        guard let accessToken = accessToken, !baseURL.isEmpty else {
            print("NetworkService: No access token or server URL available for data request")
            throw ImmichError.notAuthenticated
        }
        
        let urlString = "\(baseURL)\(endpoint)"
        guard let url = URL(string: urlString) else {
            throw ImmichError.invalidURL
        }
        
        var request = URLRequest(url: url)
        
        // Set authentication header based on auth type
        if currentAuthType == .apiKey {
            request.setValue(accessToken, forHTTPHeaderField: "x-api-key")
        } else {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            print("NetworkService: Network error occurred in makeDataRequest: \(error)")
            // Handle network connectivity issues (timeouts, connection refused, DNS failures, etc.)
            throw ImmichError.networkError
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("NetworkService: Invalid HTTP response in makeDataRequest")
            throw ImmichError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            print("NetworkService: HTTP error in makeDataRequest with status \(httpResponse.statusCode)")
            
            // Classify HTTP status codes into appropriate ImmichError types
            switch httpResponse.statusCode {
            case 401:
                throw ImmichError.notAuthenticated
            case 403:
                throw ImmichError.forbidden
            case 500...599:
                throw ImmichError.serverError(httpResponse.statusCode)
            case 400...499:
                throw ImmichError.clientError(httpResponse.statusCode)
            default:
                // For any other status codes, treat as server error
                throw ImmichError.serverError(httpResponse.statusCode)
            }
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
    case notAuthenticated           // 401 - Invalid/expired token
    case forbidden                  // 403 - Access denied
    case invalidURL                 // Malformed URL
    case serverError(Int)          // 5xx - Server issues
    case networkError              // Network connectivity issues
    case clientError(Int)          // 4xx (except 401/403)
    
    var shouldLogout: Bool {
        switch self {
        case .notAuthenticated, .forbidden:
            return true
        case .serverError, .networkError, .invalidURL, .clientError:
            return false
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please log in."
        case .forbidden:
            return "Access forbidden. Please check your permissions."
        case .invalidURL:
            return "Invalid URL"
        case .serverError(let statusCode):
            return "Server error occurred (HTTP \(statusCode))"
        case .networkError:
            return "Network error occurred"
        case .clientError(let statusCode):
            return "Client error occurred (HTTP \(statusCode))"
        }
    }
} 
