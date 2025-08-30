//
//  AuthenticationService.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import Foundation

/// Service responsible for authentication and user management
class AuthenticationService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: Owner?
    
    private let networkService: NetworkService
    private let userManager: UserManager
    
    // Public access to network service properties
    var baseURL: String {
        return networkService.baseURL
    }
    
    var accessToken: String? {
        return networkService.accessToken
    }
    
    init(networkService: NetworkService, userManager: UserManager) {
        self.networkService = networkService
        self.userManager = userManager
        self.isAuthenticated = networkService.accessToken != nil && !networkService.baseURL.isEmpty
        print("AuthenticationService: Initialized with isAuthenticated: \(isAuthenticated), baseURL: \(networkService.baseURL)")
        validateTokenIfNeeded()
    }
    
    // MARK: - Authentication
    func signIn(serverURL: String, email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        Task {
            do {
                let token = try await userManager.authenticateWithCredentials(
                    serverURL: serverURL,
                    email: email,
                    password: password
                )
                
                // Update network service with new credentials
                networkService.saveCredentials(serverURL: serverURL, token: token)
                
                // Save email to UserDefaults for backward compatibility
                UserDefaults.standard.set(email, forKey: UserDefaultsKeys.userEmail)
                if let sharedDefaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) {
                    sharedDefaults.set(email, forKey: UserDefaultsKeys.userEmail)
                }
                
                await MainActor.run {
                    self.isAuthenticated = true
                    print("AuthenticationService: Successfully authenticated user: \(email)")
                }
                
                // Fetch user details
                do {
                    try await self.fetchUserInfo()
                } catch {
                    // Create fallback user object from saved user
                    if let savedUser = userManager.findUser(email: email, serverURL: serverURL) {
                        await MainActor.run {
                            self.currentUser = Owner(
                                id: savedUser.id,
                                email: savedUser.email,
                                name: savedUser.name,
                                profileImagePath: "",
                                profileChangedAt: "",
                                avatarColor: "primary"
                            )
                        }
                    }
                }
                
                await MainActor.run {
                    completion(true, nil)
                }
                
            } catch {
                await MainActor.run {
                    completion(false, error.localizedDescription)
                }
            }
        }
    }
    
    func signOut() {
        print("AuthenticationService: Signing out user")
        networkService.clearCredentials()
        isAuthenticated = false
        currentUser = nil
    }
    
    func switchUser(_ user: SavedUser) async throws {
        let token = try await userManager.switchToUser(user)
        
        // Update network service with new credentials
        networkService.saveCredentials(serverURL: user.serverURL, token: token)
        
        // Update email in UserDefaults for backward compatibility
        UserDefaults.standard.set(user.email, forKey: UserDefaultsKeys.userEmail)
        if let sharedDefaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) {
            sharedDefaults.set(user.email, forKey: UserDefaultsKeys.userEmail)
        }
        
        await MainActor.run {
            self.isAuthenticated = true
            print("AuthenticationService: Switched to user \(user.email)")
        }
        
        // Fetch user details from server
        do {
            try await fetchUserInfo()
        } catch {
            // Create fallback user object from saved user
            await MainActor.run {
                self.currentUser = Owner(
                    id: user.id,
                    email: user.email,
                    name: user.name,
                    profileImagePath: "",
                    profileChangedAt: "",
                    avatarColor: "primary"
                )
            }
        }
    }

    
    // MARK: - User Management
    func fetchUserInfo() async throws {
        print("AuthenticationService: Fetching user info from server")
        let user: User = try await networkService.makeRequest(
            endpoint: "/api/users/me",
            responseType: User.self
        )
        
        let owner = Owner(
            id: user.id,
            email: user.email,
            name: user.name,
            profileImagePath: user.profileImagePath,
            profileChangedAt: user.profileChangedAt,
            avatarColor: user.avatarColor
        )
        
        DispatchQueue.main.async {
            print("AuthenticationService: Updating currentUser to \(owner.email)")
            self.currentUser = owner
        }
    }
    
    private func validateTokenIfNeeded() {
        guard isAuthenticated && !networkService.baseURL.isEmpty else { 
            print("AuthenticationService: Skipping token validation - not authenticated or no baseURL")
            return 
        }
        
        Task {
            do {
                try await fetchUserInfo()
                print("AuthenticationService: Token validation successful")
            } catch let error as ImmichError {
                print("AuthenticationService: Token validation failed with ImmichError: \(error)")
                
                if error.shouldLogout {
                    print("AuthenticationService: Logging out user due to authentication error: \(error)")
                    DispatchQueue.main.async {
                        self.signOut()
                    }
                } else {
                    print("AuthenticationService: Preserving authentication state despite error: \(error)")
                    // For server/network errors, preserve authentication state
                    // The user will see error messages in the UI but won't be logged out
                }
            } catch {
                print("AuthenticationService: Token validation failed with unexpected error: \(error)")
                // Handle unexpected errors conservatively - don't logout
                // This preserves user authentication state for unknown error types
            }
        }
    }
} 
