//
//  WhatsNewView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-07-26.
//

import SwiftUI

struct WhatsNewView: View {
    let onDismiss: () -> Void
    @State private var opacity: Double = 0
    
    private let changelogContent = """
VERSION|1.0.5 Build 1

IMPROVEMENT|Better Settings Navigation
- Fixed focus issues
- More intuitive menu-style pickers replace the old segmented controls for color picker. 
- Made changes to code in Image Grid/Photos Tab to make it nicer. Please report if you notice issues. 
"""

//NEW_FEATURE|EXIF Photo Information Display
//- View detailed photo metadata in fullscreen mode by pressing the up arrow on your remote
//- See camera settings, location, file size, resolution, and capture date
//- Swipe down or press down arrow to dismiss the overlay
//
//NEW_FEATURE|Customizable Default Tab
//- Choose your preferred starting tab in Settings → Customization
//- Options: All Photos, Albums, People, or Tags (if enabled)
//- App now opens to your selected tab every time you launch
//
//NEW_FEATURE|Help & Tips Section
//- New Help & Tips section in Settings explains key features
//- Start Slideshow: Press play anywhere in the photo grid to begin slideshow from the highlighted image
//- Navigate Photos: Use arrow keys or swipe gestures to move between photos in fullscreen
//
//IMPROVEMENT|Better Settings Navigation
//- Fixed picker behavior - settings now require a click/tap to change instead of changing when you just focus on them
//- More intuitive menu-style pickers replace the old segmented controls
//
//BUGFIX|Navigation and Display
//- Updated navigation hints now show how to access photo details
//- Consistent Date Formatting across all views
//- Improved performance and stability
//"""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 12) {
                        Text("What's New in Immich Gallery")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("•Navigate using the touch surface or directional pad • View anytime in Settings • Press back to close •")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    
                    // Content
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 20),
                            GridItem(.flexible(), spacing: 20)
                        ], spacing: 20) {
                            ForEach(parseChangelog(), id: \.title) { section in
                                ChangelogCard(section: section)
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 100)
                    }
                }
                .opacity(opacity)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                opacity = 1.0
            }
        }
        .onExitCommand {
            onDismiss()
        }
    }
    
    private func parseChangelog() -> [ChangelogSection] {
        let lines = changelogContent.components(separatedBy: .newlines)
        var sections: [ChangelogSection] = []
        var currentSection = ChangelogSection(title: "", type: .version, items: [])
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty {
                continue
            }
            
            // Check if it's a section header with type
            if trimmedLine.contains("|") {
                // Save previous section
                if !currentSection.title.isEmpty || !currentSection.items.isEmpty {
                    sections.append(currentSection)
                }
                
                let components = trimmedLine.components(separatedBy: "|")
                if components.count == 2 {
                    let typeString = components[0]
                    let title = components[1]
                    
                    let sectionType: ChangelogSectionType
                    switch typeString {
                    case "VERSION":
                        sectionType = .version
                    case "NEW_FEATURE":
                        sectionType = .newFeature
                    case "IMPROVEMENT":
                        sectionType = .improvement
                    case "BUGFIX":
                        sectionType = .bugFix
                    default:
                        sectionType = .other
                    }
                    
                    currentSection = ChangelogSection(title: title, type: sectionType, items: [])
                }
            } else if trimmedLine.hasPrefix("-") {
                // It's a bullet point
                currentSection.items.append(String(trimmedLine.dropFirst(1).trimmingCharacters(in: .whitespaces)))
            }
        }
        
        // Add the last section
        if !currentSection.title.isEmpty || !currentSection.items.isEmpty {
            sections.append(currentSection)
        }
        
        return sections
    }
}

enum ChangelogSectionType {
    case version
    case newFeature
    case improvement
    case bugFix
    case other
}

struct ChangelogSection {
    let title: String
    let type: ChangelogSectionType
    var items: [String]
}

struct ChangelogCard: View {
    let section: ChangelogSection
    @Environment(\.isFocused) var isFocused
    
    private func getTypeInfo() -> (icon: String, color: Color, badge: String) {
        switch section.type {
        case .version:
            return ("app.badge.fill", .blue, "VERSION")
        case .newFeature:
            return ("sparkles", .green, "NEW")
        case .improvement:
            return ("arrow.up.circle.fill", .orange, "IMPROVED")
        case .bugFix:
            return ("wrench.and.screwdriver.fill", .red, "FIXED")
        case .other:
            return ("info.circle.fill", .gray, "INFO")
        }
    }
    
    var body: some View {
        Button(action: {
            // No action needed, just for focus
        }) {
            VStack(alignment: .leading, spacing: 16) {
                // Header with type badge and icon
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        let typeInfo = getTypeInfo()
                        
                        // Type badge
                        Text(typeInfo.badge)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(typeInfo.color)
                            )
                        
                        Spacer()
                        
                        // Icon
                        Image(systemName: typeInfo.icon)
                            .font(.title2)
                            .foregroundColor(typeInfo.color)
                    }
                    
                    // Title
                    Text(section.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                
                // Items list
                if !section.items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(section.items, id: \.self) { item in
                            HStack(alignment: .top, spacing: 10) {
                                // Bullet point
                                Circle()
                                    .fill(getTypeInfo().color)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 8)
                                
                                Text(item)
                                    .font(.system(size: 25))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isFocused ? Color.white.opacity(0.1) : Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isFocused ? getTypeInfo().color : Color.gray.opacity(0.3), lineWidth: isFocused ? 3 : 1)
                    )
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .buttonStyle(.plain)
        .focusable()
    }
}

#Preview {
    WhatsNewView(onDismiss: {})
}

