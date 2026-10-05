import BackgroundCore
import Testing

struct ShanShuiElementTests {
    @Test(arguments: ShanShuiElement.allCases, [UInt64(0), 1, 42, 9_999, UInt64.max - 1, UInt64.max])
    func elementReplayIsIndependentOfOtherSubjects(element: ShanShuiElement, seed: UInt64) {
        let generator = ShanShuiElementGenerator(element: element)
        let first = generator.generate(seed: seed)
        for other in ShanShuiElement.allCases {
            _ = ShanShuiElementGenerator(element: other).generate(seed: seed &+ 1)
        }
        let replay = generator.generate(seed: seed)
        #expect(first.primitives.count == replay.primitives.count)
        for (a, b) in zip(first.primitives, replay.primitives) {
            #expect(abs(a.tone - b.tone) < 1e-12 && abs(a.opacity - b.opacity) < 1e-12)
            #expect(a.points.count == b.points.count)
            for (p, q) in zip(a.points, b.points) {
                #expect(abs(p.x - q.x) < 1e-12 && abs(p.y - q.y) < 1e-12)
            }
            switch (a, b) {
            case let (.stroke(_, wa, _, _), .stroke(_, wb, _, _)):
                #expect(wa.count == wb.count)
                for (p, q) in zip(wa, wb) { #expect(abs(p - q) < 1e-12) }
            case (.wash, .wash): break
            default: Issue.record("Replay changed the ink primitive kind.")
            }
        }
    }

    @Test(arguments: ShanShuiElement.allCases)
    func everyElementChangesWithSeed(element: ShanShuiElement) {
        let generator = ShanShuiElementGenerator(element: element)
        let a = generator.generate(seed: 42).primitives
        let b = generator.generate(seed: 43).primitives
        let differs = a.count != b.count || zip(a, b).contains { p, q in
            p.points.count != q.points.count || zip(p.points, q.points).contains {
                abs($0.x - $1.x) + abs($0.y - $1.y) > 0.2
            }
        }
        #expect(differs)
    }

    @Test(arguments: ShanShuiElement.allCases, [UInt64(0), 1, 42, 43, 9_999, UInt64.max - 1, UInt64.max])
    func everyElementFitsItsStudyWithValidInk(element: ShanShuiElement, seed: UInt64) {
        let scene = ShanShuiElementGenerator(element: element).generate(seed: seed)
        #expect(scene.bounds.x > 0 && scene.bounds.y > 0)
        #expect(!scene.primitives.isEmpty)
        for primitive in scene.primitives {
            #expect((0...1).contains(primitive.tone) && (0...1).contains(primitive.opacity))
            #expect(primitive.points.count >= 2)
            #expect(primitive.points.allSatisfy {
                $0.x.isFinite && $0.y.isFinite
                    && (0...scene.bounds.x).contains($0.x) && (0...scene.bounds.y).contains($0.y)
            })
            if case let .stroke(points, widths, _, _) = primitive {
                #expect(points.count == widths.count)
                #expect(widths.allSatisfy { $0.isFinite && $0 >= 0 })
            }
        }
    }

    @Test
    func boatStudyIncludesFigureAboveAndHullBelowWaterline() {
        // The study puts the waterline at y=430. The figure must extend above
        // y=360, while the curved hull reaches below y=440.
        let scene = ShanShuiElementGenerator(element: .boat).generate(seed: 42)
        #expect(scene.primitives.contains {
            $0.tone < 0.6 && $0.points.contains { $0.x < 400 && $0.y < 360 }
        })
        #expect(scene.primitives.contains {
            $0.tone < 0.6 && $0.points.contains { $0.y > 440 }
        })
    }
}
