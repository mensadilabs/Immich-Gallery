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
    
    // Public access to network service properties
    var baseURL: String {
        return networkService.baseURL
    }
    
    var accessToken: String? {
        return networkService.accessToken
    }
    
    init(networkService: NetworkService) {
        self.networkService = networkService
        self.isAuthenticated = networkService.accessToken != nil && !networkService.baseURL.isEmpty
        print("AuthenticationService: Initialized with isAuthenticated: \(isAuthenticated), baseURL: \(networkService.baseURL)")
        validateTokenIfNeeded()
    }
    
    // MARK: - Authentication
    func signIn(serverURL: String, email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        let loginURL = URL(string: "\(serverURL)/api/auth/login")!
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let loginData = [
            "email": email,
            "password": password
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: loginData)
        } catch {
            completion(false, "Error creating login request: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "Invalid response from server")
                    return
                }
                
                guard let data = data else {
                    completion(false, "No data received from server")
                    return
                }
                
                if httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
                    if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = errorResponse["message"] as? String {
                        completion(false, message)
                    } else {
                        completion(false, "Authentication failed (Status: \(httpResponse.statusCode))")
                    }
                    return
                }
                
                do {
                    let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                    self?.networkService.saveCredentials(serverURL: serverURL, token: authResponse.accessToken)
                    
                    // Save email to both standard and shared UserDefaults
                    UserDefaults.standard.set(email, forKey: "immich_user_email")
                    if let sharedDefaults = UserDefaults(suiteName: "group.com.sanketh.dev.Immich-Gallery") {
                        sharedDefaults.set(email, forKey: "immich_user_email")
                    }
                    
                    self?.isAuthenticated = true
                    print("AuthenticationService: Successfully authenticated user: \(email)")
                    
                    // Fetch user details
                    Task {
                        do {
                            try await self?.fetchUserInfo()
                        } catch {
                            // Create fallback user object
                            self?.currentUser = Owner(
                                id: authResponse.userId,
                                email: authResponse.userEmail,
                                name: authResponse.name,
                                profileImagePath: authResponse.profileImagePath,
                                profileChangedAt: "",
                                avatarColor: "primary"
                            )
                        }
                    }
                    
                    completion(true, nil)
                } catch {
                    completion(false, "Invalid response format from server")
                }
            }
        }.resume()
    }
    
    func signOut() {
        print("AuthenticationService: Signing out user")
        networkService.clearCredentials()
        isAuthenticated = false
        currentUser = nil
    }
    
    func switchUser(serverURL: String, accessToken: String, email: String, name: String) {
        print("AuthenticationService: Switching to user \(email)")
        networkService.saveCredentials(serverURL: serverURL, token: accessToken)
        isAuthenticated = true
        
        currentUser = Owner(
            id: "",
            email: email,
            name: name,
            profileImagePath: "",
            profileChangedAt: "",
            avatarColor: "primary"
        )
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
        guard isAuthenticated && !networkService.baseURL.isEmpty else { return }
        
        Task {
            do {
                try await fetchUserInfo()
            } catch {
                DispatchQueue.main.async {
                    self.signOut()
                }
            }
        }
    }
} 