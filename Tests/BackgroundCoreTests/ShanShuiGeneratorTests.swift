import BackgroundCore
import Testing

struct ShanShuiGeneratorTests {
    @Test(arguments: [UInt64(0), 1, 42, UInt64.max])
    func seedReplayPreservesInk(seed: UInt64) {
        let generator = ShanShuiGenerator()
        let first = generator.generate(seed: seed)
        _ = generator.generate(seed: seed &+ 1)
        let replay = generator.generate(seed: seed)
        #expect(first.primitives.count == replay.primitives.count)
        for (a, b) in zip(first.primitives, replay.primitives) {
            #expect(abs(a.tone - b.tone) < 1e-12)
            #expect(abs(a.opacity - b.opacity) < 1e-12)
            #expect(a.points.count == b.points.count)
            for (p, q) in zip(a.points, b.points) {
                #expect(abs(p.x - q.x) < 1e-12)
                #expect(abs(p.y - q.y) < 1e-12)
            }
            if case let .stroke(_, aWidths, _, _) = a,
               case let .stroke(_, bWidths, _, _) = b {
                #expect(aWidths.count == bWidths.count)
                for (p, q) in zip(aWidths, bWidths) { #expect(abs(p - q) < 1e-12) }
            }
        }
    }

    @Test
    func differentSeedChangesMountainContour() throws {
        let first = ShanShuiGenerator().generate(seed: 42)
        let second = ShanShuiGenerator().generate(seed: 43)
        let a = try #require(first.primitives.first)
        let b = try #require(second.primitives.first)
        let difference = zip(a.points, b.points).map { abs($0.y - $1.y) }.max() ?? 0
        #expect(difference > 5)
    }

    @Test(arguments: [UInt64(0), 1, 42, 9_999, UInt64.max - 1, UInt64.max])
    func generatedInkHasFiniteMatchingSamples(seed: UInt64) {
        let scene = ShanShuiGenerator().generate(seed: seed)
        #expect(scene.bounds.x > 0 && scene.bounds.y > 0)
        #expect(scene.primitives.count > 100)
        for primitive in scene.primitives {
            #expect((0...1).contains(primitive.tone))
            #expect((0...1).contains(primitive.opacity))
            #expect(primitive.points.count >= 2)
            for point in primitive.points {
                #expect(point.x.isFinite && point.y.isFinite)
                #expect((0...scene.bounds.x).contains(point.x))
                #expect((0...scene.bounds.y).contains(point.y))
            }
            if case let .stroke(_, widths, _, _) = primitive {
                #expect(widths.count == primitive.points.count)
                #expect(widths.allSatisfy { $0.isFinite && $0 >= 0 && $0 < 10 })
            }
        }
    }
}
