//
//  VideoStreamingTests.swift
//  Immich GalleryTests
//

import Testing
import Foundation
@testable import Immich_Gallery

struct VideoStreamingTests {
    private let assetId = "0c6c4f5e-8f1a-4d2b-9a3e-5b7c9d1e2f30"
    private let sessionId = "9b2f7c1e-3d4a-4e5f-8a6b-7c8d9e0f1a2b"

    @Test func serverFeaturesDecodesRealtimeTranscodingFlag() throws {
        let enabled = try JSONDecoder().decode(ServerFeatures.self, from: Data(#"{"trash":true,"realtimeTranscoding":true}"#.utf8))
        #expect(enabled.supportsRealtimeTranscoding)

        let disabled = try JSONDecoder().decode(ServerFeatures.self, from: Data(#"{"realtimeTranscoding":false}"#.utf8))
        #expect(!disabled.supportsRealtimeTranscoding)

        let olderServer = try JSONDecoder().decode(ServerFeatures.self, from: Data(#"{"trash":true}"#.utf8))
        #expect(!olderServer.supportsRealtimeTranscoding)
    }

    @Test func hlsIsPreferredOnlyWhenServerAndUserAllowIt() {
        #expect(VideoPlaybackSource.preferred(serverSupportsHLS: true, userAllowsTranscodedStreaming: true) == .hls)
        #expect(VideoPlaybackSource.preferred(serverSupportsHLS: true, userAllowsTranscodedStreaming: false) == .progressive)
        #expect(VideoPlaybackSource.preferred(serverSupportsHLS: false, userAllowsTranscodedStreaming: true) == .progressive)
        #expect(VideoPlaybackSource.preferred(serverSupportsHLS: false, userAllowsTranscodedStreaming: false) == .progressive)
    }

    @Test func hlsEndpointsMatchImmichRoutes() {
        #expect(HLSStreamSession.mainPlaylistEndpoint(assetId: assetId) == "/api/assets/\(assetId)/video/stream/main.m3u8")
        #expect(HLSStreamSession.sessionEndpoint(assetId: assetId, sessionId: sessionId) == "/api/assets/\(assetId)/video/stream/\(sessionId)")
    }

    @Test func sessionIdIsExtractedFromVariantPlaylistAndSegmentURIs() {
        #expect(HLSStreamSession.sessionId(
            fromURI: "http://immich.local:2283/api/assets/\(assetId)/video/stream/\(sessionId)/2/playlist.m3u8",
            assetId: assetId
        ) == sessionId)
        #expect(HLSStreamSession.sessionId(
            fromURI: "https://photos.example.com/immich/api/assets/\(assetId)/video/stream/\(sessionId)/0/seg_12.m4s",
            assetId: assetId
        ) == sessionId)
    }

    @Test func sessionIdIsNilForURIsWithoutASession() {
        #expect(HLSStreamSession.sessionId(fromURI: nil, assetId: assetId) == nil)
        #expect(HLSStreamSession.sessionId(
            fromURI: "http://immich.local:2283/api/assets/\(assetId)/video/stream/main.m3u8",
            assetId: assetId
        ) == nil)
        #expect(HLSStreamSession.sessionId(
            fromURI: "http://immich.local:2283/api/assets/\(assetId)/video/playback",
            assetId: assetId
        ) == nil)
        #expect(HLSStreamSession.sessionId(
            fromURI: "http://immich.local:2283/api/assets/another-asset/video/stream/\(sessionId)/0/playlist.m3u8",
            assetId: assetId
        ) == nil)
    }

    @Test func failedHLSFallsBackToVideoFileAtCurrentPosition() {
        #expect(VideoPlaybackRecovery.afterFailure(of: .hls, playbackPosition: 42.5) == .fallBackToProgressive(resumeTime: 42.5))
        #expect(VideoPlaybackRecovery.afterFailure(of: .hls, playbackPosition: nil) == .fallBackToProgressive(resumeTime: 0))
        #expect(VideoPlaybackRecovery.afterFailure(of: .hls, playbackPosition: Double.nan) == .fallBackToProgressive(resumeTime: 0))
        #expect(VideoPlaybackRecovery.afterFailure(of: .hls, playbackPosition: -1) == .fallBackToProgressive(resumeTime: 0))
    }

    @Test func failedVideoFileIsNotRetried() {
        #expect(VideoPlaybackRecovery.afterFailure(of: .progressive, playbackPosition: 10) == .fail)
    }
}
