//
//  StatsCache.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-09-05.
//

import Foundation

// MARK: - Stats Data Models
struct StatsData {
    let exploreData: ExploreStatsData
    let peopleData: PeopleStatsData
    let assetData: AssetStatistics
    let cachedAt: Date
}

struct ExploreStatsData {
    let countries: Set<String>
    let cities: Set<String>
    let states: Set<String>
}

struct PeopleStatsData {
    let totalPeople: Int
    let namedPeople: Int
    let unnamedPeople: Int
    let favoritePeople: Int
}

// MARK: - Stats Cache Service
class StatsCache: ObservableObject {
    static let shared = StatsCache()
    
    private let cacheExpiryHours: Double = 24
    private var cachedData: StatsData?
    private let cacheURL: URL
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheURL = documentsPath.appendingPathComponent("stats_cache.json")
    }
    
    func getCachedStats() -> StatsData? {
        if let cached = cachedData {
            if !isExpired(cached.cachedAt) {
                return cached
            }
        }
        
        // Try loading from disk
        return loadFromDisk()
    }
    
    func cacheStats(_ stats: StatsData) {
        cachedData = stats
        saveToDisk(stats)
    }
    
    func clearCache() {
        cachedData = nil
        try? FileManager.default.removeItem(at: cacheURL)
    }
    
    private func isExpired(_ date: Date) -> Bool {
        let expiryDate = date.addingTimeInterval(cacheExpiryHours * 3600)
        return Date() > expiryDate
    }
    
    private func loadFromDisk() -> StatsData? {
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode(CodableStatsData.self, from: data) else {
            return nil
        }
        
        let statsData = StatsData(
            exploreData: ExploreStatsData(
                countries: Set(decoded.exploreData.countries),
                cities: Set(decoded.exploreData.cities),
                states: Set(decoded.exploreData.states)
            ),
            peopleData: PeopleStatsData(
                totalPeople: decoded.peopleData.totalPeople,
                namedPeople: decoded.peopleData.namedPeople,
                unnamedPeople: decoded.peopleData.unnamedPeople,
                favoritePeople: decoded.peopleData.favoritePeople
            ),
            assetData: decoded.assetData,
            cachedAt: decoded.cachedAt
        )
        
        if !isExpired(statsData.cachedAt) {
            cachedData = statsData
            return statsData
        }
        
        // Cache is expired, remove it
        try? FileManager.default.removeItem(at: cacheURL)
        return nil
    }
    
    private func saveToDisk(_ stats: StatsData) {
        let codableData = CodableStatsData(
            exploreData: CodableExploreStatsData(
                countries: Array(stats.exploreData.countries),
                cities: Array(stats.exploreData.cities),
                states: Array(stats.exploreData.states)
            ),
            peopleData: CodablePeopleStatsData(
                totalPeople: stats.peopleData.totalPeople,
                namedPeople: stats.peopleData.namedPeople,
                unnamedPeople: stats.peopleData.unnamedPeople,
                favoritePeople: stats.peopleData.favoritePeople
            ),
            assetData: stats.assetData,
            cachedAt: stats.cachedAt
        )
        
        if let encoded = try? JSONEncoder().encode(codableData) {
            try? encoded.write(to: cacheURL)
        }
    }
}

// MARK: - Codable Versions for Disk Storage
private struct CodableStatsData: Codable {
    let exploreData: CodableExploreStatsData
    let peopleData: CodablePeopleStatsData
    let assetData: AssetStatistics
    let cachedAt: Date
}

private struct CodableExploreStatsData: Codable {
    let countries: [String]
    let cities: [String]
    let states: [String]
}

private struct CodablePeopleStatsData: Codable {
    let totalPeople: Int
    let namedPeople: Int
    let unnamedPeople: Int
    let favoritePeople: Int
}