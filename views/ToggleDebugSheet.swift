import SwiftUI

struct ToggleDebugSheet: View {
    let logs: [String]
    let onClear: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.07, green: 0.08, blue: 0.12).ignoresSafeArea()

                if logs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "ladybug")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.purple.opacity(0.6))
                        Text("Chưa có log nào")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(white: 0.45))
                        Text("Bật một chức năng để xem log inject")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(white: 0.30))
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(logs.enumerated()), id: \.offset) { _, entry in
                                Text(entry)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(textColor(for: entry))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 4)
                                    .background(rowBg(for: entry))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                }
            }
            .navigationTitle("Toggle Debug Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xóa") { onClear() }
                        .foregroundStyle(Color.red.opacity(0.8))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func textColor(for entry: String) -> Color {
        if entry.contains("❌") { return Color(red: 1.0, green: 0.38, blue: 0.38) }
        if entry.contains("✓")  { return Color(red: 0.28, green: 0.90, blue: 0.52) }
        if entry.contains("⚠")  { return Color(red: 1.0, green: 0.75, blue: 0.20) }
        if entry.contains("⏳") || entry.contains("🗑") { return Color(white: 0.55) }
        if entry.contains("▶")  { return Color(red: 0.55, green: 0.75, blue: 1.0) }
        return Color(white: 0.70)
    }

    private func rowBg(for entry: String) -> Color {
        if entry.contains("❌") { return Color(red: 1.0, green: 0.20, blue: 0.20).opacity(0.10) }
        if entry.contains("✓")  { return Color(red: 0.10, green: 0.80, blue: 0.40).opacity(0.07) }
        return Color.white.opacity(0.03)
    }
}
