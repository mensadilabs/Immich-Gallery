//
//  ArtModeOverlay.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-01-02.
//

import SwiftUI

/// Simple overlay view that creates a dimming effect similar to Samsung Frame TV Art Mode
struct ArtModeOverlay: View {
    let level: ArtModeLevel
    
    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(overlayOpacity))
            .allowsHitTesting(false) // Allow touches to pass through
            .ignoresSafeArea()
    }
    
    private var overlayOpacity: Double {
        switch level {
        case .off:
            return 0.0
        case .low:
            return 0.15 // 15% darkening
        case .high:
            return 0.35 // 35% darkening
        case .automatic:
            return automaticOpacity
        }
    }
    
    /// Calculates opacity based on current time and user-defined day/night hours
    private var automaticOpacity: Double {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        
        let dayStart = UserDefaults.standard.artModeDayStart
        let nightStart = UserDefaults.standard.artModeNightStart
        
        // Determine if it's day or night based on time ranges
        let isDayTime: Bool
        
        if dayStart < nightStart {
            // Normal case: day 7-20, night 20-7
            isDayTime = currentHour >= dayStart && currentHour < nightStart
        } else {
            // Edge case: crosses midnight (e.g., day 22-6, night 6-22)
            isDayTime = currentHour >= dayStart || currentHour < nightStart
        }
        
        return isDayTime ? 0.15 : 0.35 // Low opacity for day, high for night
    }
}

/// Art Mode levels
enum ArtModeLevel: String, CaseIterable {
    case off = "off"
    case low = "low"
    case high = "high"
    case automatic = "automatic"
    
    var displayName: String {
        switch self {
        case .off: return "Off"
        case .low: return "Low (Always)"
        case .high: return "High (Always)"
        case .automatic: return "Automatic (Time-based)"
        }
    }
}

#Preview {
    ZStack {
        // Sample image background
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.blue, .purple, .pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        
        Text("Sample Image Content")
            .font(.largeTitle)
            .foregroundColor(.white)
        
        // Art Mode overlay
        ArtModeOverlay(level: .low)
    }
    .frame(width: 400, height: 300)
}