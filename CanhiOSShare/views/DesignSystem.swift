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
        .allowsHitTesting(false)
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
    enum ToastStyle: Equatable {
        case success, off, error, info

        var icon: String {
            switch self {
            case .success: return "bolt.fill"
            case .off:     return "moon.fill"
            case .error:   return "exclamationmark.triangle.fill"
            case .info:    return "checkmark.circle.fill"
            }
        }
        var color: Color {
            switch self {
            case .success: return Color(red: 0.10, green: 0.95, blue: 0.65)
            case .off:     return Color(red: 0.50, green: 0.52, blue: 0.72)
            case .error:   return Color(red: 1.00, green: 0.30, blue: 0.35)
            case .info:    return AppTheme.techGlow
            }
        }
        var badge: String {
            switch self {
            case .success: return "BẬT"
            case .off:     return "TẮT"
            case .error:   return "LỖI"
            case .info:    return "OK"
            }
        }
    }

    let id = UUID()
    var text: String
    var style: ToastStyle = .info
}

private struct ToastOverlay: ViewModifier {
    @Binding var toast: ToastMessage?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    HStack(spacing: 12) {
                        // Left icon
                        ZStack {
                            Circle()
                                .fill(toast.style.color.opacity(0.18))
                                .frame(width: 38, height: 38)
                            Image(systemName: toast.style.icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(toast.style.color)
                        }
                        // Message
                        Text(toast.text)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        // Badge
                        Text(toast.style.badge)
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(toast.style.color)
                            .tracking(0.6)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(toast.style.color.opacity(0.15), in: Capsule())
                            .overlay(Capsule().strokeBorder(toast.style.color.opacity(0.55), lineWidth: 1))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(red: 0.04, green: 0.06, blue: 0.12).opacity(0.92))
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [toast.style.color.opacity(0.70), toast.style.color.opacity(0.20)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 12, y: 4)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(toast.id)
                    .task(id: toast.id) {
                        try? await Task.sleep(nanoseconds: 2_800_000_000)
                        if self.toast?.id == toast.id { self.toast = nil }
                    }
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.72), value: toast)
    }
}

extension View {
    func toast(_ message: Binding<ToastMessage?>) -> some View {
        modifier(ToastOverlay(toast: message))
    }
}

// MARK: - Custom patch alert

private struct PatchAlertOverlay: ViewModifier {
    @Binding var alert: PatchStoreAlert?
    let language: AppLanguage

    private enum AlertKind {
        case failure, success, warning, info
        var color: Color {
            switch self {
            case .failure: return Color(red: 1.00, green: 0.30, blue: 0.35)
            case .success: return Color(red: 0.10, green: 0.95, blue: 0.65)
            case .warning: return Color(red: 0.96, green: 0.65, blue: 0.14)
            case .info:    return Color(red: 0.32, green: 0.86, blue: 0.95)
            }
        }
        var icon: String {
            switch self {
            case .failure: return "exclamationmark.triangle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.circle.fill"
            case .info:    return "info.circle.fill"
            }
        }
    }

    private func kind(for alert: PatchStoreAlert) -> AlertKind {
        switch alert.titleKey {
        case "common.failed": return .failure
        case "common.done":   return .success
        default:
            if alert.titleKey.contains("unsupported") { return .warning }
            return .info
        }
    }

    func body(content: Content) -> some View {
        content.overlay {
            if let alert {
                let k = kind(for: alert)
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture { self.alert = nil }
                    VStack(spacing: 0) {
                        // Top stripe
                        Rectangle()
                            .fill(k.color)
                            .frame(height: 3)
                            .clipShape(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 20, bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0, topTrailingRadius: 20
                                )
                            )
                        VStack(spacing: 18) {
                            // Icon
                            ZStack {
                                Circle()
                                    .fill(k.color.opacity(0.14))
                                    .frame(width: 60, height: 60)
                                Image(systemName: k.icon)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(k.color)
                            }
                            .padding(.top, 24)
                            // Title
                            Text(language.text(alert.titleKey))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                            // Message
                            Text(alert.message(language: language))
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color(red: 0.68, green: 0.74, blue: 0.88))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, -6)
                            // Divider
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 1)
                            // OK button
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    self.alert = nil
                                }
                            } label: {
                                Text(language.text("common.ok"))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(k.color)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 8)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                    }
                    .background(
                        Color(red: 0.08, green: 0.11, blue: 0.22).opacity(0.97)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(k.color.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: k.color.opacity(0.18), radius: 30, y: 8)
                    .shadow(color: Color.black.opacity(0.50), radius: 16, y: 4)
                    .padding(.horizontal, 32)
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
                }
                .animation(.spring(response: 0.38, dampingFraction: 0.75), value: alert.id)
            }
        }
    }
}

extension View {
    func patchAlert(_ alert: Binding<PatchStoreAlert?>, language: AppLanguage) -> some View {
        modifier(PatchAlertOverlay(alert: alert, language: language))
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

// MARK: - iOS 15 Compat

struct AnyNavigationStack<Content: View>: View {
    @ViewBuilder private var content: () -> Content

    init(@ViewBuilder _ content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        if #available(iOS 16, *) {
            NavigationStack(root: content)
        } else {
            NavigationView(content: content)
                .navigationViewStyle(.stack)
        }
    }
}

private struct ToolbarHiddenModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content.toolbar(.hidden, for: .navigationBar)
        } else {
            content.navigationBarHidden(true)
        }
    }
}

private struct TrackingModifier: ViewModifier {
    let tracking: CGFloat
    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content.tracking(tracking)
        } else {
            content
        }
    }
}

private struct FontWeightModifier: ViewModifier {
    let weight: Font.Weight
    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content.fontWeight(weight)
        } else {
            content
        }
    }
}

private struct ScrollContentBackgroundHiddenModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

private struct ScrollDismissesKeyboardModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content.scrollDismissesKeyboard(.interactively)
        } else {
            content
        }
    }
}

private struct PresentationMediumDetentModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content.presentationDetents([.medium])
        } else {
            content
        }
    }
}

private struct PresentationLargeDetentModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content.presentationDetents([.large])
        } else {
            content
        }
    }
}

private struct FormStyleGroupedModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content.formStyle(.grouped)
        } else {
            content
        }
    }
}

private struct PresentationMediumLargeDetentModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content.presentationDetents([.medium, .large])
        } else {
            content
        }
    }
}

private struct PresentationHeightDetentModifier: ViewModifier {
    let height: CGFloat
    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content.presentationDetents([.height(height)])
        } else {
            content
        }
    }
}

private struct PresentationDragIndicatorModifier: ViewModifier {
    let visible: Bool
    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content.presentationDragIndicator(visible ? .visible : .hidden)
        } else {
            content
        }
    }
}

struct LabeledRow<C: View>: View {
    let label: String
    @ViewBuilder private var content: () -> C

    init(_ label: String, @ViewBuilder content: @escaping () -> C) {
        self.label = label
        self.content = content
    }

    var body: some View {
        if #available(iOS 16, *) {
            LabeledContent(label, content: content)
        } else {
            HStack {
                Text(label)
                Spacer()
                content()
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}

extension LabeledRow where C == Text {
    init(_ label: String, value: String) {
        self.label = label
        self.content = { Text(value) }
    }
}

extension View {
    func toolbarHidden15() -> some View { modifier(ToolbarHiddenModifier()) }
    func tracking15(_ v: CGFloat) -> some View { modifier(TrackingModifier(tracking: v)) }
    func fontWeight15(_ w: Font.Weight) -> some View { modifier(FontWeightModifier(weight: w)) }
    func scrollContentBackground15() -> some View { modifier(ScrollContentBackgroundHiddenModifier()) }
    func scrollDismissesKeyboard15() -> some View { modifier(ScrollDismissesKeyboardModifier()) }
    func presentationMediumDetent() -> some View { modifier(PresentationMediumDetentModifier()) }
    func presentationLargeDetent() -> some View { modifier(PresentationLargeDetentModifier()) }
    func presentationMediumLargeDetent() -> some View { modifier(PresentationMediumLargeDetentModifier()) }
    func presentationHeightDetent(_ h: CGFloat) -> some View { modifier(PresentationHeightDetentModifier(height: h)) }
    func presentationDragIndicator15(_ visible: Bool) -> some View { modifier(PresentationDragIndicatorModifier(visible: visible)) }
    func formStyleGrouped() -> some View { modifier(FormStyleGroupedModifier()) }
}
