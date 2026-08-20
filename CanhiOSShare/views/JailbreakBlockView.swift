import SwiftUI

struct JailbreakBlockView: View {
    let onRecheck: () -> Void

    var body: some View {
        ZStack {
            TechBackground()

            VStack(spacing: 18) {
                Spacer()

                FaceIcon(size: 88, color: Color(red: 0.96, green: 0.26, blue: 0.26), isSad: true)
                    .shadow(color: Color(red: 0.96, green: 0.26, blue: 0.26).opacity(0.45), radius: 18, y: 6)

                Text("Thiết bị đã Jailbreak")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("App không hỗ trợ thiết bị đã jailbreak.\nVui lòng gỡ jailbreak để tiếp tục sử dụng.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                Spacer()

                Button(action: onRecheck) {
                    Text("Kiểm tra lại")
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
