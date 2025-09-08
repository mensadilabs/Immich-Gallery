//
//  ExploreDetailView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-09-06.
//

import SwiftUI

struct ExploreDetailView: View {
    let city: String
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    @State private var cityAssets: [ImmichAsset] = []
    @State private var slideshowTrigger: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                AssetGridView(
                    assetService: assetService,
                    authService: authService,
                    assetProvider: createAssetProvider(for: city),
                    albumId: nil,
                    personId: nil,
                    tagId: nil,
                    city: city,
                    isAllPhotos: false,
                    isFavorite: false,
                    onAssetsLoaded: { loadedAssets in
                        self.cityAssets = loadedAssets
                    },
                    deepLinkAssetId: nil
                )
            }
            .navigationTitle(city)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: startSlideshow) {
                        Image(systemName: "play.rectangle")
                            .foregroundColor(.white)
                    }
                    .disabled(cityAssets.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .fullScreenCover(isPresented: $slideshowTrigger) {
            SlideshowView(
                albumId: nil,
                personId: nil, 
                tagId: nil,
                city: city,
                startingIndex: 0,
                isFavorite: false
            )
        }
        .onAppear(){
            print("Explore detail view for city: \(city)")
        }
    }
    
    private func createAssetProvider(for city: String) -> AssetProvider {
        return AssetProviderFactory.createProvider(
            city: city,
            assetService: assetService
        )
    }
    
    private func startSlideshow() {
        // Stop auto-slideshow timer before starting slideshow
        NotificationCenter.default.post(name: NSNotification.Name("stopAutoSlideshowTimer"), object: nil)
        slideshowTrigger = true
    }
}