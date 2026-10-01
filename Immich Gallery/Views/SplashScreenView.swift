//
//  WhatsNewView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-07-26.
//

import SwiftUI

// MARK: - Data Models

enum ChangelogSectionType: String, Codable {
    case version
    case newFeature = "new_feature"
    case improvement
    case bugFix = "bug_fix"
    case experimental
    case other
}

struct ChangelogSection: Identifiable, Codable {
    let id = UUID()
    let title: String
    let type: ChangelogSectionType
    var items: [String]

    enum CodingKeys: String, CodingKey {
        case title
        case type
        case items
    }
}

/// A version and the change sections that belong to it.
struct ChangelogVersion: Identifiable, Codable {
    let id = UUID()
    let version: String
    let releaseDate: String?
    let isBeta: Bool?
    var changes: [ChangelogSection]

    enum CodingKeys: String, CodingKey {
        case version
        case releaseDate
        case isBeta
        case changes
    }

    var formattedReleaseDate: String? {
        ChangelogRepository.formattedDate(releaseDate)
    }

    var versionDisplayText: String {
        let betaSuffix = isBeta == true ? " Beta" : ""
        guard let formattedReleaseDate else {
            return "Version \(version)\(betaSuffix)"
        }

        return "Version \(version)\(betaSuffix) - \(formattedReleaseDate)"
    }
}

private enum ChangelogRepository {
    private static let inputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    private static let outputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    static func load() -> [ChangelogVersion] {
        guard
            let url = Bundle.main.url(forResource: "releases", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let versions = try? JSONDecoder().decode([ChangelogVersion].self, from: data)
        else {
            return []
        }

        return versions
    }

    static func formattedDate(_ value: String?) -> String? {
        guard
            let value,
            let date = inputFormatter.date(from: value)
        else {
            return nil
        }

        return outputFormatter.string(from: date)
    }
}

// MARK: - View

struct WhatsNewView: View {
    let onDismiss: () -> Void
    @State private var opacity: Double = 0
    @State private var showPreviousVersions = false
    private let versions = ChangelogRepository.load()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                GitHubMilestoneStarfield()
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                HStack(alignment: .top, spacing: 0) {
                    brandPanel
                        .frame(width: geo.size.width * 0.34)

                    changesPanel
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .opacity(opacity)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { opacity = 1.0 } }
        .onExitCommand { onDismiss() }
    }
}

// MARK: - GitHub Milestone Celebration

private struct GitHubMilestoneStarfield: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    private let stars = MilestoneStar.all

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(stars) { star in
                    Image(systemName: star.usesSparkles ? "sparkles" : "star.fill")
                        .font(.system(size: star.size, weight: .semibold))
                        .foregroundColor(.yellow)
                        .opacity(isAnimating && !reduceMotion ? star.opacity : 0.18)
                        .scaleEffect(isAnimating && !reduceMotion ? star.endScale : star.startScale)
                        .rotationEffect(.degrees(isAnimating && !reduceMotion ? star.rotation : 0))
                        .position(
                            x: geometry.size.width * star.x,
                            y: geometry.size.height * star.y
                        )
                        .offset(y: isAnimating && !reduceMotion ? -star.travel : star.travel * 0.25)
                        .animation(
                            reduceMotion
                                ? nil
                                : .easeInOut(duration: star.duration)
                                    .repeatForever(autoreverses: true)
                                    .delay(star.delay),
                            value: isAnimating
                        )
                }
            }
        }
        .onAppear { isAnimating = true }
    }
}

private struct MilestoneStar: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let startScale: CGFloat
    let endScale: CGFloat
    let opacity: Double
    let travel: CGFloat
    let rotation: Double
    let duration: Double
    let delay: Double
    let usesSparkles: Bool

    static let all: [MilestoneStar] = (0..<28).map(makeStar)

    private static func makeStar(index: Int) -> MilestoneStar {
        let x = CGFloat(0.03) + CGFloat((index * 37 + 11) % 95) / CGFloat(100)
        let y = CGFloat(0.05) + CGFloat((index * 53 + 7) % 90) / CGFloat(100)
        let startScale = CGFloat(0.55) + CGFloat(index % 4) * CGFloat(0.08)
        let endScale = CGFloat(0.95) + CGFloat(index % 3) * CGFloat(0.16)

        return MilestoneStar(
            id: index,
            x: x,
            y: y,
            size: CGFloat(14 + (index * 11) % 24),
            startScale: startScale,
            endScale: endScale,
            opacity: 0.18 + Double(index % 5) * 0.08,
            travel: CGFloat(12 + (index * 7) % 34),
            rotation: Double(index.isMultiple(of: 2) ? 22 : -22),
            duration: 2.2 + Double(index % 6) * 0.35,
            delay: Double(index % 8) * 0.12,
            usesSparkles: index.isMultiple(of: 5)
        )
    }
}

// MARK: - Brand Panel

private extension WhatsNewView {
    var milestoneBadge: some View {
        Group {
            if #available(tvOS 26.0, *) {
                milestoneBadgeContent
                    .glassEffect(
                        .regular.tint(Color.yellow.opacity(0.08)),
                        in: Capsule()
                    )
            } else {
                milestoneBadgeContent
                    .background(
                        Capsule().fill(Color.white.opacity(0.1))
                    )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Celebrating 200 GitHub stars. Thank you for your support!")
    }

    var milestoneBadgeContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("200 GitHub Stars")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("Thank you for your support!")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    var brandPanel: some View {
        let latest = versions.first

        return VStack(alignment: .leading, spacing: 24) {
            Image("icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
//                .frame(width: 168, height: 168)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .padding(.top, 60)

            VStack(alignment: .leading, spacing: 20) {
                Text("What's New")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundColor(.white)

                Text("Immich Gallery")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(.gray)
                
                if let latest {
                    HStack(spacing: 10) {
                        Text("Version \(latest.version)")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(Color.white.opacity(0.12))
                            )
                    }
                }

                milestoneBadge
                
            }.padding(.leading, 10)

            

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Text("Be a star - leave a star, or five.")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.gray)

                Text("Press the Back button to close")
                    .font(.system(size: 18))
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
        .padding(.leading, 80)
        .padding(.trailing, 50)
        .padding(.vertical, 80)
    }
}

// MARK: - Changes Panel

private extension WhatsNewView {
    var changesPanel: some View {
        let latest = versions.first
        let previous = Array(versions.dropFirst())

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if let latest {
                    versionGroup(latest, isPrimary: true)
                } else {
                    missingChangelogCard
                }

                if !previous.isEmpty {
                    if showPreviousVersions {
                        ForEach(previous) { versionGroup($0, isPrimary: false) }
                    } else {
                        showPreviousButton
                    }
                }
            }
            // Native tvOS card focus expands beyond its resting frame. Keep
            // enough room on both sides so the focus effect is not clipped.
            .padding(.horizontal, 60)
            .padding(.top, 80)
            .padding(.bottom, 100)
        }
    }

    var missingChangelogCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Release notes unavailable")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)

            Text("The app could not load its bundled release notes file.")
                .font(.system(size: 20))
                .foregroundColor(.gray)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    func versionGroup(_ version: ChangelogVersion, isPrimary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            versionHeader(version, isPrimary: isPrimary)
            ForEach(version.changes) { ChangelogCard(section: $0) }
        }
        .padding(.bottom, 12)
    }

    func versionHeader(_ version: ChangelogVersion, isPrimary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(version.versionDisplayText)
                .font(.system(size: isPrimary ? 30 : 24, weight: .bold))
                .foregroundColor(isPrimary ? .white : .gray)
                
                Spacer(minLength: 16)
            }
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
        }
    }

    var showPreviousButton: some View {
        Button(action: { withAnimation { showPreviousVersions = true } }) {
            HStack(spacing: 10) {
                Image(systemName: "chevron.down")
                Text("Show previous versions")
            }
            .font(.system(size: 22, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
            )
        }
        .buttonStyle(CardButtonStyle())
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
            .frame(maxWidth: .infinity, alignment: .topLeading)
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
                        .font(.system(size: 22))
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
