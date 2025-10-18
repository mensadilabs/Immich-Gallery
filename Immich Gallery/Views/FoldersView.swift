//
//  FoldersView.swift
//  Immich Gallery
//
//  Created by Codex on 2025-09-12.
//

import SwiftUI

struct FoldersView: View {
    @ObservedObject var folderService: FolderService
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    
    @State private var folders: [ImmichFolder] = []
    @State private var selectedFolder: ImmichFolder?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var thumbnailProvider: FolderThumbnailProvider {
        FolderThumbnailProvider(assetService: assetService)
    }
    
    var body: some View {
        SharedGridView(
            items: folders,
            config: .foldersStyle,
            thumbnailProvider: thumbnailProvider,
            isLoading: isLoading,
            errorMessage: errorMessage,
            onItemSelected: { folder in
                selectedFolder = folder
            },
            onRetry: {
                Task {
                    await loadFolders()
                }
            }
        )
        .fullScreenCover(item: $selectedFolder) { folder in
            FolderDetailView(folder: folder, assetService: assetService, authService: authService)
        }
        .onAppear {
            if folders.isEmpty {
                Task {
                    await loadFolders()
                }
            }
        }
    }
    
    private func loadFolders() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let fetchedFolders = try await folderService.fetchUniquePaths()
            await MainActor.run {
                let uniqueFolders = Array(Set(fetchedFolders))
                self.folders = uniqueFolders.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load folders: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

struct FolderDetailView: View {
    let folder: ImmichFolder
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    
    private var folderTitle: String {
        folder.primaryTitle.isEmpty ? folder.path : folder.primaryTitle
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                AssetGridView(assetService: assetService,
                              authService: authService,
                              assetProvider: AssetProviderFactory.createProvider(
                                folderPath: folder.path,
                                assetService: assetService
                              ),
                              albumId: nil,
                              personId: nil,
                              tagId: nil,
                              city: nil,
                              isAllPhotos: false,
                              isFavorite: false,
                              onAssetsLoaded: nil,
                              deepLinkAssetId: nil)
            }
            .navigationTitle(folderTitle)
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
    let (_, _, authService, assetService, _, _, _, folderService) =
    MockServiceFactory.createMockServices()
    return FoldersView(folderService: folderService, assetService: assetService, authService: authService)
}
