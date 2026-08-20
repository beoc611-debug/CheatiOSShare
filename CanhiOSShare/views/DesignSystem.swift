import SwiftUI

// MARK: - App Theme

enum AppTheme {
    // Original accent — kept for compatibility with non-cyber views
    static let accent = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.00, green: 0.64, blue: 0.42, alpha: 1.00)
                : UIColor(red: 0.85, green: 0.42, blue: 0.20, alpha: 1.00)
        }
    )
    static let pageBackground = Color(uiColor: .systemBackground)
    static let consoleBackground = Color(uiColor: .secondarySystemBackground)
    static let pageInset: CGFloat = 16
    static let rowIconSize: CGFloat = 17
    static let rowIconFrame: CGFloat = 28
    static let fileRowIconSize: CGFloat = 17
    static let fileRowIconFrame: CGFloat = 30
    static let fileRowHeight: CGFloat = 60
    static let appIconSize: CGFloat = 32
    static let emptyIconSize: CGFloat = 30
    static let selectionIconSize: CGFloat = 18

    // MARK: Cyberpunk palette
    static let cyberBase      = Color(red: 0.012, green: 0.031, blue: 0.090)
    static let techGlow       = Color(red: 0.180, green: 0.522, blue: 1.000)   // electric blue
    static let neonPurple     = Color(red: 0.580, green: 0.227, blue: 0.949)   // neon purple
    static let neonCyan       = Color(red: 0.102, green: 0.851, blue: 1.000)   // cyan
    static let techCardFill   = Color(red: 0.068, green: 0.098, blue: 0.180)

    static var techCardStroke: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.18, green: 0.52, blue: 1.00).opacity(0.55),
                Color(red: 0.58, green: 0.23, blue: 0.95).opacity(0.38)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let rowPalette: [Color] = [
        Color(red: 1.00, green: 0.56, blue: 0.24),
        Color(red: 0.96, green: 0.28, blue: 0.42),
        Color(red: 0.30, green: 0.78, blue: 0.96),
        Color(red: 0.66, green: 0.46, blue: 0.98),
        Color(red: 0.36, green: 0.85, blue: 0.56),
    ]
    static func rowColor(_ index: Int) -> Color { rowPalette[index % rowPalette.count] }

    static func resolvedBannerColor(_ hex: String?) -> Color {
        guard let hex, let color = Color(hex: hex) else {
            return Color(red: 0.12, green: 0.09, blue: 0.28)
        }
        return color
    }
}

// MARK: - Color hex initializer

extension Color {
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >>  8) & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}

// MARK: - TechBackground

struct TechBackground: View {
    var body: some View {
        GeometryReader { geo in
            Image("AppBg")
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
    }
}

// MARK: - TechCard modifier

struct TechCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(AppTheme.techCardFill)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.techCardStroke, lineWidth: 1)
            )
            .shadow(color: AppTheme.techGlow.opacity(0.10), radius: 18, y: 5)
    }
}

extension View {
    func techCard(_ cornerRadius: CGFloat = 20) -> some View {
        modifier(TechCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - PressScaleButtonStyle

struct PressScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

// MARK: - Toast

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    var text: String
}

private struct ToastOverlay: ViewModifier {
    @Binding var toast: ToastMessage?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.rowColor(4))
                            .padding(.top, 1)
                        Text(toast.text)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppTheme.techGlow.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: AppTheme.techGlow.opacity(0.25), radius: 18, y: 6)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(toast.id)
                    .task(id: toast.id) {
                        try? await Task.sleep(nanoseconds: 2_800_000_000)
                        if self.toast?.id == toast.id { self.toast = nil }
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.78), value: toast)
    }
}

extension View {
    func toast(_ message: Binding<ToastMessage?>) -> some View {
        modifier(ToastOverlay(toast: message))
    }
}

// MARK: - Reusable components (original)

struct AppRowIcon: View {
    let systemName: String
    var tint: Color = AppTheme.accent
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.12))
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: frameSize, height: frameSize)
        .accessibilityHidden(true)
    }
}

struct AppSearchField: View {
    @Binding var text: String
    let prompt: String
    let clearLabel: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearLabel)
            }
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 36)
        .background(
            Color(uiColor: .secondarySystemFill),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

struct AppLogo: View {
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let icon = UIImage(named: "AppIcon60x60")
                ?? Bundle.main.path(forResource: "AppIcon60x60@2x", ofType: "png")
                    .flatMap(UIImage.init(contentsOfFile:))
                ?? UIImage(named: "AppIcon") {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.accent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }
}
