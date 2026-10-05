@testable import BackgroundCore
import Testing

struct InkPrimitiveTests {
    @Test func legacyToneMapsToThreeEqualChannels() {
        let ink: InkPrimitive = .wash(points: [[0, 0], [8, 0], [0, 8]], tone: 0.37, opacity: 0.6)
        for value in [ink.color.x, ink.color.y, ink.color.z] { #expect(abs(value - 0.37) < 1e-12) }
        #expect(abs(ink.tone - 0.37) < 1e-12)
        let scene: ShanShuiScene = InkScene(seed: 42, bounds: [10, 10], primitives: [ink])
        let chunk: ShanShuiLandscapeChunk = InkChunk(index: -1, scene: scene)
        #expect(chunk.index == -1)
    }

    @Test func geometryMappingPreservesEveryInkCase() {
        let points: [SIMD2<Double>] = [[2, 3], [4, 5], [6, 3]]
        let all: [InkPrimitive] = [
            .wash(points: points, tone: 0.3, opacity: 0.4),
            .stroke(points: points, widths: [1, 2, 3], tone: 0.3, opacity: 0.4),
            .colorWash(points: points, color: [0.2, 0.6, 0.3], opacity: 0.4),
            .colorStroke(points: points, widths: [1, 2, 3], color: [0.2, 0.6, 0.3], opacity: 0.4)
        ]
        for ink in all {
            let mapped = ink.mapGeometry({ $0 * 2 + [10, 20] }, widthScale: 2)
            #expect(mapped.points.count == points.count)
            for (a, b) in zip(mapped.points, points) {
                #expect(abs(a.x - (b.x * 2 + 10)) < 1e-12)
                #expect(abs(a.y - (b.y * 2 + 20)) < 1e-12)
            }
            #expect(abs(mapped.opacity - ink.opacity) < 1e-12)
            for c in 0..<3 { #expect(abs(mapped.color[c] - ink.color[c]) < 1e-12) }
            switch (ink, mapped) {
            case (.wash, .wash), (.colorWash, .colorWash): break
            case let (.stroke(_, a, _, _), .stroke(_, b, _, _)),
                 let (.colorStroke(_, a, _, _), .colorStroke(_, b, _, _)):
                for (x, y) in zip(a, b) { #expect(abs(y - x * 2) < 1e-12) }
            default: Issue.record("Mapping changed the ink case.")
            }
        }
    }
}
