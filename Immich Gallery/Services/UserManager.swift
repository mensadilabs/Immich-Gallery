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
    
    private let storage: HybridUserStorage
    
    init(storage: HybridUserStorage? = nil) {
        self.storage = storage ?? HybridUserStorage()
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
        
        // Set users synchronously during initialization to ensure proper startup order
        savedUsers = users
        print("UserManager: Loaded \(users.count) saved users")
        
        // Load current user immediately after savedUsers is populated
        loadCurrentUser()
    }
    
    /// Loads the current active user from storage
    private func loadCurrentUser() {
        if let currentUserId = getCurrentUserId(),
           let user = savedUsers.first(where: { $0.id == currentUserId }) {
            currentUser = user
            print("UserManager: Loaded current user: \(user.email)")
        } else {
            // If no previously saved user ID is found, or the user is not in the list,
            // set the first saved user as the current one.
            if let firstUser = savedUsers.first {
                currentUser = firstUser
                setCurrentUserId(firstUser.id)
                print("UserManager: No current user found. Defaulted to first saved user: \(firstUser.email)")
            } else {
                currentUser = nil
                print("UserManager: No users found in saved list.")
            }
        }
    }
    
    /// Switches to a different user account
    /// Returns the user's token for authentication
    func switchToUser(_ user: SavedUser) async throws -> String {
        guard let token = storage.getToken(forUserId: user.id) else {
            throw UserStorageError.tokenNotFound
        }
        
        // Clear cookies for the server when switching users to ensure clean authentication state
        clearHTTPCookies(for: user.serverURL)
        
        await MainActor.run {
            currentUser = user
            setCurrentUserId(user.id)
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
                clearHTTPCookies(for: user.serverURL)
                
                // If there are other users, switch to the first one
                if let nextUser = savedUsers.first {
                    currentUser = nextUser
                    setCurrentUserId(nextUser.id)
                    print("UserManager: Switched to next available user: \(nextUser.email)")
                } else {
                    // No other users available, clear current user
                    currentUser = nil
                    clearCurrentUserId()
                    print("UserManager: No other users available, cleared current user")
                }
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
        // Clear any existing cookies for this server to ensure clean password authentication
        clearHTTPCookies(for: serverURL)
        
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
        
        // Set as current user
        await MainActor.run {
            currentUser = savedUser
            setCurrentUserId(savedUser.id)
        }
        
        return authResponse.accessToken
    }
    
    /// Authenticates with API key and saves the user
    func authenticateWithApiKey(serverURL: String, email: String, apiKey: String) async throws -> String {
        // Clear any existing cookies for this server to ensure clean API key authentication
        clearHTTPCookies(for: serverURL)
        
        // Validate API key by fetching user info
        let userInfo = try await validateApiKey(serverURL: serverURL, apiKey: apiKey)
        
        // Create user object
        let userId = generateUserIdForUser(email: email, serverURL: serverURL)
        let savedUser = SavedUser(
            id: userId,
            email: email,
            name: userInfo.name,
            serverURL: serverURL,
            authType: .apiKey
        )
        
        // Save user and API key as token
        try await saveUser(savedUser, token: apiKey)
        
        // Set as current user
        await MainActor.run {
            currentUser = savedUser
            setCurrentUserId(savedUser.id)
        }
        
        return apiKey
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
            clearCurrentUserId()
        }
        
        print("UserManager: Cleared all user data")
    }
    
    /// Logs out only the current user (removes them from saved users)
    func logoutCurrentUser() async throws {
        guard let currentUser = currentUser else {
            print("UserManager: No current user to logout")
            return
        }
        
        print("UserManager: Logging out current user: \(currentUser.email)")
        try await removeUser(currentUser)
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
    
    private func validateApiKey(serverURL: String, apiKey: String) async throws -> User {
        let userURL = URL(string: "\(serverURL)/api/users/me")!
        var request = URLRequest(url: userURL)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "UserManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorResponse["message"] as? String {
                throw NSError(domain: "UserManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
            } else {
                throw NSError(domain: "UserManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API key validation failed"])
            }
        }
        
        return try JSONDecoder().decode(User.self, from: data)
    }
    
    // MARK: - Current User Persistence
    
    private var sharedDefaults: UserDefaults {
        return UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? UserDefaults.standard
    }
    
    private func setCurrentUserId(_ userId: String) {
        sharedDefaults.set(userId, forKey: "currentActiveUserId")
        print("UserManager: Set current user ID: \(userId)")
    }
    
    private func getCurrentUserId() -> String? {
        return sharedDefaults.string(forKey: "currentActiveUserId")
    }
    
    private func clearCurrentUserId() {
        sharedDefaults.removeObject(forKey: "currentActiveUserId")
        print("UserManager: Cleared current user ID")
    }
    
    // MARK: - Public Current User Methods
    
    /// Gets the current user's authentication token
    var currentUserToken: String? {
        guard let currentUser = currentUser else { return nil }
        return getUserToken(currentUser)
    }
    
    /// Gets the current user's server URL
    var currentUserServerURL: String? {
        return currentUser?.serverURL
    }
    
    /// Gets the current user's authentication type
    var currentUserAuthType: SavedUser.AuthType? {
        return currentUser?.authType
    }
    
    /// Checks if there's a currently authenticated user
    var hasCurrentUser: Bool {
        return currentUser != nil && currentUserToken != nil
    }
    
    // MARK: - HTTP Cookie Management
    
    /// Clears HTTP cookies for a specific server URL
    private func clearHTTPCookies(for serverURL: String) {
        guard let url = URL(string: serverURL) else { return }
        
        let cookieStorage = HTTPCookieStorage.shared
        if let cookies = cookieStorage.cookies(for: url) {
            for cookie in cookies {
                cookieStorage.deleteCookie(cookie)
                print("UserManager: Deleted cookie: \(cookie.name) for \(cookie.domain)")
            }
            print("UserManager: Cleared \(cookies.count) cookies for \(serverURL)")
        } else {
            print("UserManager: No cookies found for \(serverURL)")
        }
    }
    
    /// Clears all HTTP cookies (use with caution)
    private func clearAllHTTPCookies() {
        let cookieStorage = HTTPCookieStorage.shared
        if let cookies = cookieStorage.cookies {
            for cookie in cookies {
                cookieStorage.deleteCookie(cookie)
            }
            print("UserManager: Cleared all \(cookies.count) HTTP cookies")
        }
    }
}
