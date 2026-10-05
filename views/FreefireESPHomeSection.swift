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
    @State private var showDNSSheet = false
    @State private var uiConfig: UIConfig? = nil
    @State private var showESPToast = false
    @State private var espToastIsOn = false
    @State private var pendingESPCheck = false
    @State private var gameOpenPending = false
    @State private var wasPatching = false
    @State private var showPatchErrorSheet = false
    @State private var patchErrorMsg = ""

    var body: some View {
        VStack(spacing: 14) {
            if tab == 0 {
                statusCard
                patchButton
                dnsButton
            } else if tab == 1 {
                ServerTabView(store: store, sections: uiConfig?.esp ?? [])
            } else {
                ServerTabView(store: store, sections: uiConfig?.misc ?? [])
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .onAppear {
            let cached = PatchHubService.cachedUIConfig()
            if !cached.isEmpty { uiConfig = cached }
        }
        .task {
            while !Task.isCancelled {
                if let fresh = await PatchHubService.fetchUIConfig() {
                    uiConfig = fresh
                }
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
        .onChange(of: store.isPatching) { isNowPatching in
            if !isNowPatching && wasPatching {
                let errors = store.patchLog.filter { $0.level == .err }.count
                if errors == 0 && !store.patchLog.isEmpty {
                    pendingESPCheck = true
                    gameOpenPending = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        guard gameOpenPending else { return }
                        gameOpenPending = false
                        openGame()
                    }
                }
            }
            wasPatching = isNowPatching
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            gameOpenPending = false  // user đã về app → cancel pending openGame
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
                try? await Task.sleep(nanoseconds: 3_000_000_000)
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

    // MARK: - Patch button

    private var patchButton: some View {
        let detected = store.selectedVariant == .freefire ? store.detectedBundleID : store.detectedMAXBundleID
        let patchInstalled = store.selectedVariant == .freefire ? store.isPatchInstalled : store.isPatchInstalledMAX

        return VStack(spacing: 6) {
            if patchInstalled && !store.isPatching {
                Button { store.removePatches() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.uturn.backward.circle.fill").font(.system(size: 15, weight: .bold))
                        Text("Un Patch").font(.system(size: 15, weight: .bold)).kerning15(0.2)
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
                            .font(.system(size: 15, weight: .bold)).kerning15(0.2)
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

        }
    }

    // MARK: - DNS button

    private var dnsButton: some View {
        Button { showDNSSheet = true } label: {
            HStack(spacing: 10) {
                ZStack {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 17, weight: .bold))
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(Color(red: 0.55, green: 0.05, blue: 0.20))
                        .offset(y: 1)
                }
                Text("Download DNS")
                    .font(.system(size: 15, weight: .bold)).kerning15(0.2)
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
                            .font(.system(size: 11, weight: .heavy)).foregroundStyle(orange.opacity(0.80)).kerning15(0.8)
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
        .presentationFractionDetent(0.72)
        .presentationDragIndicator15(false)
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
        .presentationFractionDetent(0.72)
        .presentationDragIndicator15(false)
        .preferredColorScheme(.dark)
    }

    private func stepHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(accent.opacity(0.80))
                .kerning15(0.8)
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

