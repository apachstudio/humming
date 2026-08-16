import SwiftUI

/// The handwritten "humming" wordmark as a single continuous stroke,
/// traced from the Figma logo so it can draw itself with `trim`.
/// Natural aspect ratio is roughly 184 × 76.
struct WordmarkShape: Shape {
    /// Zigzag skeleton: sharp peaks rising through the middle of the
    /// word and tapering off, matching the brand scribble.
    private static let points: [CGPoint] = [
        CGPoint(x: 0.000, y: 0.70),
        CGPoint(x: 0.030, y: 0.30),
        CGPoint(x: 0.062, y: 0.78),
        CGPoint(x: 0.095, y: 0.18),
        CGPoint(x: 0.128, y: 0.80),
        CGPoint(x: 0.162, y: 0.12),
        CGPoint(x: 0.195, y: 0.82),
        CGPoint(x: 0.228, y: 0.08),
        CGPoint(x: 0.262, y: 0.84),
        CGPoint(x: 0.295, y: 0.10),
        CGPoint(x: 0.328, y: 0.85),
        CGPoint(x: 0.362, y: 0.14),
        CGPoint(x: 0.395, y: 0.85),
        CGPoint(x: 0.428, y: 0.10),
        CGPoint(x: 0.462, y: 0.86),
        CGPoint(x: 0.495, y: 0.16),
        CGPoint(x: 0.528, y: 0.86),
        CGPoint(x: 0.562, y: 0.22),
        CGPoint(x: 0.595, y: 0.86),
        CGPoint(x: 0.630, y: 0.30),
        CGPoint(x: 0.662, y: 0.86),
        CGPoint(x: 0.695, y: 0.38),
        CGPoint(x: 0.728, y: 0.86),
        CGPoint(x: 0.762, y: 0.42),
        CGPoint(x: 0.795, y: 0.88)
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0, rect.height > 0 else { return path }

        func point(_ normalized: CGPoint) -> CGPoint {
            CGPoint(
                x: rect.minX + normalized.x * rect.width,
                y: rect.minY + normalized.y * rect.height
            )
        }

        let skeleton = Self.points
        path.move(to: point(skeleton[0]))
        for p in skeleton.dropFirst() {
            path.addLine(to: point(p))
        }

        // The "g" tail: a tight curl that reads as the end blob.
        path.addQuadCurve(
            to: point(CGPoint(x: 0.945, y: 0.62)),
            control: point(CGPoint(x: 0.900, y: 0.35))
        )
        path.addQuadCurve(
            to: point(CGPoint(x: 0.905, y: 0.92)),
            control: point(CGPoint(x: 1.000, y: 0.95))
        )
        path.addQuadCurve(
            to: point(CGPoint(x: 0.885, y: 0.70)),
            control: point(CGPoint(x: 0.845, y: 0.86))
        )
        return path
    }
}

/// Renders the wordmark stroke, optionally partially drawn (0...1)
/// for the self-writing splash animation.
struct WordmarkView: View {
    var progress: CGFloat = 1
    var color: Color = .white

    var body: some View {
        GeometryReader { proxy in
            WordmarkShape()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: max(1.5, proxy.size.height * 0.11),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .padding(proxy.size.height * 0.08)
        }
        .aspectRatio(184 / 76, contentMode: .fit)
    }
}

#Preview {
    ZStack {
        HumTheme.charcoal.ignoresSafeArea()
        WordmarkView()
            .frame(width: 200)
    }
}
