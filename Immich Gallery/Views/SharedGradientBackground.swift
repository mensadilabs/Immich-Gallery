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
                Color.blue.opacity(0.3),
                Color.purple.opacity(0.2),
                Color.gray.opacity(0.4)
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
    @FocusState private var isFocused: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .scaleEffect(isFocused ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isFocused ? Color.blue.opacity(0.2) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 2)
                    )
                    .scaleEffect(isFocused ? 1.5 : 1.0)
            )
            .shadow(color: isFocused ? .blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            .focused($isFocused)
    }
}

struct SharedOpaqueBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.1, green: 0.1, blue: 0.2),
                Color(red: 0.15, green: 0.1, blue: 0.25),
                Color(red: 0.2, green: 0.15, blue: 0.3)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    SharedOpaqueBackground()
} 
