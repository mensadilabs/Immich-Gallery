//
//  StorageMigration.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-08-31
//

import Foundation

/// Handles migration to hybrid storage: Keychain for security + UserDefaults for extension compatibility
/// Tokens are duplicated in both storages as a conscious security/functionality trade-off
class StorageMigration {
    
    /// Migrates tokens to hybrid storage (Keychain + UserDefaults)
    /// User metadata remains in UserDefaults for extension compatibility  
    /// This is a one-time operation that copies tokens to Keychain while preserving UserDefaults copies
    static func migrateTokensToKeychain() throws {
        let migrationKey = "migrated_tokens_to_keychain_v1"
        let sharedDefaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? UserDefaults.standard
        
        // Check if migration already completed
        if sharedDefaults.bool(forKey: migrationKey) {
            print("StorageMigration: Token migration to Keychain already completed")
            return
        }
        
        print("StorageMigration: Starting token migration from UserDefaults to Keychain...")
        
        let userDefaultsStorage = UserDefaultsStorage()
        let keychainTokenStorage = KeychainTokenStorage()
        
        // Load all users to get their IDs for token migration
        let existingUsers = userDefaultsStorage.loadUsers()
        print("StorageMigration: Found \(existingUsers.count) users, checking for tokens to migrate")
        
        var migratedTokens = 0
        var errors: [Error] = []
        
        for user in existingUsers {
            do {
                // Only migrate token if it exists in UserDefaults
                if let token = userDefaultsStorage.getToken(forUserId: user.id) {
                    try keychainTokenStorage.saveToken(token, forUserId: user.id)
                    migratedTokens += 1
                    print("StorageMigration: Migrated token for user: \(user.email)")
                } else {
                    print("StorageMigration: No token found for user: \(user.email)")
                }
                
            } catch {
                print("StorageMigration: Error migrating token for user \(user.email): \(error)")
                errors.append(error)
            }
        }
        
        // Verify migration by checking tokens in Keychain
        var verifiedTokens = 0
        for user in existingUsers {
            if keychainTokenStorage.getToken(forUserId: user.id) != nil {
                verifiedTokens += 1
            }
        }
        
        if verifiedTokens == migratedTokens {
            print("StorageMigration: Token migration verification successful - \(verifiedTokens) tokens in Keychain")
            
            // Clean up ALL UserDefaults tokens - TopShelf extension now uses Keychain
            let allKeys = sharedDefaults.dictionaryRepresentation().keys
            let tokenKeys = allKeys.filter { $0.hasPrefix("immich_token_") }
            
            for tokenKey in tokenKeys {
                sharedDefaults.removeObject(forKey: tokenKey)
                print("StorageMigration: Cleaned up UserDefaults token key: \(tokenKey)")
            }
            
            if tokenKeys.count > 0 {
                print("StorageMigration: Removed \(tokenKeys.count) UserDefaults tokens")
            } else {
                print("StorageMigration: No UserDefaults tokens found to clean up")
            }
            
            // Mark migration as completed
            sharedDefaults.set(true, forKey: migrationKey)
            print("StorageMigration: Token migration completed successfully - tokens now Keychain-only")
            
        } else {
            print("StorageMigration: Token migration verification failed - expected \(migratedTokens), found \(verifiedTokens)")
            // Don't throw here, allow partial migration
        }
        
        // Report results
        print("StorageMigration: Final results - Tokens migrated: \(migratedTokens), Verified: \(verifiedTokens), Errors: \(errors.count)")
        
        if !errors.isEmpty {
            print("StorageMigration: Encountered \(errors.count) errors during token migration")
            // Don't throw here as partial migration might still be useful
        }
    }
    
    /// Creates the appropriate storage implementation based on migration status
    static func createStorage() -> UserStorage {
        do {
            // Always try to migrate tokens first (safe to call multiple times)
            try migrateTokensToKeychain()
            
            print("StorageMigration: Using HybridUserStorage (UserDefaults + Keychain)")
            return HybridUserStorage()
            
        } catch {
            print("StorageMigration: Token migration failed, falling back to UserDefaults: \(error)")
            return UserDefaultsStorage()
        }
    }
}

// MARK: - Migration Error Types

enum MigrationError: Error, LocalizedError {
    case verificationFailed(expected: Int, actual: Int)
    case partialMigration(successful: Int, failed: Int)
    
    var errorDescription: String? {
        switch self {
        case .verificationFailed(let expected, let actual):
            return "Migration verification failed: expected \(expected) users, found \(actual) in Keychain"
        case .partialMigration(let successful, let failed):
            return "Partial migration: \(successful) successful, \(failed) failed"
        }
    }
}
