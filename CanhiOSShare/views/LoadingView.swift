import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            TechBackground()
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(AppTheme.accent.opacity(0.15), lineWidth: 3)
                        .frame(width: 72, height: 72)
                    ProgressView()
                        .tint(AppTheme.accent)
                        .scaleEffect(1.5)
                }
                VStack(spacing: 6) {
                    Text("Cảnh iOS Share")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Đang khởi tạo…")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct ErrorBlockView: View {
    let message: String

    var body: some View {
        ZStack {
            TechBackground()
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.red)
                VStack(spacing: 8) {
                    Text("Không thể khởi động")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
