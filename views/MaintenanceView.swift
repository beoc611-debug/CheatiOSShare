import SwiftUI

/// A hard, un-dismissable block shown instead of everything else — including the key-entry
/// screen — while the web admin has maintenance mode switched on. There is deliberately no close
/// button and no navigation off this screen.
struct MaintenanceView: View {
    let notice: MaintenanceNotice
    @Environment(\.appLanguage) private var language

    private let accent = Color(red: 0.96, green: 0.76, blue: 0.16)

    var body: some View {
        ZStack {
            TechBackground()
            Color.black.opacity(0.72).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    FaceIcon(size: 80, color: accent, isSad: true)
                        .shadow(color: accent.opacity(0.6), radius: 20, y: 4)

                    VStack(spacing: 10) {
                        Text(notice.title.isEmpty ? language.text("maintenance.default_title") : notice.title)
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text(notice.message.isEmpty ? language.text("maintenance.default_message") : notice.message)
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 8)

                    if !notice.link1Label.isEmpty, !notice.link1URL.isEmpty, let url1 = URL(string: notice.link1URL) {
                        Link(destination: url1) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle.fill")
                                Text(notice.link1Label)
                                    .font(.body.weight(.bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.black)
                        }
                    }
                    if !notice.link2Label.isEmpty, !notice.link2URL.isEmpty, let url2 = URL(string: notice.link2URL) {
                        Link(destination: url2) {
                            Text(notice.link2Label)
                                .font(.body.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(accent.opacity(0.35), lineWidth: 1.5)
                        )
                )
                .padding(.horizontal, 24)
                .shadow(color: .black.opacity(0.5), radius: 30, y: 10)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
}
