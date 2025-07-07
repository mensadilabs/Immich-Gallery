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
    @StateObject private var immichService = ImmichService()
    @State private var selectedTab = 0
    @State private var refreshTrigger = UUID()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                if !immichService.isAuthenticated {
                    // Show sign-in view
                    SignInView(immichService: immichService)
                } else {
                    // Main app interface
                    TabView(selection: $selectedTab) {
                        AssetGridView(immichService: immichService, albumId: nil, personId: nil, onAssetsLoaded: nil)
                            .tabItem {
                                Image(systemName: "photo.on.rectangle")
                                Text("Photos")
                            }
                            .tag(0)
                        
                        AlbumListView(immichService: immichService)
                            .tabItem {
                                Image(systemName: "folder")
                                Text("Albums")
                            }
                            .tag(1)
                        
                        PeopleGridView(immichService: immichService)
                            .tabItem {
                                Image(systemName: "person.crop.circle")
                                Text("People")
                            }
                            .tag(2)
                        
                        CacheManagementView(immichService: immichService)
                            .tabItem {
                                Image(systemName: "gear")
                                Text("Settings")
                            }
                            .tag(3)
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
