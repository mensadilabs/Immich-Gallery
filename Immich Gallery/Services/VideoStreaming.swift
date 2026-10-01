//
//  VideoStreaming.swift
//  Immich Gallery
//

import Foundation

/// Server capabilities from `GET /api/server/features` that affect video playback.
struct ServerFeatures: Codable, Equatable {
    /// Whether real-time HLS transcoding is enabled (Immich v3+). Missing on older servers.
    let realtimeTranscoding: Bool?

    var supportsRealtimeTranscoding: Bool {
        realtimeTranscoding == true
    }
}

/// The endpoint a video is played from.
enum VideoPlaybackSource: Equatable {
    /// Immich real-time HLS transcoding. The bitrate adapts to the network, so high-bitrate
    /// originals don't have to be streamed byte-for-byte.
    case hls
    /// The stored video file (`/video/playback`): the encoded version if one exists, otherwise the original.
    case progressive

    static func preferred(serverSupportsHLS: Bool, userAllowsTranscodedStreaming: Bool) -> VideoPlaybackSource {
        serverSupportsHLS && userAllowsTranscodedStreaming ? .hls : .progressive
    }
}

/// What to do after the current player item fails.
enum VideoPlaybackRecovery: Equatable {
    case fallBackToProgressive(resumeTime: Double)
    case fail

    static func afterFailure(of source: VideoPlaybackSource, playbackPosition: Double?) -> VideoPlaybackRecovery {
        switch source {
        case .hls:
            guard let position = playbackPosition, position.isFinite, position > 0 else {
                return .fallBackToProgressive(resumeTime: 0)
            }
            return .fallBackToProgressive(resumeTime: position)
        case .progressive:
            return .fail
        }
    }
}

/// Immich's HLS streaming contract (`/api/assets/{id}/video/stream/...`, server v3+).
enum HLSStreamSession {
    static func mainPlaylistEndpoint(assetId: String) -> String {
        "/api/assets/\(assetId)/video/stream/main.m3u8"
    }

    static func sessionEndpoint(assetId: String, sessionId: String) -> String {
        "/api/assets/\(assetId)/video/stream/\(sessionId)"
    }

    /// The server creates a session for every main playlist request and embeds its ID in the variant
    /// playlist and segment paths: `.../assets/{assetId}/video/stream/{sessionId}/{variant}/...`.
    static func sessionId(fromURI uri: String?, assetId: String) -> String? {
        guard let uri, let path = URLComponents(string: uri)?.path else { return nil }
        let parts = path.split(separator: "/").map(String.init)
        guard let streamIndex = parts.indices.first(where: { index in
            index >= 2 && index + 1 < parts.count
                && parts[index] == "stream" && parts[index - 1] == "video" && parts[index - 2] == assetId
        }) else { return nil }
        let candidate = parts[streamIndex + 1]
        return UUID(uuidString: candidate) == nil ? nil : candidate
    }
}
