import SwiftUI
import Darwin
import UIKit

struct FreefireESPHomeSection: View {
    @ObservedObject var store: FreefireESPStore
    /// 0 = Home (status + patch), 1 = ESP/AIM, 2 = Misc (settings)
    var tab: Int = 0

    @State private var statCPU: Int = 0
    @State private var statRAMPct: Int = 0
    @State private var statRAMUsedMB: Int = 0
    @State private var showLog = false
    @State private var showDNSSheet = false
    @State private var showESPToast = false
    @State private var espToastIsOn = false
    @State private var pendingESPCheck = false
    @State private var wasPatching = false
    @State private var showPatchErrorSheet = false
    @State private var patchErrorMsg = ""

    var body: some View {
        Group {
            if tab == 0 {
                VStack(spacing: 14) {
                    statusCard
                    patchButton
                    dnsButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            } else if tab == 1 {
                ScrollView {
                    ServerTabView(store: store, sections: store.uiConfig.esp)
                }
            } else {
                ScrollView {
                    ServerTabView(store: store, sections: store.uiConfig.misc)
                }
            }
        }
        .task(id: tab) {
            if (tab == 1 || tab == 2) && store.uiConfig.isEmpty {
                await store.fetchUIConfig()
            }
        }
        .onChange(of: store.isPatching) { isNowPatching in
            if !isNowPatching && wasPatching {
                let errors = store.patchLog.filter { $0.level == .err }.count
                if errors == 0 && !store.patchLog.isEmpty {
                    pendingESPCheck = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        openGame()
                    }
                }
            }
            wasPatching = isNowPatching
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            guard pendingESPCheck else { return }
            pendingESPCheck = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                let statusStr = store.checkESPStatus() ?? ""
                espToastIsOn = statusStr.hasPrefix("✅")
                showESPToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                    showESPToast = false
                }
            }
        }
        .onReceive(store.$patchResult) { result in
            guard let result = result else { return }
            if case .failure(let msg) = result {
                patchErrorMsg = msg
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showPatchErrorSheet = true
                }
            }
        }
        .sheet(isPresented: $showESPToast) {
            ESPResultSheet(isOn: espToastIsOn, onDismiss: { showESPToast = false })
        }
        .sheet(isPresented: $showPatchErrorSheet) {
            PatchErrorSheet(message: patchErrorMsg, onDismiss: { showPatchErrorSheet = false })
        }
    }

    // MARK: - Open game helper

    private func openGame() {
        let bundleID = store.selectedVariant == .freefire
            ? (store.detectedBundleID ?? "com.dts.freefireth")
            : (store.detectedMAXBundleID ?? "com.dts.freefiremax")
        // Private API (works on TrollStore / sideloaded)
        if let wsClass = NSClassFromString("LSApplicationWorkspace"),
           let ws = (wsClass as AnyObject).perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() {
            let sel = NSSelectorFromString("openApplicationWithBundleID:")
            if (ws as AnyObject).responds(to: sel) {
                _ = (ws as AnyObject).perform(sel, with: bundleID)
                return
            }
        }
        // URL scheme fallback
        for scheme in ["freefire://", "garena://"] {
            if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url); return
            }
        }
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

            statusDivider

            let cpuColor: Color = statCPU < 40
                ? Color(red: 0.10, green: 0.90, blue: 0.52)
                : (statCPU < 70 ? Color(red: 1.00, green: 0.80, blue: 0.10) : Color(red: 1.00, green: 0.25, blue: 0.25))
            statusRow(
                icon: "cpu",
                iconColor: cpuColor,
                label: "CPU (app)",
                value: "\(statCPU)%",
                valueColor: cpuColor
            )

            statusDivider

            let ramColor: Color = statRAMPct < 60
                ? Color(red: 0.10, green: 0.90, blue: 0.52)
                : (statRAMPct < 80 ? Color(red: 1.00, green: 0.80, blue: 0.10) : Color(red: 1.00, green: 0.25, blue: 0.25))
            statusRow(
                icon: "memorychip",
                iconColor: ramColor,
                label: "RAM (hệ thống)",
                value: "\(statRAMPct)%  \(statRAMUsedMB)MB",
                valueColor: ramColor
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .techCard()
        .task {
            while !Task.isCancelled {
                updateSystemStats()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func updateSystemStats() {
        // RAM system-wide via host_statistics64
        var vmInfo = vm_statistics64_data_t()
        var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        withUnsafeMutablePointer(to: &vmInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                _ = host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmCount)
            }
        }
        let pgSize = UInt64(vm_page_size)
        let total = ProcessInfo.processInfo.physicalMemory
        let free = (UInt64(vmInfo.free_count) + UInt64(vmInfo.inactive_count)) * pgSize
        let used = total > free ? total - free : 0
        statRAMPct = total > 0 ? Int(used * 100 / total) : 0
        statRAMUsedMB = Int(used / 1_048_576)

        // CPU: sum across this app's threads
        var threads: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        guard task_threads(mach_task_self_, &threads, &threadCount) == KERN_SUCCESS,
              let threadList = threads else { return }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: threadList),
                          vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.size))
        }
        var totalCPU: Double = 0
        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var infoCount = mach_msg_type_number_t(MemoryLayout<thread_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
            let kr = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                    thread_info(threadList[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &infoCount)
                }
            }
            if kr == KERN_SUCCESS && (info.flags & TH_FLAGS_IDLE) == 0 {
                totalCPU += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
            }
        }
        statCPU = min(Int(totalCPU), 999)
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

    // MARK: - ESP Color helpers

    private static let espElements = ["Line", "Box", "Health", "Name", "Distance", "Count", "Skeleton", "FOV"]

    private func currentColorBinding() -> Binding<Color> {
        Binding(
            get: {
                switch self.store.selectedEspElement {
                case 0: return self.store.lineColor
                case 1: return self.store.boxColor
                case 2: return self.store.healthColor
                case 3: return self.store.nameColor
                case 4: return self.store.distColor
                case 5: return self.store.countColor
                case 6: return self.store.skeletonColor
                default: return self.store.fovColor
                }
            },
            set: { newColor in
                switch self.store.selectedEspElement {
                case 0: self.store.lineColor     = newColor
                case 1: self.store.boxColor      = newColor
                case 2: self.store.healthColor   = newColor
                case 3: self.store.nameColor     = newColor
                case 4: self.store.distColor     = newColor
                case 5: self.store.countColor    = newColor
                case 6: self.store.skeletonColor = newColor
                default: self.store.fovColor     = newColor
                }
                self.store.flushStatePublic()
            }
        )
    }

    private func currentColor() -> Color {
        switch store.selectedEspElement {
        case 0: return store.lineColor
        case 1: return store.boxColor
        case 2: return store.healthColor
        case 3: return store.nameColor
        case 4: return store.distColor
        case 5: return store.countColor
        case 6: return store.skeletonColor
        default: return store.fovColor
        }
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
            toggleRow("Skeleton ESP", icon: "figure.walk",
                      on: store.showSkeleton, color: Color(red: 0.00, green: 1.00, blue: 1.00)) { store.toggle(\.showSkeleton) }
            rowDivider
            toggleRow("ESP Count", icon: "number.circle.fill",
                      on: store.espCount, color: Color(red: 1.00, green: 0.22, blue: 0.22)) { store.toggle(\.espCount) }
        }
    }

    // MARK: - ESP Color card

    private var espColorCard: some View {
        let accentColor = Color(red: 0.55, green: 0.80, blue: 1.00)
        return espGroup(title: "ESP COLOR", icon: "paintpalette.fill", color: accentColor) {
            // Toggle
            toggleRow("ESP Color", icon: "paintpalette.fill",
                      on: store.espColorEnabled, color: accentColor) { store.toggle(\.espColorEnabled) }

            if store.espColorEnabled {
                rowDivider

                // Element picker row
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(accentColor.opacity(0.18)).frame(width: 38, height: 38)
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }
                    Text("Element")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
                    Spacer()
                    // Color circle preview
                    Circle()
                        .fill(currentColor())
                        .frame(width: 20, height: 20)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
                    // Element stepper
                    HStack(spacing: 0) {
                        Button {
                            store.selectedEspElement = (store.selectedEspElement + Self.espElements.count - 1) % Self.espElements.count
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(accentColor)
                                .frame(width: 28, height: 30)
                        }.buttonStyle(.plain)
                        Text(Self.espElements[store.selectedEspElement])
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 54)
                        Button {
                            store.selectedEspElement = (store.selectedEspElement + 1) % Self.espElements.count
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(accentColor)
                                .frame(width: 28, height: 30)
                        }.buttonStyle(.plain)
                    }
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                }
                .padding(.vertical, 11)

                rowDivider

                // Full color picker (iOS 14+ native — shows color wheel + sliders)
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(currentColor().opacity(0.3)).frame(width: 38, height: 38)
                        Image(systemName: "circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(currentColor())
                    }
                    ColorPicker(
                        Self.espElements[store.selectedEspElement],
                        selection: currentColorBinding(),
                        supportsOpacity: false
                    )
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
                }
                .padding(.vertical, 8)

                // Health info note (no separate thickness — follows Box)
                if store.selectedEspElement == 2 {
                    rowDivider
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(Color.white.opacity(0.07)).frame(width: 38, height: 38)
                            Image(systemName: "info.circle")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
                        }
                        Text("Health bar width tự theo Box")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                // Thickness slider (Line=0, Box=1, Name=3, Skeleton=6)
                if store.selectedEspElement == 0 || store.selectedEspElement == 1 || store.selectedEspElement == 3 || store.selectedEspElement == 6 {
                    rowDivider
                    let isName = store.selectedEspElement == 3
                    let elemName = Self.espElements[store.selectedEspElement]
                    let thickBinding = Binding<Double>(
                        get: {
                            if self.store.selectedEspElement == 0 { return Double(self.store.lineThicknessRaw) }
                            if self.store.selectedEspElement == 3 { return Double(self.store.nameThicknessRaw) }
                            if self.store.selectedEspElement == 6 { return Double(self.store.skelThicknessRaw) }
                            return Double(self.store.boxThicknessRaw)
                        },
                        set: { v in
                            let raw = Int32(v)
                            if self.store.selectedEspElement == 0 { self.store.lineThicknessRaw = raw }
                            else if self.store.selectedEspElement == 3 { self.store.nameThicknessRaw = raw }
                            else if self.store.selectedEspElement == 6 { self.store.skelThicknessRaw = raw }
                            else { self.store.boxThicknessRaw = raw }
                            self.store.flushStatePublic()
                        }
                    )
                    let rawVal: Int32 = store.selectedEspElement == 0 ? store.lineThicknessRaw
                        : (store.selectedEspElement == 3 ? store.nameThicknessRaw
                        : (store.selectedEspElement == 6 ? store.skelThicknessRaw : store.boxThicknessRaw))
                    let displayVal = isName
                        ? String(format: "%.1fx", 1.0 + Double(rawVal) * 0.02)
                        : String(format: "%.1f px", 0.5 + Double(rawVal) * 0.2)

                    VStack(spacing: 2) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(accentColor.opacity(0.18)).frame(width: 38, height: 38)
                                Image(systemName: isName ? "textformat.size" : "lineweight")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(accentColor)
                            }
                            Text(isName ? "Name size" : "\(elemName) thickness")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.78))
                            Spacer()
                            Text(displayVal)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(accentColor)
                                .frame(width: 52, alignment: .trailing)
                        }
                        .padding(.vertical, 8)
                        Slider(value: thickBinding, in: 1...97, step: 1)
                            .tint(accentColor)
                            .padding(.bottom, 8)
                    }
                }
            }
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
                        Image(systemName: "arrow.uturn.backward.circle.fill").font(.system(size: 15, weight: .bold))
                        Text("Un Patch").font(.system(size: 15, weight: .bold)).kerning(0.2)
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
                                    ? [Color(red: 0.18, green: 0.04, blue: 0.07), Color(red: 0.12, green: 0.03, blue: 0.05)]
                                    : [Color(red: 0.85, green: 0.10, blue: 0.28), Color(red: 1.00, green: 0.28, blue: 0.50)],
                                startPoint: .leading, endPoint: .trailing)
                            if !store.isPatching {
                                LinearGradient(colors: [.white.opacity(0.14), .clear], startPoint: .top, endPoint: .center)
                            }
                        }.clipShape(CutShape(cut: 14))
                    )
                    .overlay(CutShape(cut: 14).strokeBorder(
                        store.isPatching ? AppTheme.techGlow.opacity(0.20) : AppTheme.neonCyan.opacity(0.55),
                        lineWidth: 1.2))
                    .shadow(color: store.isPatching ? .clear : AppTheme.techGlow.opacity(0.50), radius: 16, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(store.isPatching || detected == nil)
                .opacity((detected == nil && !store.isPatching) ? 0.45 : 1.0)
            }

            if detected == nil {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 1.0, green: 0.65, blue: 0.10).opacity(0.18))
                            .frame(width: 38, height: 38)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(red: 1.0, green: 0.70, blue: 0.10))
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Không tìm thấy \(store.selectedVariant.rawValue)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 1.0, green: 0.80, blue: 0.35))
                        Text("Hãy cài game lên thiết bị trước khi sử dụng tính năng này.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color(red: 0.70, green: 0.65, blue: 0.50))
                        Text("⚠︎ Có khả năng thiết bị của bạn không nằm trong danh sách hỗ trợ của phiên bản iOS này.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(red: 1.0, green: 0.70, blue: 0.10).opacity(0.80))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(red: 1.0, green: 0.65, blue: 0.10).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(red: 1.0, green: 0.70, blue: 0.10).opacity(0.30), lineWidth: 1))
            }

            if !store.patchLog.isEmpty {
                Button { showLog = true } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Xem log patch")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        let errors = store.patchLog.filter { $0.level == .err }.count
                        let warns  = store.patchLog.filter { $0.level == .warn }.count
                        if errors > 0 {
                            Text("\(errors) lỗi").font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(red: 1, green: 0.3, blue: 0.3))
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Color(red: 1, green: 0.3, blue: 0.3).opacity(0.15))
                                .clipShape(Capsule())
                        } else if warns > 0 {
                            Text("\(warns) cảnh báo").font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(red: 1, green: 0.75, blue: 0.1))
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Color(red: 1, green: 0.75, blue: 0.1).opacity(0.15))
                                .clipShape(Capsule())
                        } else {
                            Text("OK").font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(red: 0.1, green: 0.9, blue: 0.52))
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Color(red: 0.1, green: 0.9, blue: 0.52).opacity(0.15))
                                .clipShape(Capsule())
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.neonCyan.opacity(0.85))
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(AppTheme.neonCyan.opacity(0.07))
                    .clipShape(CutShape(cut: 10))
                    .overlay(CutShape(cut: 10).strokeBorder(AppTheme.neonCyan.opacity(0.22), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showLog) {
            PatchLogSheet(store: store, entries: store.patchLog) { store.clearLog() }
        }
    }

    // MARK: - DNS button

    private var dnsButton: some View {
        Button { showDNSSheet = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 15, weight: .bold))
                Text("Download DNS")
                    .font(.system(size: 15, weight: .bold)).kerning(0.2)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.55, green: 0.05, blue: 0.20), Color(red: 0.75, green: 0.12, blue: 0.35)],
                    startPoint: .leading, endPoint: .trailing)
                .clipShape(CutShape(cut: 14))
            )
            .overlay(CutShape(cut: 14).strokeBorder(Color(red: 1.00, green: 0.25, blue: 0.50).opacity(0.45), lineWidth: 1.2))
            .shadow(color: Color(red: 0.85, green: 0.10, blue: 0.28).opacity(0.35), radius: 14, y: 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDNSSheet) {
            ZStack {
                Color(red: 0.05, green: 0.02, blue: 0.03).ignoresSafeArea()
                NextDNSView()
            }
            .preferredColorScheme(.dark)
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
            Slider(value: Binding(get: { Double(store.fovRadius) }, set: { store.setFovRadius(Int32($0)) }), in: 30...500, step: 10)
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

    // MARK: - Toggle row (see bottom of file for PatchLogSheet)

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

// MARK: - Patch Error Sheet

private struct PatchErrorSheet: View {
    let message: String
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let orange = Color(red: 1.00, green: 0.65, blue: 0.10)

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.13).ignoresSafeArea()
            Circle()
                .fill(RadialGradient(colors: [orange.opacity(0.18), .clear],
                                     center: .center, startRadius: 0, endRadius: 180))
                .frame(width: 360, height: 360).offset(y: -60).blur(radius: 20)

            VStack(spacing: 0) {
                Capsule().fill(Color.white.opacity(0.18)).frame(width: 36, height: 4)
                    .padding(.top, 12).padding(.bottom, 20)

                ZStack {
                    Circle().fill(orange.opacity(0.18)).frame(width: 80, height: 80)
                    Circle().strokeBorder(orange.opacity(0.40), lineWidth: 1.5).frame(width: 80, height: 80)
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 36, weight: .bold)).foregroundStyle(orange)
                }
                .padding(.bottom, 14)

                Text("Patch thất bại")
                    .font(.system(size: 20, weight: .heavy)).foregroundStyle(orange)
                    .padding(.bottom, 6)
                Text("Đã xảy ra lỗi khi ghi file vào game")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                    .padding(.bottom, 20)

                // Steps card
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("CÓ THỂ LÀM GÌ?")
                            .font(.system(size: 11, weight: .heavy)).foregroundStyle(orange.opacity(0.80)).kerning(0.8)
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

                    stepRow(num: "1", icon: "arrow.uturn.backward.circle.fill",
                            color: Color(red: 1.0, green: 0.75, blue: 0.15),
                            title: "Thử bấm Patch lại",
                            desc: "Đóng bảng này và bấm 'Patch File vào Game' một lần nữa.")
                    divider
                    stepRow(num: "2", icon: "gamecontroller.fill",
                            color: Color(red: 0.55, green: 0.72, blue: 1.0),
                            title: "Mở Free Fire trước, rồi quay lại patch",
                            desc: "Đảm bảo game đã khởi động ít nhất một lần để hệ thống nhận dạng đúng đường dẫn.")
                    divider
                    stepRow(num: "3", icon: "trash.circle.fill",
                            color: Color(red: 0.80, green: 0.40, blue: 1.0),
                            title: "Xoá dữ liệu game rồi mở lại",
                            desc: "Vào Cài đặt → Cổng ứng dụng → Free Fire → Xoá dữ liệu app → mở lại game một lần rồi thử patch.")
                    if !message.isEmpty && !message.hasPrefix("Không tìm") {
                        divider
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14)).foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                                .padding(.top, 1)
                            Text(message)
                                .font(.system(size: 12)).foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                }
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(orange.opacity(0.20), lineWidth: 1))
                .padding(.horizontal, 16).padding(.bottom, 24)

                Button { dismiss(); onDismiss() } label: {
                    Text("Đã hiểu")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(LinearGradient(
                            colors: [Color(red: 0.50, green: 0.30, blue: 0.05), Color(red: 0.38, green: 0.22, blue: 0.03)],
                            startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(orange.opacity(0.45), lineWidth: 1.2))
                }
                .buttonStyle(.plain).padding(.horizontal, 16).padding(.bottom, 20)
            }
        }
        .presentationDetents([.fraction(0.72)])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5).padding(.leading, 58)
    }

    private func stepRow(num: String, icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.18)).frame(width: 38, height: 38)
                Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(num).font(.system(size: 10, weight: .heavy)).foregroundStyle(color)
                        .frame(width: 16, height: 16).background(color.opacity(0.20)).clipShape(Circle())
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                }
                Text(desc).font(.system(size: 12)).foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

// MARK: - ESP Result Sheet

private struct ESPResultSheet: View {
    let isOn: Bool
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let green  = Color(red: 0.10, green: 0.92, blue: 0.55)
    private let red    = Color(red: 1.00, green: 0.38, blue: 0.38)
    private let accent: Color

    init(isOn: Bool, onDismiss: @escaping () -> Void) {
        self.isOn = isOn
        self.onDismiss = onDismiss
        self.accent = isOn
            ? Color(red: 0.10, green: 0.92, blue: 0.55)
            : Color(red: 1.00, green: 0.38, blue: 0.38)
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.13).ignoresSafeArea()
            // glow
            Circle()
                .fill(RadialGradient(
                    colors: [accent.opacity(0.22), .clear],
                    center: .center, startRadius: 0, endRadius: 200))
                .frame(width: 400, height: 400)
                .offset(y: -60)
                .blur(radius: 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // handle
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 36, height: 4)
                        .padding(.top, 12)
                        .padding(.bottom, 20)

                    // icon
                    ZStack {
                        Circle().fill(accent.opacity(0.18)).frame(width: 88, height: 88)
                        Circle().strokeBorder(accent.opacity(0.40), lineWidth: 1.5).frame(width: 88, height: 88)
                        Image(systemName: isOn ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(accent)
                    }
                    .padding(.bottom, 16)

                    // title
                    Text(isOn ? "ESP đang hoạt động ✅" : "ESP chưa kích hoạt ❌")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(accent)
                        .padding(.bottom, 6)

                    Text(isOn
                        ? "Patch thành công — tính năng đã sẵn sàng trong game"
                        : "Cần thêm một vài bước để kích hoạt ESP")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 22)

                    // steps card
                    VStack(alignment: .leading, spacing: 0) {
                        stepHeader(isOn ? "Những gì bạn có thể làm" : "Hướng dẫn kích hoạt lại")

                        if isOn {
                            stepRow(num: "1", icon: "gamecontroller.fill", color: green,
                                    title: "Vào Free Fire và chơi bình thường",
                                    desc: "ESP đã sẵn sàng — mở game và bắt đầu trận là thấy ngay.")
                            divider
                            stepRow(num: "2", icon: "app.badge.fill", color: Color(red: 0.55, green: 0.72, blue: 1.0),
                                    title: "Không tắt app bằng đa nhiệm",
                                    desc: "Khi chơi game, đừng vuốt lên bỏ app trong màn hình đa nhiệm. Chỉ cần nhấn Home hoặc chuyển sang game là đủ.")
                            divider
                            stepRow(num: "3", icon: "arrow.clockwise.circle.fill", color: Color(red: 0.80, green: 0.65, blue: 1.0),
                                    title: "Khi nào cần patch lại?",
                                    desc: "Nếu game được cập nhật hoặc ESP tự dưng tắt thì bấm Patch lại là ổn.")
                        } else {
                            stepRow(num: "1", icon: "arrow.uturn.backward.circle.fill", color: Color(red: 1.0, green: 0.75, blue: 0.15),
                                    title: "Quay lại và bấm Patch lại",
                                    desc: "Đóng bảng này → bấm 'Patch File vào Game' một lần nữa.")
                            divider
                            stepRow(num: "2", icon: "gamecontroller.fill", color: Color(red: 0.55, green: 0.72, blue: 1.0),
                                    title: "Mở Free Fire, vào đến màn hình chính",
                                    desc: "App sẽ tự mở game. Đợi vào đến màn hình lobby, không cần vào trận.")
                            divider
                            stepRow(num: "3", icon: "clock.arrow.circlepath", color: Color(red: 0.80, green: 0.65, blue: 1.0),
                                    title: "Chờ vài giây rồi quay lại đây",
                                    desc: "Để game chạy khoảng 10 giây rồi switch về app — bảng thông báo sẽ tự hiện.")
                            divider
                            stepRow(num: "4", icon: "creditcard.fill", color: red,
                                    title: "Vẫn TẮT? Kiểm tra tài khoản Premium",
                                    desc: "Có thể tài khoản đã hết hạn hoặc chưa kích hoạt trên thiết bị này. Xem thông tin key ở cuối màn hình chính.")
                        }
                    }
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(accent.opacity(0.20), lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                    // dismiss
                    Button {
                        dismiss(); onDismiss()
                    } label: {
                        Text(isOn ? "Vào game thôi!" : "Đã hiểu, thử lại")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                LinearGradient(
                                    colors: isOn
                                        ? [Color(red: 0.05, green: 0.52, blue: 0.28), Color(red: 0.03, green: 0.38, blue: 0.20)]
                                        : [Color(red: 0.52, green: 0.10, blue: 0.10), Color(red: 0.38, green: 0.07, blue: 0.07)],
                                    startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(accent.opacity(0.45), lineWidth: 1.2))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .presentationDetents([.fraction(0.72)])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }

    private func stepHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(accent.opacity(0.80))
                .kerning(0.8)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 0.5)
            .padding(.leading, 58)
    }

    private func stepRow(num: String, icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(num)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(color)
                        .frame(width: 16, height: 16)
                        .background(color.opacity(0.20))
                        .clipShape(Circle())
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(desc)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(red: 0.52, green: 0.63, blue: 0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - Patch Log Sheet

private struct PatchLogSheet: View {
    let store: FreefireESPStore
    let entries: [PatchLogEntry]
    let onClear: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var espStatus: String? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.12).ignoresSafeArea()

                VStack(spacing: 0) {
                    // ESP status banner
                    if let status = espStatus {
                        let isOn = status.hasPrefix("✅")
                        HStack(spacing: 8) {
                            Text(status)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isOn
                                    ? Color(red: 0.10, green: 0.95, blue: 0.55)
                                    : Color(red: 1.0, green: 0.55, blue: 0.55))
                            Spacer()
                            Button {
                                espStatus = store.checkESPStatus()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color(red: 0.5, green: 0.65, blue: 1.0))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            isOn
                                ? Color(red: 0.05, green: 0.22, blue: 0.12)
                                : Color(red: 0.22, green: 0.06, blue: 0.06)
                        )
                    }

                    if entries.isEmpty && espStatus == nil {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 36))
                                .foregroundStyle(Color(red: 0.35, green: 0.40, blue: 0.55))
                            Text("Không có log")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color(red: 0.40, green: 0.48, blue: 0.65))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(entries) { entry in
                                    logRow(entry)
                                    Rectangle()
                                        .fill(Color.white.opacity(0.05))
                                        .frame(height: 0.5)
                                        .padding(.leading, 44)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle("Log Patch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { dismiss() }
                        .foregroundStyle(AppTheme.neonCyan)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            espStatus = store.checkESPStatus()
                        } label: {
                            Label("Check ESP", systemImage: "bolt.shield")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(Color(red: 0.4, green: 0.85, blue: 1.0))
                        Button("Xóa") {
                            onClear()
                            espStatus = nil
                        }
                        .foregroundStyle(Color(red: 1, green: 0.4, blue: 0.4))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func logRow(_ entry: PatchLogEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(iconBg(entry.level))
                    .frame(width: 28, height: 28)
                Image(systemName: iconName(entry.level))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(iconColor(entry.level))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(textColor(entry.level))
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.time)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color(red: 0.38, green: 0.44, blue: 0.58))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    private func iconName(_ level: PatchLogEntry.Level) -> String {
        switch level {
        case .ok:   return "checkmark"
        case .err:  return "xmark"
        case .warn: return "exclamationmark"
        case .info: return "info"
        }
    }

    private func iconColor(_ level: PatchLogEntry.Level) -> Color {
        switch level {
        case .ok:   return Color(red: 0.10, green: 0.90, blue: 0.52)
        case .err:  return Color(red: 1.00, green: 0.30, blue: 0.30)
        case .warn: return Color(red: 1.00, green: 0.75, blue: 0.10)
        case .info: return Color(red: 0.45, green: 0.65, blue: 1.00)
        }
    }

    private func iconBg(_ level: PatchLogEntry.Level) -> Color {
        iconColor(level).opacity(0.15)
    }

    private func textColor(_ level: PatchLogEntry.Level) -> Color {
        switch level {
        case .ok:   return Color(red: 0.88, green: 0.95, blue: 0.90)
        case .err:  return Color(red: 1.00, green: 0.60, blue: 0.60)
        case .warn: return Color(red: 1.00, green: 0.88, blue: 0.55)
        case .info: return Color(red: 0.70, green: 0.78, blue: 0.92)
        }
    }
}
