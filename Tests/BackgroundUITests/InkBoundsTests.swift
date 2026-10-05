import BackgroundCore
@testable import BackgroundUI
import Testing

struct InkBoundsTests {
    @Test func expandedEdgeStrokeOwnsOnlyItsHalfAndDefaultIsUnchanged() throws {
        let ink: InkPrimitive = .colorStroke(points: [[0, 2], [0, 8]], widths: [4, 4], color: [0.2, 0.6, 0.3], opacity: 0.5)
        let scene = InkScene(seed: 0, bounds: [10, 10], primitives: [ink])
        let normal = try InkMeshCompiler().compile(scene)
        #expect(normal.vertices.contains { $0.position.x < -1 })
        let clipped = try InkMeshCompiler().compile(scene, clippingToBounds: true)
        #expect(clipped.vertices.allSatisfy { (0...10).contains($0.position.x) && (0...10).contains($0.position.y) })
        var area: Float = 0
        for i in stride(from: 0, to: clipped.vertices.count, by: 3) {
            let a = clipped.vertices[i].position, b = clipped.vertices[i + 1].position, c = clipped.vertices[i + 2].position
            area += abs((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)) / 2
        }
        #expect(abs(area - 12) < 1e-5)
    }

    @Test func clippingDoesNotHideInvalidInvisibleInk() {
        let invalid: [InkPrimitive] = [
            .colorWash(points: [[20, 20], [30, 20], [20, 30]], color: [.nan, 0.5, 0.5], opacity: 1),
            .colorStroke(points: [[20, 20], [30, 30]], widths: [1], color: [0.2, 0.6, 0.3], opacity: 1),
            .wash(points: [[.infinity, 20], [30, 20], [20, 30]], tone: 0, opacity: 1)
        ]
        for ink in invalid {
            #expect(throws: InkMeshError.self) {
                try InkMeshCompiler().compile(InkScene(seed: 0, bounds: [10, 10], primitives: [ink]), clippingToBounds: true)
            }
        }
    }
}
