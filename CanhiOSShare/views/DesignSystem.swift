import SwiftUI

// MARK: - Colors & Theme

enum AppTheme {
    static let background   = Color(red: 0.03, green: 0.05, blue: 0.12)
    static let card         = Color(red: 0.06, green: 0.09, blue: 0.18)
    static let cardStroke   = Color(white: 1, opacity: 0.07)
    static let accent       = Color(red: 0.35, green: 0.75, blue: 1.00) // cyan-blue
    static let purple       = Color(red: 0.58, green: 0.35, blue: 1.00)
    static let green        = Color(red: 0.20, green: 0.85, blue: 0.45)
    static let red          = Color(red: 0.96, green: 0.26, blue: 0.26)
    static let textPrimary  = Color.white
    static let textSecondary = Color(white: 0.55)
}

// MARK: - TechBackground

struct TechBackground: View {
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            Canvas { ctx, size in
                let step: CGFloat = 28
                var path = Path()
                stride(from: CGFloat(0), through: size.width, by: step).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                stride(from: CGFloat(0), through: size.height, by: step).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                ctx.stroke(path, with: .color(.white.opacity(0.038)), lineWidth: 0.5)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - TechCard

struct TechCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(AppTheme.cardStroke, lineWidth: 1)
            )
    }
}

// MARK: - EntryCard (grid tile on HomeView)

struct LocationEntry: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let path: String
}

extension LocationEntry {
    static let all: [LocationEntry] = [
        LocationEntry(icon: "tray.full.fill",   iconColor: AppTheme.accent,  title: "App Data",     subtitle: "Containers/Data", path: "/private/var/mobile/Containers/Data/Application"),
        LocationEntry(icon: "person.2.fill",     iconColor: AppTheme.purple,  title: "App Groups",   subtitle: "Shared/AppGroup", path: "/private/var/mobile/Containers/Shared/AppGroup"),
        LocationEntry(icon: "server.rack",        iconColor: Color(red:0.2,green:0.7,blue:0.4), title: "System Data", subtitle: "Containers/System", path: "/private/var/mobile/Containers/Data/System"),
        LocationEntry(icon: "internaldrive.fill", iconColor: Color(red:1.0,green:0.6,blue:0.1), title: "User Data",   subtitle: "/var/mobile",       path: "/private/var/mobile"),
        LocationEntry(icon: "apps.iphone",        iconColor: Color(red:0.9,green:0.3,blue:0.6), title: "App List",    subtitle: "Ứng dụng đã cài",   path: "__applist__"),
        LocationEntry(icon: "photo.fill",         iconColor: Color(red:0.4,green:0.7,blue:1.0), title: "Wallpapers",  subtitle: "Cryptex/Wallpapers", path: "/private/var/mobile/Library/SpringBoard"),
    ]
}

struct EntryCard: View {
    let entry: LocationEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(entry.iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: entry.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(entry.iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(entry.subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppTheme.cardStroke, lineWidth: 1)
        )
    }
}

// MARK: - PressScaleButtonStyle

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
