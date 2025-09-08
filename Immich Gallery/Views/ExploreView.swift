//
//  ExploreView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-09-05.
//

import SwiftUI

struct ExploreView: View {
    @ObservedObject var exploreService: ExploreService
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var userManager: UserManager
    
    @State private var assets: [ImmichAsset] = []
    @State private var exploreItems: [ExploreAsset] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedAsset: ImmichAsset?
    @State private var showingFullScreen = false
    @State private var currentAssetIndex: Int = 0
    @State private var showingStats = false
    @State private var selectedExploreItem: ExploreAsset?
    @State private var belowFold = false
    @State private var showcaseHeight: CGFloat = 0
    @State private var showcaseHighlightedItem: ExploreAsset?
    @State private var focusedItemID: String?
    @State private var navigationDirection: BackgroundImageView.NavigationDirection = .none
    @State private var previousFocusedItemID: String?
    @State private var randomizedFirstRowItems: [ExploreAsset] = []
    
    // Computed property to get the focused explore item
    private var focusedExploreItem: ExploreAsset? {
        guard let focusedItemID = focusedItemID else {
            print("🎯 ExploreView: No focused item ID, using first randomized item")
            return randomizedFirstRowItems.first
        }
        let item = exploreItems.first { $0.id == focusedItemID }
        print("🎯 ExploreView: Focused item - ID: \(focusedItemID), Found: \(item?.primaryTitle ?? "nil")")
        return item
    }
    
    var body: some View {
        ZStack {
            // Background with gradient mask
            BackgroundImageView(
                selectedItem: focusedExploreItem ?? exploreItems.first,
                assetService: assetService,
                belowFold: belowFold,
                exploreItems: exploreItems,
                navigationDirection: navigationDirection
            )
            .onAppear {
                print("🎯 BackgroundImageView: Initial item - \((focusedExploreItem ?? exploreItems.first)?.primaryTitle ?? "nil")")
            }
            
            if isLoading {
                ProgressView("Loading explore data...")
                    .foregroundColor(.white)
                    .scaleEffect(1.5)
            } else if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    Text("Error")
                        .font(.title)
                        .foregroundColor(.white)
                    Text(errorMessage)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") {
                        loadExploreData()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if exploreItems.isEmpty {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No Places Found")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("Photos with location data will appear here")
                        .foregroundColor(.gray)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Above-the-fold showcase section
                        VStack(alignment: .leading) {
                            if let displayItem = focusedExploreItem ?? exploreItems.first {
                                HStack(alignment: .center, spacing: 40) {
                                    VStack(alignment: .leading, spacing: 20) {
                                        Spacer(minLength: 40)
                                        
                                        Text(displayItem.primaryTitle.isEmpty == true ? "Unknown City" : displayItem.primaryTitle )
                                            .font(.largeTitle)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .animation(.easeInOut(duration: 0.3), value: displayItem.id)
                                        
                                        Text("\(displayItem.secondaryTitle ?? "")")
                                            .font(.title2)
                                            .foregroundColor(.white.opacity(0.8))
                                        
                                        HStack(spacing: 20) {
                                            Button(action: {
                                                showingStats = true
                                            }) {
                                                HStack(spacing: 8) {
                                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                                        .font(.title2)
                                                        .foregroundColor(Color.teal)
                                                    Text("View Library Stats")
                                                        .font(.caption)
                                                        .foregroundColor(.primary)
                                                }
                                                .padding(16)
                                                .cornerRadius(12)
                                            }
                                            .buttonStyle(.card)
                                        }
                                        
                                        Spacer(minLength: 20)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 60)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .focusSection()
                        .containerRelativeFrame(.vertical, alignment: .topLeading) {
                            length, _ in length * 0.6
                        }
                        
                        //                        .frame(height: calculateShowcaseHeight())
                        .onScrollVisibilityChange { visible in
                            withAnimation {
                                belowFold = !visible
                            }
                        }
                        
                        // First Row (Above the fold)
                        ExploreFirstRow(
                            exploreItems: randomizedFirstRowItems,
                            assetService: assetService,
                            focusedItemID: $focusedItemID,
                            onItemSelected: { item in
                                selectedExploreItem = item
                            }
                        )
                        .padding(.horizontal)
                        
                        // Remaining Grid Items (Below the fold)
                        if exploreItems.count > GridConfig.peopleStyle.columns.count {
                            ExploreRemainingGrid(
                                exploreItems: exploreItems,
                                assetService: assetService,
                                focusedItemID: $focusedItemID,
                                onItemSelected: { item in
                                    selectedExploreItem = item
                                }
                            )
                            .padding(.vertical)
                        }
                    }
                }
                //                .scrollTargetBehavior(
                //                    FoldSnappingScrollTargetBehavior(
                //                        aboveFold: !belowFold,
                //                        showcaseHeight: showcaseHeight
                //                    )
                //                )
            }
        }
        .sheet(isPresented: $showingStats) {
            StatsView(statsService: createStatsService())
        }
        .fullScreenCover(item: $selectedExploreItem) { exploreItem in
            ExploreDetailView(city: exploreItem.primaryTitle, assetService: assetService, authService: authService)
        }
        .onAppear {
            if assets.isEmpty {
                loadExploreData()
            } else if randomizedFirstRowItems.isEmpty {
                // If data is already loaded but first row items aren't randomized yet
                randomizeFirstRowItems()
            }
        }
        .onChange(of: focusedItemID) { oldValue, newValue in
            print("🎯 ExploreView: focusedItemID changed from \(oldValue ?? "nil") to \(newValue ?? "nil")")
            
            // Determine navigation direction based on index changes
            if let oldValue = oldValue, let newValue = newValue,
               let oldIndex = exploreItems.firstIndex(where: { $0.id == oldValue }),
               let newIndex = exploreItems.firstIndex(where: { $0.id == newValue }) {
                
                if newIndex > oldIndex {
                    navigationDirection = .forward
                } else if newIndex < oldIndex {
                    navigationDirection = .backward
                } else {
                    navigationDirection = .none
                }
            } else {
                navigationDirection = .none
            }
            
            if let newValue = newValue, let item = exploreItems.first(where: { $0.id == newValue }) {
                print("🎯 ExploreView: Above-the-fold should update to: \(item.primaryTitle), direction: \(navigationDirection)")
            }
            
            previousFocusedItemID = oldValue
        }
    }
    
    private func loadExploreData() {
        guard authService.isAuthenticated else {
            errorMessage = "Not authenticated. Please check your credentials."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await exploreService.fetchExploreData()
                await MainActor.run {
                    self.assets = result
                    self.exploreItems = result.map { ExploreAsset(asset: $0) }
                    self.isLoading = false
                    self.randomizeFirstRowItems()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    //    private func calculateShowcaseHeight() -> CGFloat {
    //        let screenHeight = UIScreen.main.bounds.height
    //        let screenWidth = UIScreen.main.bounds.width
    //
    //        // Detect 4K vs 1080p based on screen dimensions
    //        if screenHeight >= 2160 || screenWidth >= 3840 {
    //            // 4K Apple TV
    //            let height: CGFloat = 1600
    //            showcaseHeight = height
    //            return height
    //        } else {
    //            // 1080p Apple TV
    //            let height: CGFloat = 800
    //            showcaseHeight = height
    //            return height
    //        }
    //    }
    
    private func randomizeFirstRowItems() {
        let columnsCount = GridConfig.peopleStyle.columns.count
        if exploreItems.count > columnsCount {
            randomizedFirstRowItems = Array(exploreItems.shuffled().prefix(columnsCount))
        } else {
            randomizedFirstRowItems = exploreItems
        }
        print("🎯 ExploreView: Randomized first row items: \(randomizedFirstRowItems.map { $0.primaryTitle })")
    }
    
    private func createStatsService() -> StatsService {
        let networkService = NetworkService(userManager: userManager)
        let exploreService = ExploreService(networkService: networkService)
        let peopleService = PeopleService(networkService: networkService)
        return StatsService(exploreService: exploreService, peopleService: peopleService, networkService: networkService)
    }
    
}

// MARK: - First Row Component
struct ExploreFirstRow: View {
    let exploreItems: [ExploreAsset]
    let assetService: AssetService
    @Binding var focusedItemID: String?
    let onItemSelected: (ExploreAsset) -> Void
    
    @FocusState private var localFocusedItem: String?
    
    var body: some View {
        HStack(alignment: .top, spacing: GridConfig.peopleStyle.spacing) {
            Spacer()
            ForEach(exploreItems) { item in
                FirstRowItem(
                    item: item,
                    assetService: assetService,
                    isCurrentlyFocused: localFocusedItem == item.id,
                    onItemSelected: onItemSelected
                )
                .focused($localFocusedItem, equals: item.id)
            }
            Spacer()
        }
        .focusSection()
        .onChange(of: localFocusedItem) { oldValue, newValue in
            print("🎯 ExploreFirstRow: Focus changed from \(oldValue ?? "nil") to \(newValue ?? "nil")")
            if let newValue = newValue {
                focusedItemID = newValue
                if let item = exploreItems.first(where: { $0.id == newValue }) {
                    print("🎯 ExploreFirstRow: Focus gained - \(item.primaryTitle)")
                }
            }
        }
        .onAppear {
            print("🎯 ExploreFirstRow: onAppear - items count: \(exploreItems.count)")
            // Let user naturally focus on items instead of auto-focusing
        }
    }
}

// MARK: - First Row Item (No bottom text)
struct FirstRowItem: View {
    let item: ExploreAsset
    let assetService: AssetService
    let isCurrentlyFocused: Bool
    let onItemSelected: (ExploreAsset) -> Void
    
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
        Button(action: {
            onItemSelected(item)
        }) {
            VStack(spacing: 8) {
                // Thumbnail only, no bottom text
                Group {
                    if let thumbnailImage = thumbnailImage {
                        Image(uiImage: thumbnailImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                    }
                }
                .frame(width: GridConfig.peopleStyle.itemWidth, height: 250)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCurrentlyFocused ? Color.white : Color.clear, lineWidth: isCurrentlyFocused ? 4 : 0)
                )
                .scaleEffect(isCurrentlyFocused ? 1.1 : 1.0)
                .animation(.easeIn(duration: 2), value: isCurrentlyFocused)
            }
        }
        .padding(.top, 100)
        .buttonStyle(CardButtonStyle())
        .onAppear {
            print("🎯 FirstRowItem (\(item.primaryTitle)): onAppear")
        }
        .task(id: item.id) {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        do {
            let image = try await assetService.loadImage(asset: item.asset, size: "preview")
            await MainActor.run {
                thumbnailImage = image
            }
        } catch {
            print("Failed to load thumbnail for first row item: \(error)")
        }
    }
}

// MARK: - Remaining Grid Component
struct ExploreRemainingGrid: View {
    let exploreItems: [ExploreAsset]
    let assetService: AssetService
    @Binding var focusedItemID: String?
    let onItemSelected: (ExploreAsset) -> Void
    
    private let columns = GridConfig.peopleStyle.columns
    private let spacing = GridConfig.peopleStyle.spacing
    
    var body: some View {
        LazyVStack(spacing: 20) {
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(exploreItems) { item in
                    FocusableGridItem(
                        item: item,
                        assetService: assetService,
                        isCurrentlyFocused: focusedItemID == item.id,
                        onFocusChange: { isFocused in
                            print("🎯 RemainingGrid: Focus change for \(item.primaryTitle) - isFocused: \(isFocused)")
                            if isFocused {
                                focusedItemID = item.id
                            }
                        },
                        onItemSelected: onItemSelected
                    )
                }
            }
        }
        // .background(Color.black.opacity(0.3))
    }
}

// MARK: - Custom Focus-Aware Grid
struct ExploreCustomGrid: View {
    let exploreItems: [ExploreAsset]
    let assetService: AssetService
    @Binding var focusedItemID: String?
    let onItemSelected: (ExploreAsset) -> Void
    
    private let columns = GridConfig.peopleStyle.columns
    private let spacing = GridConfig.peopleStyle.spacing
    
    var body: some View {
        LazyVStack(spacing: 20) {
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(exploreItems) { item in
                    FocusableGridItem(
                        item: item,
                        assetService: assetService,
                        isCurrentlyFocused: focusedItemID == item.id,
                        onFocusChange: { isFocused in
                            print("🎯 FocusableGridItem: Focus change for \(item.primaryTitle) - isFocused: \(isFocused)")
                            if isFocused {
                                print("🎯 FocusableGridItem: Setting focusedItemID to: \(item.id)")
                                focusedItemID = item.id
                            }
                        },
                        onItemSelected: onItemSelected
                    )
                }
            }
        }
        .onAppear {
            // Set initial focus to first item if no focus is set
            print("🎯 ExploreCustomGrid: onAppear - exploreItems count: \(exploreItems.count)")
            if focusedItemID == nil && !exploreItems.isEmpty {
                let firstItemID = exploreItems.first?.id
                print("🎯 ExploreCustomGrid: Setting initial focus to: \(firstItemID ?? "nil")")
                focusedItemID = firstItemID
            } else {
                print("🎯 ExploreCustomGrid: Focus already set to: \(focusedItemID ?? "nil")")
            }
        }
    }
}

// MARK: - Focusable Grid Item
struct FocusableGridItem: View {
    let item: ExploreAsset
    let assetService: AssetService
    let isCurrentlyFocused: Bool
    let onFocusChange: (Bool) -> Void
    let onItemSelected: (ExploreAsset) -> Void
    
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        Button(action: {
            onItemSelected(item)
        }) {
            SharedGridItemView(
                item: item,
                config: .peopleStyle,
                thumbnailProvider: ExploreThumbnailProvider(assetService: assetService),
                isFocused: isFocused,
                animationTrigger: 0
            )
        }
        .frame(width: GridConfig.peopleStyle.itemWidth, height: GridConfig.peopleStyle.itemHeight)
        .padding(10)
        .buttonStyle(CardButtonStyle())
        .onChange(of: isFocused) { _, newValue in
            print("🎯 FocusableGridItem (\(item.primaryTitle)): isFocused changed from environment - newValue: \(newValue)")
            onFocusChange(newValue)
        }
        .onAppear {
            print("🎯 FocusableGridItem (\(item.primaryTitle)): onAppear - initial isFocused: \(isFocused)")
        }
    }
}

// MARK: - Background Image View
struct BackgroundImageView: View {
    let selectedItem: ExploreAsset?
    let assetService: AssetService
    let belowFold: Bool
    let exploreItems: [ExploreAsset] // Need all items for mosaic
    let navigationDirection: NavigationDirection
    @State private var backgroundImage: UIImage?
    @State private var additionalImages: [UIImage] = []
    @State private var pendingItem: ExploreAsset?
    @State private var opacity: Double = 1.0
    @State private var animationTask: Task<Void, Never>?
    
    enum NavigationDirection {
        case none, forward, backward
    }
    
    var body: some View {
        Group {
            if let backgroundImage = backgroundImage {
                GeometryReader { geometry in
                    let imageAspectRatio = backgroundImage.size.width / backgroundImage.size.height
                    let isPortrait = imageAspectRatio < 1.0
                    
                    Group {
                        if isPortrait && !additionalImages.isEmpty {
                            // Portrait mosaic layout
                            HStack(spacing: 0) {
                                // Main image (left side)
                                Image(uiImage: backgroundImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width * 0.5)
                                    .clipped()
                                
                                // Additional images (right side)
                                VStack(spacing: 0) {
                                    ForEach(Array(additionalImages.prefix(2).enumerated()), id: \.offset) { index, image in
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(
                                                width: geometry.size.width * 0.5,
                                                height: geometry.size.height / 1.65
                                            )
                                            .clipped()
                                    }
                                    
                                    // Fill remaining space if we have less than 2 images
                                    if additionalImages.count < 2 {
                                        Rectangle()
                                            .fill(Color.clear)
                                            .frame(
                                                width: geometry.size.width * 0.5,
                                                height: geometry.size.height / 2
                                            )
                                    }
                                }
                                .frame(maxHeight: .infinity)
                            }
                            .ignoresSafeArea()
                        } else {
                            // Single image layout (landscape or no additional images)
                            Image(uiImage: backgroundImage)
                                .resizable()
                                .aspectRatio(contentMode: isPortrait ? .fit : .fill)
                                .frame(
                                    width: isPortrait ? min(geometry.size.width * 0.8, geometry.size.height * imageAspectRatio) : geometry.size.width,
                                    height: isPortrait ? min(geometry.size.height, geometry.size.width / imageAspectRatio) : geometry.size.height,
                                    alignment: .center
                                )
                                .clipped()
                                .ignoresSafeArea()
                        }
                    }
                    .opacity(opacity)
                    .animation(.easeIn(duration: 2), value: opacity)
                }
                .overlay {
                    Rectangle()
                        .fill(.regularMaterial)
                        .mask {
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0.25),
                                    .init(color: .black.opacity(belowFold ? 1 : 0.3), location: 0.375),
                                    .init(color: .black.opacity(belowFold ? 1 : 0), location: 0.5)
                                ],
                                startPoint: .bottom, endPoint: .top
                            )
                        }
                }
                .ignoresSafeArea()
            } else {
                SharedGradientBackground()
            }
        }
        .task(id: selectedItem?.id) {
            await scheduleBackgroundImageUpdate()
        }
        .onDisappear {
            animationTask?.cancel()
        }
    }
    
    private func scheduleBackgroundImageUpdate() async {
        // Cancel any existing animation task
        animationTask?.cancel()
        
        guard let selectedItem = selectedItem else {
            print("🖼️ BackgroundImageView: No selected item to load")
            return
        }
        
        // Store the pending item
        pendingItem = selectedItem
        
        // Create a new task with 1-second delay
        animationTask = Task {
            do {
                // Wait 1 second, but check if task is cancelled
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                // Check if this is still the current pending item and task wasn't cancelled
                guard !Task.isCancelled, pendingItem?.id == selectedItem.id else {
                    print("🖼️ BackgroundImageView: Animation cancelled or focus changed")
                    return
                }
                
                // Step 1: Fade out current image
                await MainActor.run {
                    opacity = 0.0
                }
                
                // Wait for fade out animation to complete
                try await Task.sleep(nanoseconds: 2000_000_000) // 0.5 seconds
                
                // Check if still valid
                guard !Task.isCancelled, pendingItem?.id == selectedItem.id else {
                    print("🖼️ BackgroundImageView: Animation cancelled during fade out")
                    return
                }
                
                // Step 2: Load new image while faded out
                await loadBackgroundImage(for: selectedItem)
                
                // Check if still valid
                guard !Task.isCancelled, pendingItem?.id == selectedItem.id else {
                    print("🖼️ BackgroundImageView: Animation cancelled after loading")
                    return
                }
                
                // Step 3: Fade in new image
                await MainActor.run {
                    opacity = 1.0
                }
                
            } catch is CancellationError {
                print("🖼️ BackgroundImageView: Animation task was cancelled")
                await MainActor.run {
                    opacity = 1.0
                }
            } catch {
                print("🖼️ BackgroundImageView: Unexpected error in animation task: \(error)")
                await MainActor.run {
                    opacity = 1.0
                }
            }
        }
    }
    
    
    private func loadBackgroundImage() async {
        guard let selectedItem = selectedItem else {
            print("🖼️ BackgroundImageView: No selected item to load")
            return
        }
        await loadBackgroundImage(for: selectedItem)
    }
    
    private func loadBackgroundImage(for selectedItem: ExploreAsset) async {
        
        print("🖼️ BackgroundImageView: Loading background for \(selectedItem.primaryTitle) (ID: \(selectedItem.id))")
        
        do {
            guard let image = try await assetService.loadImage(asset: selectedItem.asset, size: "preview") else {
                print("🖼️ BackgroundImageView: No image returned for \(selectedItem.primaryTitle)")
                return
            }
            
            // Check if image is portrait and load additional images
            let imageAspectRatio = image.size.width / image.size.height
            let isPortrait = imageAspectRatio < 1.0
            
            var finalImage = image
            var additionalImagesArray: [UIImage] = []
            var useMosaic = false
            
            if isPortrait {
                print("🖼️ BackgroundImageView: Portrait detected, checking for landscape alternatives from same location")
                
                // Fetch additional assets from the same location
                do {
                    let cityAssets = try await assetService.fetchAssets(limit: 5, city: selectedItem.primaryTitle )
                    
                    // Get all assets excluding the main one
                    let allAssets = cityAssets.assets.filter { $0.id != selectedItem.asset.id }
                    
                    var allLoadedImages: [UIImage] = []
                    
                    // Load all images to check their orientations
                    for asset in allAssets.prefix(4) { // Load up to 4 additional images
                        do {
                            if let loadedImage = try await assetService.loadImage(asset: asset, size: "preview") {
                                allLoadedImages.append(loadedImage)
                            }
                        } catch {
                            print("🖼️ BackgroundImageView: Failed to load image from \(selectedItem.primaryTitle): \(error)")
                        }
                    }
                    
                    // Find first landscape image
                    if let landscapeImage = allLoadedImages.first(where: { $0.size.width / $0.size.height >= 1.0 }) {
                        print("🖼️ BackgroundImageView: Found landscape alternative, using that instead of mosaic")
                        finalImage = landscapeImage
                        useMosaic = false
                    } else {
                        print("🖼️ BackgroundImageView: No landscape alternatives found, using mosaic layout")
                        additionalImagesArray = Array(allLoadedImages.prefix(2))
                        useMosaic = true
                    }
                    
                } catch {
                    print("🖼️ BackgroundImageView: Failed to fetch additional assets for \(selectedItem.primaryTitle): \(error)")
                    // Fallback to mosaic with original portrait image
                    useMosaic = true
                }
            }
            
            await MainActor.run {
                print("🖼️ BackgroundImageView: Successfully loaded background for \(selectedItem.primaryTitle)")
                backgroundImage = finalImage
                additionalImages = useMosaic ? additionalImagesArray : []
            }
        } catch {
            print("🖼️ BackgroundImageView: Failed to load background for \(selectedItem.primaryTitle): \(error)")
        }
    }
}

// MARK: - Fold Snapping Scroll Behavior
struct FoldSnappingScrollTargetBehavior: ScrollTargetBehavior {
    var aboveFold: Bool
    var showcaseHeight: CGFloat
    
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let firstRowHeight = 300.00 + 100 // item + padding
        let secondRowStart = showcaseHeight + firstRowHeight + 100
        
        // Only apply snapping if we're scrolling beyond the first row
        guard target.rect.minY > firstRowHeight else {
            // Allow normal scrolling in the first row area
            return
        }
        
        // Check if we're in the second row area where snapping should occur
        if target.rect.minY > secondRowStart * 0.5 && target.rect.minY < secondRowStart * 1.5 {
            if target.rect.minY > secondRowStart {
                // Snap to show the second row fully (align at top of screen)
                target.rect.origin.y = secondRowStart
            } else {
                // Snap back to show first row (showcase + first row visible)
                target.rect.origin.y = 0
            }
        }
        
        // For scrolling far down, allow normal behavior
        if target.rect.minY > secondRowStart * 1.5 {
            return
        }
        
        // For scrolling back up from deep in content
        if !aboveFold && target.rect.minY < showcaseHeight * 0.6 {
            target.rect.origin.y = 0
        }
    }
}

// MARK: - Thumbnail Provider for Explore Items
class ExploreThumbnailProvider: ThumbnailProvider {
    private let assetService: AssetService
    
    init(assetService: AssetService) {
        self.assetService = assetService
    }
    
    func loadThumbnails(for item: GridDisplayable) async -> [UIImage] {
        guard let exploreAsset = item as? ExploreAsset else { return [] }
        
        do {
            if let image = try await assetService.loadImage(asset: exploreAsset.asset, size: "preview") {
                return [image]
            }
        } catch {
            print("Failed to load thumbnail for explore asset: \(error)")
        }
        
        return []
    }
}
