import SwiftUI

struct SplashScreenView: View {
    var onFinished: () -> Void

    @State private var logoScale:    CGFloat = 0.3
    @State private var logoOpacity:  Double  = 0
    @State private var ring1Scale:   CGFloat = 0.4
    @State private var ring2Scale:   CGFloat = 0.4
    @State private var ring1Opacity: Double  = 0
    @State private var ring2Opacity: Double  = 0
    @State private var titleOpacity: Double  = 0
    @State private var titleOffset:  CGFloat = 30
    @State private var tagOpacity:   Double  = 0
    @State private var progressVal:  CGFloat = 0
    @State private var progressOp:   Double  = 0
    @State private var screenOpacity:Double  = 1
    @State private var glowPulse:    Bool    = false
    @State private var particles:    [SplashParticle] = SplashParticle.spawn(60)
    @State private var burstActive:  Bool    = false

    private let accent = Color(red: 0.30, green: 0.70, blue: 1.00)
    private let purple = Color(red: 0.65, green: 0.20, blue: 1.00)
    private let cyan   = Color(red: 0.10, green: 0.90, blue: 1.00)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background layer
                ZStack {
                    Color(red: 0.03, green: 0.02, blue: 0.12).ignoresSafeArea()
                    // Ambient glow
                    RadialGradient(colors: [purple.opacity(0.30), .clear],
                                   center: UnitPoint(x: 0.5, y: 0.38),
                                   startRadius: 0, endRadius: 340)
                        .ignoresSafeArea()
                    RadialGradient(colors: [accent.opacity(0.12), .clear],
                                   center: UnitPoint(x: 0.2, y: 0.7),
                                   startRadius: 0, endRadius: 220)
                        .ignoresSafeArea()
                    // Floating star dots
                    StarFieldView(particles: particles, size: geo.size)
                }

                // Particle burst
                if burstActive {
                    BurstView(center: CGPoint(x: geo.size.width/2, y: geo.size.height * 0.38),
                              accent: accent, purple: purple)
                }

                VStack(spacing: 0) {
                    Spacer()

                    // Logo + rings
                    ZStack {
                        // Outer ring
                        Circle()
                            .strokeBorder(
                                AngularGradient(colors: [purple.opacity(0.7), cyan.opacity(0.2), purple.opacity(0.7)],
                                                center: .center),
                                lineWidth: 1.5
                            )
                            .frame(width: 200, height: 200)
                            .scaleEffect(ring2Scale)
                            .opacity(ring2Opacity)
                            .rotationEffect(.degrees(glowPulse ? 360 : 0))
                            .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: glowPulse)

                        // Inner ring
                        Circle()
                            .strokeBorder(
                                AngularGradient(colors: [accent.opacity(0.9), purple.opacity(0.3), accent.opacity(0.9)],
                                                center: .center),
                                lineWidth: 2
                            )
                            .frame(width: 158, height: 158)
                            .scaleEffect(ring1Scale)
                            .opacity(ring1Opacity)
                            .rotationEffect(.degrees(glowPulse ? -360 : 0))
                            .animation(.linear(duration: 5).repeatForever(autoreverses: false), value: glowPulse)

                        // Pulsing glow
                        Circle()
                            .fill(RadialGradient(colors: [accent.opacity(0.22), purple.opacity(0.12), .clear],
                                                 center: .center, startRadius: 0, endRadius: 70))
                            .frame(width: 140, height: 140)
                            .scaleEffect(glowPulse ? 1.18 : 0.92)
                            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: glowPulse)

                        // App icon
                        appIconView
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                    }

                    Spacer().frame(height: 40)

                    // Title
                    VStack(spacing: 6) {
                        Text("CheatiOSVip")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.white, accent],
                                               startPoint: .leading, endPoint: .trailing))
                        Text("DSW")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [accent, purple],
                                               startPoint: .leading, endPoint: .trailing))
                            .shadow(color: accent.opacity(0.9), radius: 10)
                    }
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)

                    Spacer().frame(height: 10)

                    Text("Trợ thủ game · An toàn · Ổn định")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .opacity(tagOpacity)

                    Spacer()

                    // Segmented progress indicator
                    VStack(spacing: 14) {
                        HStack(spacing: 7) {
                            ForEach(0..<6, id: \.self) { i in
                                let filled = progressVal >= CGFloat(i + 1) / 6.0
                                Capsule()
                                    .fill(filled
                                        ? AnyShapeStyle(LinearGradient(
                                            colors: [cyan.opacity(0.9), accent, purple],
                                            startPoint: .leading, endPoint: .trailing))
                                        : AnyShapeStyle(Color.white.opacity(0.08)))
                                    .frame(width: 32, height: 5)
                                    .shadow(color: filled ? accent.opacity(0.75) : .clear, radius: 6)
                                    .animation(.easeInOut(duration: 0.25).delay(Double(i) * 0.1), value: filled)
                            }
                        }

                        Text("Đang khởi động...")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .opacity(progressOp)
                    .padding(.bottom, 60)
                }
            }
        }
        .opacity(screenOpacity)
        .preferredColorScheme(.dark)
        .onAppear { runSequence() }
    }

    @ViewBuilder
    private var appIconView: some View {
        Group {
            if let icon = UIImage(named: "AppIcon60x60") ?? UIImage(named: "AppIcon") {
                Image(uiImage: icon).resizable().scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(colors: [accent, purple],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "shield.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 110, height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(accent.opacity(0.6), lineWidth: 1.5))
        .shadow(color: accent.opacity(0.6), radius: 24)
        .shadow(color: purple.opacity(0.4), radius: 40)
    }

    private func runSequence() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1)) {
            logoScale = 1.0; logoOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
            ring1Scale = 1.0; ring1Opacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
            ring2Scale = 1.0; ring2Opacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { glowPulse = true }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.7)) {
            titleOpacity = 1.0; titleOffset = 0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.95)) { tagOpacity = 1.0 }
        withAnimation(.easeIn(duration: 0.3).delay(1.1)) { progressOp = 1.0 }
        withAnimation(.easeInOut(duration: 1.6).delay(1.15)) { progressVal = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { burstActive = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(.easeInOut(duration: 0.55)) { screenOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { onFinished() }
        }
    }
}

// MARK: - Star field

struct SplashParticle: Identifiable {
    let id = UUID()
    var x, y: CGFloat
    var size: CGFloat
    var opacity: Double
    var speed: Double

    static func spawn(_ count: Int) -> [SplashParticle] {
        (0..<count).map { _ in
            SplashParticle(x: CGFloat.random(in: 0...1),
                           y: CGFloat.random(in: 0...1),
                           size: CGFloat.random(in: 1...3),
                           opacity: Double.random(in: 0.2...0.8),
                           speed: Double.random(in: 1.5...4.0))
        }
    }
}

private struct StarFieldView: View {
    let particles: [SplashParticle]
    let size: CGSize
    @State private var phase = false

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Circle()
                    .fill(Color.white.opacity(phase ? p.opacity : p.opacity * 0.3))
                    .frame(width: p.size, height: p.size)
                    .position(x: p.x * size.width, y: p.y * size.height)
                    .animation(.easeInOut(duration: p.speed).repeatForever(autoreverses: true)
                        .delay(Double.random(in: 0...2)), value: phase)
            }
        }
        .onAppear { phase = true }
    }
}

// MARK: - Burst

private struct BurstParticle: Identifiable {
    let id = UUID()
    let angle: Double
    let speed: CGFloat
    let size:  CGFloat
    let color: Color
}

private struct BurstView: View {
    let center: CGPoint
    let accent:  Color
    let purple:  Color
    @State private var progress: Double = 0
    private let items: [BurstParticle]

    init(center: CGPoint, accent: Color, purple: Color) {
        self.center = center
        self.accent = accent
        self.purple = purple
        let colors: [Color] = [accent, purple, .white, .cyan,
                                Color(red: 0.9, green: 0.5, blue: 1)]
        self.items = (0..<55).map { _ in
            BurstParticle(angle: Double.random(in: 0...(2 * .pi)),
                          speed: CGFloat.random(in: 60...170),
                          size:  CGFloat.random(in: 2...6),
                          color: colors.randomElement()!)
        }
    }

    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { ctx, _ in
                let t = CGFloat(progress)
                for p in items {
                    let px = center.x + cos(p.angle) * p.speed * t
                    let py = center.y + sin(p.angle) * p.speed * t
                    let a  = max(0, 1 - t * 1.6)
                    ctx.opacity = a
                    ctx.fill(Path(ellipseIn: CGRect(x: px - p.size/2, y: py - p.size/2,
                                                     width: p.size, height: p.size)),
                             with: .color(p.color))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) { progress = 1 }
        }
    }
}
