import BackgroundCore
import SwiftUI

public struct LayeredHillsDesign: BackgroundDesign {
    public static let title: String = "Layered hills"

    public init() {}

    public func makeView(seed: UInt64) -> some View {
        // Generation stays outside Canvas's drawing closure.
        LayeredHillsView(scene: LayeredHillsGenerator().generate(seed: seed))
    }
}

private struct LayeredHillsView: View {
    let scene: LayeredHillsScene

    var body: some View {
        Canvas { context, size in
            guard size.width.isFinite, size.height.isFinite,
                  size.width > 0, size.height > 0 else { return }

            for (index, ridgeline) in scene.layers.enumerated() {
                guard let first = ridgeline.first else { continue }
                var path: Path = Path()
                path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
                for point in ridgeline.dropFirst() {
                    path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.closeSubpath()

                let ink: Color = Color(red: 0.18, green: 0.25, blue: 0.24)
                context.fill(path, with: .color(ink.opacity(0.12 + Double(index) * 0.09)))
            }
        }
        .background(PaperDesign.color)
        .accessibilityHidden(true)
    }
}
