//
//  SharedGradientBackground.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-06-29.
//

import SwiftUI

// Shared background gradient for consistent styling across the app
struct SharedGradientBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 44/255, green: 83/255, blue: 100/255),
                Color(red: 44/255, green: 83/255, blue: 100/255),
                Color(red: 44/255, green: 83/255, blue: 100/255)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// Shared utility function for background colors
func getBackgroundColor(_ colorString: String) -> Color {
    switch colorString {
    case "auto":
        return .black // Fallback for non-slideshow contexts
    case "black":
        return .black
    case "white":
        return .white
    case "gray":
        return .gray
    case "blue":
        return .blue
    case "purple":
        return .purple
    default:
        return .black
    }
}

// Custom button style to remove default tvOS focus ring
struct CustomFocusButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Custom focusable button style for color selection
struct ColorSelectionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SharedOpaqueBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 44/255, green: 83/255, blue: 100/255),
                Color(red: 44/255, green: 83/255, blue: 100/255),
                Color(red: 44/255, green: 83/255, blue: 100/255)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    SharedGradientBackground()
}
