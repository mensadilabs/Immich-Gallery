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

// MARK: - Main Settings View

struct SettingsView: View {
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @ObservedObject var authService: AuthenticationService
    @State private var showingClearCacheAlert = false
    @State private var showingSignOutAlert = false
    @State private var showingSignIn = false
    @State private var showingWhatsNew = false
    @State private var savedUsers: [SavedUser] = []
    @AppStorage("hideImageOverlay") private var hideImageOverlay = true
    @AppStorage("slideshowInterval") private var slideshowInterval: Double = 6.0
    @AppStorage("slideshowBackgroundColor") private var slideshowBackgroundColor = "white"
    @AppStorage("showTagsTab") private var showTagsTab = false
    @AppStorage("defaultStartupTab") private var defaultStartupTab = "photos"
    @AppStorage("assetSortOrder") private var assetSortOrder = "desc"
    @AppStorage("use24HourClock") private var use24HourClock = true
    @AppStorage("enableReflectionsInSlideshow") private var enableReflectionsInSlideshow = true
    @AppStorage("enableKenBurnsEffect") private var enableKenBurnsEffect = false
    @AppStorage("enableThumbnailAnimation") private var enableThumbnailAnimation = true
    @AppStorage("enableSlideshowShuffle") private var enableSlideshowShuffle = false
    @AppStorage("allPhotosSortOrder") private var allPhotosSortOrder = "desc"
    @AppStorage("enableTopShelf") private var enableTopShelf = true
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
                        // User Actions Section
                        VStack(spacing: 16) {
                                Button(action: {
                                    showingSignIn = true
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "person.badge.plus")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                        Text("Add User")
                                            .font(.caption)
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
                                    HStack(spacing: 8) {
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
                        
                        // Interface Settings Section
                        SettingsSection(title: "Interface") {
                            AnyView(VStack(spacing: 12) {
                                SettingsRow(
                                    icon: "tag",
                                    title: "Show Tags Tab",
                                    subtitle: "Enable the tags tab in the main navigation",
                                    content: AnyView(Toggle("", isOn: $showTagsTab).labelsHidden())
                                )
                                
                                SettingsRow(
                                    icon: "house",
                                    title: "Default Startup Tab",
                                    subtitle: "Choose which tab opens when the app starts",
                                    content: AnyView(
                                        Picker("Default Tab", selection: $defaultStartupTab) {
                                            Text("All Photos").tag("photos")
                                            Text("Albums").tag("albums")
                                            Text("People").tag("people")
                                            if showTagsTab {
                                                Text("Tags").tag("tags")
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .frame(width: 300, alignment: .trailing)
                                    )
                                )
                                
                                SettingsRow(
                                    icon: "play.rectangle.on.rectangle",
                                    title: "Enable Thumbnail Animation",
                                    subtitle: "Animate thumbnails in Albums, People, and Tags views",
                                    content: AnyView(Toggle("", isOn: $enableThumbnailAnimation).labelsHidden())
                                )
                                
                                SettingsRow(
                                    icon: "tv",
                                    title: "Top Shelf Extension",
                                    subtitle: "Show recent photos on Apple TV home screen",
                                    content: AnyView(Toggle("", isOn: $enableTopShelf).labelsHidden())
                                )
                            })
                        }
                        
                        // Sorting Settings Section
                        SettingsSection(title: "Sorting") {
                            AnyView(VStack(spacing: 12) {
                                SettingsRow(
                                    icon: "photo.on.rectangle",
                                    title: "All Photos Sort Order",
                                    subtitle: "Order photos in the All Photos tab",
                                    content: AnyView(
                                        Picker("All Photos Sort Order", selection: $allPhotosSortOrder) {
                                            Text("Newest First").tag("desc")
                                            Text("Oldest First").tag("asc")
                                        }
                                        .pickerStyle(.menu)
                                        .frame(width: 300, alignment: .trailing)
                                    )
                                )
                                
                                SettingsRow(
                                    icon: "arrow.up.arrow.down",
                                    title: "Albums & Collections Sort Order",
                                    subtitle: "Order photos in Albums, People, and Tags",
                                    content: AnyView(
                                        Picker("Collections Sort Order", selection: $assetSortOrder) {
                                            Text("Newest First").tag("desc")
                                            Text("Oldest First").tag("asc")
                                        }
                                        .pickerStyle(.menu)
                                        .frame(width: 300, alignment: .trailing)
                                    )
                                )
                            })
                        }
                        
                        // Slideshow Settings Section
                        SettingsSection(title: "Slideshow") {
                            AnyView(VStack(spacing: 12) {
                                SlideshowSettings(
                                    slideshowInterval: $slideshowInterval,
                                    slideshowBackgroundColor: $slideshowBackgroundColor,
                                    use24HourClock: $use24HourClock,
                                    hideOverlay: $hideImageOverlay,
                                    enableReflections: $enableReflectionsInSlideshow,
                                    enableKenBurns: $enableKenBurnsEffect,
                                    enableShuffle: $enableSlideshowShuffle,
                                    isMinusFocused: $isMinusFocused,
                                    isPlusFocused: $isPlusFocused,
                                    focusedColor: $focusedColor
                                )
                            })
                        }
                        
                        // Help Section
                        SettingsSection(title: "Help & Tips") {
                            AnyView(VStack(spacing: 12) {
                                SettingsRow(
                                    icon: "play.circle",
                                    title: "Start Slideshow",
                                    subtitle: "Press play anywhere in the photo grid to start slideshow from the highlighted image",
                                    content: AnyView(
                                        HStack(spacing: 8) {
                                            Image(systemName: "play.fill")
                                                .font(.title3)
                                            Text("Play/Pause")
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                    )
                                )
                                
                                SettingsRow(
                                    icon: "arrow.up.and.down.and.arrow.left.and.right",
                                    title: "Navigate Photos",
                                    subtitle: "Swipe left or right to navigate. Swipe up and down to show hide image details in the fullscreen view",
                                    content: AnyView(
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.left")
                                                .foregroundColor(.gray)
                                                .font(.caption)
                                            Image(systemName: "arrow.right")
                                                .foregroundColor(.gray)
                                                .font(.caption)
                                            Image(systemName: "arrow.up")
                                                .foregroundColor(.gray)
                                                .font(.caption)
                                            Image(systemName: "arrow.down")
                                                .foregroundColor(.gray)
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                    )
                                )
                                
                                Button(action: {
                                    showingWhatsNew = true
                                }) {
                                    SettingsRow(
                                        icon: "doc.text",
                                        title: "What's New",
                                        subtitle: "View changelog and latest features",
                                        content: AnyView(
                                            HStack(spacing: 8) {
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(.blue)
                                                    .font(.caption)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(8)
                                        )
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    requestAppStoreReview()
                                }) {
                                    SettingsRow(
                                        icon: "star",
                                        title: "Rate App",
                                        subtitle: "Leave a review on the App Store",
                                        content: AnyView(
                                            HStack(spacing: 8) {
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(.blue)
                                                    .font(.caption)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(8)
                                        )
                                    )
                                }
                                .buttonStyle(.plain)
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
            .sheet(isPresented: $showingSignIn) {
                SignInView(authService: authService, mode: .addUser, onUserAdded: loadSavedUsers)
            }
            .sheet(isPresented: $showingWhatsNew) {
                WhatsNewView(onDismiss: {
                    showingWhatsNew = false
                })
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
    
    private func requestAppStoreReview() {
        let appStoreID = "id6748482378"
        if let url = URL(string: "itms-apps://itunes.apple.com/app/id\(appStoreID)?action=write-review") {
            UIApplication.shared.open(url)
        }
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



#Preview {
    let networkService = NetworkService()
    let authService = AuthenticationService(networkService: networkService)
    SettingsView(authService: authService)
}


