import SwiftUI
import UIKit

// MARK: - Main Game View

struct FlappyBirdGameView: View {
    @AppStorage("flappyHighScore") private var highScore: Int = 0
    @AppStorage("fakeAppEnabled")  private var fakeEnabled: Bool = false
    @State private var showSecretSheet = false

    // Screen (set on appear)
    @State private var sw: CGFloat = 0
    @State private var sh: CGFloat = 0

    // Bird
    @State private var birdY:    CGFloat = 0
    @State private var velocity: CGFloat = 0
    @State private var wingDown: Bool    = false

    // Pipes
    @State private var pipes: [FBPipe] = []

    // Game
    @State private var score:      Int      = 0
    @State private var phase:      Phase    = .idle
    @State private var frameCount: Int      = 0
    @State private var gndShift:   CGFloat  = 0
    @State private var deathAlpha: Double   = 0

    // Stars
    @State private var stars: [FBStar] = (0..<72).map { _ in
        FBStar(
            nx: CGFloat.random(in: 0...1),
            ny: CGFloat.random(in: 0...0.80),
            size: CGFloat.random(in: 0.8...2.6),
            spd: CGFloat.random(in: 0.12...0.55)
        )
    }

    // ── Constants ────────────────────────────────────────────────
    private let G:         CGFloat = 0.44
    private let flapV:     CGFloat = -9.2
    private let pipeSpd:   CGFloat = 3.0
    private let pipeW:     CGFloat = 58
    private let gapH:      CGFloat = 158
    private let groundH:   CGFloat = 72
    private let birdR:     CGFloat = 18
    private let spawnEvery: Int    = 92

    private var playH: CGFloat { sh - groundH }
    private var birdX: CGFloat { sw * 0.27 }

    enum Phase { case idle, playing, dead }

    struct FBPipe: Identifiable {
        let id = UUID()
        var x: CGFloat
        let gapMid: CGFloat
        var passed = false
    }

    struct FBStar {
        var nx: CGFloat
        let ny: CGFloat
        let size: CGFloat
        let spd: CGFloat
    }

    let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                sky()
                starField()
                ForEach(pipes) { drawPipe($0) }
                ground()
                bird()
                scoreHUD()
                if phase == .idle { idleOverlay() }
                if phase == .dead  { deathOverlay() }
                Color.white.opacity(deathAlpha).ignoresSafeArea().allowsHitTesting(false)
                FBThreeFingerLongPress(duration: 3.0) { showSecretSheet = true }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .contentShape(Rectangle())
            .onTapGesture { flap() }
            .onAppear {
                sw = geo.size.width
                sh = geo.size.height
                resetGame()
            }
            .onReceive(ticker) { _ in tick() }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showSecretSheet) { FakeAppSheetView() }
    }

    // MARK: - Sky & Stars

    @ViewBuilder func sky() -> some View {
        LinearGradient(colors: [
            Color(red: 0.03, green: 0.02, blue: 0.18),
            Color(red: 0.07, green: 0.05, blue: 0.28),
            Color(red: 0.13, green: 0.10, blue: 0.38),
            Color(red: 0.18, green: 0.13, blue: 0.32)
        ], startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()
    }

    @ViewBuilder func starField() -> some View {
        Canvas { ctx, size in
            for s in stars {
                let x = s.nx * size.width
                let y = s.ny * size.height
                let r = s.size / 2
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - r, y: y - r, width: s.size, height: s.size)),
                    with: .color(.white.opacity(0.78))
                )
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Pipes

    @ViewBuilder func drawPipe(_ pipe: FBPipe) -> some View {
        let capH:  CGFloat = 26
        let bodyW: CGFloat = pipeW - 10
        let topH   = pipe.gapMid - gapH / 2
        let botY   = pipe.gapMid + gapH / 2
        let botH   = playH - botY

        let pipeBody = LinearGradient(colors: [
            Color(red: 0.08, green: 0.52, blue: 0.22),
            Color(red: 0.15, green: 0.78, blue: 0.32),
            Color(red: 0.08, green: 0.52, blue: 0.22)
        ], startPoint: .leading, endPoint: .trailing)

        let capGrad = LinearGradient(colors: [
            Color(red: 0.18, green: 0.90, blue: 0.40),
            Color(red: 0.06, green: 0.62, blue: 0.26)
        ], startPoint: .leading, endPoint: .trailing)

        // Top pipe
        if topH > 2 {
            VStack(spacing: 0) {
                pipeBody.frame(width: bodyW, height: max(1, topH - capH))
                ZStack {
                    Capsule().fill(capGrad)
                        .shadow(color: Color(red: 0.15, green: 0.95, blue: 0.42).opacity(0.6), radius: 10)
                }
                .frame(width: pipeW + 10, height: capH)
            }
            .frame(width: pipeW, height: topH)
            .position(x: pipe.x + pipeW / 2, y: topH / 2)
        }

        // Bottom pipe
        if botH > 2 {
            VStack(spacing: 0) {
                ZStack {
                    Capsule().fill(capGrad)
                        .shadow(color: Color(red: 0.15, green: 0.95, blue: 0.42).opacity(0.6), radius: 10)
                }
                .frame(width: pipeW + 10, height: capH)
                pipeBody.frame(width: bodyW, height: max(1, botH - capH))
            }
            .frame(width: pipeW, height: botH)
            .position(x: pipe.x + pipeW / 2, y: botY + botH / 2)
        }
    }

    // MARK: - Ground

    @ViewBuilder func ground() -> some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [
                Color(red: 0.14, green: 0.52, blue: 0.20),
                Color(red: 0.07, green: 0.28, blue: 0.12)
            ], startPoint: .top, endPoint: .bottom)

            Rectangle()
                .fill(Color(red: 0.22, green: 0.74, blue: 0.30))
                .frame(height: 14)

            if sw > 0 {
                Canvas { ctx, size in
                    let spacing: CGFloat = 80
                    let lineW:   CGFloat = 38
                    var x = -(gndShift.truncatingRemainder(dividingBy: spacing))
                    while x < size.width + spacing {
                        var p = Path()
                        p.move(to:    CGPoint(x: x,        y: 22))
                        p.addLine(to: CGPoint(x: x + lineW, y: 22))
                        ctx.stroke(p, with: .color(Color(red: 0.18, green: 0.60, blue: 0.26).opacity(0.55)), lineWidth: 2)
                        x += spacing
                    }
                }
            }
        }
        .frame(height: groundH)
        .position(x: sw / 2, y: sh - groundH / 2)
        .overlay(
            Rectangle()
                .fill(Color(red: 0.24, green: 0.92, blue: 0.40).opacity(0.50))
                .frame(width: sw, height: 2)
                .position(x: sw / 2, y: sh - groundH),
            alignment: .bottom
        )
        .shadow(color: Color(red: 0.12, green: 0.90, blue: 0.36).opacity(0.30), radius: 6, y: -4)
    }

    // MARK: - Bird

    @ViewBuilder func bird() -> some View {
        let rot = min(max(Double(velocity) * 4.5, -25.0), 88.0)
        ZStack {
            Circle()
                .fill(Color(red: 1.0, green: 0.80, blue: 0.0).opacity(0.20))
                .frame(width: birdR * 2 + 22, height: birdR * 2 + 22)

            // Body
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 1.0, green: 0.92, blue: 0.30),
                             Color(red: 0.95, green: 0.60, blue: 0.05)],
                    center: UnitPoint(x: 0.35, y: 0.30),
                    startRadius: 1, endRadius: birdR
                ))
                .frame(width: birdR * 2, height: birdR * 2)
                .shadow(color: Color(red: 0.95, green: 0.55, blue: 0.0).opacity(0.55), radius: 6)

            // Wing
            Ellipse()
                .fill(LinearGradient(
                    colors: [Color(red: 0.90, green: 0.68, blue: 0.08),
                             Color(red: 0.72, green: 0.48, blue: 0.02)],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 20, height: 11)
                .offset(x: -2, y: wingDown ? 8 : 2)
                .rotationEffect(.degrees(wingDown ? 28 : 0))
                .animation(.easeInOut(duration: 0.10), value: wingDown)

            // Eye
            Circle().fill(Color.white).frame(width: 9, height: 9)
                .offset(x: birdR * 0.38, y: -birdR * 0.22)
            Circle().fill(Color.black).frame(width: 5, height: 5)
                .offset(x: birdR * 0.50, y: -birdR * 0.17)

            // Beak
            FBBeak()
                .fill(Color(red: 1.0, green: 0.55, blue: 0.10))
                .frame(width: 13, height: 9)
                .offset(x: birdR + 3, y: birdR * 0.05)
        }
        .rotationEffect(.degrees(rot))
        .position(x: birdX, y: birdY)
    }

    // MARK: - HUD

    @ViewBuilder func scoreHUD() -> some View {
        VStack {
            HStack {
                Spacer()
                Text("\(score)")
                    .font(.system(size: 50, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.75), radius: 3, x: 2, y: 2)
                    .shadow(color: Color(red: 0.50, green: 0.50, blue: 1.0).opacity(0.55), radius: 14)
                Spacer()
            }
            .padding(.top, 54)
            Spacer()
        }
    }

    // MARK: - Overlays

    @ViewBuilder func idleOverlay() -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 14) {
                Text("FLAPPY BIRD")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(red: 1.0, green: 0.92, blue: 0.28),
                                 Color(red: 1.0, green: 0.55, blue: 0.08)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .shadow(color: Color(red: 1.0, green: 0.60, blue: 0.0).opacity(0.72), radius: 18)
                    .shadow(color: .black.opacity(0.90), radius: 2, x: 2, y: 2)

                if highScore > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow).font(.system(size: 12))
                        Text("BEST: \(highScore)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.yellow.opacity(0.90))
                    }
                }
            }
            Spacer()
            tapHint("TAP TO START")
            Spacer().frame(height: groundH + 36)
        }
    }

    @ViewBuilder func deathOverlay() -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Text("GAME OVER")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(red: 1.0, green: 0.32, blue: 0.32),
                                 Color(red: 0.78, green: 0.08, blue: 0.08)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .shadow(color: Color(red: 1.0, green: 0.18, blue: 0.18).opacity(0.65), radius: 14)
                    .shadow(color: .black.opacity(0.90), radius: 2, x: 2, y: 2)

                VStack(spacing: 10) {
                    fbScoreRow("SCORE", value: score,     accent: .white)
                    Divider().background(Color.white.opacity(0.20))
                    fbScoreRow("BEST",  value: highScore, accent: .yellow)
                }
                .padding(.horizontal, 32).padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 18).fill(.black.opacity(0.52))
                        .overlay(RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 1))
                )
                .padding(.horizontal, 48)

                tapHint("TAP TO RETRY")
            }
            Spacer().frame(height: groundH + 36)
        }
    }

    @ViewBuilder func fbScoreRow(_ label: String, value: Int, accent: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(accent.opacity(0.60))
            Spacer()
            Text("\(value)")
                .font(.system(size: label == "BEST" ? 24 : 20, weight: .black, design: .rounded))
                .foregroundStyle(accent)
        }
    }

    @ViewBuilder func tapHint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.88))
            .padding(.horizontal, 30).padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(red: 0.28, green: 0.60, blue: 1.0).opacity(0.22))
                    .overlay(RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(.white.opacity(0.38), lineWidth: 1.5))
            )
    }

    // MARK: - Game Logic

    func resetGame() {
        birdY      = playH > 0 ? playH / 2 : sh / 2
        velocity   = 0
        pipes      = []
        score      = 0
        frameCount = 0
        gndShift   = 0
        phase      = .idle
    }

    func flap() {
        switch phase {
        case .idle:
            phase    = .playing
            velocity = flapV
            doWingFlap()
        case .playing:
            velocity = flapV
            doWingFlap()
        case .dead:
            resetGame()
            phase    = .playing
            velocity = flapV
        }
    }

    func doWingFlap() {
        wingDown = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { wingDown = false }
    }

    func tick() {
        guard sw > 0 else { return }

        // Scroll stars (even on idle/dead for atmosphere)
        for i in stars.indices {
            stars[i].nx -= stars[i].spd / sw
            if stars[i].nx < 0 { stars[i].nx += 1 }
        }

        guard phase == .playing else { return }

        frameCount += 1
        gndShift   += pipeSpd

        // Physics
        velocity += G
        birdY    += velocity

        // Spawn pipes
        if frameCount == 1 || frameCount % spawnEvery == 1 {
            let margin: CGFloat = 70
            let mid = CGFloat.random(in: margin + gapH / 2 ... playH - margin - gapH / 2)
            pipes.append(FBPipe(x: sw, gapMid: mid))
        }

        // Move + score
        for i in pipes.indices {
            pipes[i].x -= pipeSpd
            if !pipes[i].passed && pipes[i].x + pipeW < birdX {
                pipes[i].passed = true
                score += 1
                if score > highScore { highScore = score }
            }
        }
        pipes.removeAll { $0.x < -(pipeW + 20) }

        // Collision – shrink hitbox slightly for fairness
        let hR   = birdR * 0.68
        let bTop = birdY - hR
        let bBot = birdY + hR
        let bL   = birdX - hR
        let bR   = birdX + hR

        if bBot >= playH || bTop <= 0 { die(); return }

        for pipe in pipes {
            let pL   = pipe.x
            let pR   = pipe.x + pipeW
            if bR > pL && bL < pR {
                let gTop = pipe.gapMid - gapH / 2
                let gBot = pipe.gapMid + gapH / 2
                if bTop < gTop || bBot > gBot { die(); return }
            }
        }
    }

    func die() {
        phase     = .dead
        velocity  = flapV * 0.35
        deathAlpha = 0.60
        withAnimation(.easeOut(duration: 0.28)) { deathAlpha = 0 }
    }
}

// MARK: - Beak Shape

struct FBBeak: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to:    CGPoint(x: 0,          y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX,  y: rect.minY + rect.height * 0.2))
            p.addLine(to: CGPoint(x: rect.maxX,  y: rect.maxY - rect.height * 0.2))
            p.closeSubpath()
        }
    }
}

// MARK: - 3-Finger Long-Press Detector

struct FBThreeFingerLongPress: UIViewRepresentable {
    let duration: Double
    let action: () -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        let gr = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.fire(_:))
        )
        gr.minimumPressDuration   = duration
        gr.numberOfTouchesRequired = 3
        v.addGestureRecognizer(gr)
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func fire(_ gr: UILongPressGestureRecognizer) {
            if gr.state == .began { DispatchQueue.main.async { self.action() } }
        }
    }
}
