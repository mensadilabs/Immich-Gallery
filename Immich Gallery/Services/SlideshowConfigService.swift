//
//  SlideshowConfigService.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-01-12.
//

import Foundation

struct SlideshowConfig {
    let albumIds: [String]
    let personIds: [String]
    
    static let empty = SlideshowConfig(albumIds: [], personIds: [])
}

class SlideshowConfigService {
    private let albumService: AlbumService
    
    init(albumService: AlbumService) {
        self.albumService = albumService
    }
    
    /// Fetches the slideshow configuration from the special config album
    func fetchSlideshowConfig() async -> SlideshowConfig {
        do {
            // Get all albums and find the config album
            let albums = try await albumService.fetchAlbums()
            
            guard let configAlbum = albums.first(where: { $0.albumName == AppConstants.configAlbumName }) else {
                return .empty
            }
            
            // Get full album info with description
            let fullAlbum = try await albumService.getAlbumInfo(albumId: configAlbum.id, withoutAssets: true)
            
            guard let description = fullAlbum.description, !description.isEmpty else {
                return .empty
            }
            
            return parseConfigDescription(description)
            
        } catch {
            return .empty
        }
    }
    
    /// Parses the album description to extract albumIds and personIds
    /// Expected format: albumIds:["uuid1","uuid2"] | personIds:["uuid3","uuid4"]
    private func parseConfigDescription(_ description: String) -> SlideshowConfig {
        var albumIds: [String] = []
        var personIds: [String] = []
        
        // Split by pipe to get individual config parts
        let parts = description.components(separatedBy: "|")
        
        for part in parts {
            let trimmedPart = part.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedPart.hasPrefix("albumIds:") {
                albumIds = parseUUIDArray(from: trimmedPart, prefix: "albumIds:")
            } else if trimmedPart.hasPrefix("personIds:") {
                personIds = parseUUIDArray(from: trimmedPart, prefix: "personIds:")
            }
        }
        
        return SlideshowConfig(albumIds: albumIds, personIds: personIds)
    }
    
    /// Parses a UUID array from a string like 'albumIds:["uuid1","uuid2"]'
    private func parseUUIDArray(from text: String, prefix: String) -> [String] {
        // Remove the prefix (e.g., "albumIds:")
        let withoutPrefix = String(text.dropFirst(prefix.count))
        
        // Find the JSON array part between [ and ]
        guard let startIndex = withoutPrefix.firstIndex(of: "["),
              let endIndex = withoutPrefix.lastIndex(of: "]") else {
            return []
        }
        
        let arrayContent = String(withoutPrefix[withoutPrefix.index(after: startIndex)..<endIndex])
        
        // Split by commas and clean up each UUID
        let uuids = arrayContent.components(separatedBy: ",").compactMap { uuid in
            let cleaned = uuid.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "'", with: "")
            
            return cleaned.isEmpty ? nil : cleaned
        }
        
        return uuids
    }
}
