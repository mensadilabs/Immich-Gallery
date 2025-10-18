//
//  AdaptiveBackgroundView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-09-02.
//

import SwiftUI
import UIKit

/// A background view that can adapt to image colors or use predefined colors
struct AdaptiveBackgroundView: View {
    @State private var dominantColor: Color
    @State private var colorExtractionTask: Task<Void, Never>?
    
    let colorMode: BackgroundColorMode
    let image: UIImage?
    let animationDuration: Double
    
    /// Initializes the adaptive background view
    /// - Parameters:
    ///   - colorMode: The background color mode (auto, or specific color)
    ///   - image: Optional image to extract color from when in auto mode
    ///   - defaultColor: Default color to use as fallback
    ///   - animationDuration: Duration for color transition animation (default: 0.6)
    init(colorMode: BackgroundColorMode, image: UIImage? = nil, defaultColor: Color = .white, animationDuration: Double = 0.6) {
        self.colorMode = colorMode
        self.image = image
        self.animationDuration = animationDuration
        self._dominantColor = State(initialValue: colorMode.color ?? defaultColor)
    }
    
    var body: some View {
        dominantColor
            .ignoresSafeArea()
            .animation(.easeInOut(duration: animationDuration), value: dominantColor)
            .onAppear {
                updateBackgroundColor()
            }
            .onChange(of: image) { _, _ in
                updateBackgroundColor()
            }
            .onChange(of: colorMode) { _, _ in
                updateBackgroundColor()
            }
            .onDisappear {
                colorExtractionTask?.cancel()
            }
    }
    
    private func updateBackgroundColor() {
        // Cancel any ongoing color extraction
        colorExtractionTask?.cancel()
        
        if case .auto = colorMode, let image = image {
            // Extract dominant color from image
            colorExtractionTask = Task {
                let extractedColor = await ImageColorExtractor.extractDominantColorAsync(from: image)
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    dominantColor = extractedColor
                }
            }
        } else {
            // Use predefined color
            dominantColor = colorMode.color ?? .black
        }
    }
    
    /// Async function to extract and set background color, returns when complete
    func loadBackgroundColor() async {
        if case .auto = colorMode, let image = image {
            let extractedColor = await ImageColorExtractor.extractDominantColorAsync(from: image)
            await MainActor.run {
                dominantColor = extractedColor
            }
            
            // Wait for animation to complete
            try? await Task.sleep(nanoseconds: UInt64(animationDuration * 1_000_000_000))
        } else {
            await MainActor.run {
                dominantColor = colorMode.color ?? .black
            }
            // Wait for animation to complete
            try? await Task.sleep(nanoseconds: UInt64(animationDuration * 1_000_000_000))
        }
    }
}

/// Enumeration of background color modes
enum BackgroundColorMode: Equatable {
    case auto
    case black
    case white
    case gray
    case blue
    case purple
    
    var color: Color? {
        switch self {
        case .auto:
            return nil // Will be extracted from image
        case .black:
            return .black
        case .white:
            return .white
        case .gray:
            return .gray
        case .blue:
            return .blue
        case .purple:
            return .purple
        }
    }
    
    /// Creates a BackgroundColorMode from a string value
    /// - Parameter colorString: The string representation of the color
    /// - Returns: The corresponding BackgroundColorMode
    static func from(string colorString: String) -> BackgroundColorMode {
        switch colorString {
        case "auto":
            return .auto
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
}

#Preview {
    VStack {
        AdaptiveBackgroundView(colorMode: .blue)
            .frame(height: 100)
        
        AdaptiveBackgroundView(colorMode: .auto, defaultColor: .purple)
            .frame(height: 100)
    }
}