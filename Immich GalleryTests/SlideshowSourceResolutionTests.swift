//
//  SlideshowSourceResolutionTests.swift
//  Immich GalleryTests
//
//  Covers the bug where launching a slideshow for a specific album played the
//  auto-slideshow config album (immich-gallery-config) instead of the selected one.
//

import Testing
@testable import Immich_Gallery

struct SlideshowSourceResolutionTests {

    /// Bug repro: the user opens a specific album ("Kids" is the auto-slideshow
    /// config album, but here they opened a *different* album) and presses play.
    /// The slideshow must play the album they selected, not the config album.
    @Test func explicitAlbumSelectionIsNotOverriddenByAutoSlideshowConfig() {
        let selection = SlideshowView.SlideshowSelection(
            albumId: "vacation-album-id",   // explicitly opened album
            personId: nil,
            tagId: nil,
            city: nil,
            isFavorite: false
        )
        // Auto-slideshow config points at a DIFFERENT album (the "Kids" album).
        let config = SlideshowConfig(albumIds: ["kids-auto-config-album-id"], personIds: [])

        let source = SlideshowView.resolveSlideshowSource(selection: selection, config: config)

        #expect(source == .selection(selection))
    }

    /// The auto-slideshow / all-photos entry point (no explicit target) should
    /// still use the config when one is configured.
    @Test func noExplicitSelectionUsesAutoSlideshowConfig() {
        let selection = SlideshowView.SlideshowSelection(
            albumId: nil,
            personId: nil,
            tagId: nil,
            city: nil,
            isFavorite: false
        )
        let config = SlideshowConfig(albumIds: ["kids-auto-config-album-id"], personIds: [])

        let source = SlideshowView.resolveSlideshowSource(selection: selection, config: config)

        #expect(source == .config(config))
    }

    /// An explicit selection is honored when no auto-slideshow config is set.
    @Test func explicitSelectionUsedWhenConfigEmpty() {
        let selection = SlideshowView.SlideshowSelection(
            albumId: "vacation-album-id",
            personId: nil,
            tagId: nil,
            city: nil,
            isFavorite: false
        )

        let source = SlideshowView.resolveSlideshowSource(selection: selection, config: .empty)

        #expect(source == .selection(selection))
    }

    /// Favorites is also an explicit target and must not be overridden by config.
    @Test func favoritesSelectionIsNotOverriddenByConfig() {
        let selection = SlideshowView.SlideshowSelection(
            albumId: nil,
            personId: nil,
            tagId: nil,
            city: nil,
            isFavorite: true
        )
        let config = SlideshowConfig(albumIds: ["kids-auto-config-album-id"], personIds: [])

        let source = SlideshowView.resolveSlideshowSource(selection: selection, config: config)

        #expect(source == .selection(selection))
    }

    @Test func slideshowStartPositionFetchesPagesUntilFocusedAssetIsFound() async throws {
        let pages = [
            1: SlideshowAssetPage(items: ["a", "b"], hasMore: true),
            2: SlideshowAssetPage(items: ["c", "focused", "e"], hasMore: true)
        ]
        var requestedPages: [Int] = []

        let result = try await SlideshowStartPosition.find(
            assetID: "focused",
            fetchPage: { page in
                requestedPages.append(page)
                return pages[page]!
            },
            id: { $0 }
        )

        #expect(requestedPages == [1, 2])
        #expect(result?.page == 2)
        #expect(result?.offset == 1)
        #expect(result?.items == ["c", "focused", "e"])
        #expect(result?.hasMore == true)
    }

    @Test func slideshowStartPositionStopsWhenFocusedAssetIsAbsent() async throws {
        let pages = [
            1: SlideshowAssetPage(items: ["a"], hasMore: true),
            2: SlideshowAssetPage(items: ["b"], hasMore: false)
        ]
        var requestedPages: [Int] = []

        let result = try await SlideshowStartPosition.find(
            assetID: "missing",
            fetchPage: { page in
                requestedPages.append(page)
                return pages[page]!
            },
            id: { $0 }
        )

        #expect(requestedPages == [1, 2])
        #expect(result.map { $0.page } == nil)
    }

    @Test func slideshowConfigParserAcceptsWhitespaceCaseAndNewlines() {
        let config = SlideshowConfigService.parseConfigDescription(
            "  ALBUMids : [\"album-1\", \"album-2\"]\nPERSONids:['person-1']"
        )

        #expect(config == SlideshowConfig(albumIds: ["album-1", "album-2"], personIds: ["person-1"]))
    }

    @Test func slideshowConfigParserRejectsMalformedConfiguration() {
        #expect(SlideshowConfigService.parseConfigDescription("albumIds:[\"album-1\"") == nil)
    }

    @Test func slideshowConfigRejectsInvalidUUIDs() {
        let config = SlideshowConfig(albumIds: ["c7e09884-c687-4ca3-8820 -a5be692b1f37"], personIds: [])

        #expect(!SlideshowConfigService.hasValidImmichIdentifiers(config))
    }

    @Test func slideshowConfigValidationReportsInvalidIdentifiers() {
        #expect(
            SlideshowConfigLoadResult.invalidIdentifier.userFacingMessage
                == "Album and person IDs must be valid UUIDs."
        )
    }

    @Test func slideshowConfigSummaryUsesResolvedSourceNames() {
        let config = SlideshowConfig(albumIds: ["album-id"], personIds: [])
        let summary = SlideshowConfigSummary(
            result: .configured(config),
            sourceNames: ["Album: Family"]
        )

        #expect(summary.displayText == "Album: Family")
    }

}
