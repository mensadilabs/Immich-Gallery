//
//  SortSettingsView.swift
//  Immich Gallery
//
//  Created by Harley Wakeman on 1/18/26.
//

import SwiftUI

struct SortSettingsView: View {
    @Binding var sortField: String
    @Binding var sortOrder: String
    var onApply: () -> Void

    let fields = [
        ("Date Taken", "localDateTime"),
        ("File Name", "originalFileName")
    ]

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            
            VStack(spacing: 40) {
                Text("Sort Options").font(.system(size: 60, weight: .bold))

                HStack(spacing: 60) {
                    // Field Selection
                    VStack(alignment: .leading) {
                        Text("Sort By").font(.headline).foregroundColor(.gray)
                        ForEach(fields, id: \.1) { label, value in
                            Button(action: { sortField = value }) {
                                HStack {
                                    Text(label)
                                    Spacer()
                                    if sortField == value { Image(systemName: "checkmark") }
                                }
                                .frame(width: 400)
                            }
                        }
                    }

                    // Order Selection
                    VStack(alignment: .leading) {
                        Text("Order").font(.headline).foregroundColor(.gray)
                        Button(action: { sortOrder = "desc" }) {
                            HStack {
                                Text("Descending")
                                Spacer()
                                if sortOrder == "desc" { Image(systemName: "checkmark") }
                            }
                            .frame(width: 400)
                        }
                        Button(action: { sortOrder = "asc" }) {
                            HStack {
                                Text("Ascending")
                                Spacer()
                                if sortOrder == "asc" { Image(systemName: "checkmark") }
                            }
                            .frame(width: 400)
                        }
                    }
                }

                Button("Apply") { onApply() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 40)
            }
        }
    }
}
