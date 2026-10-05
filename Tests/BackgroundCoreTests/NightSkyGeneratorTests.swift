@testable import BackgroundCore
import Testing

struct NightSkyGeneratorTests {
    @Test(arguments: Array(UInt64(0)...UInt64(31)) + [42, 43, .max],
          [Int64.min, -9, -1, 0, 1, 9, .max])
    func skyReplaysWithFiniteLocalInk(seed: UInt64, index: Int64) {
        let generator = NightSkyChunkGenerator()
        let first = generator.generate(seed: seed, index: index)
        for other: Int64 in [2, -1, 0, 4, -3] { _ = generator.generate(seed: seed &+ 1, index: other) }
        let repeated = generator.generate(seed: seed, index: index)
        #expect(first.index == index && repeated.scene.seed == first.scene.seed)
        expectNightSkyInkEqual(first.scene.primitives, repeated.scene.primitives)
        #expect(!first.scene.primitives.isEmpty)
        for ink in first.scene.primitives {
            #expect(ink.points.allSatisfy {
                $0.x.isFinite && $0.y.isFinite && $0.x >= -1e-9 && $0.x <= 1200 + 1e-9
                    && $0.y >= -1e-9 && $0.y <= 800 + 1e-9
            })
            #expect([ink.color.x, ink.color.y, ink.color.z, ink.opacity].allSatisfy {
                $0.isFinite && (0...1).contains($0)
            })
            if case let .colorStroke(points, widths, _, _) = ink {
                #expect(points.count == widths.count && widths.allSatisfy { $0.isFinite && $0 >= 0 })
            }
        }
    }

    @Test func drawingDetailVariationPreservesPlacementsAndOtherInk() throws {
        let layout = NightSkyComposition(seed: 42, index: 0)
        let moon = try #require(layout.moon)
        let before = NightSkyMoonInk.draw(moon)
        let original = NightSkyChunkGenerator().generate(seed: 42, index: 0).scene.primitives
        for group in layout.groups {
            _ = NightSkyInk.group(group)
            let extra = NightSkyWashGroup(id: group.id, lobes: group.lobes + group.lobes.prefix(1), envelope: group.envelope)
            _ = NightSkyInk.group(extra)
        }
        for star in layout.stars {
            _ = NightSkyInk.star(.init(anchor: star.anchor, radius: star.radius,
                                      isAccent: star.isAccent, seed: star.seed ^ 0xD37A))
        }
        expectNightSkyInkEqual(before, NightSkyMoonInk.draw(moon))
        expectNightSkyInkEqual(original, NightSkyChunkGenerator().generate(seed: 42, index: 0).scene.primitives)
        let repeated = NightSkyComposition(seed: 42, index: 0)
        #expect(repeated.stars.count == layout.stars.count)
        for (a, b) in zip(layout.stars, repeated.stars) {
            #expect(abs(a.anchor.x - b.anchor.x) < 1e-12 && abs(a.anchor.y - b.anchor.y) < 1e-12)
        }
        #expect(abs(try #require(repeated.moon).anchor.x - moon.anchor.x) < 1e-12)
    }

    @Test func changedSeedChangesActualSkyGeometry() {
        let a = NightSkyChunkGenerator().generate(seed: 42, index: 0).scene.primitives.flatMap(\.points)
        let b = NightSkyChunkGenerator().generate(seed: 43, index: 0).scene.primitives.flatMap(\.points)
        #expect(a.count != b.count || zip(a, b).contains { abs($0.x - $1.x) > 1e-6 || abs($0.y - $1.y) > 1e-6 })
    }
}

func expectNightSkyInkEqual(_ a: [InkPrimitive], _ b: [InkPrimitive]) {
    #expect(a.count == b.count)
    for (p, q) in zip(a, b) {
        #expect(abs(p.opacity - q.opacity) < 1e-12)
        for c in 0..<3 { #expect(abs(p.color[c] - q.color[c]) < 1e-12) }
        #expect(p.points.count == q.points.count)
        for (u, v) in zip(p.points, q.points) { #expect(abs(u.x - v.x) < 1e-12 && abs(u.y - v.y) < 1e-12) }
        switch (p, q) {
        case (.wash, .wash), (.colorWash, .colorWash): break
        case let (.stroke(_, x, _, _), .stroke(_, y, _, _)),
             let (.colorStroke(_, x, _, _), .colorStroke(_, y, _, _)):
            #expect(x.count == y.count)
            for (u, v) in zip(x, y) { #expect(abs(u - v) < 1e-12) }
        default: Issue.record("Replay changed primitive case.")
        }
    }
}
