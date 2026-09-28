import SwiftUI

struct FreefireESPHomeSection: View {
    @ObservedObject var store: FreefireESPStore
    /// 0 = Home (status + patch), 1 = ESP/AIM, 2 = Misc (settings)
    var tab: Int = 0

    var body: some View {
        VStack(spacing: 14) {
            if tab == 0 {
                statusCard
                patchButton
            } else if tab == 1 {
                espCard
                aimCard
                patchButton
            } else {
                settingsCard
                patchButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Status card

    private var statusCard: some View {
        VStack(spacing: 0) {
            // Game variant picker — CutShape style
            HStack(spacing: 4) {
                ForEach(FreefireESPStore.FFVariant.allCases) { variant in
                    let isSelected = store.selectedVariant == variant
                    Button {
                        store.selectVariant(variant)
                    } label: {
                        Text(variant.rawValue)
                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? .white : Color(red: 0.45, green: 0.55, blue: 0.75))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                isSelected
                                    ? AnyView(
                                        CutShape(cut: 8).fill(
                                            LinearGradient(
                                                colors: [AppTheme.neonPurple, AppTheme.techGlow],
                                                startPoint: .leading, endPoint: .trailing))
                                        .overlay(CutShape(cut: 8).strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
                                    )
                                    : AnyView(Color.clear)
                            )
                            .animation(.easeInOut(duration: 0.12), value: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color.white.opacity(0.06))
            .clipShape(CutShape(cut: 11))
            .overlay(CutShape(cut: 11).strokeBorder(AppTheme.neonPurple.opacity(0.28), lineWidth: 0.8))
            .padding(.bottom, 14)

            let detected = store.selectedVariant == .freefire ? store.detectedBundleID : store.detectedMAXBundleID
            let patchInstalled = store.selectedVariant == .freefire ? store.isPatchInstalled : store.isPatchInstalledMAX

            statusRow(
                icon: "apps.iphone",
                iconColor: detected != nil ? AppTheme.neonCyan : Color(red: 0.45, green: 0.50, blue: 0.68),
                label: store.selectedVariant.rawValue,
                value: detected != nil ? "Đã phát hiện" : "Không tìm thấy",
                valueColor: detected != nil
                    ? Color(red: 0.10, green: 0.90, blue: 0.52)
                    : Color(red: 0.80, green: 0.30, blue: 0.30)
            )

            statusDivider

            statusRow(
                icon: "doc.badge.gearshape",
                iconColor: patchInstalled ? AppTheme.techGlow : Color(red: 0.45, green: 0.50, blue: 0.68),
                label: "Patch file",
                value: patchInstalled ? "Đã cài đặt" : "Chưa cài",
                valueColor: patchInstalled
                    ? Color(red: 0.10, green: 0.90, blue: 0.52)
                    : Color(red: 0.85, green: 0.65, blue: 0.10)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .techCard()
    }

    private func statusRow(icon: String, iconColor: Color, label: String, value: String, valueColor: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, 4)
    }

    private var statusDivider: some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [.clear, AppTheme.techGlow.opacity(0.18), .clear],
                startPoint: .leading, endPoint: .trailing))
            .frame(height: 0.5)
            .padding(.vertical, 9)
    }

    // MARK: - Row divider

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 0.5)
            .padding(.horizontal, 4)
    }

    // MARK: - ESP card

    private var espCard: some View {
        espGroup(title: "ESP", icon: "eye.fill", color: AppTheme.neonCyan) {
            toggleRow("Bật ESP", icon: "power.circle.fill",
                      on: store.enableESP, color: AppTheme.neonCyan) { store.toggle(\.enableESP) }
            rowDivider
            toggleRow("Player Box", icon: "square.dashed",
                      on: store.playerBox, color: AppTheme.techGlow) { store.toggle(\.playerBox) }
            rowDivider
            toggleRow("Top Tracer", icon: "arrow.up.to.line.compact",
                      on: store.topTracer, color: AppTheme.techGlow) { store.toggle(\.topTracer) }
            rowDivider
            toggleRow("Health Bar", icon: "heart.fill",
                      on: store.healthBar, color: Color(red: 0.20, green: 0.92, blue: 0.55)) { store.toggle(\.healthBar) }
            rowDivider
            toggleRow("Player Name", icon: "person.text.rectangle",
                      on: store.playerName, color: Color(red: 0.55, green: 0.72, blue: 1.00)) { store.toggle(\.playerName) }
            rowDivider
            toggleRow("Distance", icon: "ruler",
                      on: store.distance, color: Color(red: 0.90, green: 0.72, blue: 0.20)) { store.toggle(\.distance) }
            rowDivider
            toggleRow("ESP Count", icon: "number.circle.fill",
                      on: store.espCount, color: Color(red: 1.00, green: 0.22, blue: 0.22)) { store.toggle(\.espCount) }
        }
    }

    // MARK: - AIM card

    private var aimCard: some View {
        espGroup(title: "AIM", icon: "scope", color: AppTheme.neonPurple) {
            toggleRow("Silent Aim", icon: "dot.scope",
                      on: store.silentAim, color: AppTheme.neonPurple) { store.toggle(\.silentAim) }
            if store.silentAim {
                rowDivider
                silentFovSliderRow()
            }
            rowDivider
            toggleRow("No Recoil", icon: "waveform.path.ecg",
                      on: store.noRecoil, color: Color(red: 0.85, green: 0.45, blue: 1.00)) { store.toggle(\.noRecoil) }
            rowDivider
            toggleRow("Aim FOV", icon: "viewfinder.circle",
                      on: store.aimFov, color: Color(red: 1.00, green: 0.80, blue: 0.10)) { store.toggle(\.aimFov) }
            if store.aimFov {
                rowDivider
                fovSliderRow()
                rowDivider
                toggleRow("Hide FOV", icon: "eye.slash",
                          on: store.aimFovHide, color: Color(red: 0.60, green: 0.60, blue: 0.60)) { store.toggle(\.aimFovHide) }
                rowDivider
                segmentRow(
                    label: "Nhắm vào", icon: "target",
                    options: ["Thân", "Đầu", "Mix"],
                    selected: Int(store.aimMode),
                    color: Color(red: 1.00, green: 0.80, blue: 0.10)
                ) { store.setAimMode(Int32($0)) }
                if store.aimMode == 2 {
                    rowDivider
                    segmentRow(
                        label: "% Nhắm đầu", icon: "person.crop.circle",
                        options: ["25%", "50%", "75%", "100%"],
                        selected: Int(store.headRate) - 1,
                        color: Color(red: 0.85, green: 0.45, blue: 1.00)
                    ) { store.setHeadRate(Int32($0 + 1)) }
                }
            }
        }
    }

    // MARK: - Settings card (Misc tab)

    private var settingsCard: some View {
        espGroup(title: "MISC", icon: "slider.horizontal.3", color: Color(red: 0.90, green: 0.65, blue: 0.15)) {
            toggleRow("Fast Parachute", icon: "wind",
                      on: store.fastParachute, color: Color(red: 0.90, green: 0.65, blue: 0.15)) { store.toggle(\.fastParachute) }
            rowDivider
            toggleRow("Speed Running ×3", icon: "hare.fill",
                      on: store.speedRunning, color: Color(red: 0.95, green: 0.40, blue: 0.25)) { store.toggle(\.speedRunning) }
            rowDivider
            toggleRow("Fake Dame", icon: "bolt.fill",
                      on: store.fakeDamage, color: Color(red: 1.00, green: 0.22, blue: 0.22)) { store.toggle(\.fakeDamage) }
        }
    }

    // MARK: - Patch button

    private var patchButton: some View {
        let detected = store.selectedVariant == .freefire ? store.detectedBundleID : store.detectedMAXBundleID
        let patchInstalled = store.selectedVariant == .freefire ? store.isPatchInstalled : store.isPatchInstalledMAX

        return VStack(spacing: 6) {
            if patchInstalled && !store.isPatching {
                Button { store.removePatches() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "trash.fill").font(.system(size: 15, weight: .bold))
                        Text("Xóa Patch File Khỏi Game").font(.system(size: 15, weight: .bold)).kerning(0.2)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.75, green: 0.15, blue: 0.15), Color(red: 0.55, green: 0.10, blue: 0.10)],
                            startPoint: .leading, endPoint: .trailing
                        ).clipShape(CutShape(cut: 14))
                    )
                    .overlay(CutShape(cut: 14).strokeBorder(Color.red.opacity(0.45), lineWidth: 1.2))
                    .shadow(color: Color.red.opacity(0.35), radius: 12, y: 4)
                }
                .buttonStyle(.plain)
            } else {
                Button { store.patchGame() } label: {
                    HStack(spacing: 10) {
                        if store.isPatching {
                            ProgressView().scaleEffect(0.85).tint(.white)
                        } else {
                            Image(systemName: "doc.badge.plus").font(.system(size: 16, weight: .bold))
                        }
                        Text(store.isPatching ? "Đang patch..." : "Patch File vào Game")
                            .font(.system(size: 15, weight: .bold)).kerning(0.2)
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
                                startPoint: .leading, endPoint: .trailing)
                            if !store.isPatching {
                                LinearGradient(colors: [.white.opacity(0.12), .clear], startPoint: .top, endPoint: .center)
                            }
                        }.clipShape(CutShape(cut: 14))
                    )
                    .overlay(CutShape(cut: 14).strokeBorder(
                        store.isPatching ? AppTheme.techGlow.opacity(0.25) : AppTheme.neonCyan.opacity(0.55),
                        lineWidth: 1.2))
                    .shadow(color: store.isPatching ? .clear : AppTheme.neonPurple.opacity(0.50), radius: 16, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(store.isPatching || detected == nil)
                .opacity((detected == nil && !store.isPatching) ? 0.45 : 1.0)
            }

            if detected == nil {
                Text("Không tìm thấy \(store.selectedVariant.rawValue) — hãy cài game trước")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(red: 0.55, green: 0.45, blue: 0.68))
                    .multilineTextAlignment(.center)
            }
        }
        .alert(item: $store.patchResult) { result in
            switch result {
            case .success:
                return Alert(title: Text("Patch thành công"), message: Text("Đang mở game..."), dismissButton: .default(Text("OK")))
            case .failure(let msg):
                return Alert(title: Text("Patch thất bại"), message: Text(msg), dismissButton: .default(Text("OK")))
            }
        }
    }

    // MARK: - Group helper

    private func espGroup<Content: View>(
        title: String, icon: String, color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(color)
                Text(title).font(.system(size: 11, weight: .heavy)).foregroundStyle(color.opacity(0.85)).kerning(1.0)
                Spacer()
            }
            .padding(.bottom, 10)
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .techCard()
    }

    // MARK: - Slider rows

    private func silentFovSliderRow() -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(AppTheme.neonPurple.opacity(0.18)).frame(width: 38, height: 38)
                    Image(systemName: "scope").font(.system(size: 16, weight: .semibold)).foregroundStyle(AppTheme.neonPurple)
                }
                Text("Silent FOV").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
                Spacer()
                Text("\(store.silentFov)").font(.system(size: 14, weight: .bold)).foregroundStyle(AppTheme.neonPurple).frame(width: 40, alignment: .trailing)
            }
            .padding(.vertical, 8)
            Slider(value: Binding(get: { Double(store.silentFov) }, set: { store.setSilentFov(Int32($0)) }), in: 50...500, step: 10)
                .tint(AppTheme.neonPurple).padding(.bottom, 8)
        }
    }

    private func fovSliderRow() -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(Color(red: 1.00, green: 0.80, blue: 0.10).opacity(0.18)).frame(width: 38, height: 38)
                    Image(systemName: "circle.dashed").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color(red: 1.00, green: 0.80, blue: 0.10))
                }
                Text("FOV Radius").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
                Spacer()
                Text("\(store.fovRadius)").font(.system(size: 14, weight: .bold)).foregroundStyle(Color(red: 1.00, green: 0.80, blue: 0.10)).frame(width: 36, alignment: .trailing)
            }
            .padding(.vertical, 8)
            Slider(value: Binding(get: { Double(store.fovRadius) }, set: { store.setFovRadius(Int32($0)) }), in: 30...200, step: 5)
                .tint(Color(red: 1.00, green: 0.80, blue: 0.10)).padding(.bottom, 8)
        }
    }

    // MARK: - Segment row

    private func segmentRow(
        label: String, icon: String, options: [String],
        selected: Int, color: Color, onSelect: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9).fill(color.opacity(0.18)).frame(width: 38, height: 38)
                Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(color)
            }
            Text(label).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
            Spacer()
            HStack(spacing: 0) {
                ForEach(options.indices, id: \.self) { i in
                    let isActive = i == selected
                    Button { onSelect(i) } label: {
                        Text(options[i])
                            .font(.system(size: 11, weight: isActive ? .bold : .medium))
                            .foregroundStyle(isActive ? .white : Color(red: 0.45, green: 0.55, blue: 0.75))
                            .padding(.horizontal, 9).padding(.vertical, 6)
                            .background(isActive
                                ? AnyView(Capsule().fill(color.opacity(0.35)).overlay(Capsule().strokeBorder(color.opacity(0.6), lineWidth: 1)))
                                : AnyView(Color.clear))
                            .animation(.easeInOut(duration: 0.10), value: isActive)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3).background(Color.white.opacity(0.07)).clipShape(Capsule())
        }
        .padding(.vertical, 11)
    }

    // MARK: - Toggle row

    private func toggleRow(
        _ label: String, icon: String, on: Bool, color: Color,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(on ? color.opacity(0.22) : Color.white.opacity(0.07))
                    .frame(width: 38, height: 38)
                    .animation(.easeInOut(duration: 0.10), value: on)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(on ? color : Color(red: 0.40, green: 0.48, blue: 0.65))
                    .animation(.easeInOut(duration: 0.10), value: on)
            }
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(on ? .white : Color(red: 0.52, green: 0.60, blue: 0.78))
                .animation(.easeInOut(duration: 0.10), value: on)
            Spacer()
            // Tắt / Bật tab buttons
            HStack(spacing: 0) {
                Button { if on { action() } } label: {
                    Text("Tắt")
                        .font(.system(size: 12, weight: !on ? .bold : .medium))
                        .foregroundStyle(!on ? .white : Color(red: 0.45, green: 0.55, blue: 0.75))
                        .frame(width: 40, height: 28)
                        .background(!on
                            ? AnyView(Capsule().fill(Color(red: 0.30, green: 0.32, blue: 0.45)))
                            : AnyView(Color.clear))
                        .animation(.easeInOut(duration: 0.10), value: on)
                }
                .buttonStyle(.plain)
                Button { if !on { action() } } label: {
                    Text("Bật")
                        .font(.system(size: 12, weight: on ? .bold : .medium))
                        .foregroundStyle(on ? .white : Color(red: 0.45, green: 0.55, blue: 0.75))
                        .frame(width: 40, height: 28)
                        .background(on
                            ? AnyView(Capsule().fill(color.opacity(0.85)))
                            : AnyView(Color.clear))
                        .animation(.easeInOut(duration: 0.10), value: on)
                }
                .buttonStyle(.plain)
            }
            .padding(2).background(Color.white.opacity(0.08)).clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
        }
        .padding(.vertical, 11)
    }
}
