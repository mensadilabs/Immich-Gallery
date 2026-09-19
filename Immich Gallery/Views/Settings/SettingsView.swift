//
//  SettingsView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//
//⁠‌‌​​​​‌​‌​‌​‌​​‌​‌‌​‌‌​‌​‌‌​​‌​‌​‌‌​‌‌‌​​‌‌‌​​‌‌​‌‌​​​​‌​‌‌​​‌​​​‌‌​‌​​‌​‌‌​‌‌​​​‌‌​​​​‌​‌‌​​​‌​​‌‌‌​​‌‌⁠


import SwiftUI
import TVServices

// MARK: - Reusable Components

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let content: AnyView
    let isOn: Bool
    
    init(icon: String, title: String, subtitle: String, content: AnyView, isOn: Bool = false) {
            self.icon = icon
            self.title = title
            self.subtitle = subtitle
            self.content = content
            self.isOn = isOn
        }

    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isOn ? .green : .blue)
                .font(.title3)
                .frame(width: 24)
                .padding()
            
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
        .background(isOn ? Color.green.opacity(0.05): Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var userManager: UserManager
    @State private var showingClearCacheAlert = false
    @State private var showingDeleteUserAlert = false
    @State private var userToDelete: SavedUser?
    @State private var showingSignIn = false
    @State private var showingWhatsNew = false
    @State private var showingVisibleTabs = false
    @State private var isValidatingSlideshowConfig = false
    @State private var slideshowConfigValidationMessage = ""
    @State private var showingSlideshowConfigValidation = false
    @State private var slideshowConfigSummary = "Loading configuration…"
    @AppStorage("hideImageOverlay") private var hideImageOverlay = true
    @AppStorage(UserDefaultsKeys.showCurrentTimeWidget) private var showCurrentTimeWidget = true
    @AppStorage(UserDefaultsKeys.photoDateDisplayMode) private var photoDateDisplayMode = "dateAndTime"
    @AppStorage(UserDefaultsKeys.showLocationOverlay) private var showLocationOverlay = true
    @State private var slideshowInterval: Double = UserDefaults.standard.object(forKey: "slideshowInterval") as? Double ?? 8.0
    @AppStorage("slideshowBackgroundColor") private var slideshowBackgroundColor = "white"
    @AppStorage(UserDefaultsKeys.showPhotosTab) private var showPhotosTab = true
    @AppStorage(UserDefaultsKeys.showAlbumsTab) private var showAlbumsTab = true
    @AppStorage(UserDefaultsKeys.showPeopleTab) private var showPeopleTab = true
    @AppStorage(UserDefaultsKeys.showTagsTab) private var showTagsTab = false
    @AppStorage(UserDefaultsKeys.showFoldersTab) private var showFoldersTab = false
    @AppStorage(UserDefaultsKeys.showExploreTab) private var showExploreTab = true
    @AppStorage(UserDefaultsKeys.showSearchTab) private var showSearchTab = true
    @AppStorage(UserDefaultsKeys.defaultStartupTab) private var defaultStartupTab = "photos"
    @AppStorage("use24HourClock") private var use24HourClock = true
    @AppStorage("enableReflectionsInSlideshow") private var enableReflectionsInSlideshow = true
    @AppStorage("enableKenBurnsEffect") private var enableKenBurnsEffect = false
    @AppStorage("enableDynamicTransitions") private var enableDynamicTransitions = false
    @AppStorage("enableSlideshowShuffle") private var enableSlideshowShuffle = false
    @AppStorage(UserDefaultsKeys.reverseFullscreenHorizontalNavigation) private var reverseFullscreenHorizontalNavigation = false
    @AppStorage(UserDefaultsKeys.photosViewMode) private var photosViewMode = "timeline"
    @AppStorage(UserDefaultsKeys.lockupThumbnailMode) private var lockupThumbnailMode = LockupThumbnailMode.current.rawValue
    @AppStorage(UserDefaultsKeys.appBackgroundStyle) private var appBackgroundStyle = AppBackgroundStyle.graphite.rawValue
    @AppStorage("navigationStyle") private var navigationStyle = NavigationStyle.tabs.rawValue
    @AppStorage("enableTopShelf", store: UserDefaults(suiteName: AppConstants.appGroupIdentifier)) private var enableTopShelf = true
    @AppStorage("topShelfStyle", store: UserDefaults(suiteName: AppConstants.appGroupIdentifier)) private var topShelfStyle = "sectioned"
    @AppStorage("topShelfImageSelection", store: UserDefaults(suiteName: AppConstants.appGroupIdentifier)) private var topShelfImageSelection = "recent"
    @AppStorage(UserDefaultsKeys.autoSlideshowTimeout) private var autoSlideshowTimeout: Int = 0 // 0 = off
    @AppStorage(UserDefaultsKeys.launchIntoSlideshow) private var launchIntoSlideshow: Bool = false
    @AppStorage(UserDefaultsKeys.showDiagnosticsOverlay) private var showDiagnosticsOverlay = false
    @AppStorage("artModeLevel") private var artModeLevel = "off"
    @AppStorage("artModeDayStart") private var artModeDayStart = 7
    @AppStorage("artModeNightStart") private var artModeNightStart = 20
    @FocusState private var isMinusFocused: Bool
    @FocusState private var isPlusFocused: Bool
    @FocusState private var focusedColor: String?

    private var visibleTabs: Set<TabName> {
        var tabs = Set<TabName>()
        if showPhotosTab { tabs.insert(.photos) }
        if showAlbumsTab { tabs.insert(.albums) }
        if showPeopleTab { tabs.insert(.people) }
        if showTagsTab { tabs.insert(.tags) }
        if showFoldersTab { tabs.insert(.folders) }
        if showExploreTab { tabs.insert(.explore) }
        if showSearchTab { tabs.insert(.search) }
        return tabs
    }

    private var visibleTabsSummary: String {
        "\(visibleTabs.count) visible"
    }
    
    private var serverInfoSection: some View {
        Button(action: {
            refreshServerConnection()
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: authService.baseURL.lowercased().hasPrefix("https") ? "lock.fill" : "lock.open.fill")
                        .foregroundColor(authService.baseURL.lowercased().hasPrefix("https") ? .green : .red)
                        .font(.system(size: 100 * 0.4))
                }
                .padding(.trailing, 10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(authService.baseURL)
                        .font(.headline)
                        .foregroundColor(.primary)
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
            .padding()
            .background(Color.green.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(CardButtonStyle())
    }
    private var userActionsSection: some View {
        VStack(spacing: 16) {
            if userManager.savedUsers.count > 0 {
                ForEach(userManager.savedUsers, id: \.id) { user in
                    userRow(user: user)
                }
            }
            
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
            .buttonStyle(CardButtonStyle())
        }
    }
    
    private func userRow(user: SavedUser) -> some View {
        HStack {
            Button(action: {
                switchToUser(user)
            }) {
                HStack {
                    HStack(spacing: 16) {
                        ProfileImageView(
                            userId: user.id,
                            authType: user.authType,
                            size: 100,
                            profileImageData: user.profileImageData
                        )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Badge(
                                    user.authType == .apiKey ? "API Key" : "Password",
                                    color: user.authType == .apiKey ? Color.orange : Color.blue
                                )
                                
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
                    }
                    
                    Spacer()
                    
                    if userManager.currentUser?.id == user.id {
                        Badge("Active", color: Color.green)
                    } else {
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(user.authType == .apiKey ? .orange : .blue)
                            .font(.title3)
                    }
                }
                .padding()
                .background {
                    let accentColor = user.authType == .apiKey ? Color.orange : Color.blue
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accentColor.opacity(0.05))
                }
            }
            .buttonStyle(CardButtonStyle())
            
            Button(action: {
                userToDelete = user
                showingDeleteUserAlert = true
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.title3)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            .buttonStyle(CardButtonStyle())
        }
    }
    
    private var footerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text("Powered by")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Maple Syrup")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("🍁")
                    .font(.caption)
            }
        }
        .padding(.vertical, 20)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                SharedGradientBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 30) {
                        
                        serverInfoSection
                        userActionsSection
                        
                        // Interface Settings Section
                        SettingsSection(title: "Interface") {
                            AnyView(VStack(spacing: 12) {
                                    SettingsRow(
                                        icon: "rectangle.3.group",
                                        title: "Tabs",
                                        subtitle: "Choose visible tabs and the default startup tab",
                                        content: AnyView(
                                            Button(action: { showingVisibleTabs = true }) {
                                                HStack(spacing: 8) {
                                                    Text(visibleTabsSummary)
                                                    Image(systemName: "chevron.right")
                                                }
                                            }
                                            .buttonStyle(.bordered)
                                        )
                                    )
                                    SettingsRow(
                                        icon: "calendar",
                                        title: "Photos View",
                                        subtitle: "How the Photos tab displays your library. Timeline groups photos by month and loads each month on demand for better performance on large libraries.",
                                        content: AnyView(
                                            Picker("Photos View", selection: $photosViewMode) {
                                                Text("Grid").tag("grid")
                                                Text("Timeline").tag("timeline")
                                            }
                                                .pickerStyle(.menu)
                                                .frame(width: 300, alignment: .trailing)
                                        )
                                    )

                                    SettingsRow(
                                        icon: "photo.on.rectangle",
                                        title: "Lockup Thumbnails",
                                        subtitle: "Choose whether album, people, tag, and folder cards use the current cover or a random matching asset.",
                                        content: AnyView(
                                            Picker("Lockup Thumbnails", selection: $lockupThumbnailMode) {
                                                Text("Current").tag(LockupThumbnailMode.current.rawValue)
                                                Text("Random").tag(LockupThumbnailMode.random.rawValue)
                                            }
                                                .pickerStyle(.menu)
                                                .frame(width: 300, alignment: .trailing)
                                        )
                                    )

                                    SettingsRow(
                                        icon: "paintpalette",
                                        title: "App Background",
                                        subtitle: "Change the background style used across the app",
                                        content: AnyView(
                                            Picker("App Background", selection: $appBackgroundStyle) {
                                                ForEach(AppBackgroundStyle.allCases, id: \.self) { style in
                                                    Text(style.displayName).tag(style.rawValue)
                                                }
                                            }
                                                .pickerStyle(.menu)
                                                .frame(width: 300, alignment: .trailing)
                                        )
                                    )

                                    SettingsRow(
                                        icon: "rectangle.split.3x1",
                                        title: "Navigation Style",
                                        subtitle: "Choose between a classic tab bar or the adaptive sidebar layout",
                                        content: AnyView(
                                            Picker("Navigation Style", selection: Binding(
                                                get: { NavigationStyle(rawValue: navigationStyle) ?? .tabs },
                                                set: { navigationStyle = $0.rawValue }
                                            )) {
                                                ForEach(NavigationStyle.allCases, id: \.self) { style in
                                                    Text(style.displayName).tag(style)
                                                }
                                            }
                                                .pickerStyle(.menu)
                                                .frame(width: 300, alignment: .trailing)
                                        )
                                    )

                                    SettingsRow(
                                        icon: "arrow.left.arrow.right",
                                        title: "Reverse Fullscreen Left/Right",
                                        subtitle: "Flip horizontal navigation in the fullscreen image viewer.",
                                        content: AnyView(
                                            Picker("Reverse Fullscreen Left/Right", selection: $reverseFullscreenHorizontalNavigation) {
                                                Text("Off").tag(false)
                                                Text("On").tag(true)
                                            }
                                            .pickerStyle(.menu)
                                            .frame(width: 300, alignment: .trailing)
                                        ),
                                        isOn: reverseFullscreenHorizontalNavigation
                                    )
                                }
                            )
                        }
                        
                        // TopShelf Settings Section
                        SettingsSection(title: "Top Shelf") {
                            AnyView(VStack(spacing: 12) {
                                SettingsRow(
                                    icon: "tv",
                                    title: "Top Shelf Extension",
                                    subtitle: "Choose display style or disable Top Shelf entirely. Compact mode shows a mix of portrait and landscape photos.",
                                    content: AnyView(
                                        Picker("Top Shelf", selection: Binding(
                                            get: { enableTopShelf ? topShelfStyle : "off" },
                                            set: { newValue in
                                                if newValue == "off" {
                                                    enableTopShelf = false
                                                } else {
                                                    enableTopShelf = true
                                                    topShelfStyle = newValue
                                                }
                                            }
                                        )) {
                                            Text("Off").tag("off")
                                            Text("Compact").tag("sectioned")
                                            Text("Fullscreen").tag("carousel")
                                        }
                                            .pickerStyle(.menu)
                                            .frame(width: 300, alignment: .trailing)
                                    ),
                                    isOn: enableTopShelf
                                )
                                
                                if enableTopShelf {
                                    SettingsRow(
                                        icon: "photo.on.rectangle.angled",
                                        title: "Image Selection",
                                        subtitle: "Choose between recent photos or random photos from your library.",
                                        content: AnyView(
                                            Picker("Image Selection", selection: $topShelfImageSelection) {
                                                Text("Recent Photos").tag("recent")
                                                Text("Random Photos").tag("random")
                                            }
                                                .pickerStyle(.menu)
                                                .frame(width: 500, alignment: .trailing)
                                                .onChange(of: topShelfImageSelection) { _, _ in
                                                    TVTopShelfContentProvider.topShelfContentDidChange()
                                                }
                                        )
                                    )
                                }
                            })
                        }
                        
                        // Slideshow Settings Section
                        SettingsSection(title: "Slideshow") {
                            AnyView(VStack(spacing: 12) {
                                SettingsRow(
                                    icon: "play.rectangle.on.rectangle",
                                    title: "Launch Into Slideshow",
                                    subtitle: "Start the slideshow automatically when the app opens (uses your slideshow config album, if set, otherwise all photos)",
                                    content: AnyView(
                                        Picker("Launch Into Slideshow", selection: $launchIntoSlideshow) {
                                            Text("On").tag(true)
                                            Text("Off").tag(false)
                                        }
                                            .pickerStyle(.menu)
                                            .frame(width: 300, alignment: .trailing)
                                    ),
                                    isOn: launchIntoSlideshow
                                )

                                SettingsRow(
                                    icon: "clock.arrow.circlepath",
                                    title: "Auto-Start Slideshow",
                                    subtitle: "Play all photos after inactivity (or your slideshow config album, if set)",
                                    content: AnyView(AutoSlideshowTimeoutPicker(timeout: $autoSlideshowTimeout)),
                                    isOn: autoSlideshowTimeout > 0
                                )

                                SlideshowSettings(
                                    slideshowInterval: $slideshowInterval,
                                    slideshowBackgroundColor: $slideshowBackgroundColor,
                                    use24HourClock: $use24HourClock,
                                    hideOverlay: $hideImageOverlay,
                                    showCurrentTimeWidget: $showCurrentTimeWidget,
                                    photoDateDisplayMode: $photoDateDisplayMode,
                                    showLocationOverlay: $showLocationOverlay,
                                    enableReflections: $enableReflectionsInSlideshow,
                                    enableKenBurns: $enableKenBurnsEffect,
                                    enableDynamicTransitions: $enableDynamicTransitions,
                                    enableShuffle: $enableSlideshowShuffle,
                                    isMinusFocused: $isMinusFocused,
                                    isPlusFocused: $isPlusFocused,
                                    focusedColor: $focusedColor
                                )
                                .onChange(of: slideshowInterval) { _, newValue in
                                    UserDefaults.standard.set(newValue, forKey: "slideshowInterval")
                                }
                            })
                        }
                        
                        // Art Mode Settings Section
                        SettingsSection(title: "") {
                            AnyView(VStack(spacing: 12) {
                                HStack{Badge("Experimental", color: Color.red, minWidth: 200)
                                    Spacer()
                                }
                                SettingsRow(
                                    icon: "paintbrush",
                                    title: "Dim Level",
                                    subtitle: "Apply a transparent overlay to dim slideshow images. Best used with black slideshow background color",
                                    content: AnyView(
                                        Picker("Dim Level", selection: $artModeLevel) {
                                            ForEach(ArtModeLevel.allCases, id: \.self) { level in
                                                Text(level.displayName).tag(level.rawValue)
                                            }
                                        }
                                            .pickerStyle(.menu)
                                            .frame(width: 400, alignment: .trailing)
                                    ),
                                    isOn: artModeLevel != "off"
                                )
                                
                                if artModeLevel == "automatic" {
                                    SettingsRow(
                                        icon: "sun.max",
                                        title: "Day Mode Start",
                                        subtitle: "Hour when low dimming begins (0-23)",
                                        content: AnyView(
                                            Picker("Day Start", selection: $artModeDayStart) {
                                                ForEach(0..<24, id: \.self) { hour in
                                                    Text(String(format: "%02d:00", hour)).tag(hour)
                                                }
                                            }
                                            .pickerStyle(.menu)
                                            .frame(width: 250, alignment: .trailing)
                                        )
                                    )
                                    
                                    SettingsRow(
                                        icon: "moon.stars",
                                        title: "Night Mode Start",
                                        subtitle: "Hour when high dimming begins (0-23)",
                                        content: AnyView(
                                            Picker("Night Start", selection: $artModeNightStart) {
                                                ForEach(0..<24, id: \.self) { hour in
                                                    Text(String(format: "%02d:00", hour)).tag(hour)
                                                }
                                            }
                                            .pickerStyle(.menu)
                                            .frame(width: 250, alignment: .trailing)
                                        )
                                    )
                                }
                                
                                SettingsRow(
                                    icon: "gearshape.fill",
                                    title: "Auto-Start Slideshow Configuration",
                                    subtitle: "Create an empty album with 0 photos, then set:\nName: \(AppConstants.configAlbumName)\nDescription: albumIds:[\"album UUID\"] | personIds:[\"person UUID\"]",
                                    content: AnyView(
                                        VStack(alignment: .trailing, spacing: 10) {
                                            Text(slideshowConfigSummary)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.trailing)
                                                .frame(maxWidth: 360, alignment: .trailing)
                                            Button(isValidatingSlideshowConfig ? "Validating…" : "Validate Config") {
                                                validateSlideshowConfig()
                                            }
                                            .buttonStyle(.bordered)
                                            .disabled(isValidatingSlideshowConfig)
                                        }
                                    ),
                                    isOn: autoSlideshowTimeout > 0 || launchIntoSlideshow
                                )
                            })
                        }
                        
                        // Help Section
                        SettingsSection(title: "Help & Support") {
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

                                SettingsRow(
                                    icon: "ladybug",
                                    title: "Report an Issue",
                                    subtitle: "Scan with your phone to open https://github.com/mensadilabs/Immich-Gallery/issues",
                                    content: AnyView(
                                        Image("GitHubIssuesQRCode")
                                            .resizable()
                                            .interpolation(.none)
                                            .scaledToFit()
                                            .frame(width: 160, height: 160)
                                            .padding(12)
                                            .background(Color.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .accessibilityLabel("QR code for Immich Gallery GitHub Issues")
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
                                .buttonStyle(CardButtonStyle())
                                
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
                                .buttonStyle(CardButtonStyle())
                            })
                        }
                        
                        // Diagnostics Section
                        // Available in release builds so field reporters can
                        // capture performance data without connecting Xcode.
                        SettingsSection(title: "Diagnostics") {
                            AnyView(VStack(spacing: 12) {
                                SettingsRow(
                                    icon: "waveform.path.ecg",
                                    title: "Show Diagnostics Overlay",
                                    subtitle: "Display live Timeline, network, CPU, UI-delay, and memory-footprint measurements.",
                                    content: AnyView(
                                        Picker("Show Diagnostics Overlay", selection: $showDiagnosticsOverlay) {
                                            Text("Off").tag(false)
                                            Text("On").tag(true)
                                        }
                                        .pickerStyle(.menu)
                                        .frame(width: 300, alignment: .trailing)
                                    ),
                                    isOn: showDiagnosticsOverlay
                                )
                            })
                        }

                        // Cache Section (Debug only)

#if DEBUG
                        CacheSection(
                            thumbnailCache: thumbnailCache,
                            showingClearCacheAlert: $showingClearCacheAlert
                        )
#endif
                        
                        footerSection
                    }
                    .padding()
                }
            }
            .fullScreenCover(isPresented: $showingSignIn) {
                SignInView(authService: authService, userManager: userManager, mode: .addUser, onUserAdded: { userManager.loadUsers() })
            }
            .fullScreenCover(isPresented: $showingWhatsNew) {
                WhatsNewView(onDismiss: {
                    showingWhatsNew = false
                })
            }
            .sheet(isPresented: $showingVisibleTabs) {
                VisibleTabsSettingsView(
                    initialSelection: visibleTabs,
                    initialDefaultTab: TabName.from(storedValue: defaultStartupTab) ?? .photos
                ) { selection, defaultTab in
                    applyVisibleTabs(selection, defaultTab: defaultTab)
                }
            }
            .task {
                await refreshSlideshowConfigSummary()
            }
            .alert("Slideshow Configuration", isPresented: $showingSlideshowConfigValidation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(slideshowConfigValidationMessage)
            }
            .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    thumbnailCache.clearAllCaches()
                }
            } message: {
                Text("This will remove all cached thumbnails from both memory and disk. Images will be re-downloaded when needed.")
            }
            .alert("Delete User", isPresented: $showingDeleteUserAlert) {
                Button("Cancel", role: .cancel) {
                    userToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let user = userToDelete {
                        removeUser(user)
                    }
                    userToDelete = nil
                }
            } message: {
                if let user = userToDelete {
                    let isCurrentUser = userManager.currentUser?.id == user.id
                    let isLastUser = userManager.savedUsers.count == 1
                    
                    if isCurrentUser && isLastUser {
                        Text("Are you sure you want to delete this user? This will sign you out and you'll need to sign in again to access your photos.")
                    } else if isCurrentUser {
                        Text("Are you sure you want to delete the current user? You will be switched to another saved user.")
                    } else {
                        Text("Are you sure you want to delete this user account?")
                    }
                } else {
                    Text("Are you sure you want to delete this user?")
                }
            }
            .onAppear {
                userManager.loadUsers()
                thumbnailCache.refreshCacheStatistics()
            }
        }
    }

    private func applyVisibleTabs(_ tabs: Set<TabName>, defaultTab: TabName) {
        defaultStartupTab = defaultTab.storedValue
        showPhotosTab = tabs.contains(.photos)
        showAlbumsTab = tabs.contains(.albums)
        showPeopleTab = tabs.contains(.people)
        showTagsTab = tabs.contains(.tags)
        showFoldersTab = tabs.contains(.folders)
        showExploreTab = tabs.contains(.explore)
        showSearchTab = tabs.contains(.search)
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
                let wasCurrentUser = userManager.currentUser?.id == user.id
                
                try await userManager.removeUser(user)
                
                // If we removed the current user, update the authentication service
                if wasCurrentUser {
                    if userManager.hasCurrentUser {
                        // Switch to the new current user
                        print("SettingsView: Switching to next available user after removal")
                        authService.updateCredentialsFromCurrentUser()
                        
                        await MainActor.run {
                            authService.isAuthenticated = true
                        }
                        
                        // Fetch the new current user info
                        try await authService.fetchUserInfo()
                        
                        // Refresh the app UI
                        NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.refreshAllTabs), object: nil)
                    } else {
                        // No users left, sign out completely
                        print("SettingsView: No users left, signing out completely")
                        await MainActor.run {
                            authService.isAuthenticated = false
                            authService.currentUser = nil
                        }
                        authService.clearCredentials()
                    }
                }
            } catch {
                print("SettingsView: Failed to remove user: \(error)")
                // Handle error - could show alert to user
            }
        }
    }
    
    
    
    
    private func validateSlideshowConfig() {
        isValidatingSlideshowConfig = true
        Task {
            let summary = await SlideshowConfigSummaryService(
                networkService: authService.authenticatedNetworkService
            ).load()
            await MainActor.run {
                slideshowConfigSummary = summary.displayText
                slideshowConfigValidationMessage = summary.result.validationMessage
                isValidatingSlideshowConfig = false
                showingSlideshowConfigValidation = true
            }
        }
    }

    private func refreshSlideshowConfigSummary() async {
        let summary = await SlideshowConfigSummaryService(
            networkService: authService.authenticatedNetworkService
        ).load()
        await MainActor.run {
            slideshowConfigSummary = summary.displayText
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
    
    // Create fake users for preview
    let apiKeyUser = SavedUser(
        id: "1",
        email: "admin@example.com",
        name: "Admin User",
        serverURL: "https://demo.immich.app",
        authType: .apiKey
    )
    
    let passwordUser = SavedUser(
        id: "2",
        email: "john.doe@company.com",
        name: "John Doe",
        serverURL: "https://photos.myserver.com",
        authType: .jwt
    )
    
    let anotherApiKeyUser = SavedUser(
        id: "3",
        email: "service@automation.net",
        name: "Service Account",
        serverURL: "https://immich.local:2283",
        authType: .apiKey
    )
    
    // Set fake data after initialization
    DispatchQueue.main.async {
        userManager.savedUsers = [apiKeyUser, passwordUser, anotherApiKeyUser]
        userManager.currentUser = passwordUser
    }
    
    let networkService = NetworkService(userManager: userManager)
    let authService = AuthenticationService(networkService: networkService, userManager: userManager)
    let assetService = AssetService(networkService: networkService)
    
    return SettingsView(authService: authService, userManager: userManager)
}
