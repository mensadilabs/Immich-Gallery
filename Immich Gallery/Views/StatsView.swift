//
//  StatsView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-09-05.
//

import SwiftUI

struct StatsView: View {
    @ObservedObject var statsService: StatsService
    @State private var statsData: StatsData?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var lastUpdated: Date?
    
    var body: some View {
        NavigationView {
            ZStack {
                SharedGradientBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 30) {
                        // Header Section
                        headerSection
                        
                        // Stats Sections
                        if let stats = statsData {
                            assetStatsSection(stats.assetData)
                            exploreStatsSection(stats.exploreData)
                            peopleStatsSection(stats.peopleData)
                        }
                        
                        // Loading or Error State
                        if isLoading {
                            loadingSection
                        } else if error != nil {
                            errorSection
                        }
                    }
                    .padding()
                }
            }
            .onAppear {
                loadStatsIfNeeded()
            }
        }
        
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Library Statistics")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let lastUpdated = lastUpdated {
                        Text("Last updated: \(formatLastUpdated(lastUpdated))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    refreshStats()
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text("Refresh")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(CardButtonStyle())
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func assetStatsSection(_ assetData: AssetStatistics) -> some View {
        SettingsSection(title: "Library Content") {
            AnyView(VStack(spacing: 32) {
                HStack(spacing: 32) {
                    StatCard(
                        icon: "photo.stack.fill",
                        title: "Total Assets",
                        count: assetData.total,
                        color: .blue
                    )
                    
                    StatCard(
                        icon: "photo.fill",
                        title: "Images",
                        count: assetData.images,
                        color: .green
                    )
                    
                    StatCard(
                        icon: "video.fill",
                        title: "Videos",
                        count: assetData.videos,
                        color: .orange
                    )
                }
            })
        }
    }
    
    private func exploreStatsSection(_ exploreData: ExploreStatsData) -> some View {
        SettingsSection(title: "Places Visited") {
            AnyView(VStack(spacing: 32) {
                HStack(spacing: 32) {
                    StatCard(
                        icon: "globe",
                        title: "Countries",
                        count: exploreData.countries.count,
                        color: .green
                    )
                    
                    StatCard(
                        icon: "map",
                        title: "States",
                        count: exploreData.states.count,
                        color: .purple
                    )
                    
                    StatCard(
                        icon: "building.2",
                        title: "Cities",
                        count: exploreData.cities.count,
                        color: .orange
                    )
                }
            })
        }
    }
    
    private func peopleStatsSection(_ peopleData: PeopleStatsData) -> some View {
        SettingsSection(title: "People") {
            AnyView(VStack(spacing: 32) {
                VStack(spacing: 32) {
                    HStack(spacing: 32) {
                        StatCard(
                            icon: "person.3.fill",
                            title: "Total People",
                            count: peopleData.totalPeople,
                            color: .blue
                        )
                        StatCard(
                            icon: "person.fill.questionmark",
                            title: "Unnamed",
                            count: peopleData.unnamedPeople,
                            color: .gray
                        )
                        
                        StatCard(
                            icon: "person.fill.checkmark",
                            title: "Named",
                            count: peopleData.namedPeople,
                            color: .green
                        )
                        StatCard(
                            icon: "heart.fill",
                            title: "Favorites",
                            count: peopleData.favoritePeople,
                            color: .red
                        )
                        
                    }
                }
                
            })
        }
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading statistics...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: 100)
    }
    
    private var errorSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundColor(.red)
            
            Text("Failed to load statistics")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Please check your connection and try again")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                refreshStats()
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .foregroundColor(.red)
                    Text("Retry")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
            .buttonStyle(CardButtonStyle())
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func loadStatsIfNeeded() {
        guard statsData == nil && !isLoading else { return }
        
        // Check if we have cached data first
        if let cachedStats = StatsCache.shared.getCachedStats() {
            statsData = cachedStats
            lastUpdated = cachedStats.cachedAt
            return
        }
        
        // Load fresh data
        refreshStats()
    }
    
    private func refreshStats() {
        isLoading = true
        error = nil
        
        Task {
            do {
                let stats = try await statsService.getStats(forceRefresh: true)
                
                await MainActor.run {
                    self.statsData = stats
                    self.lastUpdated = stats.cachedAt
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    private func formatLastUpdated(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        Button(action: {
            // Do nothing
        }) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
                
                VStack(spacing: 4) {
                    Text("\(count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(CardButtonStyle())
    }
}

#Preview {
    let userManager = UserManager()
    let networkService = NetworkService(userManager: userManager)
    let exploreService = ExploreService(networkService: networkService)
    let peopleService = PeopleService(networkService: networkService)
    let statsService = StatsService(exploreService: exploreService, peopleService: peopleService, networkService: networkService)
    
    StatsView(statsService: statsService)
}
