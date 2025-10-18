//
//  GridDisplayableExtensions.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-09-04.
//

import SwiftUI

// MARK: - ImmichAlbum + GridDisplayable
extension ImmichAlbum: GridDisplayable {
    var primaryTitle: String { albumName }
    var secondaryTitle: String? { nil }
    var thumbnailId: String? { albumThumbnailAssetId }
    var itemCount: Int? { assetCount }
    var gridCreatedAt: String? { createdAt }
    var isFavorite: Bool? { nil }
    var isShared: Bool? { shared }
    var sharingText: String? { 
        if shared {
            return owner.name
        }
        return nil
    }
    var iconName: String { "folder" }
    var gridColor: Color? { nil }
}

// MARK: - Person + GridDisplayable
extension Person: GridDisplayable {
    var primaryTitle: String { name.isEmpty ? "Unknown Person" : name }
    var secondaryTitle: String? { nil }
    var description: String? { nil }
    var thumbnailId: String? { id }
    var itemCount: Int? { nil }
    var gridCreatedAt: String? { updatedAt }
    var isShared: Bool? { nil }
    var sharingText: String? { nil }
    var iconName: String { "person.crop.circle" }
    var gridColor: Color? { 
        if let colorString = color, !colorString.isEmpty {
            switch colorString.lowercased() {
            case "red", "#ff0000", "#f00":
                return .red
            case "blue", "#0000ff", "#00f":
                return .blue
            case "green", "#00ff00", "#0f0":
                return .green
            case "yellow", "#ffff00", "#ff0":
                return .yellow
            case "orange", "#ffa500":
                return .orange
            case "purple", "#800080":
                return .purple
            case "pink", "#ffc0cb":
                return .pink
            default:
                return .blue
            }
        }
        return nil
    }
}

// MARK: - Tag + GridDisplayable
extension Tag: GridDisplayable {
    var primaryTitle: String { name }
    var secondaryTitle: String? { 
        if !value.isEmpty && value != name {
            return value
        }
        return "Tag"
    }
    var description: String? { nil }
    var thumbnailId: String? { nil }
    var itemCount: Int? { nil }
    var gridCreatedAt: String? { createdAt }
    var isFavorite: Bool? { nil }
    var isShared: Bool? { nil }
    var sharingText: String? { nil }
    var iconName: String { "tag.fill" }
    var gridColor: Color? { 
        if let colorString = color, !colorString.isEmpty {
            switch colorString.lowercased() {
            case "red", "#ff0000", "#f00":
                return .red
            case "blue", "#0000ff", "#00f":
                return .blue
            case "green", "#00ff00", "#0f0":
                return .green
            case "yellow", "#ffff00", "#ff0":
                return .yellow
            case "orange", "#ffa500":
                return .orange
            case "purple", "#800080":
                return .purple
            case "pink", "#ffc0cb":
                return .pink
            default:
                return .blue
            }
        }
        return .blue
    }
}