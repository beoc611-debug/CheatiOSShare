import SwiftUI

/// A hard, un-dismissable block shown instead of everything else — including the key-entry
/// screen — while the web admin has maintenance mode switched on. There is deliberately no close
/// button and no navigation off this screen.
struct MaintenanceView: View {
    let notice: MaintenanceNotice
    @Environment(\.appLanguage) private var language

    var body: some View {
        ZStack {
            TechBackground()

            VStack(spacing: 18) {
                Spacer()

                FaceIcon(size: 88, color: Color(red: 0.96, green: 0.76, blue: 0.16), isSad: true)
                    .shadow(color: Color(red: 0.96, green: 0.76, blue: 0.16).opacity(0.4), radius: 18, y: 6)

                Text(notice.title.isEmpty ? language.text("maintenance.default_title") : notice.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text(notice.message.isEmpty ? language.text("maintenance.default_message") : notice.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
}
