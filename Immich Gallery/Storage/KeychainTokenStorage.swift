//
//  KeychainTokenStorage.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-08-31
//

import Foundation
import Security

/// Lightweight Keychain storage for authentication tokens only
class KeychainTokenStorage {
    private let service: String
    
    init(service: String = "com.mensadi-labs.immich-gallery") {
        self.service = service
    }
    
    // MARK: - Token Management
    
    func saveToken(_ token: String, forUserId id: String) throws {
        guard let tokenData = token.data(using: .utf8) else {
            throw UserStorageError.encodingFailed
        }
        
        let account = "token_\(id)"
        try saveData(tokenData, account: account)
        print("KeychainTokenStorage: Saved token for user ID \(id)")
    }
    
    func getToken(forUserId id: String) -> String? {
        let account = "token_\(id)"
        
        guard let tokenData = try? loadData(account: account),
              let token = String(data: tokenData, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    func removeToken(forUserId id: String) throws {
        let account = "token_\(id)"
        try deleteItem(account: account)
        print("KeychainTokenStorage: Removed token for user ID \(id)")
    }
    
    func removeAllTokens() throws {
        // Query for all token items in our service
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        // errSecItemNotFound is OK - means nothing to delete
        if status != errSecSuccess && status != errSecItemNotFound {
            print("KeychainTokenStorage: Delete all failed with status: \(status)")
            throw UserStorageError.deleteFailed
        }
        
        print("KeychainTokenStorage: Removed all tokens")
    }
    
    // MARK: - Private Keychain Helpers
    
    private func saveData(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            print("KeychainTokenStorage: Save failed with status: \(status)")
            throw UserStorageError.saveFailed
        }
    }
    
    private func loadData(account: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw UserStorageError.loadFailed
        }
        
        return data
    }
    
    private func deleteItem(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        // errSecItemNotFound is OK - means item already doesn't exist
        if status != errSecSuccess && status != errSecItemNotFound {
            print("KeychainTokenStorage: Delete failed with status: \(status)")
            throw UserStorageError.deleteFailed
        }
    }
}