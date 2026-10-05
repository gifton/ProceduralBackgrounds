import BackgroundCore
import Testing

struct ShanShuiLandscapeTests {
    @Test(arguments: [UInt64(0), 1, 42, 9_999, UInt64.max - 1, UInt64.max])
    func landscapeReplayPreservesAllInk(seed: UInt64) {
        let generator = ShanShuiLandscapeGenerator()
        let first = generator.generate(seed: seed)
        _ = generator.generate(seed: seed &+ 1)
        _ = ShanShuiGenerator().generate(seed: seed)
        let replay = generator.generate(seed: seed)
        #expect(first.primitives.count == replay.primitives.count)
        for (a, b) in zip(first.primitives, replay.primitives) {
            #expect(abs(a.tone - b.tone) < 1e-12)
            #expect(abs(a.opacity - b.opacity) < 1e-12)
            #expect(a.points.count == b.points.count)
            for (p, q) in zip(a.points, b.points) {
                #expect(abs(p.x - q.x) < 1e-12 && abs(p.y - q.y) < 1e-12)
            }
            switch (a, b) {
            case let (.stroke(_, widthsA, _, _), .stroke(_, widthsB, _, _)):
                #expect(widthsA.count == widthsB.count)
                for (p, q) in zip(widthsA, widthsB) { #expect(abs(p - q) < 1e-12) }
            case (.wash, .wash): break
            default: Issue.record("Replay changed the primitive kind.")
            }
        }
    }

    @Test
    func landscapeChangesWithSeed() throws {
        let a = try #require(ShanShuiLandscapeGenerator().generate(seed: 42).primitives.first)
        let b = try #require(ShanShuiLandscapeGenerator().generate(seed: 43).primitives.first)
        #expect(zip(a.points, b.points).contains { abs($0.x - $1.x) + abs($0.y - $1.y) > 5 })
    }

    @Test
    func landscapeSeedsChangeThePopulation() {
        // A fixed collection with only noisy contours would have one count.
        let counts = Set((0..<32).map {
            ShanShuiLandscapeGenerator().generate(seed: UInt64($0)).primitives.count
        })
        #expect(counts.count > 4)
    }

    @Test(arguments: (0..<32).map { UInt64($0) } + [42, 43, 60, 9_999, 793_993, 7_293_725_857_078_157_220, UInt64.max - 1, UInt64.max])
    func landscapeGeometryStaysWithinWorld(seed: UInt64) {
        let scene = ShanShuiLandscapeGenerator().generate(seed: seed)
        #expect(abs(scene.bounds.x - 1200) < 1e-12 && abs(scene.bounds.y - 800) < 1e-12)
        #expect(scene.primitives.count > 1000)
        for primitive in scene.primitives {
            #expect((0...1).contains(primitive.tone) && (0...1).contains(primitive.opacity))
            #expect(primitive.points.count >= 2)
            #expect(primitive.points.allSatisfy {
                $0.x.isFinite && $0.y.isFinite && (0...1200).contains($0.x) && (0...800).contains($0.y)
            })
            if case let .stroke(_, widths, _, _) = primitive {
                #expect(widths.count == primitive.points.count)
                #expect(widths.allSatisfy { $0.isFinite && $0 >= 0 && $0 < 12 })
            }
        }
    }

    @Test
    func landscapeIncludesDepthAndOpenWater() {
        let scene = ShanShuiLandscapeGenerator().generate(seed: 42)
        #expect(scene.primitives.contains {
            $0.tone > 0.8 && $0.tone < 0.97 && $0.opacity > 0.2
                && $0.points.contains { $0.x > 850 && $0.y < 350 }
        })
        let waterMarks = scene.primitives.filter { primitive in
            guard case .stroke = primitive, let first = primitive.points.first,
                  let last = primitive.points.last else { return false }
            return primitive.points.allSatisfy { $0.x > 650 && $0.y > 610 && $0.y < 755 }
                && last.x - first.x > 20 && abs(last.y - first.y) < 4
                && primitive.opacity < 0.3
        }
        #expect(waterMarks.count > 10)
    }
}
