import SwiftUI

struct SplashScreenView: View {
    var onFinished: () -> Void

    @State private var contentOpacity: Double  = 0
    @State private var contentScale:   CGFloat = 0.88
    @State private var screenOpacity:  Double  = 1

    private let gold   = Color(red: 1.00, green: 0.78, blue: 0.20)
    private let gold2  = Color(red: 0.85, green: 0.55, blue: 0.05)
    private let white  = Color.white

    var body: some View {
        ZStack {
            // ── Background image ──
            Image("AppBg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // ── Center content ──
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    // Gamepad icon box
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [gold.opacity(0.18), gold2.opacity(0.08)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 88, height: 88)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(colors: [gold, gold2],
                                                       startPoint: .topLeading,
                                                       endPoint: .bottomTrailing),
                                        lineWidth: 1.5
                                    )
                            )

                        // Orbital ring behind gamepad
                        Ellipse()
                            .stroke(
                                LinearGradient(colors: [gold.opacity(0.9), gold2.opacity(0.3)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 2
                            )
                            .frame(width: 64, height: 22)
                            .rotationEffect(.degrees(-18))

                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(colors: [gold, gold2],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .shadow(color: gold.opacity(0.6), radius: 10)
                    }
                    .shadow(color: gold.opacity(0.35), radius: 20, y: 6)

                    // App name
                    Text("CheatiOSVip")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(
                            LinearGradient(colors: [gold, Color(red: 1.0, green: 0.92, blue: 0.55), gold2],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: gold.opacity(0.5), radius: 12)

                    // Premium pill
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(gold)
                        Text("Premium")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(gold)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(colors: [gold, gold2],
                                               startPoint: .leading, endPoint: .trailing),
                                lineWidth: 1.4
                            )
                    )

                    // Subtitle
                    Text("Nền tảng Patch Game hàng đầu")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.70))
                        .padding(.top, 2)
                }
                .scaleEffect(contentScale)
                .opacity(contentOpacity)

                Spacer()

                // Copyright
                Text("© CanhiOSCrack / ALL Rights Reserved")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(gold.opacity(0.55))
                    .padding(.bottom, 36)
                    .opacity(contentOpacity)
            }
        }
        .opacity(screenOpacity)
        .preferredColorScheme(.dark)
        .onAppear { runSequence() }
    }

    private func runSequence() {
        withAnimation(.spring(response: 0.60, dampingFraction: 0.72).delay(0.15)) {
            contentOpacity = 1
            contentScale   = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.20) {
            withAnimation(.easeInOut(duration: 0.42)) { screenOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) { onFinished() }
        }
    }
}

struct SplashParticle: Identifiable {
    let id = UUID()
    var x, y: CGFloat; var size: CGFloat; var opacity: Double; var speed: Double
    static func spawn(_ count: Int) -> [SplashParticle] { [] }
}
