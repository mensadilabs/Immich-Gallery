//
//  SlideshowConfigSummaryService.swift
//  Immich Gallery
//
//  Resolves configured slideshow IDs into user-facing source names.
//

import Foundation

struct SlideshowConfigSummary: Equatable {
    let result: SlideshowConfigLoadResult
    let sourceNames: [String]

    var displayText: String {
        sourceNames.isEmpty ? result.validationMessage : sourceNames.joined(separator: "\n")
    }
}

final class SlideshowConfigSummaryService {
    private let networkService: NetworkService

    init(networkService: NetworkService) {
        self.networkService = networkService
    }

    func load() async -> SlideshowConfigSummary {
        let albumService = AlbumService(networkService: networkService)
        let result = await SlideshowConfigService(albumService: albumService).fetchSlideshowConfig()

        guard case let .configured(config) = result else {
            return SlideshowConfigSummary(result: result, sourceNames: [])
        }

        let peopleService = PeopleService(networkService: networkService)
        async let albumNames = resolveAlbumNames(config.albumIds, albumService: albumService)
        async let personNames = resolvePersonNames(config.personIds, peopleService: peopleService)

        let resolvedAlbums = await albumNames
        let resolvedPeople = await personNames
        return SlideshowConfigSummary(result: result, sourceNames: resolvedAlbums + resolvedPeople)
    }

    private func resolveAlbumNames(_ ids: [String], albumService: AlbumService) async -> [String] {
        await withTaskGroup(of: (Int, String).self, returning: [String].self) { group in
            for (index, id) in ids.enumerated() {
                group.addTask {
                    do {
                        let album = try await albumService.getAlbumInfo(albumId: id, withoutAssets: true)
                        return (index, "Album: \(album.albumName)")
                    } catch {
                        return (index, "Unknown album (\(id))")
                    }
                }
            }

            var names = Array(repeating: "", count: ids.count)
            for await (index, name) in group {
                names[index] = name
            }
            return names
        }
    }

    private func resolvePersonNames(_ ids: [String], peopleService: PeopleService) async -> [String] {
        await withTaskGroup(of: (Int, String).self, returning: [String].self) { group in
            for (index, id) in ids.enumerated() {
                group.addTask {
                    do {
                        let person = try await peopleService.getPersonInfo(personId: id)
                        return (index, "Person: \(person.name)")
                    } catch {
                        return (index, "Unknown person (\(id))")
                    }
                }
            }

            var names = Array(repeating: "", count: ids.count)
            for await (index, name) in group {
                names[index] = name
            }
            return names
        }
    }
}
