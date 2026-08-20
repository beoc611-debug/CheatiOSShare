import SwiftUI

struct GameNoticeSheetView: View {
    let notice: GameNotice
    let onContinue: () -> Void
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.neonPurple.opacity(0.18))
                    .frame(width: 80, height: 80)
                    .blur(radius: 10)
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.neonPurple, AppTheme.techGlow],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: AppTheme.neonPurple.opacity(0.55), radius: 14, y: 4)
            }

            if !notice.title.isEmpty {
                Text(notice.title)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
            }

            if !notice.message.isEmpty {
                Text(notice.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !notice.linkLabel.isEmpty, !notice.linkURL.isEmpty, let url = URL(string: notice.linkURL) {
                Link(notice.linkLabel, destination: url)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.techGlow)
            }

            Button {
                onContinue()
            } label: {
                Text("Đã hiểu, tiếp tục")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.neonPurple, AppTheme.techGlow],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .shadow(color: AppTheme.neonPurple.opacity(0.40), radius: 10, y: 3)
            }
            .padding(.top, 6)

            Spacer()
        }
        .padding(.horizontal, 28)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}
