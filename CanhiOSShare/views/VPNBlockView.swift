import SwiftUI

/// Hard-blocks the app when VPN or proxy is detected.
/// Shows the reason and a Retry button — dismissed automatically once the user
/// turns off VPN/proxy and taps Retry (or the monitor fires again).
struct VPNBlockView: View {
    let isVPN: Bool
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            TechBackground()

            VStack(spacing: 18) {
                Spacer()

                FaceIcon(size: 88, color: Color(red: 0.96, green: 0.26, blue: 0.26), isSad: true)
                    .shadow(color: Color(red: 0.96, green: 0.26, blue: 0.26).opacity(0.45), radius: 18, y: 6)

                Text(isVPN ? "VPN đang bật" : "Proxy đang bật")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(isVPN
                     ? "Tắt VPN rồi mở lại app để tiếp tục sử dụng."
                     : "Tắt proxy trong Cài đặt > Wi-Fi rồi mở lại app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                Spacer()

                Button(action: onRetry) {
                    Text("Thử lại")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.96, green: 0.26, blue: 0.26).opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(red: 0.96, green: 0.26, blue: 0.26).opacity(0.5), lineWidth: 1)
                        )
                        .cornerRadius(14)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.dark)
    }
}
