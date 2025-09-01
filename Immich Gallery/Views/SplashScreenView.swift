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
