import BackgroundCore
@testable import BackgroundUI
import Testing

struct InkClippingPrecisionTests {
    @Test func sharedTriangleEdgesClipToIdenticalBoundaryVertices() throws {
        for sample: Int in 0..<40 {
            let shift: Double = Double(sample) * 0.137
            let scene = InkScene(seed: 42, bounds: [1200, 800], primitives: [
                .colorWash(points: [[-701.29 + shift, -304.927], [1937.338, -212.477 + shift],
                                    [1802.571 - shift, 1001.333], [-306.731, 1102.999 - shift]],
                           color: [0.9, 0.1, 0.2], opacity: 0.37)
            ])
            let mesh = try InkMeshCompiler().compile(scene, clippingToBounds: true)
            for (index, a) in mesh.vertices.enumerated() {
                for b in mesh.vertices.dropFirst(index + 1) {
                    let delta = a.position - b.position
                    if abs(delta.x) < 0.001 && abs(delta.y) < 0.001 {
                        #expect(a.position.x.bitPattern == b.position.x.bitPattern)
                        #expect(a.position.y.bitPattern == b.position.y.bitPattern)
                    }
                }
            }
        }
    }
}
