//
//  TimelineView.swift
//  Immich Gallery
//
//  A sectioned-by-month alternative to the All Photos grid. Built on the
//  Immich timeline buckets API: one cheap call fetches every month + count,
//  then each month's assets load lazily as its section scrolls into view.
//  Because the columnar bucket payload is small and month lookups skip the
//  offset-walk that /search/metadata pays on deep scroll, this is well suited
//  to large libraries.
//

import SwiftUI

struct TimelineView: View {
    private enum ToolbarButton: Hashable {
        case filter
        case favorites
        case mediaType
        case resetFilters
        case sort
        case calendar
    }

    private enum MediaFilter: Hashable {
        case all
        case video

        var title: String {
            switch self {
            case .all: "All"
            case .video: "Video"
            }
        }

        var iconName: String {
            switch self {
            case .all: "photo.on.rectangle.angled"
            case .video: "video.fill"
            }
        }

        var assetType: AssetType? {
            switch self {
            case .all: nil
            case .video: .video
            }
        }
    }

    private enum ScrollAnchor: Hashable {
        case top
    }

    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    @AppStorage(UserDefaultsKeys.allPhotosSortOrder) private var allPhotosSortOrder = "desc"

    @State private var buckets: [TimelineBucket] = []
    @State private var bucketAssets: [String: [ImmichAsset]] = [:]
    // The bucket endpoint returns a whole month at once, which can be tens of
    // thousands of assets. Keep fetched assets separate from the number exposed
    // to SwiftUI/tvOS focus: the focus engine must never receive an entire large
    // month just because that month crossed a page boundary.
    @State private var visibleAssetLimit = 0
    @State private var isLoadingUnfilteredPage = false
    @State private var isLoading = false
    @State private var isScrolling = false
    @State private var errorMessage: String?
    @State private var showingFilterModal = false
    @State private var filters = PhotoFilterSelection.saved
    @State private var favoritesOnly = false
    @State private var mediaFilter: MediaFilter = .all
    @State private var loadGeneration = UUID()
    @State private var filteredNextPage: Int?
    @State private var isLoadingFilteredPage = false
    @State private var showingCalendar = false

    private let assetPageSize = 120

    @State private var selectedAsset: ImmichAsset?
    @State private var showingFullScreen = false
    @State private var showingSlideshow = false
    @State private var slideshowLaunchAsset: ImmichAsset?
    @State private var currentAssetIndex: Int = 0
    @FocusState private var focusedAssetId: String?
    @FocusState private var focusedToolbarButton: ToolbarButton?

    private let columnCount = 5
    private let tileWidth: CGFloat = 300
    private let tileHeight: CGFloat = 360
    private let gridSpacing: CGFloat = 50

    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(tileWidth), spacing: gridSpacing), count: columnCount)
    }

    private var hasMetadataFilter: Bool {
        filters.activeCount > 0 || mediaFilter != .all
    }

    private var hasActiveFilter: Bool {
        hasMetadataFilter || favoritesOnly
    }

    private var activeFilterCount: Int {
        filters.activeCount
            + (favoritesOnly ? 1 : 0)
            + (mediaFilter == .all ? 0 : 1)
    }

    private struct RenderedSection: Identifiable {
        let bucket: TimelineBucket
        let assets: ArraySlice<ImmichAsset>

        var id: String { bucket.id }
    }

    /// Month sections containing at most `visibleAssetLimit` actual cells in
    /// total. A loaded 15,000-photo month can therefore contribute only the
    /// remaining cells in the current 120-item page.
    private var renderedSections: [RenderedSection] {
        let loadedBuckets = buckets.prefix { bucketAssets[$0.timeBucket] != nil }
        let availableCounts = loadedBuckets.map { bucketAssets[$0.timeBucket]?.count ?? 0 }
        let visibleCounts = Self.visibleCounts(availableCounts: availableCounts, limit: visibleAssetLimit)

        return zip(loadedBuckets, visibleCounts).compactMap { bucket, visibleCount in
            guard visibleCount > 0, let assets = bucketAssets[bucket.timeBucket] else { return nil }
            return RenderedSection(bucket: bucket, assets: assets.prefix(visibleCount))
        }
    }

    private var renderedAssetCount: Int {
        renderedSections.reduce(0) { $0 + $1.assets.count }
    }

    private var loadedAssetCount: Int {
        buckets.reduce(0) { $0 + (bucketAssets[$1.timeBucket]?.count ?? 0) }
    }

    private var loadedMonthCount: Int {
        buckets.reduce(0) { $0 + (bucketAssets[$1.timeBucket] == nil ? 0 : 1) }
    }

    private var largestLoadedMonth: Int {
        bucketAssets.values.map(\.count).max() ?? 0
    }

    private var hasMoreUnfilteredAssets: Bool {
        visibleAssetLimit < loadedAssetCount || bucketAssets.count < buckets.count
    }

    private var canRequestMoreAssets: Bool {
        guard renderedAssetCount > 0 else { return false }
        if hasMetadataFilter {
            return filteredNextPage != nil && !isLoadingFilteredPage
        }
        return hasMoreUnfilteredAssets && !isLoadingUnfilteredPage
    }

    // Flat, ordered list of every asset loaded so far — passed to the
    // fullscreen viewer so left/right paging works across loaded months.
    private var loadedAssetsInOrder: [ImmichAsset] {
        buckets.flatMap { bucketAssets[$0.timeBucket] ?? [] }
    }

    /// `currentAssetIndex` includes videos, while a photo slideshow only queues
    /// images. Convert the focused position into the matching image offset.
    private var slideshowStartingIndex: Int {
        // Resolve focus at launch time as well as maintaining currentAssetIndex.
        // Play/Pause can arrive immediately after a focus move, before its
        // onChange handler has committed the new index.
        let focusedIndex = loadedAssetsInOrder.index(forFocusedAssetID: focusedAssetId) ?? currentAssetIndex
        let precedingAssets = loadedAssetsInOrder.prefix(focusedIndex + 1)
        return max(0, precedingAssets.filter { $0.type == .image }.count - 1)
    }

    var body: some View {
        let _ = PerformanceDiagnostics.updateTimeline {
            PerformanceDiagnostics.TimelineSnapshot(
                visibleAssets: renderedAssetCount,
                loadedAssets: loadedAssetCount,
                loadedMonths: loadedMonthCount,
                totalMonths: buckets.count,
                largestLoadedMonth: largestLoadedMonth,
                isPaging: isLoadingFilteredPage || isLoadingUnfilteredPage
            )
        }

        ZStack {
            SharedGradientBackground()

            VStack(spacing: 18) {
                if isLoading {
                    filterAndSortToolbar
                        .padding(.horizontal, 72)
                    Spacer()
                    ProgressView("Loading timeline...")
                        .foregroundColor(.white)
                        .scaleEffect(1.5)
                    Spacer()
                } else if let errorMessage {
                    filterAndSortToolbar
                        .padding(.horizontal, 72)
                    Spacer()
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
                        Button("Retry") { reloadTimeline() }
                            .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                } else if buckets.isEmpty {
                    filterAndSortToolbar
                        .padding(.horizontal, 72)
                    Spacer()
                    VStack {
                        Image(systemName: emptyStateIconName)
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text(emptyStateTitle)
                            .font(.title)
                            .foregroundColor(.white)
                        Text(emptyStateMessage)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    timelineContent
                }
            }
            .padding(.top, 20)
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            if let selectedAsset = selectedAsset {
                let assets = loadedAssetsInOrder
                FullScreenImageView(
                    asset: selectedAsset,
                    assets: assets,
                    assetService: assetService,
                    authenticationService: authService,
                    currentAssetIndex: $currentAssetIndex
                )
                // A fullScreenCover doesn't inherit the presenter's overlay, so
                // reattach the same shared diagnostics monitor here.
                .diagnosticsOverlay()
            }
        }
        .fullScreenCover(isPresented: $showingSlideshow) {
            if let slideshowLaunchAsset {
                SlideshowView(
                    launchContext: SlideshowLaunchContext(
                        startingAsset: slideshowLaunchAsset,
                        startingIndex: slideshowStartingIndex,
                        filters: filters,
                        favoritesOnly: favoritesOnly,
                        assetType: mediaFilter.assetType,
                        sortOrder: allPhotosSortOrder
                    )
                )
            }
        }
        .onPlayPauseCommand {
            guard let focusedAsset = loadedAssetsInOrder.first(where: { $0.id == focusedAssetId }), focusedAsset.type == .image else { return }
            slideshowLaunchAsset = focusedAsset
            NotificationCenter.default.post(
                name: NSNotification.Name(NotificationNames.pauseInactivityMonitoring),
                object: nil
            )
            showingSlideshow = true
        }
        .onChange(of: focusedAssetId) { _, focusedAssetID in
            if let index = loadedAssetsInOrder.index(forFocusedAssetID: focusedAssetID) {
                currentAssetIndex = index
            }
        }
        .fullScreenCover(isPresented: $showingCalendar, onDismiss: restoreCalendarButtonFocus) {
            CalendarMonthGridView(
                assetService: assetService,
                authService: authService,
                order: allPhotosSortOrder
            )
        }
        .sheet(isPresented: $showingFilterModal) {
            FilterSettingsView(
                assetService: assetService,
                selection: $filters
            ) {
                applyFilters()
            }
        }
        .onAppear {
            if buckets.isEmpty && !isLoading {
                reloadTimeline()
            }
        }
    }

    private var filterAndSortToolbar: some View {
        HStack {
            Spacer()
            filterAndSortButtons
        }
    }

    private var filterAndSortButtons: some View {
        HStack(spacing: 30) {
            Button(action: { showingFilterModal = true }) {
                Image(systemName: activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .frame(width: 44, height: 32)
                    .overlay(alignment: .topTrailing) {
                        if activeFilterCount > 0 {
                            Text("\(activeFilterCount)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 28, minHeight: 28)
                                .background(.red, in: Circle())
                                .offset(x: 12, y: -10)
                        }
                    }
                }
            .buttonStyle(.bordered)
            .focused($focusedToolbarButton, equals: .filter)
            .accessibilityLabel("Timeline filters")
            .accessibilityValue(activeFilterCount > 0 ? "\(activeFilterCount) active" : "None active")
            .accessibilityHint("Opens timeline filter settings")

            Button(action: toggleFavoritesOnly) {
                Image(systemName: favoritesOnly ? "heart.fill" : "heart")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.bordered)
            .focused($focusedToolbarButton, equals: .favorites)
            .accessibilityLabel(favoritesOnly ? "Show all timeline media" : "Show favorites only")
            .accessibilityHint("Toggles the favorites-only timeline filter")

            Button(action: toggleMediaFilter) {
                Image(systemName: mediaFilter.iconName)
            }
            .buttonStyle(.bordered)
            .focused($focusedToolbarButton, equals: .mediaType)
            .accessibilityLabel(mediaFilter == .all ? "Show videos only" : "Show all media")
            .accessibilityValue(mediaFilter.title)
            .accessibilityHint("Toggles the timeline media-type filter")

            Button(action: resetFilters) {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .focused($focusedToolbarButton, equals: .resetFilters)
            .disabled(!hasActiveFilter)
            .accessibilityLabel("Reset timeline filters")
            .accessibilityHint("Clears all active timeline filters")

            AllPhotosSortButton(
                sortOrder: allPhotosSortOrder,
                action: toggleSortOrder,
                accessibilityLabel: "Sort timeline by date taken"
            )
            .focused($focusedToolbarButton, equals: .sort)

            Button(action: { showingCalendar = true }) {
                Label("Months", systemImage: "calendar")
            }
            .buttonStyle(.bordered)
            .focused($focusedToolbarButton, equals: .calendar)
            .accessibilityLabel("Browse by month")
            .accessibilityHint("Shows one card for every month containing photos")
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
    }

    private func toggleSortOrder() {
        allPhotosSortOrder = allPhotosSortOrder == "asc" ? "desc" : "asc"
        reloadTimeline()
    }

    private func toggleFavoritesOnly() {
        favoritesOnly.toggle()
        reloadTimeline()
    }

    private func toggleMediaFilter() {
        mediaFilter = mediaFilter == .all ? .video : .all
        reloadTimeline()
    }

    private func resetFilters() {
        guard hasActiveFilter else { return }
        filters.reset()
        favoritesOnly = false
        mediaFilter = .all
        filters.save()
        reloadTimeline()
    }

    private func restoreCalendarButtonFocus() {
        Task { @MainActor in
            await Task.yield()
            focusedToolbarButton = .calendar
        }
    }

    // MARK: - Month section

    private var timelineContent: some View {
        let sections = renderedSections

        return ScrollViewReader { proxy in
            ScrollView {
                if let firstSection = sections.first {
                    timelineHeader(for: firstSection.bucket)
                        .padding(.horizontal, 72)
                        .padding(.top, 16)
                        .id(ScrollAnchor.top)
                }

                // A single grid with a hard cell limit. `LazyVGrid` alone is not
                // enough on tvOS: the focus engine can still evaluate declared
                // off-screen buttons when resolving vertical movement.
                LazyVGrid(columns: columns, spacing: gridSpacing) {
                    if let firstSection = sections.first {
                        Section {
                            sectionContent(firstSection)
                        }
                    }

                    ForEach(sections.dropFirst()) { section in
                        Section {
                            sectionContent(section)
                        } header: {
                            sectionHeader(for: section.bucket)
                        }
                    }
                }
                // The controls sit on the right while a one-result grid starts
                // on the far left. Expand both regions to bridge that gap.
                .focusSection()
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 40)
                .onExitCommand {
                    guard focusedAssetId != nil else { return }

                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(ScrollAnchor.top, anchor: .top)
                    }
                    focusedAssetId = nil

                    Task { @MainActor in
                        await Task.yield()
                        focusedToolbarButton = .filter
                    }
                }

                if isLoadingFilteredPage || isLoadingUnfilteredPage {
                    ProgressView("Loading more...")
                        .foregroundColor(.white)
                        .padding(.bottom, 40)
                }
            }
            .onScrollPhaseChange { _, newPhase, context in
                isScrolling = ThumbnailScrollLoadingPolicy.shouldPauseLoading(
                    during: newPhase,
                    velocity: context.velocity
                )
            }
            // A normal ScrollView child's onAppear fires when it enters the view
            // hierarchy, not when it reaches the viewport. Observe real scroll
            // geometry instead so a page is revealed only near the actual end.
            .onScrollGeometryChange(for: Bool.self) { geometry in
                let viewportBottom = geometry.contentOffset.y + geometry.containerSize.height
                let distanceToBottom = geometry.contentSize.height - viewportBottom
                return distanceToBottom <= tileHeight * 2
            } action: { wasNearBottom, isNearBottom in
                guard !wasNearBottom, isNearBottom, canRequestMoreAssets else { return }
                loadNextAssetPage()
            }
        }
    }

    private func timelineHeader(for bucket: TimelineBucket) -> some View {
        HStack(spacing: 30) {
            Text(Self.monthLabel(for: bucket.timeBucket))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Spacer(minLength: 30)

            filterAndSortButtons
        }
        // Pair with the grid's focus section so navigation across the wide
        // title/control gap works in both directions for a one-item result.
        .focusSection()
    }

    /// Full-width month label (a Section header spans all columns).
    private func sectionHeader(for bucket: TimelineBucket) -> some View {
        Text(Self.monthLabel(for: bucket.timeBucket))
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 8)
            .padding(.top, 20)
    }

    @ViewBuilder
    private func sectionContent(_ section: RenderedSection) -> some View {
        ForEach(section.assets) { asset in
            assetTile(asset)
        }
    }

    private func assetTile(_ asset: ImmichAsset) -> some View {
        Button(action: {
            selectedAsset = asset
            if let index = loadedAssetsInOrder.firstIndex(of: asset) {
                currentAssetIndex = index
            }
            showingFullScreen = true
        }) {
            AssetThumbnailView(
                asset: asset,
                assetService: assetService,
                isFocused: focusedAssetId == asset.id,
                shouldLoadThumbnail: !isScrolling,
                allowsThumbhashPlaceholder: false,
                showsDateOverlay: false,
                thumbnailLoadDelayNanoseconds: 0
            )
        }
        .frame(width: tileWidth, height: tileHeight)
        .id(asset.id)
        .focused($focusedAssetId, equals: asset.id)
        .buttonStyle(CardButtonStyle())
    }

    // MARK: - Loading

    private func reloadTimeline() {
        guard authService.isAuthenticated else {
            errorMessage = "Not authenticated. Please check your credentials."
            isLoading = false
            return
        }

        // Keep an already-rendered timeline mounted while a toolbar action
        // refreshes it. Replacing the scroll view with the loading screen moves
        // the focused toolbar and makes the whole page visibly jump.
        let preservesCurrentTimeline = !buckets.isEmpty
        let generation = UUID()
        loadGeneration = generation
        filteredNextPage = nil
        isLoadingFilteredPage = false
        isLoadingUnfilteredPage = false
        isLoading = !preservesCurrentTimeline
        errorMessage = nil

        if !preservesCurrentTimeline {
            buckets = []
            bucketAssets = [:]
            visibleAssetLimit = 0
            focusedAssetId = nil
        }

        if hasMetadataFilter {
            loadFilteredTimelinePage(1, generation: generation, isInitialPage: true)
        } else {
            loadBuckets(generation: generation)
        }
    }

    private func loadBuckets(generation: UUID) {
        let order = allPhotosSortOrder
        let favoritesOnly = favoritesOnly

        Task {
            do {
                let fetched = try await assetService.fetchTimelineBuckets(
                    order: order,
                    isFavorite: favoritesOnly
                )
                let sorted = Self.filteredAndSortedBuckets(fetched, order: order, year: nil)

                // Fetch enough complete bucket responses to cover the first
                // cell page, then install them atomically. The response may
                // contain far more assets, but rendering remains capped below.
                let initialAssets = try await fetchBucketAssets(
                    covering: assetPageSize,
                    in: sorted,
                    startingWith: [:],
                    order: order,
                    favoritesOnly: favoritesOnly
                )

                await MainActor.run {
                    guard self.loadGeneration == generation else { return }
                    self.buckets = sorted
                    self.bucketAssets = initialAssets
                    self.visibleAssetLimit = min(self.assetPageSize, Self.assetCount(in: initialAssets, orderedBy: sorted))
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    guard self.loadGeneration == generation else { return }
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func loadNextAssetPage() {
        if hasMetadataFilter {
            if let nextPage = filteredNextPage, !isLoadingFilteredPage {
                loadFilteredTimelinePage(nextPage, generation: loadGeneration, isInitialPage: false)
            }
            return
        }

        guard !isLoadingUnfilteredPage, hasMoreUnfilteredAssets else { return }
        isLoadingUnfilteredPage = true

        let targetLimit = visibleAssetLimit + assetPageSize
        let generation = loadGeneration
        let order = allPhotosSortOrder
        let favoritesOnly = favoritesOnly
        let sortedBuckets = buckets
        let existingAssets = bucketAssets

        Task {
            do {
                let updatedAssets = try await fetchBucketAssets(
                    covering: targetLimit,
                    in: sortedBuckets,
                    startingWith: existingAssets,
                    order: order,
                    favoritesOnly: favoritesOnly
                )
                await MainActor.run {
                    guard self.loadGeneration == generation else { return }
                    self.bucketAssets = updatedAssets
                    self.visibleAssetLimit = min(
                        targetLimit,
                        Self.assetCount(in: updatedAssets, orderedBy: sortedBuckets)
                    )
                    self.isLoadingUnfilteredPage = false
                }
            } catch {
                await MainActor.run {
                    guard self.loadGeneration == generation else { return }
                    self.isLoadingUnfilteredPage = false
                }
            }
        }
    }

    /// Bucket responses are all-or-nothing, so load consecutive months until
    /// their real response sizes cover the requested cell limit. Responses are
    /// accumulated off-screen and committed together by the caller.
    private func fetchBucketAssets(
        covering targetCount: Int,
        in orderedBuckets: [TimelineBucket],
        startingWith existingAssets: [String: [ImmichAsset]],
        order: String,
        favoritesOnly: Bool
    ) async throws -> [String: [ImmichAsset]] {
        var result = existingAssets
        var accumulated = 0

        for bucket in orderedBuckets {
            try Task.checkCancellation()

            if let assets = result[bucket.timeBucket] {
                accumulated += assets.count
            } else {
                guard accumulated < targetCount else { break }
                let assets = try await assetService.fetchBucketAssets(
                    timeBucket: bucket.timeBucket,
                    order: order,
                    isFavorite: favoritesOnly
                )
                result[bucket.timeBucket] = assets
                accumulated += assets.count
            }

            if accumulated >= targetCount { break }
        }

        return result
    }

    private func loadFilteredTimelinePage(_ page: Int, generation: UUID, isInitialPage: Bool) {
        guard !isLoadingFilteredPage else { return }
        isLoadingFilteredPage = true
        let order = allPhotosSortOrder
        let filters = filters
        let favoritesOnly = favoritesOnly
        let assetType = mediaFilter.assetType

        Task {
            do {
                let result = try await assetService.fetchFilteredTimelineAssets(
                    page: page,
                    size: assetPageSize,
                    order: order,
                    city: filters.city,
                    state: filters.state,
                    country: filters.country,
                    cameraMake: filters.cameraMake,
                    cameraModel: filters.cameraModel,
                    lensModel: filters.lensModel,
                    year: filters.year,
                    isFavorite: favoritesOnly,
                    assetType: assetType
                )
                await MainActor.run {
                    guard self.loadGeneration == generation else { return }
                    self.mergeFilteredAssets(result.assets, order: order, replacing: isInitialPage)
                    self.filteredNextPage = Self.nextPageNumber(from: result.nextPage, after: page)
                    self.isLoadingFilteredPage = false
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    guard self.loadGeneration == generation else { return }
                    self.isLoadingFilteredPage = false
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func mergeFilteredAssets(_ newAssets: [ImmichAsset], order: String, replacing: Bool) {
        var merged = replacing ? [] : loadedAssetsInOrder
        var seen = Set(merged.map(\.id))
        merged.append(contentsOf: newAssets.filter { seen.insert($0.id).inserted })

        let grouped = Dictionary(grouping: merged, by: Self.monthBucketKey(for:))
        let keys = grouped.keys.sorted { order == "asc" ? $0 < $1 : $0 > $1 }
        buckets = keys.map { TimelineBucket(timeBucket: $0, count: grouped[$0]?.count ?? 0) }
        bucketAssets = Dictionary(uniqueKeysWithValues: keys.map { ($0, grouped[$0] ?? []) })
        visibleAssetLimit = merged.count
    }

    private func applyFilters() {
        filters.save()
        showingFilterModal = false
        reloadTimeline()
    }

    private var emptyStateIconName: String {
        if mediaFilter == .video {
            return "video.fill"
        }
        if favoritesOnly {
            return "heart.fill"
        }
        return "calendar"
    }

    private var emptyStateTitle: String {
        if favoritesOnly && mediaFilter == .video {
            return "No Favorite Videos Found"
        }
        if mediaFilter == .video {
            return "No Videos Found"
        }
        if favoritesOnly {
            return "No Favorites Found"
        }
        return "No Media Found"
    }

    private var emptyStateMessage: String {
        if filters.activeCount > 0 {
            return "Try changing the active filters"
        }
        if favoritesOnly && mediaFilter == .video {
            return "Your favorite videos will appear here"
        }
        if mediaFilter == .video {
            return "Your videos will appear here"
        }
        if favoritesOnly {
            return "Your favorite photos and videos will appear here"
        }
        return "Your photos and videos will appear here"
    }

    // MARK: - Formatting

    static func monthBucketKey(for asset: ImmichAsset) -> String {
        let captureDate = asset.localDateTime.isEmpty ? asset.fileCreatedAt : asset.localDateTime
        let month = String(captureDate.prefix(7))
        return "\(month)-01T00:00:00.000Z"
    }

    static func nextPageNumber(from nextPage: String?, after currentPage: Int) -> Int? {
        guard let nextPage, !nextPage.isEmpty else { return nil }
        if let page = Int(nextPage) { return page }
        if let components = URLComponents(string: nextPage),
           let value = components.queryItems?.first(where: { $0.name == "page" })?.value,
           let page = Int(value) {
            return page
        }
        return currentPage + 1
    }

    static func filteredAndSortedBuckets(_ buckets: [TimelineBucket], order: String, year: Int?) -> [TimelineBucket] {
        let yearFiltered = year.map { selectedYear in
            buckets.filter { $0.timeBucket.hasPrefix(String(selectedYear)) }
        } ?? buckets

        return yearFiltered.sorted { first, second in
            order == "asc" ? first.timeBucket < second.timeBucket : first.timeBucket > second.timeBucket
        }
    }

    /// Counts fetched assets in timeline order. Kept internal for regression
    /// tests covering highly uneven month sizes.
    static func assetCount(
        in assetsByBucket: [String: [ImmichAsset]],
        orderedBy buckets: [TimelineBucket]
    ) -> Int {
        buckets.reduce(0) { $0 + (assetsByBucket[$1.timeBucket]?.count ?? 0) }
    }

    /// Returns the number of cells each consecutive month may contribute to a
    /// hard global limit. This is the invariant the old bucket frontier lacked.
    static func visibleCounts(availableCounts: [Int], limit: Int) -> [Int] {
        guard limit > 0 else { return [] }
        var remaining = limit
        var result: [Int] = []

        for count in availableCounts where remaining > 0 {
            let visible = min(max(0, count), remaining)
            result.append(visible)
            remaining -= visible
        }

        return result
    }

    private static let bucketParser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM"
        return f
    }()

    private static let monthDisplay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    /// "2024-03-01T00:00:00.000Z" -> "March 2024".
    static func monthLabel(for timeBucket: String) -> String {
        let prefix = String(timeBucket.prefix(7)) // "yyyy-MM"
        if let date = bucketParser.date(from: prefix) {
            return monthDisplay.string(from: date)
        }
        return prefix
    }
}
