//
//  SlideShowSettings.swift
//  Immich Gallery
//
//  Created by mensadi labs on 2025-07-28.
//

import Foundation
import SwiftUI

// MARK: - Slideshow Settings Component

struct SlideshowSettings: View {
    @Binding var slideshowInterval: Double
    @Binding var slideshowBackgroundColor: String
    @Binding var use24HourClock: Bool
    @Binding var hideOverlay: Bool
    @Binding var enableReflections: Bool
    @Binding var enableKenBurns: Bool
    @Binding var enableShuffle: Bool
    @Binding var autoSlideshowTimeout: Int
    @FocusState.Binding var isMinusFocused: Bool
    @FocusState.Binding var isPlusFocused: Bool
    @FocusState.Binding var focusedColor: String?
    @State private var showPerformanceAlert = false
    
    
    var body: some View {
        VStack(spacing: 12) {
            // Slideshow Interval Setting
            SettingsRow(
                icon: "timer",
                title: "Slideshow Interval",
                subtitle: "Time between slides in slideshow mode",
                content: AnyView(
                    HStack(spacing: 40) {
                        Button(action: {
                            if slideshowInterval > 2 {
                                slideshowInterval -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(isMinusFocused ? .white : .blue)
                                .font(.title2)
                        }
                        .buttonStyle(CustomFocusButtonStyle())
                        .disabled(slideshowInterval <= 6)
                        .focused($isMinusFocused)
                        
                        Text("\(Int(slideshowInterval))s")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(minWidth: 50)
                        
                        Button(action: {
                            if slideshowInterval < 15 {
                                slideshowInterval += 1
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(isPlusFocused ? .white : .blue)
                                .font(.title2)
                        }
                        .buttonStyle(CustomFocusButtonStyle())
                        .disabled(slideshowInterval >= 15)
                        .focused($isPlusFocused)
                    }
                )
            )
            
            // Slideshow Background Color Setting
            SettingsRow(
                icon: "paintbrush",
                title: "Slideshow Background",
                subtitle: "Background color for slideshow mode",
                content: AnyView(
                    HStack {
                        // Color preview circle
                        Group {
                            if slideshowBackgroundColor == "auto" {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(
                                            colors: [.red, .orange, .yellow, .green, .blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                    Image(systemName: "paintpalette.fill")
                                        .foregroundColor(.white)
                                        .font(.caption)
                                }
                            } else {
                                Circle()
                                    .fill(getBackgroundColor(slideshowBackgroundColor))
                            }
                        }
                        .frame(width: 32, height: 32)
                        
                        Picker("Background Color", selection: $slideshowBackgroundColor) {
                            ForEach(["auto", "black", "white", "gray", "blue", "purple"], id: \.self) { color in
                                Text(color.capitalized).tag(color)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: slideshowBackgroundColor) { _, newValue in
                            if newValue == "auto" {
                                showPerformanceAlert = true
                            }
                        }
                    }
                )
            )
            
            // Clock Format Setting
             SettingsRow(
                 icon: "clock",
                 title: "Clock Format",
                 subtitle: "Time format for slideshow overlay.",
                 content: AnyView(
                     Picker("Clock Format", selection: $use24HourClock) {
                         Text("12 Hour").tag(false)
                         Text("24 Hour").tag(true)
                     }
                         .pickerStyle(.menu)
                         .frame(width: 300, alignment: .trailing)
                 )
             )
            
            SettingsRow(
                icon: "shuffle",
                title: "Shuffle Images (beta)",
                subtitle: "Randomly shuffle image order during slideshow (This uses `/search/random` endpoint. Does not work when viewing an album that is shared-in. To my knowledge, this is a limitation of Immich random endpoint. If you disagree, open a GH issue with details.) ",
                content: AnyView(
                    Picker("Shuffle Images", selection: $enableShuffle) {
                        Text("Off").tag(false)
                        Text("On").tag(true)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 300, alignment: .trailing)
                )
            )
            
            SettingsRow(
                icon: "eye.slash",
                title: "Hide Image Overlays",
                subtitle: "Hide clock, date, location overlay from slideshow and fullscreen view.",
                content: AnyView(
                    Picker("Hide Image Overlays", selection: $hideOverlay) {
                        Text("Off").tag(false)
                        Text("On").tag(true)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 300, alignment: .trailing)
                )
            )
            
             SettingsRow(
                 icon: "clock.arrow.circlepath",
                 title: "Auto-Start Slideshow",
                 subtitle: "Start slideshow after inactivity",
                 content: AnyView(AutoSlideshowTimeoutPicker(timeout: $autoSlideshowTimeout))
             )
            
             SettingsRow(
                 icon: "camera.macro.circle",
                 title: "Image Effects",
                 subtitle: "Choose visual effects for slideshow images",
                 content: AnyView(
                     Picker("Image Effects", selection: Binding(
                         get: {
                             if enableKenBurns {
                                 return "kenBurns"
                             } else if enableReflections {
                                 return "reflections"
                             } else {
                                 return "none"
                             }
                         },
                         set: { newValue in
                             switch newValue {
                             case "kenBurns":
                                 enableKenBurns = true
                                 enableReflections = false
                             case "reflections":
                                 enableKenBurns = false
                                 enableReflections = true
                             default: // "none"
                                 enableKenBurns = false
                                 enableReflections = false
                             }
                         }
                     )) {
                         Text("None").tag("none")
                         Text("Reflections").tag("reflections")
                         Text("Pan and Zoom").tag("kenBurns")
                     }
                     .pickerStyle(.menu)
                     .frame(width: 400, alignment: .trailing)
                 )
             )
        }
        .alert("Performance Warning", isPresented: $showPerformanceAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Enable Auto Color") {
                slideshowBackgroundColor = "auto"
            }
        } message: {
            Text("Auto background color analyzes each image to extract dominant colors. This may cause performance issues with large images during slideshow transitions.")
        }
    }
    
    private func getBackgroundColor(_ colorName: String) -> Color {
        switch colorName {
        case "auto": return .black // Fallback for preview, actual auto color is handled in slideshow
        case "black": return .black
        case "white": return .white
        case "gray": return .gray
        case "blue": return .blue
        case "purple": return .purple
        default: return .black
        }
    }
}


#Preview {
    @State var slideshowInterval: Double = 6.0
    @State var slideshowBackgroundColor = "white"
    @State var use24HourClock = true
    @State var hideOverlay = true
    @State var enableReflections = true
    @State var enableKenBurns = false
    @State var enableShuffle = false
    @State var autoSlideshowTimeout = 5
    @FocusState var isMinusFocused: Bool
    @FocusState var isPlusFocused: Bool
    @FocusState var focusedColor: String?
    
    return SlideshowSettings(
        slideshowInterval: $slideshowInterval,
        slideshowBackgroundColor: $slideshowBackgroundColor,
        use24HourClock: $use24HourClock,
        hideOverlay: $hideOverlay,
        enableReflections: $enableReflections,
        enableKenBurns: $enableKenBurns,
        enableShuffle: $enableShuffle,
        autoSlideshowTimeout: $autoSlideshowTimeout,
        isMinusFocused: $isMinusFocused,
        isPlusFocused: $isPlusFocused,
        focusedColor: $focusedColor
    )
    .preferredColorScheme(.light)
    .padding()
}

