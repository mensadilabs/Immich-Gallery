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

struct VersionGroup: Identifiable {
    let id = UUID()
    let version: String
    let sections: [ChangelogSection]
}

// MARK: - View

struct WhatsNewView: View {
    let onDismiss: () -> Void
    @State private var opacity: Double = 0

    private let changelogContent = """

    VERSION|1.2.0

    IMPROVEMENT| Sidebar Layout Optimization
    - When using Sidebar navigation, the Filter and Sort buttons now sit higher in the content area, giving the photo grid more screen real estate.
    - Try switching to Sidebar style in Settings → Interface if you haven't already — it makes great use of the available space.

    NEW_FEATURE| Multi-Select Filters
    - You can now select multiple cities and years at once in the All Photos filter.
    - Want Paris and London? 2022 and 2024? Go wild. Select them all and we'll fetch everything in parallel.
    - Consecutive years (e.g. 2022-2024) are smart enough to collapse into a single request. You're welcome.

    IMPROVEMENT| Filter UI Redesign
    - The filter modal got a facelift. Title, combo counter, and action buttons now live on one row.
    - A live counter shows how many filter combinations you're using out of the max 6.

    IMPROVEMENT| What's New Timeline
    - You're looking at it. The changelog is now a timeline instead of a wall of cards.

    VERSION|1.1.9

    NEW_FEATURE| Background & Library Controls
    - Added an app-wide background style picker in Settings → Interface, including a true black Midnight theme.
    - Added a new Settings → Sorting option to hide Filter and Sort buttons in the main library view.
    - When Filter and Sort buttons are hidden, the All Photos grid now reclaims that space to show more images.

    BUGFIX| Folders UI hangs on large libraries
    - Fixed a bug where folders view may hang on large libraries.
    - Made some additional performance improvements to people and tags tab.

    VERSION|1.1.8

    NEW_FEATURE| All Photos Sort & Filter
    - Added sort and filter controls to the main library (All Photos) view.

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

    private let timelineLineWidth: CGFloat = 3
    private let nodeSize: CGFloat = 20
    private let versionNodeSize: CGFloat = 30

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    headerView

                    ScrollView {
                        let groups = parseVersionGroups()

                        VStack(spacing: 0) {
                            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                                timelineVersionGroup(group: group, isLast: index == groups.count - 1)
                            }
                        }
                        .padding(.leading, 60)
                        .padding(.trailing, 40)
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
        VStack(spacing: 8) {
            Text("What's New")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)

            Text("Be a star - leave a star, or five.")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(.top, 30)
    }

    func timelineVersionGroup(group: VersionGroup, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Version node
            HStack(alignment: .center, spacing: 20) {
                // Timeline node for version
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: versionNodeSize, height: versionNodeSize)
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: versionNodeSize + 12, height: versionNodeSize + 12)
                }
                .frame(width: versionNodeSize + 12)

                Text(group.version)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.vertical, 10)

            // Section entries
            ForEach(Array(group.sections.enumerated()), id: \.element.id) { sectionIndex, section in
                let isLastSection = isLast && sectionIndex == group.sections.count - 1
                timelineEntry(section: section, showLine: !isLastSection)
            }
        }
    }

    func timelineEntry(section: ChangelogSection, showLine: Bool) -> some View {
        let typeInfo = getTypeInfo(for: section.type)

        return HStack(alignment: .top, spacing: 20) {
            // Timeline connector
            VStack(spacing: 0) {
                // Line above node
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: timelineLineWidth)
                    .frame(height: 15)

                // Node
                Circle()
                    .fill(typeInfo.color)
                    .frame(width: nodeSize, height: nodeSize)

                // Line below node
                if showLine {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: timelineLineWidth)
                        .frame(maxHeight: .infinity)
                } else {
                    Spacer()
                }
            }
            .frame(width: versionNodeSize + 12)

            // Card content
            Button(action: {}) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text(typeInfo.badge)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(typeInfo.color)
                            )

                        Text(section.title)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        Image(systemName: typeInfo.icon)
                            .font(.title3)
                            .foregroundColor(typeInfo.color)
                    }

                    if !section.items.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(section.items, id: \.self) { item in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(typeInfo.color.opacity(0.6))
                                        .frame(width: 5, height: 5)
                                        .padding(.top, 7)
                                    Text(item)
                                        .font(.system(size: 20))
                                        .foregroundColor(.white.opacity(0.8))
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(CardButtonStyle())
            .padding(.bottom, 8)
        }
    }

    func getTypeInfo(for type: ChangelogSectionType) -> (icon: String, color: Color, badge: String) {
        switch type {
        case .version: return ("app.badge.fill", .blue, "VERSION")
        case .newFeature: return ("sparkles", .green, "NEW")
        case .improvement: return ("arrow.up.circle.fill", .orange, "IMPROVED")
        case .bugFix: return ("ladybug.slash", .red, "FIXED")
        case .experimental: return ("flask", .purple, "EXPERIMENTAL")
        case .other: return ("info.circle.fill", .gray, "INFO")
        }
    }
}

// MARK: - Parsing Logic

private extension WhatsNewView {
    func parseVersionGroups() -> [VersionGroup] {
        let sections = parseChangelog()
        var groups: [VersionGroup] = []
        var currentVersion = ""
        var currentSections: [ChangelogSection] = []

        for section in sections {
            if section.type == .version {
                if !currentVersion.isEmpty {
                    groups.append(VersionGroup(version: currentVersion, sections: currentSections))
                }
                currentVersion = section.title.trimmingCharacters(in: .whitespaces)
                currentSections = []
            } else {
                currentSections.append(section)
            }
        }

        if !currentVersion.isEmpty {
            groups.append(VersionGroup(version: currentVersion, sections: currentSections))
        }

        return groups
    }

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

#Preview {
    WhatsNewView(onDismiss: {})
}
