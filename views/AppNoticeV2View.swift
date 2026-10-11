import SwiftUI

struct AppNoticeV2View: View {
    let notice: AppNoticeV2
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                // Header bar
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(red: 1.0, green: 0.80, blue: 0.20))
                        Text(notice.title ?? "THÔNG BÁO")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(.white)
                            .kerning(0.5)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(white: 0.55))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(red: 0.10, green: 0.10, blue: 0.14))

                Rectangle()
                    .fill(Color(red: 1.0, green: 0.80, blue: 0.20).opacity(0.6))
                    .frame(height: 1)

                // Content
                ScrollView {
                    Text(notice.content)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.88))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                .frame(maxHeight: 220)

                // Close button
                Button { dismiss() } label: {
                    Text("Đã hiểu")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.85, green: 0.55, blue: 0.05), Color(red: 0.70, green: 0.38, blue: 0.02)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .padding(.top, 8)
            }
            .background(Color(red: 0.07, green: 0.07, blue: 0.10))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(red: 1.0, green: 0.80, blue: 0.20).opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 24, y: 8)
            .padding(.horizontal, 24)
            .scaleEffect(appeared ? 1.0 : 0.88)
            .opacity(appeared ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                appeared = true
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onDismiss()
        }
    }
}
