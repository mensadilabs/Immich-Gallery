//
//  SettingsView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @ObservedObject var authService: AuthenticationService
    @State private var showingClearCacheAlert = false
    @State private var showingSignOutAlert = false
    @State private var showingAddUser = false
    @State private var savedUsers: [SavedUser] = []
    @AppStorage("hideImageOverlay") private var hideImageOverlay = false
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.3),
                        Color.purple.opacity(0.2),
                        Color.gray.opacity(0.4)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // User Management Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("User Management")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            // Current User Display
                            if let user = authService.currentUser {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(user.name)
                                            .font(.headline)
                                        Text(user.email)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("Active")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            // User Switcher
                            if savedUsers.count > 1 {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Switch User")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    ForEach(savedUsers.filter { $0.email != authService.currentUser?.email }, id: \.id) { user in
                                        HStack {
                                            Button(action: {
                                                switchToUser(user)
                                            }) {
                                                HStack {
                                                    Image(systemName: "person.circle")
                                                        .foregroundColor(.blue)
                                                        .font(.title3)
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(user.name)
                                                            .font(.subheadline)
                                                            .foregroundColor(.primary)
                                                        Text(user.email)
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    Image(systemName: "arrow.right.circle")
                                                        .foregroundColor(.blue)
                                                        .font(.title3)
                                                }
                                                .padding()
                                                .background(Color.gray.opacity(0.1))
                                                .cornerRadius(12)
                                            }
                                            .buttonStyle(.plain)
                                            
                                            Button(action: {
                                                removeUser(user)
                                            }) {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.red)
                                                    .font(.title3)
                                                    .padding(8)
                                                    .background(Color.red.opacity(0.1))
                                                    .cornerRadius(8)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            
                            // Add User Button
                            Button(action: {
                                showingAddUser = true
                            }) {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                        .foregroundColor(.blue)
                                    Text("Add Another User")
                                        .foregroundColor(.blue)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Account Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Account")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            if let user = authService.currentUser {
                                HStack {
                                    Image(systemName: "server.rack")
                                        .foregroundColor(.green)
                                    Text("Server")
                                    Spacer()
                                    Text(authService.baseURL)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                showingSignOutAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .foregroundColor(.red)
                                    Text("Sign Out")
                                        .foregroundColor(.red)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                            }.buttonStyle(.plain)
                        }
                        
                        // Display Settings Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Display Settings")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "eye.slash")
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Hide Image Overlays")
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        Text("Hide date, location, and other info overlays on images")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $hideImageOverlay)
                                        .labelsHidden()
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Cache Management Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Cache Management")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Button(action: {
                                showingClearCacheAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                    Text("Clear All Cache")
                                        .foregroundColor(.red)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                            }.buttonStyle(.plain)
                            
                            Button(action: {
                                thumbnailCache.clearExpiredCache()
                            }) {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundColor(.orange)
                                    Text("Clear Expired Cache")
                                        .foregroundColor(.orange)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                            }.buttonStyle(.plain)
                        }
                        
                        // Cache Information Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Cache Information")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                // Cache Limits
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Cache Limits")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    HStack {
                                        Text("Memory Cache Limit")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(formatBytes(100 * 1024 * 1024))
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    HStack {
                                        Text("Disk Cache Limit")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(formatBytes(500 * 1024 * 1024))
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    HStack {
                                        Text("Max Memory Images")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("200")
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    HStack {
                                        Text("Cache Expiration")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("7 days")
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                    }
                                }
                                
                                Divider()
                                
                                // Current Usage
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Current Usage")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    HStack {
                                        Text("Memory Cache")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(formatBytes(thumbnailCache.memoryCacheSize))
                                                .font(.caption)
                                                .foregroundColor(.primary)
                                            Text("\(thumbnailCache.memoryCacheCount) images")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    HStack {
                                        Text("Disk Cache")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(formatBytes(thumbnailCache.diskCacheSize))
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    HStack {
                                        Text("Total Cache")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(formatBytes(thumbnailCache.memoryCacheSize + thumbnailCache.diskCacheSize))
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
            .sheet(isPresented: $showingAddUser) {
                AddUserView(onUserAdded: loadSavedUsers)
            }
            .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    thumbnailCache.clearAllCaches()
                }
            } message: {
                Text("This will remove all cached thumbnails from both memory and disk. Images will be re-downloaded when needed.")
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authService.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out? You'll need to sign in again to access your photos.")
            }
            .onAppear {
                loadSavedUsers()
            }
        }
    }
    
    private func loadSavedUsers() {
        savedUsers = []
        
        // Load current user if authenticated
        if let currentUser = authService.currentUser {
            let currentUserId = getCurrentUserId()
            savedUsers.append(SavedUser(
                id: currentUserId,
                email: currentUser.email,
                name: currentUser.name,
                serverURL: authService.baseURL
            ))
        }
        
        // Load other saved users
        let userDefaults = UserDefaults.standard
        let savedUserKeys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("immich_user_") }
        
        for key in savedUserKeys {
            if let userData = userDefaults.data(forKey: key),
               let user = try? JSONDecoder().decode(SavedUser.self, from: userData) {
                // Don't add if it's the current user
                if user.email != authService.currentUser?.email {
                    savedUsers.append(user)
                }
            }
        }
    }
    
    private func switchToUser(_ user: SavedUser) {
        // Save current user if authenticated
        if let currentUser = authService.currentUser {
            saveCurrentUser()
        }
        
        // Get the token for the selected user
        let token = UserDefaults.standard.string(forKey: "immich_token_\(user.id)")
        
        if let token = token {
            // Switch to the selected user
            authService.switchUser(
                serverURL: user.serverURL,
                accessToken: token,
                email: user.email,
                name: user.name
            )
            
            // Fetch user details
            Task {
                do {
                    try await authService.fetchUserInfo()
                    DispatchQueue.main.async {
                        self.loadSavedUsers()
                        // Refresh the app by posting a notification
                        NotificationCenter.default.post(name: .userSwitched, object: nil)
                    }
                } catch {
                    print("Failed to fetch user info: \(error)")
                }
            }
        }
    }
    
    private func saveCurrentUser() {
        guard let currentUser = authService.currentUser,
              let accessToken = authService.accessToken else { return }
        
        let userId = getCurrentUserId()
        let user = SavedUser(
            id: userId,
            email: currentUser.email,
            name: currentUser.name,
            serverURL: authService.baseURL
        )
        
        // Save user data
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "immich_user_\(userId)")
        }
        
        // Save token separately
        UserDefaults.standard.set(accessToken, forKey: "immich_token_\(userId)")
    }
    
    private func removeUser(_ user: SavedUser) {
        // Remove user data and token
        UserDefaults.standard.removeObject(forKey: "immich_user_\(user.id)")
        UserDefaults.standard.removeObject(forKey: "immich_token_\(user.id)")
        
        // Reload the saved users list
        loadSavedUsers()
    }
    
    private func getCurrentUserId() -> String {
        // Use email as user ID for simplicity
        return authService.currentUser?.email ?? "unknown"
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// Extension to make overlay setting easily accessible throughout the app
extension UserDefaults {
    var hideImageOverlay: Bool {
        get { bool(forKey: "hideImageOverlay") }
        set { set(newValue, forKey: "hideImageOverlay") }
    }
}

struct SavedUser: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let serverURL: String
}

struct AddUserView: View {
    let onUserAdded: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var serverURL = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.3),
                        Color.purple.opacity(0.2),
                        Color.gray.opacity(0.4)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Add New User")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Sign in with another account")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Form
                    VStack(spacing: 20) {
                        // Server URL
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Server URL")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("https://your-immich-server.com", text: $serverURL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .keyboardType(.URL)
                                .onAppear {
                                    if serverURL.isEmpty {
                                        serverURL = "https://"
                                    }
                                }
                        }
                        
                        // Email
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("your-email@example.com", text: $email)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .keyboardType(.emailAddress)
                        }
                        
                        // Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            SecureField("Enter your password", text: $password)
                        }
                    }
                    
                    // Sign In Button
                    Button(action: signIn) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            
                            Text(isLoading ? "Adding User..." : "Add User")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || serverURL.isEmpty || email.isEmpty || password.isEmpty)
                    .opacity((isLoading || serverURL.isEmpty || email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
                    
                    Spacer()
                }
                .padding(.horizontal, 30)
                .padding(.top, 50)
                .alert("Add User Error", isPresented: $showError) {
                    Button("OK") { }
                } message: {
                    Text(errorMessage)
                }
            }
            .navigationTitle("Add User")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
    
    private func signIn() {
        guard !serverURL.isEmpty && !email.isEmpty && !password.isEmpty else {
            return
        }
        
        isLoading = true
        
        // Clean up the server URL
        var cleanURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanURL.hasPrefix("http://") && !cleanURL.hasPrefix("https://") {
            cleanURL = "https://" + cleanURL
        }
        
        if cleanURL.hasSuffix("/") {
            cleanURL = String(cleanURL.dropLast())
        }
        
        guard URL(string: cleanURL) != nil else {
            isLoading = false
            showError = true
            errorMessage = "Please enter a valid server URL"
            return
        }
        
        // Perform authentication
        let loginURL = URL(string: "\(cleanURL)/api/auth/login")!
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
            isLoading = false
            showError = true
            errorMessage = "Error creating login request: \(error.localizedDescription)"
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    showError = true
                    errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    showError = true
                    errorMessage = "Invalid response from server"
                    return
                }
                
                guard let data = data else {
                    showError = true
                    errorMessage = "No data received from server"
                    return
                }
                
                if httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
                    if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = errorResponse["message"] as? String {
                        showError = true
                        errorMessage = message
                    } else {
                        showError = true
                        errorMessage = "Authentication failed (Status: \(httpResponse.statusCode))"
                    }
                    return
                }
                
                do {
                    let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                    
                    // Create user ID (using email as ID)
                    let userId = authResponse.userEmail
                    
                    // Save user data
                    let savedUser = SavedUser(
                        id: userId,
                        email: authResponse.userEmail,
                        name: authResponse.name,
                        serverURL: cleanURL
                    )
                    
                    if let userData = try? JSONEncoder().encode(savedUser) {
                        UserDefaults.standard.set(userData, forKey: "immich_user_\(userId)")
                    }
                    
                    // Save token separately
                    UserDefaults.standard.set(authResponse.accessToken, forKey: "immich_token_\(userId)")
                    
                    onUserAdded()
                    dismiss()
                    
                } catch {
                    showError = true
                    errorMessage = "Invalid response format from server"
                }
            }
        }.resume()
    }
}

#Preview {
    let networkService = NetworkService()
    let authService = AuthenticationService(networkService: networkService)
    SettingsView(authService: authService)
} 