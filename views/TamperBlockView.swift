import SwiftUI

/// Full-screen, non-dismissable block shown when dylib injection is detected.
/// Device is automatically reported to server and banned.
struct TamperBlockView: View {
    var body: some View {
        ZStack {
            TechBackground()

            VStack(spacing: 20) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color(red: 0.98, green: 0.27, blue: 0.35).opacity(0.15))
                        .frame(width: 88, height: 88)
                        .blur(radius: 10)
                    Image(systemName: "shield.slash.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(Color(red: 0.98, green: 0.27, blue: 0.35))
                }

                VStack(spacing: 10) {
                    Text("THIẾT BỊ BỊ KHÓA")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.white)

                    Text("Phát hiện file tiêm trái phép vào ứng dụng.\nThiết bị đã bị báo cáo và khóa vĩnh viễn.\nLiên hệ admin: t.me/canhioscrack")
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.55, green: 0.60, blue: 0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if let url = URL(string: "https://t.me/canhioscrack") {
                    Link(destination: url) {
                        Text("Liên hệ Admin")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                }

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
}
