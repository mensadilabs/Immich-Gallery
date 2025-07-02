//
//  ContentView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var immichService = ImmichService()
    @State private var selectedTab = 0
    
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
                        AssetGridView(immichService: immichService, albumId: nil)
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
                        
                        CacheManagementView(immichService: immichService)
                            .tabItem {
                                Image(systemName: "gear")
                                Text("Settings")
                            }
                            .tag(2)
                    }
                    // .accentColor(.blue)
                }
            }
            .navigationTitle("Immich Gallery")
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

#Preview {
    ContentView()
}
