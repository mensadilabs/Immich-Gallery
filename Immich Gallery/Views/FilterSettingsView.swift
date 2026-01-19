//
//  FilterSettingsView.swift
//  Immich Gallery
//
//  Created by Harley Wakeman on 1/18/26.
//

import SwiftUI

struct FilterSettingsView: View {
    let allAssets: [ImmichAsset]
    @Binding var selectedYears: Set<Int>
    @Binding var selectedLocations: Set<String>
    @Binding var selectedDevices: Set<String>
    var onApply: () -> Void
    let assetProvider: AssetProvider

    // Local state so changes only apply on "Apply" click
    @State private var localYears: Set<Int>
    @State private var localLocations: Set<String>
    @State private var localDevices: Set<String>

    // State to hold data fetched from provider/assets
    @State private var availableYears: [Int] = []
    @State private var availableLocations: [String] = []
    @State private var availableDevices: [String] = []
    @State private var isLoading = true

    // MARK: - Focus
    enum FilterFocus: Hashable {
        case resetButton
        case applyButton
        case middleColumn
        case rightColumn
    }

    @FocusState private var focusedField: FilterFocus?

    init(
        allAssets: [ImmichAsset],
        assetProvider: AssetProvider,
        selectedYears: Binding<Set<Int>>,
        selectedLocations: Binding<Set<String>>,
        selectedDevices: Binding<Set<String>>,
        onApply: @escaping () -> Void
    ) {
        self.allAssets = allAssets
        self.assetProvider = assetProvider
        self._selectedYears = selectedYears
        self._selectedLocations = selectedLocations
        self._selectedDevices = selectedDevices
        self.onApply = onApply

        _localYears = State(initialValue: selectedYears.wrappedValue)
        _localLocations = State(initialValue: selectedLocations.wrappedValue)
        _localDevices = State(initialValue: selectedDevices.wrappedValue)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            if isLoading {
                ProgressView("Loading filters...")
                    .scaleEffect(2)
            } else {
                VStack(spacing: 0) {

                    // Header
                    VStack(spacing: 10) {
                        Text("Filter Photos")
                            .font(.system(size: 70, weight: .bold))
                            .foregroundColor(.white)

                        Text("Select options to narrow results")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 40)

                    // Filter Columns
                    HStack(alignment: .top, spacing: 40) {
                        FilterColumn(
                            title: "Years",
                            items: availableYears,
                            selection: $localYears,
                            position: .left
                        ) {
                            focusedField = .applyButton
                        }

                        FilterColumn(
                            title: "Locations",
                            items: availableLocations,
                            selection: $localLocations,
                            position: .middle
                        ) {
                            focusedField = .applyButton
                        }
                        // Anchor for Apply → Up
                        .focused($focusedField, equals: .middleColumn)

                        FilterColumn(
                            title: "Devices",
                            items: availableDevices,
                            selection: $localDevices,
                            position: .right
                        ) {
                            focusedField = .applyButton
                        }
                        // Anchor for Apply → Right
                        .focused($focusedField, equals: .rightColumn)
                    }
                    .padding(.horizontal, 60)

                    Spacer()

                    // Bottom Buttons
                    HStack(spacing: 40) {
                        Button("Reset All") {
                            localYears.removeAll()
                            localLocations.removeAll()
                            localDevices.removeAll()
                        }
                        .buttonStyle(.bordered)
                        .focused($focusedField, equals: .resetButton)

                        Button {
                            selectedYears = localYears
                            selectedLocations = localLocations
                            selectedDevices = localDevices
                            onApply()
                        } label: {
                            Label("Apply Filters", systemImage: "checkmark.circle.fill")
                                .padding(.horizontal, 40)
                        }
                        .buttonStyle(.borderedProminent)
                        .focused($focusedField, equals: .applyButton)
                        .onMoveCommand { direction in
                            switch direction {
                            case .left:
                                focusedField = .resetButton

                            case .up:
                                focusedField = .middleColumn

                            case .right:
                                focusedField = .rightColumn

                            case .down:
                                break // explicitly do nothing

                            default:
                                break
                            }
                        }
                    }
                    .padding(.bottom, 80)
                }
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Data Loading
    private func loadData() async {
        do {
            async let fetchedCities = assetProvider.fetchAllCities()
            async let fetchedYears = assetProvider.fetchAllYears()
            async let fetchedDevices = assetProvider.fetchAllDevices()

            let (cities, years, devices) = try await (fetchedCities, fetchedYears, fetchedDevices)

            await MainActor.run {
                availableYears = years
                availableLocations = cities
                availableDevices = devices
                isLoading = false
            }
        } catch {
            print("Error loading filter data: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Filter Column
struct FilterColumn<T: Hashable & CustomStringConvertible>: View {
    enum Position {
        case left
        case middle
        case right
    }

    let title: String
    let items: [T]
    @Binding var selection: Set<T>
    let position: Position
    let onExitToApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white.opacity(0.6))
                .padding(.leading, 20)

            ScrollView {
                VStack(spacing: 15) {
                    ForEach(items.indices, id: \.self) { index in
                        let item = items[index]

                        Button {
                            if selection.contains(item) {
                                selection.remove(item)
                            } else {
                                selection.insert(item)
                            }
                        } label: {
                            HStack {
                                Text(item.description)
                                    .font(.title3)

                                Spacer()

                                if selection.contains(item) {
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
                        .onMoveCommand { direction in
                            switch direction {
                            case .down where index == items.count - 1:
                                onExitToApply()

                            case .left where position == .left:
                                onExitToApply()

                            case .right where position == .right:
                                onExitToApply()

                            default:
                                break
                            }
                        }
                    }
                }
                .padding(10)
            }
            .frame(width: 550)
        }
    }
}
