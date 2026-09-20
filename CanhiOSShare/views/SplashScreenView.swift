import SwiftUI

struct SplashScreenView: View {
    var onFinished: () -> Void

    @State private var logoScale:    CGFloat = 0.2
    @State private var logoOpacity:  Double  = 0
    @State private var ring1Scale:   CGFloat = 0.3
    @State private var ring2Scale:   CGFloat = 0.3
    @State private var ring3Scale:   CGFloat = 0.3
    @State private var ring1Opacity: Double  = 0
    @State private var ring2Opacity: Double  = 0
    @State private var ring3Opacity: Double  = 0
    @State private var ring1Rot:     Double  = 0
    @State private var ring2Rot:     Double  = 0
    @State private var ring3Rot:     Double  = 0
    @State private var titleOpacity: Double  = 0
    @State private var titleOffset:  CGFloat = 28
    @State private var tagOpacity:   Double  = 0
    @State private var techRowOp:    Double  = 0
    @State private var progressVal:  CGFloat = 0
    @State private var progressOp:   Double  = 0
    @State private var successOp:    Double  = 0
    @State private var screenOpacity:Double  = 1
    @State private var glowPulse:    Bool    = false
    @State private var scanY:        CGFloat = -160
    @State private var scanOp:       Double  = 0
    @State private var particles:    [SplashParticle] = SplashParticle.spawn(80)
    @State private var burstActive:  Bool    = false
    @State private var successPulse: Bool    = false

    private let cyan   = Color(red: 0.00, green: 0.88, blue: 1.00)
    private let blue   = Color(red: 0.22, green: 0.52, blue: 1.00)
    private let purple = Color(red: 0.58, green: 0.18, blue: 1.00)
    private let green  = Color(red: 0.12, green: 0.92, blue: 0.58)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Background ──
                ZStack {
                    Color(red: 0.02, green: 0.01, blue: 0.10).ignoresSafeArea()
                    RadialGradient(colors: [purple.opacity(0.38), .clear],
                                   center: UnitPoint(x: 0.50, y: 0.37),
                                   startRadius: 0, endRadius: 400).ignoresSafeArea()
                    RadialGradient(colors: [blue.opacity(0.20), .clear],
                                   center: UnitPoint(x: 0.12, y: 0.78),
                                   startRadius: 0, endRadius: 280).ignoresSafeArea()
                    RadialGradient(colors: [cyan.opacity(0.12), .clear],
                                   center: UnitPoint(x: 0.88, y: 0.18),
                                   startRadius: 0, endRadius: 220).ignoresSafeArea()
                }

                StarFieldView(particles: particles)

                // ── Scan beam ──
                Rectangle()
                    .fill(LinearGradient(
                        colors: [.clear, cyan.opacity(0.06), cyan.opacity(0.14), cyan.opacity(0.06), .clear],
                        startPoint: .top, endPoint: .bottom))
                    .frame(height: 140)
                    .position(x: geo.size.width / 2, y: scanY)
                    .opacity(scanOp)
                    .allowsHitTesting(false)

                // ── Burst ──
                if burstActive {
                    BurstView(center: CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.40),
                              accent: cyan, purple: purple)
                }

                VStack(spacing: 0) {
                    Spacer()

                    // ── Ring system + icon ──
                    ZStack {
                        // Outer dashed orbit
                        Circle()
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 9]))
                            .foregroundStyle(cyan.opacity(0.22))
                            .frame(width: 248, height: 248)
                            .rotationEffect(.degrees(ring3Rot))
                            .scaleEffect(ring3Scale)
                            .opacity(ring3Opacity)

                        // Progress arc on outer ring
                        Circle()
                            .trim(from: 0, to: progressVal)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: cyan.opacity(0.0), location: 0.0),
                                        .init(color: cyan,              location: 0.30),
                                        .init(color: blue,             location: 0.62),
                                        .init(color: purple,           location: 0.88),
                                        .init(color: cyan.opacity(0.0), location: 1.0)
                                    ]),
                                    center: .center),
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                            )
                            .frame(width: 248, height: 248)
                            .rotationEffect(.degrees(-90))
                            .scaleEffect(ring3Scale)
                            .opacity(progressOp)
                            .shadow(color: cyan.opacity(0.95), radius: 9)

                        // Middle ring — counter-rotating gradient
                        Circle()
                            .strokeBorder(
                                AngularGradient(colors: [cyan.opacity(0.65), blue.opacity(0.18), purple.opacity(0.55), cyan.opacity(0.65)],
                                                center: .center),
                                lineWidth: 1.5
                            )
                            .frame(width: 185, height: 185)
                            .rotationEffect(.degrees(-ring2Rot))
                            .scaleEffect(ring2Scale)
                            .opacity(ring2Opacity)

                        // Inner ring — rotating purple dashes
                        Circle()
                            .strokeBorder(
                                AngularGradient(colors: [purple.opacity(0.9), .clear, purple.opacity(0.5), .clear, purple.opacity(0.9)],
                                                center: .center),
                                style: StrokeStyle(lineWidth: 2, dash: [6, 10])
                            )
                            .frame(width: 148, height: 148)
                            .rotationEffect(.degrees(ring1Rot))
                            .scaleEffect(ring1Scale)
                            .opacity(ring1Opacity)

                        // Pulsing core glow
                        Circle()
                            .fill(RadialGradient(
                                colors: [cyan.opacity(0.20), blue.opacity(0.10), .clear],
                                center: .center, startRadius: 0, endRadius: 68))
                            .frame(width: 136, height: 136)
                            .scaleEffect(glowPulse ? 1.18 : 0.85)
                            .animation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true), value: glowPulse)

                        // App icon
                        appIconView
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                    }

                    Spacer().frame(height: 26)

                    // ── Success badge ──
                    VStack(spacing: 8) {
                        ZStack {
                            ForEach([1.0, 1.45, 1.9] as [CGFloat], id: \.self) { scale in
                                Circle()
                                    .stroke(green.opacity(0.16 / scale), lineWidth: 1.5)
                                    .frame(width: 44, height: 44)
                                    .scaleEffect(successPulse ? scale : 1.0)
                                    .opacity(successPulse ? 0 : 1)
                                    .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)
                                        .delay(Double(scale - 1.0) * 0.42), value: successPulse)
                            }
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(LinearGradient(
                                    colors: [Color(red: 0.30, green: 1.0, blue: 0.70), green],
                                    startPoint: .top, endPoint: .bottom))
                                .shadow(color: green.opacity(0.95), radius: 18)
                                .scaleEffect(successOp == 1 ? 1.0 : 0.2)
                        }
                        Text("TRUY CẬP THÀNH CÔNG")
                            .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                            .tracking(2.8)
                            .foregroundStyle(LinearGradient(
                                colors: [Color(red: 0.35, green: 1.0, blue: 0.72), green],
                                startPoint: .leading, endPoint: .trailing))
                            .shadow(color: green.opacity(0.7), radius: 10)
                    }
                    .opacity(successOp)

                    Spacer().frame(height: 22)

                    // ── Title ──
                    VStack(spacing: 6) {
                        HStack(spacing: 0) {
                            Text("Cheati")
                                .font(.system(size: 36, weight: .black))
                                .foregroundStyle(.white)
                            Text("OS")
                                .font(.system(size: 36, weight: .black))
                                .foregroundStyle(cyan)
                                .shadow(color: cyan.opacity(0.55), radius: 10)
                            Text("Vip")
                                .font(.system(size: 36, weight: .black))
                                .foregroundStyle(.white)
                        }

                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(LinearGradient(colors: [.clear, cyan.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                                .frame(height: 1)
                            Text("D  S  W")
                                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                                .tracking(6)
                                .foregroundStyle(LinearGradient(colors: [cyan, purple], startPoint: .leading, endPoint: .trailing))
                                .shadow(color: cyan.opacity(0.85), radius: 14)
                            Rectangle()
                                .fill(LinearGradient(colors: [purple.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing))
                                .frame(height: 1)
                        }
                        .frame(maxWidth: 260)
                    }
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)

                    Spacer().frame(height: 10)

                    Text("Trợ thủ game  ·  An toàn  ·  Ổn định")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.38))
                        .opacity(tagOpacity)

                    Spacer().frame(height: 14)

                    // ── Tech row ──
                    HStack(spacing: 0) {
                        techLabel("PLATFORM", "iOS")
                        techDivider
                        techLabel("EDITION", "DSW")
                        techDivider
                        techLabel("STATUS", "SECURE")
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(cyan.opacity(0.04), in: CutShape(cut: 8))
                    .overlay(CutShape(cut: 8)
                        .strokeBorder(cyan.opacity(0.12), lineWidth: 1))
                    .opacity(techRowOp)

                    Spacer()
                }
            }
        }
        .opacity(screenOpacity)
        .preferredColorScheme(.dark)
        .onAppear { runSequence() }
    }

    // ── Subviews ──

    private var techDivider: some View {
        Rectangle()
            .fill(cyan.opacity(0.20))
            .frame(width: 1, height: 24)
            .padding(.horizontal, 18)
    }

    private func techLabel(_ key: String, _ val: String) -> some View {
        VStack(spacing: 3) {
            Text(key)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(cyan.opacity(0.50))
                .tracking(1.8)
            Text(val)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.82))
        }
        .frame(maxWidth: .infinity)
    }

    private var appIconView: some View {
        ZStack {
            // Ambient glow layers
            Circle()
                .fill(RadialGradient(
                    colors: [purple.opacity(0.55), blue.opacity(0.25), .clear],
                    center: .center, startRadius: 0, endRadius: 58))
                .frame(width: 116, height: 116)
            Circle()
                .fill(RadialGradient(
                    colors: [cyan.opacity(0.18), .clear],
                    center: .center, startRadius: 0, endRadius: 52))
                .frame(width: 104, height: 104)

            // Outer octagon frame — two overlapping squares
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    LinearGradient(colors: [cyan.opacity(0.80), purple.opacity(0.55)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.8)
                .frame(width: 76, height: 76)
                .rotationEffect(.degrees(45))

            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    LinearGradient(colors: [purple.opacity(0.55), cyan.opacity(0.35)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.2)
                .frame(width: 76, height: 76)

            // Small tick marks at cardinal points
            ForEach([0.0, 90.0, 180.0, 270.0], id: \.self) { angle in
                Capsule()
                    .fill(cyan.opacity(0.60))
                    .frame(width: 2, height: 6)
                    .offset(y: -46)
                    .rotationEffect(.degrees(angle))
            }

            // Center: DSW brand text
            VStack(spacing: 1) {
                Text("DSW")
                    .font(.system(size: 26, weight: .black, design: .monospaced))
                    .tracking(5)
                    .foregroundStyle(LinearGradient(
                        colors: [cyan, blue, purple],
                        startPoint: .leading, endPoint: .trailing))
                    .shadow(color: cyan.opacity(0.85), radius: 14)
                    .shadow(color: purple.opacity(0.50), radius: 24)
                Text("CheatiOS")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .tracking(2.0)
                    .foregroundStyle(.white.opacity(0.38))
            }
        }
        .frame(width: 120, height: 120)
        .shadow(color: cyan.opacity(0.45), radius: 28)
        .shadow(color: purple.opacity(0.35), radius: 52)
    }

    // ── Animation sequence ──

    private func runSequence() {
        withAnimation(.spring(response: 0.62, dampingFraction: 0.56).delay(0.15)) {
            logoScale = 1.0; logoOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.50).delay(0.40)) { ring1Scale = 1; ring1Opacity = 1 }
        withAnimation(.easeOut(duration: 0.60).delay(0.50)) { ring2Scale = 1; ring2Opacity = 1 }
        withAnimation(.easeOut(duration: 0.70).delay(0.60)) { ring3Scale = 1; ring3Opacity = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            glowPulse = true
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) { ring1Rot = 360 }
            withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) { ring2Rot = 360 }
            withAnimation(.linear(duration: 14.0).repeatForever(autoreverses: false)) { ring3Rot = 360 }
        }
        // Scan sweep
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeIn(duration: 0.15)) { scanOp = 1 }
            withAnimation(.linear(duration: 1.3)) { scanY = 920 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
                withAnimation(.easeOut(duration: 0.2)) { scanOp = 0 }
            }
        }
        withAnimation(.spring(response: 0.52, dampingFraction: 0.70).delay(0.72)) {
            titleOpacity = 1.0; titleOffset = 0
        }
        withAnimation(.easeOut(duration: 0.45).delay(0.98)) { tagOpacity = 1.0 }
        withAnimation(.easeOut(duration: 0.45).delay(1.15)) { techRowOp = 1.0 }
        withAnimation(.easeIn(duration: 0.20).delay(1.20)) { progressOp = 1.0 }
        withAnimation(.easeInOut(duration: 1.55).delay(1.25)) { progressVal = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.95) { burstActive = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.85) {
            withAnimation(.spring(response: 0.40, dampingFraction: 0.55)) { successOp = 1.0 }
            successPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.60) {
            withAnimation(.easeInOut(duration: 0.52)) { screenOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) { onFinished() }
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
                           size: CGFloat.random(in: 1...2.8),
                           opacity: Double.random(in: 0.15...0.75),
                           speed: Double.random(in: 1.4...4.2))
        }
    }
}

private struct StarFieldView: View {
    let particles: [SplashParticle]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            Canvas { ctx, canvasSize in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for p in particles {
                    let pulse = (sin(t / p.speed + p.x * 6.28) + 1) / 2
                    let alpha = p.opacity * 0.25 + p.opacity * 0.75 * pulse
                    let x = p.x * canvasSize.width
                    let y = p.y * canvasSize.height
                    let r = p.size / 2
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: p.size, height: p.size)),
                        with: .color(.white.opacity(alpha))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Burst

private struct BurstParticle: Identifiable {
    let id = UUID()
    let angle: Double
    let speed: CGFloat
    let size: CGFloat
    let color: Color
}

private struct BurstView: View {
    let center: CGPoint
    let accent: Color
    let purple: Color
    @State private var progress: Double = 0
    private let items: [BurstParticle]

    init(center: CGPoint, accent: Color, purple: Color) {
        self.center = center; self.accent = accent; self.purple = purple
        let colors: [Color] = [accent, purple, .white, .cyan, Color(red: 0.9, green: 0.5, blue: 1)]
        self.items = (0..<60).map { _ in
            BurstParticle(angle: Double.random(in: 0...(2 * .pi)),
                          speed: CGFloat.random(in: 55...180),
                          size: CGFloat.random(in: 2...6),
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
                    let a  = max(0, 1 - t * 1.55)
                    ctx.opacity = a
                    ctx.fill(Path(ellipseIn: CGRect(x: px - p.size/2, y: py - p.size/2,
                                                     width: p.size, height: p.size)),
                             with: .color(p.color))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 1.2)) { progress = 1 } }
    }
}
