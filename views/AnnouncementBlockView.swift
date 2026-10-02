import SwiftUI

struct AnnouncementBlockView: View {
    let announcement: Announcement
    var onDismiss: (() -> Void)? = nil
    @Environment(\.appLanguage) private var language

    var body: some View {
        ZStack {
            TechBackground()

            VStack(spacing: 18) {
                Spacer()

                FaceIcon(size: 76, color: Color(red: 0.165, green: 0.388, blue: 0.788), eyebrowText: "HELLO")
                    .shadow(color: Color.blue.opacity(0.45), radius: 16, y: 6)

                if !announcement.title.isEmpty {
                    Text(announcement.title)
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if !announcement.message.isEmpty {
                    Text(announcement.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 12) {
                    if !announcement.linkLabel.isEmpty, !announcement.linkURL.isEmpty, let url = URL(string: announcement.linkURL) {
                        Link(destination: url) {
                            Text(announcement.linkLabel)
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.cyan, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .foregroundStyle(.black)
                        }
                    }
                    if !announcement.link2Label.isEmpty, !announcement.link2URL.isEmpty, let url2 = URL(string: announcement.link2URL) {
                        Link(destination: url2) {
                            Text(announcement.link2Label)
                                .font(.body.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .foregroundStyle(.white)
                        }
                    }

                    Button {
                        onDismiss?()
                    } label: {
                        Text("Đã hiểu")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.85, green: 0.10, blue: 0.28), Color(red: 1.00, green: 0.18, blue: 0.38)],
                                    startPoint: .leading, endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
}
