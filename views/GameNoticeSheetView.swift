import SwiftUI

struct GameNoticeSheetView: View {
    let notice: GameNotice
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.07, blue: 0.14).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                if !notice.title.isEmpty {
                    Text(notice.title)
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.bottom, 14)
                }

                if !notice.message.isEmpty {
                    Text(notice.message)
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.55, green: 0.65, blue: 0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                if !notice.linkLabel.isEmpty, !notice.linkURL.isEmpty, let url = URL(string: notice.linkURL) {
                    Link(notice.linkLabel, destination: url)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.techGlow)
                        .padding(.top, 12)
                }

                Spacer().frame(height: 44)

                Button {
                    onContinue()
                } label: {
                    Text("Đã hiểu")
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

                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .presentationMediumLargeDetent()
        .presentationDragIndicator15(true)
        .preferredColorScheme(.dark)
    }
}
