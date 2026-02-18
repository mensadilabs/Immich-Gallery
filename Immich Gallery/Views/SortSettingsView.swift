//
//  SortSettingsView.swift
//  Immich Gallery
//

import SwiftUI

struct SortSettingsView: View {
    @Binding var sortOrder: String
    var onApply: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()

            VStack(spacing: 40) {
                Text("Sort Options")
                    .font(.system(size: 60, weight: .bold))

                VStack(alignment: .leading, spacing: 20) {
                    Text("Sort By")
                        .font(.headline)
                        .foregroundColor(.gray)

                    HStack {
                        Text("Date Taken")
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                    .frame(width: 500)

                    Text("Order")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.top, 20)

                    Button(action: { sortOrder = "desc" }) {
                        HStack {
                            Text("Newest First")
                            Spacer()
                            if sortOrder == "desc" { Image(systemName: "checkmark") }
                        }
                        .frame(width: 500)
                    }

                    Button(action: { sortOrder = "asc" }) {
                        HStack {
                            Text("Oldest First")
                            Spacer()
                            if sortOrder == "asc" { Image(systemName: "checkmark") }
                        }
                        .frame(width: 500)
                    }
                }

                Button("Apply") { onApply() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 40)
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
    }
}
