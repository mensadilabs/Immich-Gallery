//
//  UserStorage.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-08-30
//

import Foundation

/// Protocol for user data storage abstraction
protocol UserStorage {
    func saveUser(_ user: SavedUser) throws
    func loadUsers() -> [SavedUser]
    func removeUser(withId id: String) throws
    func saveToken(_ token: String, forUserId id: String) throws
    func getToken(forUserId id: String) -> String?
    func removeToken(forUserId id: String) throws
    func removeAllUserData() throws
}