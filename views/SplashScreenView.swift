import SwiftUI

struct SplashScreenView: View {
    var onFinished: () -> Void

    @State private var screenOpacity: Double = 1
    @State private var rotation: Double = 0

    private let red   = Color(red: 1.00, green: 0.18, blue: 0.38)
    private let rose  = Color(red: 0.85, green: 0.10, blue: 0.28)

    var body: some View {
        ZStack {
            Image("AppBg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // Spinner
            ZStack {
                Circle()
                    .stroke(rose.opacity(0.18), lineWidth: 4)
                    .frame(width: 56, height: 56)

                Circle()
                    .trim(from: 0, to: 0.72)
                    .stroke(
                        LinearGradient(
                            colors: [red, rose.opacity(0.30)],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(rotation))
                    .shadow(color: red.opacity(0.55), radius: 6)
            }
        }
        .opacity(screenOpacity)
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.20) {
                withAnimation(.easeInOut(duration: 0.38)) { screenOpacity = 0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { onFinished() }
            }
        }
    }
}

struct SplashParticle: Identifiable {
    let id = UUID()
    var x, y: CGFloat; var size: CGFloat; var opacity: Double; var speed: Double
    static func spawn(_ count: Int) -> [SplashParticle] { [] }
}
