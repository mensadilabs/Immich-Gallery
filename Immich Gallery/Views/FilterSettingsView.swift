//
//  FilterSettingsView.swift
//  Immich Gallery
//

import SwiftUI

struct FilterSettingsView: View {
    let assetProvider: AssetProvider
    @Binding var selectedCity: String?
    @Binding var selectedYear: Int?
    var onApply: () -> Void

    @State private var localCity: String?
    @State private var localYear: Int?
    @State private var availableCities: [String] = []
    @State private var availableYears: [Int] = []
    @State private var isLoading = true

    init(
        assetProvider: AssetProvider,
        selectedCity: Binding<String?>,
        selectedYear: Binding<Int?>,
        onApply: @escaping () -> Void
    ) {
        self.assetProvider = assetProvider
        self._selectedCity = selectedCity
        self._selectedYear = selectedYear
        self.onApply = onApply
        _localCity = State(initialValue: selectedCity.wrappedValue)
        _localYear = State(initialValue: selectedYear.wrappedValue)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Text("Filter Photos")
                        .font(.system(size: 70, weight: .bold))
                        .foregroundColor(.white)

                    Text("Select options to narrow results")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
                .padding(.top, 60)
                .padding(.bottom, 30)

                HStack(spacing: 40) {
                    Button("Reset All") {
                        localYear = nil
                        localCity = nil
                        selectedYear = nil
                        selectedCity = nil
                        onApply()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        selectedYear = localYear
                        selectedCity = localCity
                        onApply()
                    } label: {
                        Label("Apply Filters", systemImage: "checkmark.circle.fill")
                            .padding(.horizontal, 40)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.bottom, 20)

                if isLoading {
                    ProgressView("Loading filters...")
                        .scaleEffect(1.5)
                        .padding(.top, 20)
                } else {
                    HStack(alignment: .top, spacing: 40) {
                        filterColumn(
                            title: "Years",
                            items: availableYears.map { String($0) },
                            selectedValue: localYear.map(String.init)
                        ) { selection in
                            localYear = selection.flatMap(Int.init)
                        }

                        filterColumn(
                            title: "Cities",
                            items: availableCities,
                            selectedValue: localCity
                        ) { selection in
                            localCity = selection
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

    private func filterColumn(
        title: String,
        items: [String],
        selectedValue: String?,
        onSelect: @escaping (String?) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white.opacity(0.6))
                .padding(.leading, 20)

            ScrollView {
                VStack(spacing: 15) {
                    filterButton(label: "All", isSelected: selectedValue == nil) {
                        onSelect(nil)
                    }

                    ForEach(items, id: \.self) { item in
                        filterButton(label: item, isSelected: selectedValue == item) {
                            onSelect(item)
                        }
                    }
                }
                .padding(10)
            }
            .frame(width: 550)
        }
    }

    private func filterButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.title3)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .fontWeight(.bold)
                }
            }
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
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
