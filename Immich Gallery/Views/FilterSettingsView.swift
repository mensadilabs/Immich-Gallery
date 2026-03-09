//
//  FilterSettingsView.swift
//  Immich Gallery
//

import SwiftUI

struct FilterSettingsView: View {
    let assetProvider: AssetProvider
    @Binding var selectedCities: Set<String>
    @Binding var selectedYears: Set<Int>
    var onApply: () -> Void

    @State private var localCities: Set<String>
    @State private var localYears: Set<Int>
    @State private var availableCities: [String] = []
    @State private var availableYears: [Int] = []
    @State private var isLoading = true
    @State private var showCapWarning = false

    init(
        assetProvider: AssetProvider,
        selectedCities: Binding<Set<String>>,
        selectedYears: Binding<Set<Int>>,
        onApply: @escaping () -> Void
    ) {
        self.assetProvider = assetProvider
        self._selectedCities = selectedCities
        self._selectedYears = selectedYears
        self.onApply = onApply
        _localCities = State(initialValue: selectedCities.wrappedValue)
        _localYears = State(initialValue: selectedYears.wrappedValue)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header row: title left, combo counter center, action buttons right
                HStack {
                    Text("Filter Photos")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Text(comboCountText)
                        .font(.callout)
                        .foregroundColor(comboCountColor)

                    Spacer()

                    HStack(spacing: 20) {
                        Button("Reset") {
                            localYears = []
                            localCities = []
                            selectedYears = []
                            selectedCities = []
                            onApply()
                        }
                        .buttonStyle(.bordered)

                        Button("Apply") {
                            selectedYears = localYears
                            selectedCities = localCities
                            onApply()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.top, 40)
                .padding(.bottom, 15)

                if showCapWarning {
                    Text("Each city is combined with each year range. Consecutive years (e.g. 2022-2024) count as one range.")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                        .padding(.horizontal, 120)
                        .padding(.bottom, 10)
                }

                if isLoading {
                    Spacer()
                    ProgressView("Loading filters...")
                        .scaleEffect(1.5)
                    Spacer()
                } else {
                    HStack(alignment: .top, spacing: 30) {
                        filterColumn(
                            title: "Years\(localYears.isEmpty ? "" : " (\(localYears.count))")",
                            items: availableYears.map { String($0) },
                            selectedValues: Set(localYears.map(String.init))
                        ) { item in
                            if let year = Int(item) {
                                if localYears.contains(year) {
                                    localYears.remove(year)
                                    showCapWarning = false
                                } else {
                                    var candidate = localYears
                                    candidate.insert(year)
                                    if filterComboCount(cities: localCities, years: candidate) <= maxFilterCombinations {
                                        localYears = candidate
                                        showCapWarning = false
                                    } else {
                                        withAnimation { showCapWarning = true }
                                    }
                                }
                            }
                        } onClear: {
                            localYears = []
                            showCapWarning = false
                        }

                        filterColumn(
                            title: "Cities\(localCities.isEmpty ? "" : " (\(localCities.count))")",
                            items: availableCities,
                            selectedValues: localCities
                        ) { item in
                            if localCities.contains(item) {
                                localCities.remove(item)
                                showCapWarning = false
                            } else {
                                var candidate = localCities
                                candidate.insert(item)
                                if filterComboCount(cities: candidate, years: localYears) <= maxFilterCombinations {
                                    localCities = candidate
                                    showCapWarning = false
                                } else {
                                    withAnimation { showCapWarning = true }
                                }
                            }
                        } onClear: {
                            localCities = []
                            showCapWarning = false
                        }
                    }
                    .padding(.horizontal, 60)
                }

                Spacer()
            }
        }
        .task {
            await loadData()
        }
    }

    private var currentComboCount: Int {
        filterComboCount(cities: localCities, years: localYears)
    }

    private var comboCountText: String {
        if localCities.isEmpty && localYears.isEmpty {
            return "0/\(maxFilterCombinations)"
        }
        return "\(currentComboCount)/\(maxFilterCombinations)"
    }

    private var comboCountColor: Color {
        if localCities.isEmpty && localYears.isEmpty {
            return .gray
        }
        if currentComboCount >= maxFilterCombinations {
            return .orange
        }
        return .green
    }

    private func filterColumn(
        title: String,
        items: [String],
        selectedValues: Set<String>,
        onToggle: @escaping (String) -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white.opacity(0.6))
                .padding(.leading, 15)

            ScrollView {
                VStack(spacing: 10) {
                    filterButton(label: "All", isSelected: selectedValues.isEmpty) {
                        onClear()
                    }

                    ForEach(items, id: \.self) { item in
                        filterButton(label: item, isSelected: selectedValues.contains(item)) {
                            onToggle(item)
                        }
                    }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func filterButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.body)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .fontWeight(.bold)
                }
            }
            .padding(.horizontal, 25)
            .frame(maxWidth: .infinity)
            .frame(height: 70)
        }
        .buttonStyle(.card)
    }

    private func loadData() async {
        do {
            async let fetchedCities = assetProvider.fetchAllCities()
            async let fetchedYears = assetProvider.fetchAllYears()

            let (cities, years) = try await (fetchedCities, fetchedYears)

            await MainActor.run {
                availableCities = cities
                availableYears = years
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
}
