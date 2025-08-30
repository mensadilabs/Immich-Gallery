//
//  UserModels.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-08-30
//

import Foundation

/// Represents a saved user account for multi-user support
struct SavedUser: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let serverURL: String
    let authType: AuthType
    let createdAt: Date
    
    enum AuthType: String, Codable {
        case jwt = "jwt"
        case apiKey = "api_key"
    }
    
    init(id: String, email: String, name: String, serverURL: String, authType: AuthType = .jwt) {
        self.id = id
        self.email = email
        self.name = name
        self.serverURL = serverURL
        self.authType = authType
        self.createdAt = Date()
    }
    
    // Custom decoder for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        name = try container.decode(String.self, forKey: .name)
        serverURL = try container.decode(String.self, forKey: .serverURL)
        
        // Default to jwt if authType is missing (backward compatibility)
        authType = try container.decodeIfPresent(AuthType.self, forKey: .authType) ?? .jwt
        
        // Default to current date if createdAt is missing (backward compatibility)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

/// Generates a unique user ID based on email and server URL
func generateUserIdForUser(email: String, serverURL: String) -> String {
    let combined = "\(email)@\(serverURL)"
    return combined.data(using: .utf8)?.base64EncodedString() ?? email
}