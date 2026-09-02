import SwiftUI

struct SplashScreenView: View {
    var onFinished: () -> Void

    // Phase states
    @State private var logoScale:      CGFloat = 0.3
    @State private var logoOpacity:    Double  = 0
    @State private var ring1Scale:     CGFloat = 0.4
    @State private var ring2Scale:     CGFloat = 0.4
    @State private var ring1Opacity:   Double  = 0
    @State private var ring2Opacity:   Double  = 0
    @State private var titleOpacity:   Double  = 0
    @State private var titleOffset:    CGFloat = 30
    @State private var tagOpacity:     Double  = 0
    @State private var progressWidth:  CGFloat = 0
    @State private var progressOpacity:Double  = 0
    @State private var particleBurst:  Bool    = false
    @State private var screenOpacity:  Double  = 1
    @State private var glowPulse:      Bool    = false

    private let accent = Color(red: 0.30, green: 0.70, blue: 1.00)
    private let purple = Color(red: 0.65, green: 0.20, blue: 1.00)
    private let cyan   = Color(red: 0.10, green: 0.90, blue: 1.00)

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            MatrixRainView().ignoresSafeArea().opacity(0.35)

            // Ambient radials
            RadialGradient(colors: [purple.opacity(0.25), .clear],
                           center: .center, startRadius: 0, endRadius: 350)
                .ignoresSafeArea()

            // Particles
            ParticleBurstView(active: $particleBurst, accent: accent, purple: purple)

            VStack(spacing: 0) {
                Spacer()

                // ---- Logo ring stack ----
                ZStack {
                    // Outer ring 2
                    Circle()
                        .strokeBorder(
                            AngularGradient(colors: [purple.opacity(0.6), cyan.opacity(0.3), purple.opacity(0.6)],
                                            center: .center),
                            lineWidth: 1.5
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(ring2Scale)
                        .opacity(ring2Opacity)
                        .rotationEffect(.degrees(glowPulse ? 360 : 0))
                        .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: glowPulse)

                    // Inner ring 1
                    Circle()
                        .strokeBorder(
                            AngularGradient(colors: [accent.opacity(0.9), purple.opacity(0.4), accent.opacity(0.9)],
                                            center: .center),
                            lineWidth: 2
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(ring1Scale)
                        .opacity(ring1Opacity)
                        .rotationEffect(.degrees(glowPulse ? -360 : 0))
                        .animation(.linear(duration: 5).repeatForever(autoreverses: false), value: glowPulse)

                    // Glow backdrop
                    Circle()
                        .fill(
                            RadialGradient(colors: [accent.opacity(0.20), purple.opacity(0.10), .clear],
                                           center: .center, startRadius: 0, endRadius: 70)
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(glowPulse ? 1.15 : 0.95)
                        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: glowPulse)

                    // App icon
                    Group {
                        if let icon = UIImage(named: "AppIcon60x60")
                            ?? UIImage(named: "AppIcon") {
                            Image(uiImage: icon)
                                .resizable()
                                .scaledToFill()
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(accent.opacity(0.6), lineWidth: 1.5)
                    )
                    .shadow(color: accent.opacity(0.55), radius: 24, x: 0, y: 0)
                    .shadow(color: purple.opacity(0.40), radius: 40, x: 0, y: 0)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                }

                Spacer().frame(height: 40)

                // ---- Title ----
                VStack(spacing: 8) {
                    Text("CheatiOSVip")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, accent],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                    Text("DSW")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [accent, purple],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .shadow(color: accent.opacity(0.8), radius: 8)
                }
                .opacity(titleOpacity)
                .offset(y: titleOffset)

                Spacer().frame(height: 10)

                Text("Trợ thủ game · An toàn · Ổn định")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.50))
                    .opacity(tagOpacity)

                Spacer()

                // ---- Progress bar ----
                VStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.white.opacity(0.08))
                                .frame(height: 4)
                            // Fill
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(colors: [accent, purple],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: progressWidth * geo.size.width / 100, height: 4)
                                .shadow(color: accent.opacity(0.7), radius: 6)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 48)

                    Text("Đang khởi động...")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .opacity(progressOpacity)
                .padding(.bottom, 60)
            }
        }
        .opacity(screenOpacity)
        .onAppear { runSequence() }
    }

    private func runSequence() {
        // Phase 1: Logo appears
        withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1)) {
            logoScale   = 1.0
            logoOpacity = 1.0
        }
        // Rings appear
        withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
            ring1Scale   = 1.0
            ring1Opacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
            ring2Scale   = 1.0
            ring2Opacity = 1.0
        }
        // Start rotation/pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            glowPulse = true
        }
        // Phase 2: Title slides up
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.7)) {
            titleOpacity = 1.0
            titleOffset  = 0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.95)) {
            tagOpacity = 1.0
        }
        // Phase 3: Progress bar
        withAnimation(.easeIn(duration: 0.3).delay(1.1)) {
            progressOpacity = 1.0
        }
        withAnimation(.easeInOut(duration: 1.6).delay(1.15)) {
            progressWidth = 100
        }
        // Particle burst at ~50%
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            particleBurst = true
        }
        // Phase 4: Fade out and call onFinished
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(.easeInOut(duration: 0.55)) {
                screenOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                onFinished()
            }
        }
    }
}

// MARK: - Particle burst

private struct Particle: Identifiable {
    let id    = UUID()
    var x:      CGFloat
    var y:      CGFloat
    var angle:  Double
    var speed:  CGFloat
    var size:   CGFloat
    var color:  Color
    var life:   Double
}

private struct ParticleBurstView: View {
    @Binding var active: Bool
    let accent:  Color
    let purple:  Color

    @State private var particles: [Particle] = []
    @State private var progress:  Double = 0

    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { ctx, size in
                let cx = size.width  / 2
                let cy = size.height / 2
                for p in particles {
                    let t  = CGFloat(progress) * p.speed
                    let px = cx + cos(p.angle) * t + p.x
                    let py = cy + sin(p.angle) * t + p.y
                    let a  = max(0, 1 - CGFloat(progress) * 1.8)
                    ctx.opacity = a
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - p.size/2, y: py - p.size/2,
                                               width: p.size, height: p.size)),
                        with: .color(p.color)
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onChange(of: active) { fired in
            guard fired else { return }
            spawnParticles()
            withAnimation(.easeOut(duration: 1.2)) { progress = 1 }
        }
    }

    private func spawnParticles() {
        let colors: [Color] = [accent, purple, .white, .cyan, Color(red: 0.9, green: 0.5, blue: 1)]
        particles = (0..<60).map { _ in
            Particle(
                x: CGFloat.random(in: -2...2),
                y: CGFloat.random(in: -2...2),
                angle: Double.random(in: 0...(2 * .pi)),
                speed: CGFloat.random(in: 60...180),
                size:  CGFloat.random(in: 2...6),
                color: colors.randomElement()!,
                life:  Double.random(in: 0.4...1.0)
            )
        }
    }
}
