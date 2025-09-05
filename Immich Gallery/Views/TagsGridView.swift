//
//  TagsGridView.swift
//  Immich Gallery
//

import SwiftUI

struct TagsGridView: View {
    @ObservedObject var tagService: TagService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var assetService: AssetService
    @State private var tags: [Tag] = []
    @State private var selectedTag: Tag?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var thumbnailProvider: TagThumbnailProvider {
        TagThumbnailProvider(assetService: assetService)
    }
    
    var body: some View {
        SharedGridView(
            items: tags,
            config: .tagsStyle,
            thumbnailProvider: thumbnailProvider,
            isLoading: isLoading,
            errorMessage: errorMessage,
            onItemSelected: { tag in
                selectedTag = tag
            },
            onRetry: {
                Task {
                    await loadTags()
                }
            }
        )
        .fullScreenCover(item: $selectedTag) { tag in
            TagDetailView(tag: tag, assetService: assetService, authService: authService)
        }
        .onAppear {
            if tags.isEmpty {
                Task {
                    await loadTags()
                }
            }
        }
    }
    
    private func loadTags() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedTags = try await tagService.fetchTags()
            await MainActor.run {
                self.tags = fetchedTags
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load tags: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}


struct TagDetailView: View {
    let tag: Tag
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                AssetGridView(assetService: assetService,
                              authService: authService,
                              assetProvider: AssetProviderFactory.createProvider(
                                tagId: tag.id,
                                assetService: assetService
                              ),
                              albumId: nil, personId: nil,
                              tagId: tag.id,
                              isAllPhotos: false,
                              isFavorite: false,
                              onAssetsLoaded: nil,
                              deepLinkAssetId: nil)
            }
            .navigationTitle(tag.name)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let (_, _, authService, assetService, _, peopleService, tagService) =
    MockServiceFactory.createMockServices()
    TagsGridView(tagService: tagService, authService: authService, assetService: assetService)
}
