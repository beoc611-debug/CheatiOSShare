import SwiftUI

/// Full-height bottom sheet popup for a server-pushed announcement, matching the reference
/// "welcome" style: content centered in a mostly-empty sheet, a smiling-face badge icon, title,
/// message, an optional link, and a full-width close button.
struct AnnouncementSheetView: View {
    let announcement: Announcement
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            FaceIcon(size: 76, color: Color(red: 0.165, green: 0.388, blue: 0.788), eyebrowText: "HELLO")
                .shadow(color: Color.blue.opacity(0.45), radius: 16, y: 6)

            if !announcement.title.isEmpty {
                Text(announcement.title)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
            }

            if !announcement.message.isEmpty {
                Text(announcement.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !announcement.linkLabel.isEmpty, !announcement.linkURL.isEmpty, let url = URL(string: announcement.linkURL) {
                Link(announcement.linkLabel, destination: url)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
            }

            Button {
                dismiss()
            } label: {
                Text(language.text("common.close"))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .background(Color.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.white)
            .padding(.top, 6)

            Spacer()
        }
        .padding(.horizontal, 28)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}
