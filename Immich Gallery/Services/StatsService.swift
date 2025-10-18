//
//  StatsService.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-09-05.
//

import Foundation

class StatsService: ObservableObject {
    private let exploreService: ExploreService
    private let peopleService: PeopleService
    private let networkService: NetworkService
    private let statsCache = StatsCache.shared
    
    init(exploreService: ExploreService, peopleService: PeopleService, networkService: NetworkService) {
        self.exploreService = exploreService
        self.peopleService = peopleService
        self.networkService = networkService
    }
    
    func getStats(forceRefresh: Bool = false) async throws -> StatsData {
        // Check cache first unless force refresh
        if !forceRefresh, let cachedStats = statsCache.getCachedStats() {
            return cachedStats
        }
        
        // Fetch fresh data
        let exploreData = try await fetchExploreStats()
        let peopleData = try await fetchPeopleStats()
        let assetData = try await fetchAssetStats()
        
        let stats = StatsData(
            exploreData: exploreData,
            peopleData: peopleData,
            assetData: assetData,
            cachedAt: Date()
        )
        
        // Cache the results
        statsCache.cacheStats(stats)
        
        return stats
    }
    
    private func fetchExploreStats() async throws -> ExploreStatsData {
        let assets = try await exploreService.fetchExploreData()
        
        var countries = Set<String>()
        var cities = Set<String>()
        var states = Set<String>()
        
        for asset in assets {
            if let exifInfo = asset.exifInfo {
                if let country = exifInfo.country, !country.isEmpty {
                    countries.insert(country)
                }
                if let city = exifInfo.city, !city.isEmpty {
                    cities.insert(city)
                }
                if let state = exifInfo.state, !state.isEmpty {
                    states.insert(state)
                }
            }
        }
        
        return ExploreStatsData(
            countries: countries,
            cities: cities,
            states: states
        )
    }
    
    private func fetchPeopleStats() async throws -> PeopleStatsData {
        var allPeople: [Person] = []
        var page = 1
        let pageSize = 100
        
        // Fetch all people with pagination
        while true {
            let people = try await peopleService.getAllPeople(page: page, size: pageSize, withHidden: true)
            
            if people.isEmpty {
                break
            }
            
            allPeople.append(contentsOf: people)
            
            // If we got less than the page size, we've reached the end
            if people.count < pageSize {
                break
            }
            
            page += 1
        }
        
        let totalPeople = allPeople.count
        let namedPeople = allPeople.filter { !$0.name.isEmpty && $0.name.lowercased() != "person" }.count
        let unnamedPeople = totalPeople - namedPeople
        let favoritePeople = allPeople.filter { $0.isFavorite == true }.count
        
        return PeopleStatsData(
            totalPeople: totalPeople,
            namedPeople: namedPeople,
            unnamedPeople: unnamedPeople,
            favoritePeople: favoritePeople
        )
    }
    
    private func fetchAssetStats() async throws -> AssetStatistics {
        let statistics: AssetStatistics = try await networkService.makeRequest(
            endpoint: "/api/assets/statistics",
            method: .GET,
            responseType: AssetStatistics.self
        )
        
        return statistics
    }
}