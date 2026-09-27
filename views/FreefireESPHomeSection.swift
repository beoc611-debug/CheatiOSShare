import SwiftUI

// ESP control panel embedded in the home tab.
// Store is owned by GamesHomeView and passed down so state persists across scrolls.
struct FreefireESPHomeSection: View {
    @ObservedObject var store: FreefireESPStore

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
                .padding(.top, 22)
                .padding(.bottom, 12)

            VStack(spacing: 10) {
                statusCard
                espCard
                aimCard
                settingsCard
                patchButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Section header

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "target")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.neonCyan, AppTheme.techGlow],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: AppTheme.neonCyan.opacity(0.6), radius: 6)
                Text("FREE FIRE ESP")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .kerning(0.4)
                Spacer()
                Button {
                    store.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.techGlow.opacity(0.80))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            LinearGradient(
                colors: [AppTheme.neonCyan, AppTheme.techGlow, AppTheme.techGlow.opacity(0.08), .clear],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 2)
            .clipShape(Capsule())
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Status card

    private var statusCard: some View {
        VStack(spacing: 0) {
            statusRow(
                icon: "apps.iphone",
                iconColor: store.detectedBundleID != nil ? AppTheme.neonCyan : Color(red: 0.45, green: 0.50, blue: 0.68),
                label: "Free Fire",
                value: store.detectedBundleID != nil ? "Đã phát hiện" : "Không tìm thấy",
                valueColor: store.detectedBundleID != nil
                    ? Color(red: 0.10, green: 0.90, blue: 0.52)
                    : Color(red: 0.80, green: 0.30, blue: 0.30)
            )

            statusDivider

            statusRow(
                icon: "doc.badge.gearshape",
                iconColor: store.isPatchInstalled ? AppTheme.techGlow : Color(red: 0.45, green: 0.50, blue: 0.68),
                label: "Patch file",
                value: store.isPatchInstalled ? "Đã cài đặt" : "Chưa cài",
                valueColor: store.isPatchInstalled
                    ? Color(red: 0.10, green: 0.90, blue: 0.52)
                    : Color(red: 0.85, green: 0.65, blue: 0.10)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .techCard()
    }

    private func statusRow(icon: String, iconColor: Color, label: String, value: String, valueColor: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.16))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(valueColor)
        }
    }

    private var statusDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, AppTheme.techGlow.opacity(0.18), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(height: 0.5)
            .padding(.vertical, 9)
    }

    // MARK: - ESP toggles card

    private var espCard: some View {
        espGroup(title: "ESP", icon: "eye.fill", color: AppTheme.neonCyan) {
            toggleRow("Bật ESP", icon: "power.circle.fill",
                      on: store.enableESP, color: AppTheme.neonCyan) {
                store.toggle(\.enableESP)
            }
            toggleRow("Player Box", icon: "square.dashed",
                      on: store.playerBox, color: AppTheme.techGlow) {
                store.toggle(\.playerBox)
            }
            toggleRow("Top Tracer", icon: "arrow.up.to.line.compact",
                      on: store.topTracer, color: AppTheme.techGlow) {
                store.toggle(\.topTracer)
            }
            toggleRow("Health Bar", icon: "heart.fill",
                      on: store.healthBar, color: Color(red: 0.20, green: 0.92, blue: 0.55)) {
                store.toggle(\.healthBar)
            }
            toggleRow("Player Name", icon: "person.text.rectangle",
                      on: store.playerName, color: Color(red: 0.55, green: 0.72, blue: 1.00)) {
                store.toggle(\.playerName)
            }
            toggleRow("Distance", icon: "ruler",
                      on: store.distance, color: Color(red: 0.90, green: 0.72, blue: 0.20)) {
                store.toggle(\.distance)
            }
        }
    }

    // MARK: - AIM card

    private var aimCard: some View {
        espGroup(title: "AIM", icon: "scope", color: AppTheme.neonPurple) {
            toggleRow("Silent Aim", icon: "dot.scope",
                      on: store.silentAim, color: AppTheme.neonPurple) {
                store.toggle(\.silentAim)
            }
            toggleRow("No Recoil", icon: "waveform.path.ecg",
                      on: store.noRecoil, color: Color(red: 0.85, green: 0.45, blue: 1.00)) {
                store.toggle(\.noRecoil)
            }
        }
    }

    // MARK: - Settings card

    private var settingsCard: some View {
        espGroup(title: "SETTINGS", icon: "slider.horizontal.3", color: Color(red: 0.90, green: 0.65, blue: 0.15)) {
            toggleRow("Fast Parachute", icon: "wind",
                      on: store.fastParachute, color: Color(red: 0.90, green: 0.65, blue: 0.15)) {
                store.toggle(\.fastParachute)
            }
            toggleRow("Speed Running ×3", icon: "hare.fill",
                      on: store.speedRunning, color: Color(red: 0.95, green: 0.40, blue: 0.25)) {
                store.toggle(\.speedRunning)
            }
        }
    }

    // MARK: - Patch button

    private var patchButton: some View {
        VStack(spacing: 6) {
            Button {
                store.patchGame()
            } label: {
                HStack(spacing: 10) {
                    if store.isPatching {
                        ProgressView()
                            .scaleEffect(0.85)
                            .tint(.white)
                    } else {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text(store.isPatching ? "Đang patch..." : "Patch File vào Game")
                        .font(.system(size: 15, weight: .bold))
                        .kerning(0.2)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    ZStack {
                        LinearGradient(
                            colors: store.isPatching
                                ? [Color(red: 0.20, green: 0.20, blue: 0.35), Color(red: 0.15, green: 0.15, blue: 0.28)]
                                : [AppTheme.neonPurple, AppTheme.techGlow],
                            startPoint: .leading, endPoint: .trailing
                        )
                        if !store.isPatching {
                            LinearGradient(
                                colors: [.white.opacity(0.12), .clear],
                                startPoint: .top, endPoint: .center
                            )
                        }
                    }
                    .clipShape(CutShape(cut: 14))
                )
                .overlay(
                    CutShape(cut: 14)
                        .strokeBorder(
                            store.isPatching
                                ? AppTheme.techGlow.opacity(0.25)
                                : AppTheme.neonCyan.opacity(0.55),
                            lineWidth: 1.2
                        )
                )
                .shadow(
                    color: store.isPatching ? .clear : AppTheme.neonPurple.opacity(0.50),
                    radius: 16, y: 4
                )
            }
            .buttonStyle(.plain)
            .disabled(store.isPatching || store.detectedBundleID == nil)
            .opacity((store.detectedBundleID == nil && !store.isPatching) ? 0.45 : 1.0)

            if store.detectedBundleID == nil {
                Text("Không tìm thấy Free Fire — hãy cài game trước")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(red: 0.55, green: 0.45, blue: 0.68))
                    .multilineTextAlignment(.center)
            }
        }
        .alert(item: $store.patchResult) { result in
            switch result {
            case .success:
                return Alert(
                    title: Text("Patch thành công"),
                    message: Text("Assembly-CSharp-patch.bytes đã được copy vào Documents/ của Free Fire. Mở game để áp dụng."),
                    dismissButton: .default(Text("OK"))
                )
            case .failure(let msg):
                return Alert(
                    title: Text("Patch thất bại"),
                    message: Text(msg),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    // MARK: - Helpers

    private func espGroup<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(color.opacity(0.85))
                    .kerning(1.0)
                Spacer()
            }
            .padding(.bottom, 10)

            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .techCard()
    }

    private func toggleRow(
        _ label: String,
        icon: String,
        on: Bool,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(on ? color.opacity(0.18) : Color.white.opacity(0.05))
                        .frame(width: 32, height: 32)
                        .animation(.easeInOut(duration: 0.18), value: on)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(on ? color : Color(red: 0.40, green: 0.48, blue: 0.65))
                        .animation(.easeInOut(duration: 0.18), value: on)
                }

                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(on ? .white : Color(red: 0.45, green: 0.55, blue: 0.75))
                    .animation(.easeInOut(duration: 0.18), value: on)

                Spacer()

                // Toggle pill
                ZStack(alignment: on ? .trailing : .leading) {
                    Capsule()
                        .fill(on ? color.opacity(0.30) : Color.white.opacity(0.07))
                        .frame(width: 44, height: 24)
                        .overlay(
                            Capsule()
                                .strokeBorder(on ? color.opacity(0.70) : Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: on ? color.opacity(0.40) : .clear, radius: 6)
                    Circle()
                        .fill(on ? color : Color(red: 0.35, green: 0.40, blue: 0.58))
                        .frame(width: 18, height: 18)
                        .shadow(color: on ? color.opacity(0.70) : .clear, radius: 4)
                        .padding(.horizontal, 3)
                        .animation(.spring(response: 0.25, dampingFraction: 0.72), value: on)
                }
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
