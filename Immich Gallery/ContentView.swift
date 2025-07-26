//
//  ContentView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

extension Notification.Name {
    static let refreshAllTabs = Notification.Name("refreshAllTabs")
}

struct ContentView: View {
    @StateObject private var networkService = NetworkService()
    @StateObject private var authService: AuthenticationService
    @StateObject private var assetService: AssetService
    @StateObject private var albumService: AlbumService
    @StateObject private var peopleService: PeopleService
    @StateObject private var tagService: TagService
    @State private var selectedTab = 0
    @State private var refreshTrigger = UUID()
    @AppStorage("showTagsTab") private var showTagsTab = false
    @AppStorage("defaultStartupTab") private var defaultStartupTab = "photos"
    
    init() {
        let networkService = NetworkService()
        _networkService = StateObject(wrappedValue: networkService)
        _authService = StateObject(wrappedValue: AuthenticationService(networkService: networkService))
        _assetService = StateObject(wrappedValue: AssetService(networkService: networkService))
        _albumService = StateObject(wrappedValue: AlbumService(networkService: networkService))
        _peopleService = StateObject(wrappedValue: PeopleService(networkService: networkService))
        _tagService = StateObject(wrappedValue: TagService(networkService: networkService))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                if !authService.isAuthenticated {
                    // Show sign-in view
                    SignInView(authService: authService, mode: .signIn)
                        .errorBoundary(context: "Authentication")
                } else {
                    // Main app interface
                    TabView(selection: $selectedTab) {
                        AssetGridView(assetService: assetService, authService: authService, albumId: nil, personId: nil, tagId: nil, onAssetsLoaded: nil)
                            .errorBoundary(context: "Photos Tab")
                            .tabItem {
                                Image(systemName: "photo.on.rectangle")
                                Text("Photos")
                            }
                            .tag(0)
                        
                        AlbumListView(albumService: albumService, authService: authService, assetService: assetService)
                            .errorBoundary(context: "Albums Tab")
                            .tabItem {
                                Image(systemName: "folder")
                                Text("Albums")
                            }
                            .tag(1)
                        
                        PeopleGridView(peopleService: peopleService, authService: authService, assetService: assetService)
                            .errorBoundary(context: "People Tab")
                            .tabItem {
                                Image(systemName: "person.crop.circle")
                                Text("People")
                            }
                            .tag(2)
                        
                        if showTagsTab {
                            TagsGridView(tagService: tagService, authService: authService, assetService: assetService)
                                .errorBoundary(context: "Tags Tab")
                                .tabItem {
                                    Image(systemName: "tag")
                                    Text("Tags")
                                }
                                .tag(3)
                        }
                        
                        SettingsView(authService: authService)
                            .errorBoundary(context: "Settings Tab")
                            .tabItem {
                                Image(systemName: "gear")
                                Text("Settings")
                            }
                            .tag(showTagsTab ? 4 : 3)
                    }
            .onAppear {
                        setDefaultTab()
                    }
                    .onChange(of: selectedTab) { oldValue, newValue in
                        print("Tab changed from \(oldValue) to \(newValue)")
                    }                    .id(refreshTrigger) // Force refresh when user switches
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
    }
    
    private func setDefaultTab() {
        switch defaultStartupTab {
        case "albums":
            selectedTab = 1
        case "people":
            selectedTab = 2
        case "tags":
            if showTagsTab {
                selectedTab = 3
            } else {
                selectedTab = 0 // Default to photos if tags tab is disabled
            }
        default: // "photos"
            selectedTab = 0
        }
    }
}

#Preview {
    ContentView()
}
