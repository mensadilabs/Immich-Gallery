//
//  UserDefaultsStorage.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-08-30
//

import Foundation

/// UserDefaults-based implementation of UserStorage protocol
class UserDefaultsStorage: UserStorage {
    private let userDefaults = UserDefaults.standard
    
    // MARK: - User Management
    
    func saveUser(_ user: SavedUser) throws {
        guard let userData = try? JSONEncoder().encode(user) else {
            throw UserStorageError.encodingFailed
        }
        
        let key = "\(UserDefaultsKeys.userPrefix)\(user.id)"
        userDefaults.set(userData, forKey: key)
        print("UserDefaultsStorage: Saved user \(user.email) with ID \(user.id)")
    }
    
    func loadUsers() -> [SavedUser] {
        var users: [SavedUser] = []
        
        // Get all keys that start with the user prefix
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let userKeys = allKeys.filter { $0.hasPrefix(UserDefaultsKeys.userPrefix) }
        
        for key in userKeys {
            if let userData = userDefaults.data(forKey: key) {
                do {
                    let user = try JSONDecoder().decode(SavedUser.self, from: userData)
                    users.append(user)
                    print("UserDefaultsStorage: Successfully loaded user \(user.email)")
                } catch {
                    print("UserDefaultsStorage: Failed to decode user data for key \(key): \(error)")
                    // Could implement migration logic here if needed
                }
            }
        }
        
        // Sort by creation date, newest first
        return users.sorted { $0.createdAt > $1.createdAt }
    }
    
    func removeUser(withId id: String) throws {
        let userKey = "\(UserDefaultsKeys.userPrefix)\(id)"
        userDefaults.removeObject(forKey: userKey)
        
        // Also remove associated token
        try removeToken(forUserId: id)
        
        print("UserDefaultsStorage: Removed user with ID \(id)")
    }
    
    // MARK: - Token Management
    
    func saveToken(_ token: String, forUserId id: String) throws {
        let key = "\(UserDefaultsKeys.tokenPrefix)\(id)"
        userDefaults.set(token, forKey: key)
        print("UserDefaultsStorage: Saved token for user ID \(id)")
    }
    
    func getToken(forUserId id: String) -> String? {
        let key = "\(UserDefaultsKeys.tokenPrefix)\(id)"
        return userDefaults.string(forKey: key)
    }
    
    func removeToken(forUserId id: String) throws {
        let key = "\(UserDefaultsKeys.tokenPrefix)\(id)"
        userDefaults.removeObject(forKey: key)
        print("UserDefaultsStorage: Removed token for user ID \(id)")
    }
    
    // MARK: - Cleanup
    
    func removeAllUserData() throws {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Remove all user data
        let userKeys = allKeys.filter { $0.hasPrefix(UserDefaultsKeys.userPrefix) }
        userKeys.forEach { userDefaults.removeObject(forKey: $0) }
        
        // Remove all tokens
        let tokenKeys = allKeys.filter { $0.hasPrefix(UserDefaultsKeys.tokenPrefix) }
        tokenKeys.forEach { userDefaults.removeObject(forKey: $0) }
        
        print("UserDefaultsStorage: Removed all user data")
    }
}

// MARK: - Error Types

enum UserStorageError: Error, LocalizedError {
    case encodingFailed
    case decodingFailed
    case userNotFound
    case tokenNotFound
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode user data"
        case .decodingFailed:
            return "Failed to decode user data"
        case .userNotFound:
            return "User not found"
        case .tokenNotFound:
            return "Token not found for user"
        }
    }
}