//
//  ContentView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

enum TabName: Int, CaseIterable {
    case photos = 0
    case albums = 1
    case people = 2
    case tags = 3
    case search = 4
    case settings = 5
    
    var title: String {
        switch self {
        case .photos: return "Photos"
        case .albums: return "Albums"
        case .people: return "People"
        case .tags: return "Tags"
        case .search: return "Search"
        case .settings: return "Settings"
        }
    }
    
    var iconName: String {
        switch self {
        case .photos: return "photo.on.rectangle"
        case .albums: return "folder"
        case .people: return "person.crop.circle"
        case .tags: return "tag"
        case .search: return "magnifyingglass"
        case .settings: return "gear"
        }
    }
}

extension Notification.Name {
    static let refreshAllTabs = Notification.Name(NotificationNames.refreshAllTabs)
}

struct ContentView: View {
    // Auto slideshow state
    @AppStorage(UserDefaultsKeys.autoSlideshowTimeout) private var autoSlideshowTimeout: Int = 0
    @State private var inactivityTimer: Timer? = nil
    @State private var showAutoSlideshow = false
    @State private var lastInteractionDate = Date()
    @StateObject private var networkService = NetworkService()
    @StateObject private var authService: AuthenticationService
    @StateObject private var assetService: AssetService
    @StateObject private var albumService: AlbumService
    @StateObject private var peopleService: PeopleService
    @StateObject private var tagService: TagService
    @StateObject private var searchService: SearchService
    @State private var selectedTab = 0
    @State private var refreshTrigger = UUID()
    @State private var showWhatsNew = false
    @AppStorage(UserDefaultsKeys.showTagsTab) private var showTagsTab = false
    @AppStorage(UserDefaultsKeys.defaultStartupTab) private var defaultStartupTab = "photos"
    @AppStorage(UserDefaultsKeys.lastSeenVersion) private var lastSeenVersion = ""
    @State private var searchTabHighlighted = false
    @State private var deepLinkAssetId: String?
    
    init() {
        let networkService = NetworkService()
        _networkService = StateObject(wrappedValue: networkService)
        _authService = StateObject(wrappedValue: AuthenticationService(networkService: networkService))
        _assetService = StateObject(wrappedValue: AssetService(networkService: networkService))
        _albumService = StateObject(wrappedValue: AlbumService(networkService: networkService))
        _peopleService = StateObject(wrappedValue: PeopleService(networkService: networkService))
        _tagService = StateObject(wrappedValue: TagService(networkService: networkService))
        _searchService = StateObject(wrappedValue: SearchService(networkService: networkService))
    }
    
    var body: some View {
    NavigationView {
            ZStack {
                if !authService.isAuthenticated {
                    // Show sign-in view
                    SignInView(authService: authService, mode: .signIn)
                        .errorBoundary(context: "Authentication")
                } else {
                    // Main app interface
                    TabView(selection: $selectedTab) {
                        AssetGridView(assetService: assetService, authService: authService, albumId: nil, personId: nil, tagId: nil, isAllPhotos: true, onAssetsLoaded: nil, deepLinkAssetId: deepLinkAssetId)
                            .errorBoundary(context: "Photos Tab")
                            .tabItem {
                                Image(systemName: TabName.photos.iconName)
                                Text(TabName.photos.title)
                            }
                            .tag(TabName.photos.rawValue)
                        
                        AlbumListView(albumService: albumService, authService: authService, assetService: assetService)
                            .errorBoundary(context: "Albums Tab")
                            .tabItem {
                                Image(systemName: TabName.albums.iconName)
                                Text(TabName.albums.title)
                            }
                            .tag(TabName.albums.rawValue)
                        
                        PeopleGridView(peopleService: peopleService, authService: authService, assetService: assetService)
                            .errorBoundary(context: "People Tab")
                            .tabItem {
                                Image(systemName: TabName.people.iconName)
                                Text(TabName.people.title)
                            }
                            .tag(TabName.people.rawValue)
                        
                        if showTagsTab {
                            TagsGridView(tagService: tagService, authService: authService, assetService: assetService)
                                .errorBoundary(context: "Tags Tab")
                                .tabItem {
                                    Image(systemName: TabName.tags.iconName)
                                    Text(TabName.tags.title)
                                }
                                .tag(TabName.tags.rawValue)
                        }
                        
                        SearchView(searchService: searchService, assetService: assetService, authService: authService)
                            .errorBoundary(context: "Search Tab")
                            .tabItem {
                                Image(systemName: TabName.search.iconName)
                                Text(TabName.search.title)
                            }
                            .tag(TabName.search.rawValue)
                        
                        SettingsView(authService: authService)
                            .errorBoundary(context: "Settings Tab")
                            .tabItem {
                                Image(systemName: TabName.settings.iconName)
                                Text(TabName.settings.title)
                            }
                            .tag(TabName.settings.rawValue)
                    }
                    .onAppear {
                        setDefaultTab()
                        checkForAppUpdate()
                        startInactivityTimer()
                    }
                    .onChange(of: selectedTab) { oldValue, newValue in
                        searchTabHighlighted = false
                        print("Tab changed from \(oldValue) to \(newValue)")
                        resetInactivityTimer()
                    }
                    .onChange(of: autoSlideshowTimeout) { _, _ in
                        startInactivityTimer()
                    }
                    .id(refreshTrigger) // Force refresh when user switches
                    .sheet(isPresented: $showAutoSlideshow, onDismiss: { resetInactivityTimer() }) {
                        // Start slideshow from all photos
                        AssetGridView(assetService: assetService, authService: authService, albumId: nil, personId: nil, tagId: nil, isAllPhotos: true, onAssetsLoaded: nil, deepLinkAssetId: nil)
                        // Optionally, you could present a dedicated SlideshowView here
                    }
                    // .accentColor(.blue)
                }
            }
            .navigationTitle("Immich Gallery")
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onReceive(NotificationCenter.default.publisher(for: .refreshAllTabs)) { _ in
            // Refresh all tabs by generating a new UUID
            refreshTrigger = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name(NotificationNames.openAsset))) { notification in
            if let assetId = notification.userInfo?["assetId"] as? String {
                print("ContentView: Received OpenAsset notification for asset: \(assetId)")
                
                // Switch to Photos tab and set deep link asset ID
                                            .contentShape(Rectangle())
                                            .highPriorityGesture(
                                                DragGesture(minimumDistance: 0)
                                                    .onChanged { _ in resetInactivityTimer() }
                                            )
                                            .simultaneousGesture(
                                                TapGesture().onEnded { resetInactivityTimer() }
                                            )
                                            .onAppear {
                deepLinkAssetId = assetId
                
                // Clear the deep link after a moment to avoid stale state
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    deepLinkAssetId = nil
                }
            }
        }
       .sheet(isPresented: $showWhatsNew) {
           WhatsNewView(onDismiss: {
               showWhatsNew = false
               lastSeenVersion = getCurrentAppVersion()
           })
       }
    }
    
    // MARK: - Inactivity Timer Logic
    private func startInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        if autoSlideshowTimeout > 0 {
            inactivityTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                let elapsed = Date().timeIntervalSince(lastInteractionDate)
                if elapsed > Double(autoSlideshowTimeout * 60) {
                    inactivityTimer?.invalidate()
                    inactivityTimer = nil
                    showAutoSlideshow = true
                }
            }
        }
    }

    private func resetInactivityTimer() {
        lastInteractionDate = Date()
        if showAutoSlideshow {
            showAutoSlideshow = false
        }
    }

    private func setDefaultTab() {
        switch defaultStartupTab {
        case "albums":
            selectedTab = TabName.albums.rawValue
        case "people":
            selectedTab = TabName.people.rawValue
        case "tags":
            if showTagsTab {
                selectedTab = TabName.tags.rawValue
            } else {
                selectedTab = TabName.photos.rawValue // Default to photos if tags tab is disabled
            }
        default: // "photos"
            selectedTab = TabName.photos.rawValue
        }
    }
    
    private func checkForAppUpdate() {
        let currentVersion = getCurrentAppVersion()
        
        // Show What's New if this is first launch or version changed
        if lastSeenVersion.isEmpty || lastSeenVersion != currentVersion {
            // Delay showing to ensure app is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showWhatsNew = true
            }
        }
    }
    
    private func getCurrentAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version).\(build)"
    }
}

#Preview {
    ContentView()
}
