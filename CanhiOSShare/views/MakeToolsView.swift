import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Màu / định dạng dùng chung

private enum MTStyle {
    static let muted = Color(red: 0.54, green: 0.62, blue: 0.78)
    static let dimText = Color(red: 0.40, green: 0.48, blue: 0.68)
    static let fieldFill = Color(red: 0.03, green: 0.05, blue: 0.11)
    static let danger = Color(red: 0.98, green: 0.44, blue: 0.52)
    static let ok = Color(red: 0.20, green: 0.83, blue: 0.60)
    static let warn = Color(red: 0.99, green: 0.83, blue: 0.30)

    static func number(_ v: Double) -> String {
        var s = String(format: "%.7f", v)
        while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) { s.removeLast() }
        return s == "-0" || s.isEmpty ? "0" : s
    }

    static func hex(_ c: Color) -> String {
        let ui = UIColor(c)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        func byte(_ x: CGFloat) -> Int { Swift.max(0, Swift.min(255, Int((x * 255).rounded()))) }
        return String(format: "#%02X%02X%02X", byte(r), byte(g), byte(b))
    }
}

// MARK: - Màn hình chính của tab

struct MakeToolsView: View {
    @ObservedObject private var store = MakeToolsStore.shared
    @EnvironmentObject private var licenseGate: LicenseGateStore
    @State private var showInfo = false
    @State private var showPicker = false

    // Admin/VIP keys bypass server access check
    private var hasAccess: Bool {
        licenseGate.isVipEligible || store.serverStatus == .online || store.serverStatus == .checking
    }

    var body: some View {
        ZStack(alignment: .top) {
            TechBackground()
            if !hasAccess && store.serverStatus == .noAccess {
                // Only background + lock message, no content behind
                serverOfflineOverlay
            } else {
                VStack(spacing: 0) {
                    header
                    ScrollView {
                        VStack(spacing: 14) {
                            fileCard
                            presetSection
                            simulatorCard
                            tuneCard
                            generateSection
                            resultSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                    }
                    .scrollDismissesKeyboard15()
                }
                .allowsHitTesting(store.serverStatus == .online || store.serverStatus == .checking || licenseGate.isVipEligible)

                if store.serverStatus == .offline {
                    serverOfflineOverlay
                }
            }
        }
        .onAppear { store.checkServer() }
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.item, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let u = urls.first { store.load(url: u) }
            case .failure(let err):
                store.loadError = err.localizedDescription
            }
        }
        .sheet(isPresented: Binding(get: { store.showScanResults }, set: { store.showScanResults = $0 })) {
            GameFileScanSheet(store: store)
        }
        .sheet(isPresented: Binding(get: { store.showBackups }, set: { store.showBackups = $0 })) {
            MakeBackupsSheet(store: store)
        }
    }

    private var serverOfflineOverlay: some View {
        let isNoAccess = store.serverStatus == .noAccess
        let iconName = isNoAccess ? "lock.shield" : "wifi.slash"
        let iconColor = isNoAccess ? Color(red: 1.0, green: 0.60, blue: 0.10) : Color(red: 0.98, green: 0.27, blue: 0.35)
        let title = isNoAccess ? "KHÔNG CÓ QUYỀN TRUY CẬP" : "KHÔNG CÓ SERVER"
        let subtitle = isNoAccess
            ? "Tab này chỉ dùng được với key Admin hoặc key từ Seller Premium.\nLiên hệ admin để được cấp quyền."
            : "Tools Make yêu cầu kết nối server để hoạt động.\nKiểm tra mạng và thử lại."
        return ZStack {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: iconName)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Color(red: 0.60, green: 0.65, blue: 0.78))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                if !isNoAccess {
                    Button {
                        store.checkServer()
                    } label: {
                        HStack(spacing: 8) {
                            if store.serverStatus == .checking {
                                ProgressView().tint(.white).scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(store.serverStatus == .checking ? "Đang kiểm tra…" : "Thử lại")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28).padding(.vertical, 12)
                        .background(
                            LinearGradient(colors: [AppTheme.neonCyan.opacity(0.8), AppTheme.neonPurple.opacity(0.8)],
                                           startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(store.serverStatus == .checking)
                }
            }
        }
    }

    private func openPicker() {
        showPicker = true
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                CutShape(cut: 13)
                    .fill(LinearGradient(colors: [AppTheme.neonCyan.opacity(0.28), AppTheme.neonPurple.opacity(0.18)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 46, height: 46)
                    .overlay(CutShape(cut: 13)
                        .strokeBorder(AppTheme.neonCyan.opacity(0.45), lineWidth: 1))
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [AppTheme.neonCyan, AppTheme.neonPurple], startPoint: .top, endPoint: .bottom))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Tools Make")
                    .font(.system(size: 23, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [Color(red: 0.26, green: 0.55, blue: 1.00), Color(red: 0.48, green: 0.37, blue: 1.00)],
                                                    startPoint: .leading, endPoint: .trailing))
                Text("18 preset aim · mô phỏng trực quan · Free Fire mod")
                    .font(.system(size: 11.5))
                    .foregroundStyle(MTStyle.muted)
            }
            Spacer()
            serverDot
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(red: 0.04, green: 0.05, blue: 0.13))
    }

    private var serverDot: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(serverDotColor.opacity(0.2))
                    .frame(width: 28, height: 28)
                if store.serverStatus == .checking {
                    ProgressView().tint(serverDotColor).scaleEffect(0.65)
                } else {
                    Circle().fill(serverDotColor).frame(width: 8, height: 8)
                }
            }
            Text(serverDotLabel)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(serverDotColor)
        }
    }

    private var serverDotColor: Color {
        if licenseGate.isVipEligible && store.serverStatus == .noAccess { return MTStyle.ok }
        switch store.serverStatus {
        case .checking:  return MTStyle.muted
        case .online:    return MTStyle.ok
        case .offline:   return MTStyle.danger
        case .noAccess:  return MTStyle.warn
        }
    }

    private var serverDotLabel: String {
        if licenseGate.isVipEligible && store.serverStatus == .noAccess { return "ADMIN" }
        switch store.serverStatus {
        case .checking:  return "CHECK"
        case .online:    return "ONLINE"
        case .offline:   return "OFFLINE"
        case .noAccess:  return "NO ACCESS"
        }
    }

    // MARK: File

    private var fileCard: some View {
        VStack(spacing: 10) {
            if store.hasFile || store.fileName != nil {
                loadedFileRow
            } else {
                pickButton
            }
            scanRow

            if store.isLoading {
                HStack(spacing: 8) {
                    ProgressView().tint(AppTheme.neonCyan)
                    Text("Đang đọc bundle…").font(.system(size: 13)).foregroundStyle(MTStyle.muted)
                }
            }
            if let w = store.loadWarning { banner(w, color: MTStyle.warn, icon: "exclamationmark.triangle.fill") }
            if let e = store.loadError { banner(e, color: MTStyle.danger, icon: "xmark.octagon.fill") }
            if store.isUploading {
                HStack(spacing: 8) {
                    ProgressView().tint(AppTheme.neonPurple)
                    Text("Đang tải lên server…").font(.system(size: 12)).foregroundStyle(MTStyle.muted)
                }.transition(.opacity)
            } else if let st = store.uploadStatus, !st.contains("thất bại") || !licenseGate.isVipEligible {
                HStack(spacing: 6) {
                    Image(systemName: st.contains("✓") ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(st.contains("✓") ? MTStyle.ok : MTStyle.warn)
                        .font(.system(size: 12))
                    Text(st).font(.system(size: 12)).foregroundStyle(st.contains("✓") ? MTStyle.ok : MTStyle.warn)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.transition(.opacity)
            }

            if store.hasFile && showInfo && !store.infoRows.isEmpty {
                VStack(spacing: 6) {
                    ForEach(Array(store.infoRows.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .top) {
                            Text(row[0]).font(.system(size: 12)).foregroundStyle(MTStyle.muted).frame(width: 82, alignment: .leading)
                            Text(row[1]).font(.system(size: 12, design: .monospaced)).foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(12)
                .background(MTStyle.fieldFill.opacity(0.7), in: CutShape(cut: 12))
            }
        }
        .padding(14)
        .techCard()
    }

    private var pickButton: some View {
        Button { store.scanGameFiles() } label: {
            HStack(spacing: 14) {
                ZStack {
                    CutShape(cut: 16)
                        .fill(LinearGradient(colors: [AppTheme.neonCyan.opacity(0.20), AppTheme.neonPurple.opacity(0.20)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                        .overlay(CutShape(cut: 16).strokeBorder(AppTheme.neonCyan.opacity(0.4), lineWidth: 1))
                    if store.isScanning {
                        ProgressView().tint(AppTheme.neonCyan).scaleEffect(0.9)
                    } else {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(AppTheme.neonCyan)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.isScanning ? "ĐANG DÒ FILE…" : "DÒ FILE TỪ GAME")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("Free Fire · Free Fire Max · assetindexer · cache_res")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(MTStyle.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(MTStyle.dimText)
            }
            .padding(12)
            .overlay(CutShape(cut: 16)
                .strokeBorder(AppTheme.neonCyan.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, dash: [6, 5])))
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(store.isScanning)
    }

    private var scanRow: some View {
        HStack(spacing: 8) {
            Button { openPicker() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MTStyle.muted)
                    Text("Chọn thủ công")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MTStyle.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.04), in: CutShape(cut: 12))
                .overlay(CutShape(cut: 12).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button { store.showBackups = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MTStyle.warn)
                    Text("Kho gốc")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MTStyle.warn)
                }
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(MTStyle.warn.opacity(0.08), in: CutShape(cut: 12))
                .overlay(CutShape(cut: 12).strokeBorder(MTStyle.warn.opacity(0.22), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var loadedFileRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(MTStyle.ok.opacity(0.16)).frame(width: 40, height: 40)
                Image(systemName: store.hasFile ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(store.hasFile ? MTStyle.ok : MTStyle.warn)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(store.fileName ?? "—")
                    .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    if store.fileSize > 0 {
                        Text(MakeToolsEngine.viNum(store.fileSize) + " byte").font(.system(size: 11.5)).foregroundStyle(MTStyle.ok)
                    }
                    if let d = store.detection, let b = d.build {
                        Text("· " + b).font(.system(size: 11.5)).foregroundStyle(MTStyle.muted)
                    }
                }
            }
            Spacer(minLength: 6)
            if store.hasFile {
                Button { withAnimation { showInfo.toggle() } } label: {
                    Image(systemName: showInfo ? "chevron.up.circle.fill" : "info.circle")
                        .font(.system(size: 20)).foregroundStyle(MTStyle.muted)
                }
                .buttonStyle(.plain)
            }
            Button { store.scanGameFiles() } label: {
                HStack(spacing: 5) {
                    if store.isScanning {
                        ProgressView().tint(.white).scaleEffect(0.7)
                    }
                    Text(store.isScanning ? "Đang dò…" : "Đổi file")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(LinearGradient(colors: [AppTheme.neonPurple, AppTheme.techGlow], startPoint: .leading, endPoint: .trailing), in: Capsule())
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(store.isScanning)
        }
    }

    private func banner(_ text: String, color: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 13))
            Text(text).font(.system(size: 12.5)).foregroundStyle(color).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(11)
        .background(color.opacity(0.09), in: CutShape(cut: 12))
        .overlay(CutShape(cut: 12).strokeBorder(color.opacity(0.35), lineWidth: 1))
    }

    // MARK: Chọn preset

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CHỌN CHỨC NĂNG")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking15(1.2)
                    .foregroundStyle(AppTheme.neonCyan)
                Spacer()
                Text("\(store.visiblePresets.count) / \(MakeToolsCatalog.all.count)")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(MTStyle.dimText)
            }
            filterChips
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(store.visiblePresets) { p in presetCard(p) }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("Tất cả", color: .white, on: store.filter == nil && !store.showCompatibleOnly) {
                    store.filter = nil
                    store.showCompatibleOnly = false
                }
                if store.hasFile && store.detection?.kind != nil {
                    chip("✓ Dùng được", color: MTStyle.ok, on: store.showCompatibleOnly) {
                        store.showCompatibleOnly.toggle()
                        if store.showCompatibleOnly { store.filter = nil }
                    }
                }
                ForEach(MakeCategory.allCases) { c in
                    chip(c.title, color: c.color, on: store.filter == c) {
                        store.filter = c
                        store.showCompatibleOnly = false
                    }
                }
            }
        }
    }

    private func chip(_ title: String, color: Color, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7).shadow(color: color, radius: 3)
                Text(title).font(.system(size: 12.5, weight: .bold))
            }
            .foregroundStyle(on ? Color.white : MTStyle.muted)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(on ? color.opacity(0.18) : Color.white.opacity(0.05), in: Capsule())
            .overlay(Capsule().strokeBorder(on ? color : Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func presetCard(_ p: MakePreset) -> some View {
        let selected = store.selectedID == p.id
        let ok = store.isCompatible(p)
        let scene = MakeSimBuilder.build(p.id, gender: .male, store: store, mini: true)
        let accent = p.category.color
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { store.selectedID = p.id }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    CutShape(cut: 12)
                        .fill(LinearGradient(colors: [Color(red: 0.04, green: 0.07, blue: 0.14), Color(red: 0.02, green: 0.04, blue: 0.09)],
                                             startPoint: .top, endPoint: .bottom))
                    MakeSimCanvas(scene: scene, mini: true)
                        .padding(4)
                    Text(p.number)
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(selected ? Color.black : Color.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(selected ? accent : Color.black.opacity(0.55), in: CutShape(cut: 7))
                        .padding(6)
                }
                .frame(height: 96)

                Text(p.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 34, alignment: .topLeading)
                Text(p.line)
                    .font(.system(size: 10.5))
                    .foregroundStyle(MTStyle.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 28, alignment: .topLeading)
                HStack(spacing: 4) {
                    Circle().fill(ok ? MTStyle.ok : MTStyle.dimText).frame(width: 6, height: 6)
                    Text(ok ? "Dùng được" : "cần " + p.needLabel)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ok ? MTStyle.ok : MTStyle.dimText)
                }
            }
            .padding(9)
            .frame(width: 158)
            .background(AppTheme.techCardFill.opacity(0.9), in: CutShape(cut: 16))
            .overlay(CutShape(cut: 16)
                .strokeBorder(selected ? accent : Color.white.opacity(0.08), lineWidth: selected ? 1.6 : 1))
            .shadow(color: selected ? accent.opacity(0.35) : .clear, radius: 10, y: 3)
            .opacity(ok || selected ? 1 : 0.72)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.97))
    }

    // MARK: Mô phỏng

    private var simulatorCard: some View {
        let p = store.selected
        let scene = MakeSimBuilder.build(p.id, gender: store.gender, store: store, mini: false)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle().fill(scene.accent).frame(width: 6, height: 6).shadow(color: scene.accent, radius: 4)
                        Text("MÔ PHỎNG TRỰC QUAN · PRESET " + p.number)
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .tracking15(1)
                            .foregroundStyle(scene.accent)
                    }
                    Text(p.name).font(.system(size: 19, weight: .heavy)).foregroundStyle(.white)
                }
                Spacer(minLength: 8)
                if scene.showGender { genderToggle(scene.accent) }
            }

            ZStack {
                CutShape(cut: 18)
                    .fill(LinearGradient(colors: [Color(red: 0.03, green: 0.06, blue: 0.12), Color(red: 0.02, green: 0.03, blue: 0.08)],
                                         startPoint: .top, endPoint: .bottom))
                stageGrid
                MakeSimStage(store: store, scene: scene)
                    .clipShape(CutShape(cut: 18))
                VStack {
                    HStack {
                        HStack(spacing: 7) {
                            Text("VÙNG AIM").font(.system(size: 9.5, weight: .bold, design: .monospaced)).foregroundStyle(scene.accent)
                            Text(scene.chip).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.black.opacity(0.6), in: CutShape(cut: 9))
                        .overlay(CutShape(cut: 9).strokeBorder(scene.accent.opacity(0.55), lineWidth: 1))
                        Spacer()
                    }
                    Spacer()
                    if !scene.note.isEmpty {
                        Text(scene.note)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(MTStyle.warn)
                            .multilineTextAlignment(.center)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(Color(red: 0.16, green: 0.10, blue: 0.02).opacity(0.85), in: CutShape(cut: 10))
                    }
                    HStack {
                        Spacer()
                        if store.isDraggable {
                            hintTag("↕ Kéo trên hình để đổi vị trí hitbox", scene.accent)
                        } else if p.id == "3" || p.id == "4" {
                            hintTag("Đổi màu ở mục TÙY CHỈNH bên dưới", scene.accent)
                        }
                    }
                }
                .padding(10)
                .allowsHitTesting(false)
            }
            .frame(height: 350)
            .overlay(CutShape(cut: 18).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))

            Text(p.desc)
                .font(.system(size: 13.5))
                .foregroundStyle(Color(red: 0.73, green: 0.78, blue: 0.86))
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 6) {
                ForEach(scene.legend) { l in
                    HStack(spacing: 6) {
                        CutShape(cut: 3).fill(l.color).frame(width: 10, height: 10)
                            .overlay(CutShape(cut: 3).strokeBorder(Color.white.opacity(0.5), lineWidth: 1))
                        Text(l.text).font(.system(size: 11.5)).foregroundStyle(MTStyle.muted)
                    }
                }
            }
            Text("Hình minh hoạ dựng từ đúng thông số trong script (vị trí x, scale, radius…). Tỉ lệ cơ thể chỉ mang tính minh hoạ.")
                .font(.system(size: 10.5)).foregroundStyle(MTStyle.dimText)
        }
        .padding(14)
        .techCard()
    }

    private var stageGrid: some View {
        Canvas { ctx, size in
            var p = Path()
            var x: CGFloat = 0
            while x < size.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height)); x += 25 }
            var y: CGFloat = 0
            while y < size.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y)); y += 25 }
            ctx.stroke(p, with: .color(Color.white.opacity(0.04)), lineWidth: 1)
        }
        .clipShape(CutShape(cut: 18))
        .allowsHitTesting(false)
    }

    private func hintTag(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Color.black.opacity(0.7), in: CutShape(cut: 8))
            .overlay(CutShape(cut: 8).strokeBorder(color.opacity(0.45), lineWidth: 1))
    }

    private func genderToggle(_ accent: Color) -> some View {
        HStack(spacing: 2) {
            ForEach([MakeGender.male, MakeGender.female], id: \.rawValue) { g in
                Button { store.gender = g } label: {
                    Text(g == .male ? "Nam" : "Nữ")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(store.gender == g ? Color.black : MTStyle.muted)
                        .padding(.horizontal, 13).padding(.vertical, 6)
                        .background(store.gender == g ? accent : Color.clear, in: CutShape(cut: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.black.opacity(0.35), in: CutShape(cut: 11))
        .overlay(CutShape(cut: 11).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func specsGrid(_ scene: MakeSimScene) -> some View {
        var rows: [[MakeSimSpec]] = []
        var pending: MakeSimSpec?
        for s in scene.specs {
            if s.wide {
                if let p = pending { rows.append([p]); pending = nil }
                rows.append([s])
            } else if let p = pending {
                rows.append([p, s]); pending = nil
            } else {
                pending = s
            }
        }
        if let p = pending { rows.append([p]) }
        return VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row) { s in specCell(s, accent: scene.accent) }
                    if row.count == 1 && !row[0].wide { Spacer().frame(maxWidth: .infinity) }
                }
            }
        }
    }

    private func specCell(_ s: MakeSimSpec, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(s.key.uppercased()).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(MTStyle.muted)
            Text(s.value).font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(s.highlight ? accent : .white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 11).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.035), in: CutShape(cut: 11))
        .overlay(CutShape(cut: 11).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
    }

    // MARK: Tùy chỉnh

    private var tuneCard: some View {
        let p = store.selected
        let accent = p.category.color
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "slider.horizontal.3").foregroundStyle(accent)
                Text("TÙY CHỈNH")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking15(1.2)
                    .foregroundStyle(accent)
                Text("đổi thông số → hình mô phỏng đổi ngay")
                    .font(.system(size: 11)).foregroundStyle(MTStyle.muted)
                Spacer()
                if !p.fields.isEmpty {
                    Button { store.reset(p) } label: {
                        Text("Mặc định").font(.system(size: 11.5, weight: .bold)).foregroundStyle(accent)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(accent.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if p.fields.isEmpty {
                Text("Preset này không có ô tinh chỉnh — chỉ cần chọn file rồi bấm tạo.")
                    .font(.system(size: 12.5)).foregroundStyle(MTStyle.muted)
            } else {
                if !p.tuneTitle.isEmpty {
                    Text(p.tuneTitle).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                }
                let nums = p.fields.filter { $0.kind == .number }
                if !nums.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], alignment: .leading, spacing: 10) {
                        ForEach(nums) { f in MakeNumberField(field: f, store: store, accent: accent).id(p.id + f.id) }
                    }
                }
                ForEach(p.fields.filter { $0.kind == .color }) { f in MakeColorField(field: f, store: store, accent: accent) }
                ForEach(p.fields.filter { $0.kind == .slider }) { f in MakeSliderField(field: f, store: store, accent: accent) }
                ForEach(p.fields.filter { $0.kind == .toggle }) { f in
                    Toggle(isOn: Binding(get: { store.flags[f.id] ?? f.flag }, set: { store.flags[f.id] = $0 })) {
                        Text(f.label).font(.system(size: 13.5, weight: .medium)).foregroundStyle(.white)
                    }
                    .tint(accent)
                }
            }
        }
        .padding(14)
        .techCard()
    }

    // MARK: Tạo file

    private var generateSection: some View {
        let p = store.selected
        let can = store.canGenerate
        return VStack(spacing: 8) {
            Button { store.generate() } label: {
                HStack(spacing: 10) {
                    if store.isBusy { ProgressView().tint(.black) } else { Image(systemName: "bolt.fill") }
                    Text(store.isBusy ? "ĐANG XỬ LÝ…" : "TẠO FILE MOD NGAY")
                        .font(.system(size: 16, weight: .black)).tracking15(0.8)
                }
                .foregroundStyle(Color(red: 0.01, green: 0.06, blue: 0.10))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient(colors: [AppTheme.neonCyan, AppTheme.techGlow, AppTheme.neonPurple], startPoint: .leading, endPoint: .trailing),
                            in: CutShape(cut: 16))
                .overlay(CutShape(cut: 16).strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                .shadow(color: AppTheme.neonCyan.opacity(0.35), radius: 14, y: 4)
                .opacity(can ? 1 : 0.4)
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(!can)

            if !store.hasFile {
                Text("Chọn file bundle ở trên để bắt đầu.").font(.system(size: 12)).foregroundStyle(MTStyle.muted)
            } else if !store.isCompatible(p) {
                Text("Preset này cần file \(p.needLabel) — file đang mở không phù hợp. Chọn preset có nhãn \"Dùng được\".")
                    .font(.system(size: 12)).foregroundStyle(MTStyle.warn).multilineTextAlignment(.center)
            }
        }
    }

    // MARK: Kết quả

    @ViewBuilder
    private var resultSection: some View {
        if let err = store.resultError {
            banner(err, color: MTStyle.danger, icon: "xmark.octagon.fill")
        }
        if let res = store.result {
            VStack(alignment: .leading, spacing: 12) {
                banner(res.note, color: MTStyle.ok, icon: "checkmark.circle.fill")

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(store.resultStats.enumerated()), id: \.offset) { _, s in
                        HStack(alignment: .top) {
                            Text(s[0]).font(.system(size: 12)).foregroundStyle(MTStyle.muted).frame(width: 90, alignment: .leading)
                            Text(s[1]).font(.system(size: 12, design: .monospaced)).foregroundStyle(.white)
                        }
                    }
                }
                Text("Chép đè thẳng lên file cũ:")
                    .font(.system(size: 11.5)).foregroundStyle(MTStyle.muted)
                Text(store.fileName ?? "")
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(.white)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.4), in: CutShape(cut: 10))

                // Patch vào game ngay
                if store.canPatchGame || store.isPatchingGame || store.patchGameResult != nil {
                    patchGameButton
                }

                Button { presentShare() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text("LƯU / CHIA SẺ FILE ĐÃ SỬA").font(.system(size: 13.5, weight: .heavy))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Color.white.opacity(0.08), in: CutShape(cut: 14))
                    .overlay(CutShape(cut: 14).strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(PressScaleButtonStyle())
            }
            .padding(14)
            .techCard()
        }
    }

    @ViewBuilder
    private var patchGameButton: some View {
        let isOk = store.patchGameResult == "ok"
        let isErr = store.patchGameResult?.hasPrefix("err:") == true
        let errMsg = store.patchGameResult.flatMap { $0.hasPrefix("err:") ? String($0.dropFirst(4)) : nil }

        VStack(spacing: 8) {
            Button { store.patchGameFile() } label: {
                HStack(spacing: 10) {
                    if store.isPatchingGame {
                        ProgressView().tint(.black)
                    } else if isOk {
                        Image(systemName: "checkmark.circle.fill")
                    } else {
                        Image(systemName: "gamecontroller.fill")
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.isPatchingGame ? "ĐANG GHI VÀO GAME…" : isOk ? "ĐÃ PATCH THÀNH CÔNG" : "PATCH VÀO GAME NGAY")
                            .font(.system(size: 15, weight: .black)).tracking15(0.5)
                        if let gn = store.sourceGameName {
                            Text(gn + (store.sourceGameHint.map { " · " + $0 } ?? ""))
                                .font(.system(size: 11, weight: .semibold))
                                .opacity(0.75)
                        }
                    }
                    Spacer()
                }
                .foregroundStyle(isOk ? Color.black : Color(red: 0.01, green: 0.06, blue: 0.10))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(
                    isOk
                    ? LinearGradient(colors: [MTStyle.ok, Color(red: 0.02, green: 0.59, blue: 0.41)], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [AppTheme.neonCyan, AppTheme.techGlow, AppTheme.neonPurple], startPoint: .leading, endPoint: .trailing),
                    in: CutShape(cut: 14)
                )
                .shadow(color: (isOk ? MTStyle.ok : AppTheme.neonCyan).opacity(0.35), radius: 12, y: 4)
                .opacity(store.canPatchGame || store.isPatchingGame || isOk ? 1 : 0.5)
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(!store.canPatchGame)

            if isErr, let msg = errMsg {
                banner(msg, color: MTStyle.danger, icon: "xmark.octagon.fill")
            }
            if isOk {
                Text("File đã được ghi đè vào game. Mở game để thấy hiệu lực.")
                    .font(.system(size: 11.5)).foregroundStyle(MTStyle.ok).multilineTextAlignment(.center)
            }
        }
    }

    private func presentShare() {
        guard let url = store.writeResultFile() else { return }
        let ac = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        var presenter = root
        while let next = presenter.presentedViewController { presenter = next }
        presenter.present(ac, animated: true)
    }
}

// MARK: - Các ô nhập

private struct MakeNumberField: View {
    let field: MakeField
    @ObservedObject var store: MakeToolsStore
    let accent: Color
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(field.label)
                .font(.system(size: 11)).foregroundStyle(MTStyle.muted)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            ZStack(alignment: .leading) {
                if !focused {
                    Text("••••")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .padding(.horizontal, 10).padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { focused = true }
                } else {
                    TextField("", text: $text)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .focused($focused)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 9)
                }
            }
            .background(MTStyle.fieldFill, in: CutShape(cut: 9))
            .overlay(CutShape(cut: 9)
                .strokeBorder(focused ? accent : Color.white.opacity(0.12), lineWidth: 1))
        }
        .onAppear { text = MTStyle.number(store.values[field.id] ?? field.num) }
        .onChange(of: focused) { isFocused in
            if isFocused { text = MTStyle.number(store.values[field.id] ?? field.num) }
        }
        .onChange(of: text) { new in
            let norm = new.replacingOccurrences(of: ",", with: ".")
            if let d = Double(norm), store.values[field.id] != d { store.values[field.id] = d }
        }
        .onChange(of: store.values[field.id]) { v in
            if !focused, let v = v { text = MTStyle.number(v) }
        }
    }
}

private struct MakeSliderField: View {
    let field: MakeField
    @ObservedObject var store: MakeToolsStore
    let accent: Color

    var body: some View {
        let value = store.values[field.id] ?? field.num
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(field.label).font(.system(size: 12)).foregroundStyle(MTStyle.muted)
                Spacer()
                Text(String(format: field.step < 1 && field.step.truncatingRemainder(dividingBy: 0.5) != 0 ? "%.2f" : "%.1f", value))
                    .font(.system(size: 12.5, weight: .bold, design: .monospaced)).foregroundStyle(.white)
            }
            Slider(value: Binding(get: { store.values[field.id] ?? field.num }, set: { store.values[field.id] = $0 }),
                   in: field.range, step: field.step)
                .tint(accent)
        }
    }
}

private struct MakeColorField: View {
    let field: MakeField
    @ObservedObject var store: MakeToolsStore
    let accent: Color

    var body: some View {
        let hexValue = store.hexes[field.id] ?? field.hex
        VStack(alignment: .leading, spacing: 5) {
            Text(field.label).font(.system(size: 12)).foregroundStyle(MTStyle.muted)
            HStack(spacing: 10) {
                ColorPicker("", selection: Binding(
                    get: { Color(hex: store.hexes[field.id] ?? field.hex) ?? .white },
                    set: { store.hexes[field.id] = MTStyle.hex($0) }), supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 44, height: 36)
                TextField("#RRGGBB", text: Binding(
                    get: { store.hexes[field.id] ?? field.hex },
                    set: { store.hexes[field.id] = $0.uppercased() }))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 9)
                    .background(MTStyle.fieldFill, in: CutShape(cut: 9))
                    .overlay(CutShape(cut: 9)
                        .strokeBorder(Color(hex: hexValue) == nil ? MTStyle.danger : Color.white.opacity(0.12), lineWidth: 1))
            }
        }
    }
}

// MARK: - Scan sheet

private struct GameFileScanSheet: View {
    @ObservedObject var store: MakeToolsStore
    @Environment(\.dismiss) private var dismiss

    private static let bg = Color(red: 0.04, green: 0.05, blue: 0.13)

    var body: some View {
        NavigationView {
            ZStack {
                Self.bg.ignoresSafeArea()
                if store.scannedFiles.isEmpty {
                    emptyState
                } else {
                    fileList
                }
            }
            .navigationTitle("File tìm thấy (\(store.scannedFiles.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { dismiss() }.foregroundStyle(AppTheme.neonCyan)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass").font(.system(size: 44)).foregroundStyle(MTStyle.muted)
            Text("Không tìm thấy file Unity").font(.title3.bold()).foregroundStyle(.white)
            Text("Đảm bảo Free Fire hoặc Free Fire Max đã được cài và tải đủ dữ liệu game (vào game 1 lần để game tải về).")
                .font(.system(size: 13.5)).foregroundStyle(MTStyle.muted)
                .multilineTextAlignment(.center).padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fileList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(store.scannedFiles) { file in
                    Button {
                        store.loadFromScanned(file)
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                CutShape(cut: 10)
                                    .fill(hintColor(file.hint).opacity(0.15))
                                    .frame(width: 42, height: 42)
                                Image(systemName: hintIcon(file.hint))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(hintColor(file.hint))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(file.name)
                                    .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white).lineLimit(2)
                                HStack(spacing: 6) {
                                    Text(file.gameName).font(.system(size: 11)).foregroundStyle(AppTheme.neonCyan)
                                    Text("·").foregroundStyle(MTStyle.dimText)
                                    Text(file.hint).font(.system(size: 11, weight: .semibold)).foregroundStyle(hintColor(file.hint))
                                    Text("·").foregroundStyle(MTStyle.dimText)
                                    Text(MakeToolsEngine.viNum(Int(file.size)) + " byte")
                                        .font(.system(size: 11)).foregroundStyle(MTStyle.muted)
                                }
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(MTStyle.dimText)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.04), in: CutShape(cut: 14))
                        .overlay(CutShape(cut: 14).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                    }
                    .buttonStyle(PressScaleButtonStyle(scale: 0.98))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }

    private func hintColor(_ hint: String) -> Color {
        switch hint {
        case "Hitbox": return MTStyle.ok
        case "UMA / Aim": return AppTheme.neonCyan
        default: return AppTheme.neonPurple
        }
    }

    private func hintIcon(_ hint: String) -> String {
        switch hint {
        case "Hitbox": return "person.crop.circle.fill.badge.checkmark"
        case "UMA / Aim": return "scope"
        default: return "paintpalette.fill"
        }
    }
}

// MARK: - Kho file gốc

private struct MakeBackupsSheet: View {
    @ObservedObject var store: MakeToolsStore
    @Environment(\.dismiss) private var dismiss
    @State private var backups: [MakeBackup] = []
    @State private var toast: String?
    @State private var isRestoring = false

    private func exportBackup(_ b: MakeBackup) {
        let url = MakeToolsStore.backupDir.appendingPathComponent(b.localFile)
        guard FileManager.default.fileExists(atPath: url.path) else {
            showToast("❌ File không còn tồn tại")
            return
        }
        let ac = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        var presenter = root
        while let next = presenter.presentedViewController { presenter = next }
        presenter.present(ac, animated: true)
    }

    private static let bg = Color(red: 0.04, green: 0.05, blue: 0.13)
    private static let df: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short; return f
    }()

    var body: some View {
        NavigationView {
            ZStack {
                Self.bg.ignoresSafeArea()
                if backups.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "archivebox").font(.system(size: 44)).foregroundStyle(MTStyle.muted)
                        Text("Chưa có file gốc nào").font(.title3.bold()).foregroundStyle(.white)
                        Text("Khi bạn dò file từ game và load lên, app tự lưu file gốc vào đây để bạn khôi phục bất cứ lúc nào.")
                            .font(.system(size: 13.5)).foregroundStyle(MTStyle.muted)
                            .multilineTextAlignment(.center).padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(backups) { backup in
                                backupRow(backup)
                            }
                        }
                        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 28)
                    }
                }
                if let msg = toast {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Color.black.opacity(0.85), in: Capsule())
                            .padding(.bottom, 40)
                    }
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }
            }
            .navigationTitle("Kho file gốc (\(backups.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { dismiss() }.foregroundStyle(AppTheme.neonCyan)
                }
            }
        }
        .onAppear { backups = store.loadBackupIndex() }
    }

    private func backupRow(_ b: MakeBackup) -> some View {
        HStack(spacing: 12) {
            ZStack {
                CutShape(cut: 10)
                    .fill(hintColor(b.hint).opacity(0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(hintColor(b.hint))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(b.fileName)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white).lineLimit(2)
                HStack(spacing: 6) {
                    Text(b.gameName).font(.system(size: 11)).foregroundStyle(AppTheme.neonCyan)
                    Text("·").foregroundStyle(MTStyle.dimText)
                    Text(b.hint).font(.system(size: 11)).foregroundStyle(hintColor(b.hint))
                    Text("·").foregroundStyle(MTStyle.dimText)
                    Text(MakeToolsEngine.viNum(b.fileSize) + " B").font(.system(size: 11)).foregroundStyle(MTStyle.muted)
                }
                Text(Self.df.string(from: b.backupDate))
                    .font(.system(size: 10.5, design: .monospaced)).foregroundStyle(MTStyle.dimText)
            }
            Spacer(minLength: 4)
            Button {
                isRestoring = true
                store.restoreBackup(b) { ok, msg in
                    isRestoring = false
                    showToast(ok ? "✓ " + msg : "❌ " + msg)
                }
            } label: {
                Text(isRestoring ? "…" : "Khôi phục")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(MTStyle.warn.opacity(0.18), in: Capsule())
                    .overlay(Capsule().strokeBorder(MTStyle.warn.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(isRestoring)

            Button {
                exportBackup(b)
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.neonCyan)
            }
            .buttonStyle(.plain)

            Button {
                store.deleteBackup(b)
                withAnimation { backups = store.loadBackupIndex() }
            } label: {
                Image(systemName: "trash").font(.system(size: 14)).foregroundStyle(MTStyle.danger)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white.opacity(0.04), in: CutShape(cut: 14))
        .overlay(CutShape(cut: 14).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func showToast(_ msg: String) {
        withAnimation { toast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { toast = nil } }
    }

    private func hintColor(_ hint: String) -> Color {
        switch hint {
        case "Hitbox": return MTStyle.ok
        case "UMA / Aim": return AppTheme.neonCyan
        default: return AppTheme.neonPurple
        }
    }
}
