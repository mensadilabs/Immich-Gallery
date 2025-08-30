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
    @ObservedObject var userManager: UserManager
    @State private var showingClearCacheAlert = false
    @State private var showingSignOutAlert = false
    @State private var showingSignIn = false
    @State private var showingWhatsNew = false
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
    @AppStorage("enableTopShelf", store: UserDefaults(suiteName: AppConstants.appGroupIdentifier)) private var enableTopShelf = false
    @AppStorage("topShelfStyle", store: UserDefaults(suiteName: AppConstants.appGroupIdentifier)) private var topShelfStyle = "carousel"
    @AppStorage(UserDefaultsKeys.autoSlideshowTimeout) private var autoSlideshowTimeout: Int = 0 // 0 = off
    @FocusState private var isMinusFocused: Bool
    @FocusState private var isPlusFocused: Bool
    @FocusState private var focusedColor: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                SharedGradientBackground()
                .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 30) {
                        
                        // Current User Section
                        if let savedUser = userManager.currentUser {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: savedUser.authType == .apiKey ? "key.fill" : "person.circle.fill")
                                        .foregroundColor(savedUser.authType == .apiKey ? .orange : .blue)
                                        .font(.title)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Text(savedUser.name)
                                                .font(.title2)
                                                .fontWeight(.bold)
                                            
                                            // Authentication Type Badge
                                            Text(savedUser.authType == .apiKey ? "API Key" : "Password")
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(savedUser.authType == .apiKey ? Color.orange : Color.blue)
                                                .cornerRadius(6)
                                        }
                                        
                                        Text(savedUser.email)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Text(savedUser.serverURL)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(spacing: 4) {
                                        Text("Active")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.green)
                                            .cornerRadius(8)
                                    }
                                }
                                .padding(20)
                                .background {
                                    let accentColor = savedUser.authType == .apiKey ? Color.orange : Color.blue
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(accentColor.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(accentColor.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        
                        // Server Info Section
                        Button(action: {
                            refreshServerConnection()
                        }) {
                            HStack {
                                Image(systemName: authService.baseURL.lowercased().hasPrefix("https") ? "lock.fill" : "lock.open.fill")
                                    .foregroundColor(authService.baseURL.lowercased().hasPrefix("https") ? .green : .red)
                                    .font(.headline)
                                    .padding()
                                
                                Text(authService.baseURL)
                                    .font(.headline)
                                    .foregroundColor(.primary)
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
                            
                            // User Switcher (Total: \(userManager.savedUsers.count))
                            if userManager.savedUsers.count > 1 {
                                ForEach(userManager.savedUsers.filter { $0.id != userManager.currentUser?.id }, id: \.id) { user in
                                    HStack {
                                        Button(action: {
                                            switchToUser(user)
                                        }) {
                                            HStack {
                                                Image(systemName: user.authType == .apiKey ? "key.fill" : "person.circle")
                                                    .foregroundColor(user.authType == .apiKey ? .orange : .blue)
                                                    .font(.title3)
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack(spacing: 8) {
                                                        Text(user.authType == .apiKey ? "API Key" : "Password")
                                                            .font(.caption2)
                                                            .fontWeight(.semibold)
                                                            .foregroundColor(.white)
                                                            .padding(.horizontal, 8)
                                                            .padding(.vertical, 3)
                                                            .background(user.authType == .apiKey ? Color.orange : Color.blue)
                                                            .cornerRadius(6)
                                                        
                                                        Text(user.name)
                                                            .font(.subheadline)
                                                            .fontWeight(.medium)
                                                            .foregroundColor(.primary)
                                                    }
                                                    
                                                    Text(user.email)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    
                                                    Text(user.serverURL)
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                }
                                                
                                                Spacer()
                                                
                                                Image(systemName: "arrow.right.circle")
                                                    .foregroundColor(user.authType == .apiKey ? .orange : .blue)
                                                    .font(.title3)
                                            }
                                            .padding()
                                            .background {
                                                let accentColor = user.authType == .apiKey ? Color.orange : Color.blue
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(accentColor.opacity(0.05))
                                            }
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
                                    subtitle: "Animate thumbnails in Albums, People, and Tags views.",
                                    content: AnyView(Toggle("", isOn: $enableThumbnailAnimation).labelsHidden())
                                )
                                
                                
                                SettingsRow(
                                    icon: "tv",
                                    title: "Top Shelf Extension",
                                    subtitle: "Show recent photos on Apple TV home screen",
                                    content: AnyView(Toggle("", isOn: $enableTopShelf).labelsHidden())
                                )
                                
                                if enableTopShelf {
                                    SettingsRow(
                                        icon: "rectangle.grid.1x2",
                                        title: "Top Shelf Style",
                                        subtitle: "Choose between compact sectioned or wide carousel display",
                                        content: AnyView(
                                            Picker("Top Shelf Style", selection: $topShelfStyle) {
                                                Text("Compact").tag("sectioned")
                                                Text("Fullscreen").tag("carousel")
                                            }
                                                .pickerStyle(.menu)
                                                .frame(width: 300, alignment: .trailing)
                                        )
                                    )
                                }
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
                                    autoSlideshowTimeout: $autoSlideshowTimeout,
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
                SignInView(authService: authService, userManager: userManager, mode: .addUser, onUserAdded: { userManager.loadUsers() })
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
                userManager.loadUsers()
                thumbnailCache.refreshCacheStatistics()
            }
        }
    }
    
    
    private func switchToUser(_ user: SavedUser) {
        Task {
            do {
                try await authService.switchUser(user)
                
                await MainActor.run {
                    // Refresh the app by posting a notification
                    NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.refreshAllTabs), object: nil)
                }
                
            } catch {
                print("SettingsView: Failed to switch user: \(error)")
                // Handle error - could show alert to user
            }
        }
    }
    
    
    private func removeUser(_ user: SavedUser) {
        Task {
            do {
                try await userManager.removeUser(user)
            } catch {
                print("SettingsView: Failed to remove user: \(error)")
                // Handle error - could show alert to user
            }
        }
    }
    
    
    
    
    private func refreshServerConnection() {
        Task {
            do {
                // Refresh user info to verify connection
                try await authService.fetchUserInfo()
                print("✅ Server connection refreshed successfully")
                
                // Post notification to refresh all tabs
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.refreshAllTabs), object: nil)
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




#Preview {
    let userManager = UserManager()
    let networkService = NetworkService(userManager: userManager)
    let authService = AuthenticationService(networkService: networkService, userManager: userManager)
    SettingsView(authService: authService, userManager: userManager)
}


