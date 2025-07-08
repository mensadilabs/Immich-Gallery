//
//  ContentView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

extension Notification.Name {
    static let userSwitched = Notification.Name("userSwitched")
}

struct ContentView: View {
    @StateObject private var networkService = NetworkService()
    @StateObject private var authService: AuthenticationService
    @StateObject private var assetService: AssetService
    @StateObject private var albumService: AlbumService
    @StateObject private var peopleService: PeopleService
    @State private var selectedTab = 0
    @State private var refreshTrigger = UUID()
    
    init() {
        let networkService = NetworkService()
        _networkService = StateObject(wrappedValue: networkService)
        _authService = StateObject(wrappedValue: AuthenticationService(networkService: networkService))
        _assetService = StateObject(wrappedValue: AssetService(networkService: networkService))
        _albumService = StateObject(wrappedValue: AlbumService(networkService: networkService))
        _peopleService = StateObject(wrappedValue: PeopleService(networkService: networkService))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                if !authService.isAuthenticated {
                    // Show sign-in view
                    SignInView(authService: authService)
                } else {
                    // Main app interface
                    TabView(selection: $selectedTab) {
                        AssetGridView(assetService: assetService, authService: authService, albumId: nil, personId: nil, onAssetsLoaded: nil)
                            .tabItem {
                                Image(systemName: "photo.on.rectangle")
                                Text("Photos")
                            }
                            .tag(0)
                        
                        AlbumListView(albumService: albumService, authService: authService, assetService: assetService)
                            .tabItem {
                                Image(systemName: "folder")
                                Text("Albums")
                            }
                            .tag(1)
                        
                        PeopleGridView(peopleService: peopleService, authService: authService, assetService: assetService)
                            .tabItem {
                                Image(systemName: "person.crop.circle")
                                Text("People")
                            }
                            .tag(2)
                        
                        CacheManagementView(authService: authService)
                            .tabItem {
                                Image(systemName: "gear")
                                Text("Settings")
                            }
                            .tag(3)
                    }
                    .onChange(of: selectedTab) { newValue in
                        print("ContentView: Tab changed to \(newValue)")
                    }
                    .id(refreshTrigger) // Force refresh when user switches
                    // .accentColor(.blue)
                }
            }
            .navigationTitle("Immich Gallery")
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onReceive(NotificationCenter.default.publisher(for: .userSwitched)) { _ in
            // Refresh the app by generating a new UUID
            refreshTrigger = UUID()
        }
    }
}

#Preview {
    ContentView()
}
