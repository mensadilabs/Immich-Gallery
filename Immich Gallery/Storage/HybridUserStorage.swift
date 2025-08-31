//
//  HybridUserStorage.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-08-31
//

import Foundation

/// Hybrid storage implementation combining UserDefaults for user data and Keychain for secure tokens
/// This approach provides optimal security for tokens while maintaining TopShelf extension compatibility
class HybridUserStorage: UserStorage {
    
    private let userStorage: UserDefaultsStorage
    private let tokenStorage: KeychainTokenStorage
    
    init() {
        self.userStorage = UserDefaultsStorage()
        self.tokenStorage = KeychainTokenStorage()
        print("HybridUserStorage: Initialized with UserDefaults for user data and Keychain for tokens")
    }
    
    // MARK: - User Management (UserDefaults)
    
    func saveUser(_ user: SavedUser) throws {
        try userStorage.saveUser(user)
        print("HybridUserStorage: Saved user \(user.email) to UserDefaults")
    }
    
    func loadUsers() -> [SavedUser] {
        let users = userStorage.loadUsers()
        print("HybridUserStorage: Loaded \(users.count) users from UserDefaults")
        return users
    }
    
    func removeUser(withId id: String) throws {
        // Remove user data from UserDefaults
        try userStorage.removeUser(withId: id)
        
        // Remove associated token from Keychain
        try tokenStorage.removeToken(forUserId: id)
        
        print("HybridUserStorage: Removed user with ID \(id) from both storages")
    }
    
    // MARK: - Token Management (Keychain)
    
    func saveToken(_ token: String, forUserId id: String) throws {
        // Save to Keychain only - TopShelf extension now has keychain access
        try tokenStorage.saveToken(token, forUserId: id)
        
        print("HybridUserStorage: Saved token for user ID \(id) to Keychain")
    }
    
    func getToken(forUserId id: String) -> String? {
        // Read from Keychain only
        if let token = tokenStorage.getToken(forUserId: id) {
            print("HybridUserStorage: Retrieved token for user ID \(id) from Keychain")
            return token
        }
        
        print("HybridUserStorage: No token found for user ID \(id) in Keychain")
        return nil
    }
    
    func removeToken(forUserId id: String) throws {
        // Remove from Keychain only
        try tokenStorage.removeToken(forUserId: id)
        print("HybridUserStorage: Removed token for user ID \(id) from Keychain")
    }
    
    // MARK: - Cleanup
    
    func removeAllUserData() throws {
        // Remove all user data from UserDefaults
        try userStorage.removeAllUserData()
        
        // Remove all tokens from Keychain
        try tokenStorage.removeAllTokens()
        
        print("HybridUserStorage: Removed all data from UserDefaults and Keychain")
    }
}
