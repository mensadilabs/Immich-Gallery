//
//  SettingsView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

// MARK: - Reusable Components

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let content: AnyView
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            content
        }
        .padding(16)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct SettingsSection: View {
    let title: String
    let content: () -> AnyView
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                content()
            }
        }
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Main Settings View

struct SettingsView: View {
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @ObservedObject var authService: AuthenticationService
    @State private var showingClearCacheAlert = false
    @State private var showingSignOutAlert = false
    @State private var showingAddUser = false
    @State private var savedUsers: [SavedUser] = []
    @AppStorage("hideImageOverlay") private var hideImageOverlay = true
    @AppStorage("slideshowInterval") private var slideshowInterval: Double = 6.0
    @AppStorage("slideshowBackgroundColor") private var slideshowBackgroundColor = "white"
    @AppStorage("showTagsTab") private var showTagsTab = false
    @AppStorage("assetSortOrder") private var assetSortOrder = "desc"
    @FocusState private var isMinusFocused: Bool
    @FocusState private var isPlusFocused: Bool
    @FocusState private var focusedColor: String?
    
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
                    LazyVStack(spacing: 30) {
                        // Server Info Section
                        Button(action: {
                            refreshServerConnection()
                        }) {
                            HStack {
                                Image(systemName: "server.rack")
                                    .foregroundColor(.green)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Server")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(authService.baseURL)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                    Text("Refresh")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                            }
                            .padding(16)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        // Current User Section
                        if let user = authService.currentUser {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(user.name)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                        Text(user.email)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("Active")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.green)
                                        .cornerRadius(12)
                                }
                                .padding(20)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.blue.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                        }
                        
                        // User Actions Section
                        VStack(spacing: 16) {
                            // Quick Actions
                            HStack(spacing: 16) {
                                Button(action: {
                                    showingAddUser = true
                                }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "person.badge.plus")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                        Text("Add User")
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(16)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    showingSignOutAlert = true
                                }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .font(.title2)
                                            .foregroundColor(.red)
                                        Text("Sign Out")
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(16)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // User Switcher
                            if savedUsers.count > 1 {
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
                        
                        // Display Settings Section
                        SettingsSection(title: "Customization") {
                            AnyView(VStack(spacing: 12) {
                                SettingsRow(
                                    icon: "eye.slash",
                                    title: "Hide Image Overlays",
                                    subtitle: "Hide date, location, and other info overlays",
                                    content: AnyView(Toggle("", isOn: $hideImageOverlay).labelsHidden())
                                )
                                
                                SettingsRow(
                                    icon: "tag",
                                    title: "Show Tags Tab",
                                    subtitle: "Enable the tags tab in the main navigation",
                                    content: AnyView(Toggle("", isOn: $showTagsTab).labelsHidden())
                                )
                                
                                SettingsRow(
                                    icon: "arrow.up.arrow.down",
                                    title: "Sort Order for everything",
                                    subtitle: "Order assets by creation date",
                                    content: AnyView(
                                        Picker("Sort Order", selection: $assetSortOrder) {
                                            Text("Newest First").tag("desc")
                                            Text("Oldest First").tag("asc")
                                        }
                                        .pickerStyle(.segmented)
                                        .frame(width: 500)
                                    )
                                )
                                
                                SlideshowSettings(
                                    slideshowInterval: $slideshowInterval,
                                    slideshowBackgroundColor: $slideshowBackgroundColor,
                                    isMinusFocused: $isMinusFocused,
                                    isPlusFocused: $isPlusFocused,
                                    focusedColor: $focusedColor
                                )
                            })
                        }
                        
                        // Cache Section
                        CacheSection(
                            thumbnailCache: thumbnailCache,
                            showingClearCacheAlert: $showingClearCacheAlert
                        )
                    }
                    .padding()
                }
            }
                            .sheet(isPresented: $showingAddUser) {
                    AddUserView(onUserAdded: loadSavedUsers, authService: authService)
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
                thumbnailCache.refreshCacheStatistics()
            }
        }
    }
    
    private func loadSavedUsers() {
        print("SettingsView: Loading saved users")
        savedUsers = []
        
        // Load current user if authenticated
        if let currentUser = authService.currentUser {
            let currentUserId = getCurrentUserId()
            let currentSavedUser = SavedUser(
                id: currentUserId,
                email: currentUser.email,
                name: currentUser.name,
                serverURL: authService.baseURL
            )
            savedUsers.append(currentSavedUser)
            print("SettingsView: Added current user \(currentUser.email) with ID \(currentUserId)")
        } else {
            print("SettingsView: No current user found in authService")
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
                    print("SettingsView: Added saved user \(user.email) with ID \(user.id)")
                }
            }
        }
        
        print("SettingsView: Total saved users: \(savedUsers.count)")
    }
    
    private func switchToUser(_ user: SavedUser) {
        print("SettingsView: Switching to user \(user.email) with ID \(user.id)")
        
        // Save current user if authenticated
        if let currentUser = authService.currentUser {
            print("SettingsView: Saving current user \(currentUser.email)")
            saveCurrentUser()
        }
        
        // Get the token for the selected user directly from UserDefaults
        if let token = UserDefaults.standard.string(forKey: "immich_token_\(user.id)") {
            print("SettingsView: Found token for user \(user.email), switching...")
            print("SettingsView: Token starts with: \(String(token.prefix(20)))...")
            
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
                    print("SettingsView: Fetching user info for \(user.email)")
                    try await authService.fetchUserInfo()
                    DispatchQueue.main.async {
                        print("SettingsView: Successfully switched to \(user.email), refreshing UI")
                        // Small delay to ensure the switch is complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.loadSavedUsers()
                            // Refresh the app by posting a notification
                            NotificationCenter.default.post(name: .refreshAllTabs, object: nil)
                        }
                    }
                } catch {
                    print("SettingsView: Failed to fetch user info: \(error)")
                    // Even if fetch fails, we should still refresh the UI
                    DispatchQueue.main.async {
                        self.loadSavedUsers()
                    }
                }
            }
        } else {
            print("SettingsView: No token found for user \(user.email) with ID \(user.id)")
        }
    }
    
    private func saveCurrentUser() {
        guard let currentUser = authService.currentUser,
              let accessToken = authService.accessToken else { 
            print("SettingsView: Cannot save current user - missing user or token")
            return 
        }
        
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
            print("SettingsView: Saved user data for \(currentUser.email)")
        }
        
        // Save token directly: "user@server" : token
        UserDefaults.standard.set(accessToken, forKey: "immich_token_\(userId)")
        print("SettingsView: Saved token for user \(currentUser.email)")
        print("SettingsView: Token starts with: \(String(accessToken.prefix(20)))...")
    }
    
    private func removeUser(_ user: SavedUser) {
        print("SettingsView: Removing user \(user.email)")
        
        // Remove user data
        UserDefaults.standard.removeObject(forKey: "immich_user_\(user.id)")
        
        // Remove token directly
        UserDefaults.standard.removeObject(forKey: "immich_token_\(user.id)")
        
        // Reload the saved users list
        loadSavedUsers()
    }
    
    private func getCurrentUserId() -> String {
        // Generate a unique user ID based on email and server URL
        guard let currentUser = authService.currentUser else { return "unknown" }
        return generateUserIdForUser(email: currentUser.email, serverURL: authService.baseURL)
    }
    

    
    private func refreshServerConnection() {
        Task {
            do {
                // Refresh user info to verify connection
                try await authService.fetchUserInfo()
                print("✅ Server connection refreshed successfully")
                
                // Post notification to refresh all tabs
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .refreshAllTabs, object: nil)
                }
            } catch {
                print("❌ Failed to refresh server connection: \(error)")
                // You could add an alert here to show the error to the user
            }
        }
    }
}

// Extension to make overlay setting easily accessible throughout the app
extension UserDefaults {
    var hideImageOverlay: Bool {
        get { bool(forKey: "hideImageOverlay") }
        set { set(newValue, forKey: "hideImageOverlay") }
    }
    
    var slideshowInterval: TimeInterval {
        get { double(forKey: "slideshowInterval") }
        set { set(newValue, forKey: "slideshowInterval") }
    }
    
    var slideshowBackgroundColor: String {
        get { string(forKey: "slideshowBackgroundColor") ?? "black" }
        set { set(newValue, forKey: "slideshowBackgroundColor") }
    }
    
    var showTagsTab: Bool {
        get { bool(forKey: "showTagsTab") }
        set { set(newValue, forKey: "showTagsTab") }
    }
}

struct SavedUser: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let serverURL: String
}

// Helper function to generate unique user IDs
func generateUserIdForUser(email: String, serverURL: String) -> String {
    // Create a unique ID based on email and server URL to handle same email across different servers
    let combined = "\(email)@\(serverURL)"
    return combined.data(using: .utf8)?.base64EncodedString() ?? email
}

struct AddUserView: View {
    let onUserAdded: () -> Void
    let authService: AuthenticationService
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
        
        // Direct authentication without affecting current user
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
            errorMessage = "Error creating login request"
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
                    
                    // Generate unique user ID: "user@server"
                    let userId = generateUserIdForUser(email: authResponse.userEmail, serverURL: cleanURL)
                    
                    print("AddUserView: Adding new user \(authResponse.userEmail) with ID \(userId)")
                    
                    // Save user data
                    let savedUser = SavedUser(
                        id: userId,
                        email: authResponse.userEmail,
                        name: authResponse.name,
                        serverURL: cleanURL
                    )
                    
                    if let userData = try? JSONEncoder().encode(savedUser) {
                        UserDefaults.standard.set(userData, forKey: "immich_user_\(userId)")
                        print("AddUserView: Saved user data for \(authResponse.userEmail)")
                    }
                    
                    // Save token directly: "user@server" : token
                    UserDefaults.standard.set(authResponse.accessToken, forKey: "immich_token_\(userId)")
                    print("AddUserView: Saved token for \(authResponse.userEmail) - starts with: \(String(authResponse.accessToken.prefix(20)))...")
                    
                    onUserAdded()
                    dismiss()
                    
                } catch {
                    showError = true
                    errorMessage = "Invalid response format from server"
                }
            }
        }.resume()
    }
    
    private func getBackgroundColor(_ colorName: String) -> Color {
        switch colorName {
        case "black": return .black
        case "white": return .white
        case "gray": return .gray
        case "blue": return .blue
        case "purple": return .purple
        default: return .black
        }
    }
}

// MARK: - Slideshow Settings Component

struct SlideshowSettings: View {
    @Binding var slideshowInterval: Double
    @Binding var slideshowBackgroundColor: String
    @FocusState.Binding var isMinusFocused: Bool
    @FocusState.Binding var isPlusFocused: Bool
    @FocusState.Binding var focusedColor: String?
    
    var body: some View {
        VStack(spacing: 12) {
            // Slideshow Interval Setting
            SettingsRow(
                icon: "timer",
                title: "Slideshow Interval",
                subtitle: "Time between slides in slideshow mode",
                content: AnyView(
                    HStack(spacing: 40) {
                        Button(action: {
                            if slideshowInterval > 2 {
                                slideshowInterval -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(isMinusFocused ? .white : .blue)
                                .font(.title2)
                        }
                        .buttonStyle(CustomFocusButtonStyle())
                        .disabled(slideshowInterval <= 2)
                        .focused($isMinusFocused)
                        
                        Text("\(Int(slideshowInterval))s")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(minWidth: 50)
                        
                        Button(action: {
                            if slideshowInterval < 15 {
                                slideshowInterval += 1
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(isPlusFocused ? .white : .blue)
                                .font(.title2)
                        }
                        .buttonStyle(CustomFocusButtonStyle())
                        .disabled(slideshowInterval >= 15)
                        .focused($isPlusFocused)
                    }
                )
            )
            
            // Slideshow Background Color Setting
            SettingsRow(
                icon: "paintbrush",
                title: "Slideshow Background",
                subtitle: "Background color for slideshow mode",
                content: AnyView(
                    HStack(spacing: 12) {
                        ForEach(["black", "white", "gray", "blue", "purple"], id: \.self) { color in
                            Button(action: {
                                slideshowBackgroundColor = color
                            }) {
                                Circle()
                                    .fill(getBackgroundColor(color))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(slideshowBackgroundColor == color ? Color.accentColor : Color.clear, lineWidth: 3)
                                    )
                                    .scaleEffect(slideshowBackgroundColor == color ? 1.18 : 1.0)
                            }
                            .buttonStyle(ColorSelectionButtonStyle())
                            .focused($focusedColor, equals: color)
                        }
                    }
                )
            )
        }
    }
    
    private func getBackgroundColor(_ colorName: String) -> Color {
        switch colorName {
        case "black": return .black
        case "white": return .white
        case "gray": return .gray
        case "blue": return .blue
        case "purple": return .purple
        default: return .black
        }
    }
}

// MARK: - Cache Section Component

struct CacheSection: View {
    @ObservedObject var thumbnailCache: ThumbnailCache
    @Binding var showingClearCacheAlert: Bool
    
    var body: some View {
        SettingsSection(title: "Cache") {
            AnyView(VStack(spacing: 16) {
                // Cache Actions
                HStack(spacing: 16) {
                    ActionButton(
                        icon: "clock.arrow.circlepath",
                        title: "Clear Expired",
                        color: .orange
                    ) {
                        thumbnailCache.clearExpiredCache()
                    }
                    
                    ActionButton(
                        icon: "trash",
                        title: "Clear All",
                        color: .red
                    ) {
                        showingClearCacheAlert = true
                    }
                }
                
                // Cache Information
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Usage")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
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
                .padding(16)
                .background(Color.gray.opacity(0.03))
                .cornerRadius(12)
                
                // Cache Limits
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cache Limits")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Memory Limit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatBytes(100 * 1024 * 1024))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Disk Limit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatBytes(500 * 1024 * 1024))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Expiration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("7 days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
                .background(Color.gray.opacity(0.03))
                .cornerRadius(12)
            })
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#Preview {
    let networkService = NetworkService()
    let authService = AuthenticationService(networkService: networkService)
    SettingsView(authService: authService)
}

 
