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

private struct FlyingGhostView: View {
    @State private var flightPath = (0..<9).map { _ in
        CGPoint(x: CGFloat.random(in: 0.06...0.94), y: CGFloat.random(in: 0.08...0.92))
    }
    @State private var legDurations = (0..<9).map { _ in Double.random(in: 6.0...10.5) }

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            GeometryReader { geometry in
                let totalDuration = legDurations.reduce(0, +)
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: totalDuration)
                let leg = currentLeg(at: elapsed)
                let from = flightPath[leg.index]
                let to = flightPath[(leg.index + 1) % flightPath.count]
                let progress = leg.progress * leg.progress * (3 - 2 * leg.progress)
                let normalizedX = from.x + (to.x - from.x) * progress
                let normalizedY = from.y + (to.y - from.y) * progress
                let x = 24 + normalizedX * max(0, geometry.size.width - 48)
                let y = 24 + normalizedY * max(0, geometry.size.height - 48)

                ZStack {
                    GhostSilhouette()
                        .fill(Color(red: 0.91, green: 0.93, blue: 0.97))
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)

                    HStack(spacing: 8) {
                        Circle().frame(width: 4, height: 6)
                        Circle().frame(width: 4, height: 6)
                    }
                    .foregroundStyle(Color(red: 0.19, green: 0.20, blue: 0.29))
                    .offset(y: -3)
                }
                .frame(width: 38, height: 48)
                .rotationEffect(.degrees(Double(to.x - from.x) * 18.0))
                .position(x: x, y: y)
            }
        }
        .opacity(0.72)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func currentLeg(at elapsed: TimeInterval) -> (index: Int, progress: CGFloat) {
        var legStart = 0.0
        for (index, duration) in legDurations.enumerated() {
            if elapsed < legStart + duration {
                return (index, CGFloat((elapsed - legStart) / duration))
            }
            legStart += duration
        }
        return (0, 0)
    }
}

private struct GhostSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.height * 0.48))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.minY), control1: CGPoint(x: rect.minX, y: rect.height * 0.2), control2: CGPoint(x: rect.width * 0.2, y: rect.minY))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.height * 0.48), control1: CGPoint(x: rect.width * 0.8, y: rect.minY), control2: CGPoint(x: rect.maxX, y: rect.height * 0.2))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.width * 0.68, y: rect.maxY * 0.92), control1: CGPoint(x: rect.width * 0.88, y: rect.height * 0.84), control2: CGPoint(x: rect.width * 0.79, y: rect.height * 0.84))
        path.addCurve(to: CGPoint(x: rect.width * 0.34, y: rect.maxY), control1: CGPoint(x: rect.width * 0.57, y: rect.height * 0.99), control2: CGPoint(x: rect.width * 0.46, y: rect.height * 0.99))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control1: CGPoint(x: rect.width * 0.2, y: rect.height * 0.84), control2: CGPoint(x: rect.width * 0.1, y: rect.height * 0.84))
        path.closeSubpath()
        return path
    }
}

struct WhatsNewView: View {
    let onDismiss: () -> Void
    @State private var opacity: Double = 0
    @State private var showPreviousVersions = false
    private let versions = ChangelogRepository.load()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                HStack(alignment: .top, spacing: 0) {
                    brandPanel
                        .frame(width: geo.size.width * 0.37)

                    changesPanel
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .opacity(opacity)

                FlyingGhostView()
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { opacity = 1.0 } }
        .onExitCommand { onDismiss() }
    }
}

// MARK: - Brand Panel

private extension WhatsNewView {
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
            }
            .padding(.leading, 10)

            VStack(alignment: .leading, spacing: 12) {
                // Temporarily hidden; restore for the next release.
                /*
                Image("GitHubRepositoryQRCode")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 280, height: 280)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("QR code for the Immich Gallery GitHub repository")
                */

                Text("Be a star - leave a star, or five.")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 360, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            .padding(.leading, 10)
            .padding(.top, 60)
        }
        .padding(.leading, 70)
        .padding(.trailing, 40)
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

                if isPrimary {
                    Text("Press the Back button to close")
                        .font(.system(size: 18))
                        .foregroundColor(.gray.opacity(0.7))
                }
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
