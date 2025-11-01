//
//  WhatsNewView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-07-26.
//

import SwiftUI

// MARK: - Data Models

enum ChangelogSectionType {
    case version
    case newFeature
    case improvement
    case bugFix
    case experimental
    case other
}

struct ChangelogSection: Identifiable {
    let id = UUID()
    let title: String
    let type: ChangelogSectionType
    var items: [String]
}

// MARK: - View

struct WhatsNewView: View {
    let onDismiss: () -> Void
    @State private var opacity: Double = 0
    
    private let changelogContent = """
    
    VERSION|1.1.7

    NEW_FEATURE| Tabs vs Sidebar
    - Pick your style in Settings → Interface. Tabs for the classics, Sidebar for the minimal.

    BUGFIX| Sort Order & album cover
    - Fixed the sort order again.
    - If thumbnail animation is disabled, we now show album cover of the album.
    
    VERSION|1.1.6

    NEW_FEATURE| ✨✨New Icon✨✨
    - The Icon has been a placeholder for too long. 

    BUGFIX| Fix shared album content. Discussion#81
    - Thank you for reporting @madasus. Issue has been fixed.
    
    BUGFIX| The overlay windows were broken on TvOS 26. Add user/whats new etc.Part of issue #75
    - Thanks for reporting @rmayergfx. This should fix that issue.

    VERSION|1.1.5

    NEW_FEATURE| Folders Tab
    - New opt-in Folders tab allows you to view folders from your external library.

    BUGFIX| Sorting order
    - We are once again respecting the sorting order selected in settings.
    
    IMPROVEMENT| Performance Optimizations
    - Hopefully better video player. 
    
    VERSION|1.1.4

    IMPROVEMENT| Performance Optimizations
    - Various performance improvements throughout the app for smoother navigation.
    - Enhanced loading times and reduced memory usage.
    - More improvements coming next for people with large libraries, for now, but if you're experiencing crashes when scrolling, please report. 
    
    NEW_FEATURE| Explore Tab
    - New explore tab to discover your photos through statistics or by cities visited.
    
    IMPROVEMENT| Top Shelf Enhancement
    - Top shelf now shows only landscape orientation images for better visual presentation on Apple TV.

    
    VERSION|1.1.3
    
    NEW_FEATURE| Apple TV Top Shelf Customization
    - Be brave, embrace choas: Now you can choose to display random photos on top shelf.


    IMPROVEMENT| Raw Image Support
    - Raw images now work kinda maybe. TV cannot display RAW images natively so I now load a fullsize version provided by immich.

        
    IMPROVEMENT| Album & UI Enhancements
    - Albums now show all favorite photos as a new album. Do not worry, the album does not exist in reality, like me.
    - Performance improvements to the all photos tab.
    - Changes to settings page as usual. 
    
    EXPERIMENTAL| Auto Slideshow Configuration (experimental only)
    - This may go away if I can't convince myself this is good.
    - Create empty album named "immich-gallery-config" with specific description format. Check settings for more info on setup. 
    - Support for both album and person-based slideshow configuration

     EXPERIMENTAL| Dimmed Slideshow
    - Add support for dimmed slideshow in settings.
    - Time based dim level
    - How good does it work is a matter of personal opinion/s. Try it out and let me know. Yes, I'm talking to you specifically. 
    
    
    VERSION|1.1.2
    
    NEW_FEATURE| Sign In With API key
    - All of the SSO users can now use API keys to sign in. Not sure what will break if the API does not have needed scopes. Eventually maybe I'll list them out but for now, take a guess based on the available features.
    
    IMPROVEMENT| Cleanups
    - Bug fixes and performance improvements.
    - Album view now shows "shared by you" for the albums shared by you.
    - Cleaner settings view.

    
    VERSION|1.0.14
    
    IMPROVEMENT| Slideshow optimizations
    - Rewrite SlideshowView for loading assets dynamically
    
    BUGFIX| Albums tab
    - Fix shared albums are duplicated
    - Fix slideshow does not work for shared-in albums

    
    VERSION|1.0.12
    
    BUGFIX| Fix more bugs
    - Make slideshow truly random, just like life. Outsourced this to the server. - #43 
    - Fix inactivity timer - Browse fast or the automatic slideshow will catch up to you - #43 
    - Remove date of birth from people tab - WAF+10 - #44
    
    VERSION|1.0.11
    BUGFIX| Fix bugs
    - Top shef portraits no longer do unexpected headstands or cartwheels. I Hope. 
    - Hopefully it also won't crash. But you may see reduced image quality in top shelf. 
    - Better error handling.
    - Changed color gradient, this is much better on the eyes, I think. 
    """
    
    private let gridSpacing: CGFloat = 20
    private let horizontalPadding: CGFloat = 40
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    headerView
                    
                    ScrollView {
                        LazyVStack(spacing: gridSpacing) {
                            changelogContentSections
                        }
                        .padding(.bottom, 100)
                    }
                }
                .opacity(opacity)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { opacity = 1.0 } }
        .onExitCommand { onDismiss() }
    }
}

// MARK: - Subviews

private extension WhatsNewView {
    var headerView: some View {
        VStack(spacing: 12) {
            Text("What's New in Immich Gallery")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
            
            Text("Be a star - leave a star, or five.")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(.top, 40)
    }
    
    var changelogContentSections: some View {
        let sections = parseChangelog()
        
        return ForEach(sections) { section in
                // Grid for non-version sections
                LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: gridSpacing), count: 1), spacing: gridSpacing) {
                    ChangelogCard(section: section).padding(.horizontal)
            }
        }
    }
}

// MARK: - Parsing Logic

private extension WhatsNewView {
    func parseChangelog() -> [ChangelogSection] {
        var sections: [ChangelogSection] = []
        var currentSection: ChangelogSection?
        
        for line in changelogContent.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            if trimmed.contains("|") {
                if let section = currentSection {
                    sections.append(section)
                }
                let (type, title) = parseHeader(trimmed)
                currentSection = ChangelogSection(title: title, type: type, items: [])
            } else if trimmed.hasPrefix("-") {
                currentSection?.items.append(String(trimmed.dropFirst().trimmingCharacters(in: .whitespaces)))
            }
        }
        
        if let section = currentSection {
            sections.append(section)
        }
        
        return sections
    }
    
    func parseHeader(_ line: String) -> (ChangelogSectionType, String) {
        let components = line.components(separatedBy: "|")
        guard components.count == 2 else { return (.other, line) }
        
        let type: ChangelogSectionType
        switch components[0] {
        case "VERSION": type = .version
        case "NEW_FEATURE": type = .newFeature
        case "IMPROVEMENT": type = .improvement
        case "BUGFIX": type = .bugFix
        case "EXPERIMENTAL": type = .experimental
        default: type = .other
        }
        return (type, components[1])
    }
}

// MARK: - Card View

struct ChangelogCard: View {
    let section: ChangelogSection
    @Environment(\.isFocused) var isFocused
    
    private func getTypeInfo() -> (icon: String, color: Color, badge: String) {
        switch section.type {
        case .version: return ("app.badge.fill", .blue, "VERSION")
        case .newFeature: return ("sparkles", .green, "NEW")
        case .improvement: return ("arrow.up.circle.fill", .orange, "IMPROVED")
        case .bugFix: return ("ladybug.slash", .red, "FIXED")
        case .experimental: return ("flask", .purple, "EXPERIMENTAL")
        case .other: return ("info.circle.fill", .gray, "INFO")
        }
    }
    
    var body: some View {
        let typeInfo = getTypeInfo()
        
        return Button(action: {}) {
            VStack(alignment: .leading, spacing: 16) {
                header(typeInfo)
                if !section.items.isEmpty { itemsList(typeInfo) }
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isFocused ? Color.white.opacity(0.1) : Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isFocused ? typeInfo.color : Color.gray.opacity(0.3), lineWidth: isFocused ? 3 : 1)
                    )
            )
        }
        .buttonStyle(CardButtonStyle())
        .focusable()
    }
    
    private func header(
        _ typeInfo: (icon: String, color: Color, badge: String)
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
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
                Image(systemName: typeInfo.icon)
                    .font(.title2)
                    .foregroundColor(typeInfo.color)
            }
            .padding(.bottom, 8)

            Text(section.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
    }
    
    private func itemsList(_ typeInfo: (icon: String, color: Color, badge: String)) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(section.items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(typeInfo.color)
                        .frame(width: 6, height: 6)
                        .padding(.top, 8)
                    Text(item)
                        .font(.system(size: 25))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }
}

#Preview {
    WhatsNewView(onDismiss: {})
}
