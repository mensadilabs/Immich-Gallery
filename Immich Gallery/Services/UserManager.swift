//
//  UserManager.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-08-30
//

import Foundation

/// Manages multiple user accounts and their authentication data
class UserManager: ObservableObject {
    @Published var savedUsers: [SavedUser] = []
    @Published var currentUser: SavedUser?
    
    private let storage: UserStorage
    
    init(storage: UserStorage = UserDefaultsStorage()) {
        self.storage = storage
        loadUsers()
    }
    
    // MARK: - Core Operations
    
    /// Saves a new user account with their authentication token
    func saveUser(_ user: SavedUser, token: String) async throws {
        try storage.saveUser(user)
        try storage.saveToken(token, forUserId: user.id)
        
        await MainActor.run {
            // Update local state
            if let index = savedUsers.firstIndex(where: { $0.id == user.id }) {
                savedUsers[index] = user
            } else {
                savedUsers.append(user)
            }
            
            // Sort by creation date
            savedUsers.sort { $0.createdAt > $1.createdAt }
        }
        
        print("UserManager: Saved user \(user.email) with token")
    }
    
    /// Loads all saved users from storage
    func loadUsers() {
        let users = storage.loadUsers()
        
        DispatchQueue.main.async { [weak self] in
            self?.savedUsers = users
            print("UserManager: Loaded \(users.count) saved users")
        }
    }
    
    /// Switches to a different user account
    /// Returns the user's token for authentication
    func switchToUser(_ user: SavedUser) async throws -> String {
        guard let token = storage.getToken(forUserId: user.id) else {
            throw UserStorageError.tokenNotFound
        }
        
        await MainActor.run {
            currentUser = user
        }
        
        print("UserManager: Switched to user \(user.email)")
        return token
    }
    
    /// Removes a user account and their associated data
    func removeUser(_ user: SavedUser) async throws {
        try storage.removeUser(withId: user.id)
        
        await MainActor.run {
            savedUsers.removeAll { $0.id == user.id }
            
            // Clear current user if it was the removed user
            if currentUser?.id == user.id {
                currentUser = nil
            }
        }
        
        print("UserManager: Removed user \(user.email)")
    }
    
    /// Gets the authentication token for a specific user
    func getUserToken(_ user: SavedUser) -> String? {
        return storage.getToken(forUserId: user.id)
    }
    
    // MARK: - Authentication Methods
    
    /// Authenticates with username/password and saves the user
    func authenticateWithCredentials(serverURL: String, email: String, password: String) async throws -> String {
        // Perform login request
        let authResponse = try await performLogin(serverURL: serverURL, email: email, password: password)
        
        // Create user object
        let userId = generateUserIdForUser(email: email, serverURL: serverURL)
        let savedUser = SavedUser(
            id: userId,
            email: authResponse.userEmail,
            name: authResponse.name,
            serverURL: serverURL,
            authType: .jwt
        )
        
        // Save user and token
        try await saveUser(savedUser, token: authResponse.accessToken)
        
        return authResponse.accessToken
    }
    
    /// Authenticates with API key (future implementation)
    func authenticateWithApiKey(serverURL: String, apiKey: String) async throws -> SavedUser {
        // TODO: Implement API key authentication
        // This will validate the API key against the server and return user info
        throw NSError(domain: "UserManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "API key authentication not yet implemented"])
    }
    
    // MARK: - Utility Methods
    
    /// Finds a user by email and server URL
    func findUser(email: String, serverURL: String) -> SavedUser? {
        return savedUsers.first { $0.email == email && $0.serverURL == serverURL }
    }
    
    /// Checks if a user already exists
    func userExists(email: String, serverURL: String) -> Bool {
        return findUser(email: email, serverURL: serverURL) != nil
    }
    
    /// Gets all users for a specific server
    func getUsersForServer(_ serverURL: String) -> [SavedUser] {
        return savedUsers.filter { $0.serverURL == serverURL }
    }
    
    /// Clears all user data (for logout/reset)
    func clearAllUsers() async throws {
        try storage.removeAllUserData()
        
        await MainActor.run {
            savedUsers.removeAll()
            currentUser = nil
        }
        
        print("UserManager: Cleared all user data")
    }
    
    // MARK: - Private Methods
    
    private func performLogin(serverURL: String, email: String, password: String) async throws -> AuthResponse {
        let loginURL = URL(string: "\(serverURL)/api/auth/login")!
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let loginData = [
            "email": email,
            "password": password
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: loginData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "UserManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorResponse["message"] as? String {
                throw NSError(domain: "UserManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
            } else {
                throw NSError(domain: "UserManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Authentication failed"])
            }
        }
        
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }
}