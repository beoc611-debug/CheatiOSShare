import SwiftUI

struct VPNBlockView: View {
    let isVPN: Bool
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            TechBackground()
            VStack(spacing: 28) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(AppTheme.red.opacity(0.12))
                        .frame(width: 100, height: 100)
                    Image(systemName: isVPN ? "shield.slash.fill" : "network.slash")
                        .font(.system(size: 44))
                        .foregroundStyle(AppTheme.red)
                }
                VStack(spacing: 10) {
                    Text(isVPN ? "Phát hiện VPN" : "Phát hiện Proxy")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(isVPN
                         ? "Tắt VPN trước khi dùng Cảnh iOS Share để đảm bảo an toàn."
                         : "Tắt proxy hệ thống trước khi dùng Cảnh iOS Share.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                Button(action: onRetry) {
                    Text("Kiểm tra lại")
                        .font(.headline)
                        .foregroundStyle(AppTheme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 32)
                .buttonStyle(PressScaleButtonStyle())
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
}
