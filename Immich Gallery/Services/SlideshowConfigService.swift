//
//  SlideshowConfigService.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-01-12.
//

import Foundation

struct SlideshowConfig: Equatable {
    let albumIds: [String]
    let personIds: [String]

    static let empty = SlideshowConfig(albumIds: [], personIds: [])
}

enum SlideshowConfigLoadResult: Equatable {
    case configured(SlideshowConfig)
    case configAlbumNotFound
    case missingDescription
    case invalidDescription
    case invalidIdentifier
    case emptyConfiguration
    case requestFailed

    var config: SlideshowConfig {
        if case .configured(let config) = self {
            return config
        }
        return .empty
    }

    var blocksAutoSlideshow: Bool {
        switch self {
        case .missingDescription, .invalidDescription, .invalidIdentifier, .emptyConfiguration, .requestFailed:
            return true
        case .configured, .configAlbumNotFound:
            return false
        }
    }

    var validationMessage: String {
        switch self {
        case .configured(let config):
            return "Configuration valid: \(config.albumIds.count) album(s), \(config.personIds.count) person/people."
        case .configAlbumNotFound:
            return "No \(AppConstants.configAlbumName) album was found. Auto slideshow will use the full library."
        case .missingDescription, .invalidDescription, .invalidIdentifier, .emptyConfiguration, .requestFailed:
            return userFacingMessage ?? "Could not validate the slideshow configuration."
        }
    }

    var userFacingMessage: String? {
        switch self {
        case .missingDescription:
            return "The immich-gallery-config album needs a description."
        case .invalidDescription:
            return "The slideshow configuration description is invalid."
        case .invalidIdentifier:
            return "Album and person IDs must be valid UUIDs."
        case .emptyConfiguration:
            return "The slideshow configuration has no album or person IDs."
        case .requestFailed:
            return "Could not load the slideshow configuration."
        case .configured, .configAlbumNotFound:
            return nil
        }
    }
}

class SlideshowConfigService {
    private let albumService: AlbumService

    init(albumService: AlbumService) {
        self.albumService = albumService
    }

    /// Fetches the slideshow configuration from the special config album.
    /// Failures are returned explicitly so auto slideshow can show an actionable error.
    func fetchSlideshowConfig() async -> SlideshowConfigLoadResult {
        do {
            let albums = try await albumService.fetchAlbums()
            guard let configAlbum = albums.first(where: { $0.albumName == AppConstants.configAlbumName }) else {
                return .configAlbumNotFound
            }

            let fullAlbum = try await albumService.getAlbumInfo(albumId: configAlbum.id, withoutAssets: true)
            guard let description = fullAlbum.description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .missingDescription
            }

            guard let config = Self.parseConfigDescription(description) else {
                return .invalidDescription
            }
            guard !config.albumIds.isEmpty || !config.personIds.isEmpty else {
                return .emptyConfiguration
            }
            guard Self.hasValidImmichIdentifiers(config) else {
                return .invalidIdentifier
            }
            return .configured(config)
        } catch {
            return .requestFailed
        }
    }

    /// Accepts the documented `albumIds:[...] | personIds:[...]` format, while
    /// tolerating case differences, whitespace around the colon, and newlines.
    static func parseConfigDescription(_ description: String) -> SlideshowConfig? {
        let pattern = #"(?i)\b(albumIds|personIds)\s*:\s*(\[[^\]]*\])"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(description.startIndex..., in: description)
        let matches = expression.matches(in: description, range: range)
        guard !matches.isEmpty else { return nil }

        var albumIds: [String] = []
        var personIds: [String] = []
        for match in matches {
            guard
                let keyRange = Range(match.range(at: 1), in: description),
                let arrayRange = Range(match.range(at: 2), in: description),
                let identifiers = parseIdentifierArray(String(description[arrayRange]))
            else {
                return nil
            }

            switch description[keyRange].lowercased() {
            case "albumids":
                albumIds.append(contentsOf: identifiers)
            case "personids":
                personIds.append(contentsOf: identifiers)
            default:
                break
            }
        }

        return SlideshowConfig(albumIds: albumIds, personIds: personIds)
    }

    /// Immich validates asset search IDs as version-4 UUIDs. Mirror that
    /// validation locally so a typo becomes a configuration error, not HTTP 400.
    static func hasValidImmichIdentifiers(_ config: SlideshowConfig) -> Bool {
        let pattern = #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"#
        return (config.albumIds + config.personIds).allSatisfy {
            $0.range(of: pattern, options: .regularExpression) != nil
        }
    }

    /// Prefer a real JSON array, but retain support for the single-quoted IDs
    /// accepted by earlier app versions.
    private static func parseIdentifierArray(_ text: String) -> [String]? {
        if let data = text.data(using: .utf8),
           let identifiers = try? JSONSerialization.jsonObject(with: data) as? [String] {
            return identifiers.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }

        guard text.first == "[", text.last == "]" else { return nil }
        let content = String(text.dropFirst().dropLast())
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }

        let identifiers = content.split(separator: ",").compactMap { value -> String? in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            return trimmed.isEmpty ? nil : trimmed
        }
        return identifiers.isEmpty ? nil : identifiers
    }
}
