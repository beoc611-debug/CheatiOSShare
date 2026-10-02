import SwiftUI

struct ServerTabView: View {
    @ObservedObject var store: FreefireESPStore
    let sections: [UIConfigSection]

    var body: some View {
        if sections.isEmpty {
            emptyState
        } else {
            VStack(spacing: 14) {
                ForEach(sections) { section in
                    sectionCard(section)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(AppTheme.techGlow.opacity(0.4))
            Text("Đang tải cấu hình...")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.55, green: 0.45, blue: 0.50))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - Section card

    private func sectionCard(_ section: UIConfigSection) -> some View {
        VStack(spacing: 0) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: section.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(section.accentColor)
                Text(section.title.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(section.accentColor.opacity(0.85))
                    .kerning(1.0)
                Spacer()
            }
            .padding(.bottom, 12)

            VStack(spacing: 8) {
                ForEach(visibleItems(in: section)) { item in
                    itemRow(item, accent: section.accentColor)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .techCard()
    }

    // MARK: - Item row

    @ViewBuilder
    private func itemRow(_ item: UIConfigItem, accent: Color) -> some View {
        switch item.type {
        case "toggle":
            toggleRow(item, accent: accent)
        default:
            EmptyView()
        }
    }

    private func toggleRow(_ item: UIConfigItem, accent: Color) -> some View {
        let isOn = store.boolValue(for: item.id)
        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(item.accentColor.opacity(isOn ? 0.20 : 0.10))
                    .frame(width: 36, height: 36)
                Image(systemName: item.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(item.accentColor.opacity(isOn ? 1.0 : 0.45))
            }

            Text(item.label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isOn ? .white : Color(red: 0.60, green: 0.50, blue: 0.52))
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: Binding(
                get: { store.boolValue(for: item.id) },
                set: { _ in store.toggleById(item.id) }
            ))
            .labelsHidden()
            .tint(item.accentColor)
            .scaleEffect(0.85)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { store.toggleById(item.id) }
    }

    // MARK: - Visibility filter

    private func visibleItems(in section: UIConfigSection) -> [UIConfigItem] {
        section.items.filter { item in
            guard let showIf = item.showIf, !showIf.isEmpty else { return true }
            let parentOn = store.boolValue(for: showIf)
            let expectedVal = item.showIfVal ?? "true"
            return expectedVal == "true" ? parentOn : !parentOn
        }
    }
}
