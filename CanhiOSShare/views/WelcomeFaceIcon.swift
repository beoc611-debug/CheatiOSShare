import SwiftUI

/// The face badge used by both the welcome announcement (blue, smiling, "HELLO" eyebrow) and the
/// maintenance block (yellow, frowning, no eyebrow). Drawn as vector shapes on a 100x100 logical
/// grid — matching the original UIGraphicsImageRenderer proportions — rather than rasterized, so
/// it stays crisp at any size.
struct FaceIcon: View {
    var size: CGFloat = 76
    var color: Color
    var isSad: Bool = false
    var eyebrowText: String? = nil
    var eyebrowColor: Color = Color(red: 0.498, green: 0.902, blue: 1.0)

    var body: some View {
        VStack(spacing: size * 0.05) {
            if let eyebrowText {
                Text(eyebrowText)
                    .font(.system(size: size * 0.16, weight: .bold))
                    .tracking(size * 0.01)
                    .foregroundStyle(eyebrowColor)
            }

            Canvas { context, canvasSize in
                let scale = canvasSize.width / 100

                let faceRadius = 34 * scale
                let faceRect = CGRect(
                    x: 50 * scale - faceRadius,
                    y: 52 * scale - faceRadius,
                    width: faceRadius * 2,
                    height: faceRadius * 2
                )
                context.fill(Path(ellipseIn: faceRect), with: .color(color))

                let eyeRadius = 5.5 * scale
                for eyeX: CGFloat in [38, 62] {
                    let eyeRect = CGRect(
                        x: eyeX * scale - eyeRadius,
                        y: 46 * scale - eyeRadius,
                        width: eyeRadius * 2,
                        height: eyeRadius * 2
                    )
                    context.fill(Path(ellipseIn: eyeRect), with: .color(.white))
                }

                var mouth = Path()
                if isSad {
                    mouth.move(to: CGPoint(x: 32 * scale, y: 66 * scale))
                    mouth.addCurve(
                        to: CGPoint(x: 68 * scale, y: 66 * scale),
                        control1: CGPoint(x: 38 * scale, y: 58 * scale),
                        control2: CGPoint(x: 62 * scale, y: 58 * scale)
                    )
                } else {
                    mouth.move(to: CGPoint(x: 32 * scale, y: 60 * scale))
                    mouth.addCurve(
                        to: CGPoint(x: 68 * scale, y: 60 * scale),
                        control1: CGPoint(x: 38 * scale, y: 68 * scale),
                        control2: CGPoint(x: 62 * scale, y: 68 * scale)
                    )
                }
                context.stroke(mouth, with: .color(.white), style: StrokeStyle(lineWidth: 4 * scale, lineCap: .round))
            }
            .frame(width: size, height: size)
        }
    }
}
