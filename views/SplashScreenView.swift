import SwiftUI

struct SplashScreenView: View {
    var onFinished: () -> Void

    @State private var titleOpacity: Double  = 0
    @State private var barWidth:     CGFloat = 0
    @State private var screenOpacity:Double  = 1

    private let cyan   = Color(red: 0.00, green: 0.88, blue: 1.00)
    private let purple = Color(red: 0.58, green: 0.18, blue: 1.00)

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.04, blue: 0.16),
                    Color(red: 0.03, green: 0.02, blue: 0.10)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App name
                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        Text("Cheati")
                            .font(.system(size: 32, weight: .black))
                            .foregroundStyle(.white)
                        Text("OS")
                            .font(.system(size: 32, weight: .black))
                            .foregroundStyle(cyan)
                        Text("Vip")
                            .font(.system(size: 32, weight: .black))
                            .foregroundStyle(.white)
                    }
                    Text("PREMIUM")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(
                            LinearGradient(colors: [cyan, purple],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                }
                .opacity(titleOpacity)

                Spacer().frame(height: 10)

                Text("Trợ thủ game  ·  An toàn  ·  Ổn định")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.30))
                    .opacity(titleOpacity)

                Spacer()

                // Progress bar
                VStack(spacing: 8) {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.07))
                            .frame(height: 3)
                        Capsule()
                            .fill(LinearGradient(colors: [cyan, purple],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: barWidth, height: 3)
                            .shadow(color: cyan.opacity(0.6), radius: 6)
                    }
                    .frame(maxWidth: 200)
                    .opacity(titleOpacity)
                }
                .padding(.bottom, 52)
            }
            .padding(.horizontal, 32)
        }
        .opacity(screenOpacity)
        .preferredColorScheme(.dark)
        .onAppear { runSequence() }
    }

    private func runSequence() {
        withAnimation(.easeOut(duration: 0.45).delay(0.20)) {
            titleOpacity = 1
        }
        withAnimation(.easeInOut(duration: 1.10).delay(0.55)) {
            barWidth = 200
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.85) {
            withAnimation(.easeInOut(duration: 0.40)) { screenOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onFinished() }
        }
    }
}

// Keep stubs so the compiler won't complain if anything references these
struct SplashParticle: Identifiable {
    let id = UUID()
    var x, y: CGFloat
    var size: CGFloat
    var opacity: Double
    var speed: Double
    static func spawn(_ count: Int) -> [SplashParticle] { [] }
}
