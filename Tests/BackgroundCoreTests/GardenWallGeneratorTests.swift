@testable import BackgroundCore
import Testing

struct GardenWallGeneratorTests {
    @Test(arguments: [UInt64(0), 1, 42, 43, 9999, .max],
          [Int64.min, -20, -1, 0, 1, 20, .max])
    func gardenReplaysRegardlessOfVisitOrder(seed: UInt64, index: Int64) {
        let generator = GardenWallChunkGenerator()
        let first = generator.generate(seed: seed, index: index)
        for other: Int64 in [2, -1, 0, 4, -3] { _ = generator.generate(seed: seed &+ 1, index: other) }
        expectGardenInkEqual(first.scene, generator.generate(seed: seed, index: index).scene)
    }

    @Test func initialCatHasBothPosesAndLaterChunksHaveQuietStretches() throws {
        #expect(try #require(GardenWallComposition(seed: 42, index: 0).cat).pose == .sleeping)
        #expect(try #require(GardenWallComposition(seed: 43, index: 0).cat).pose == .sitting)
        var poses: Set<GardenWallCatPose> = []
        var kinds: Set<GardenWallPlantKind> = []
        var emptyCount: Int = 0
        for seed: UInt64 in 0..<64 {
            for index: Int64 in -2...2 {
                let layout = GardenWallComposition(seed: seed, index: index)
                if let cat = layout.cat { poses.insert(cat.pose) }
                else { emptyCount += 1 }
                kinds.formUnion(layout.plants.map(\.kind))
            }
        }
        #expect(poses.count == 2 && kinds.count == 4 && emptyCount > 0)
    }

    @Test(arguments: Array(UInt64(0)...UInt64(63)))
    func populationsAreBoundedAndCatHasClearSupport(seed: UInt64) throws {
        for index: Int64 in -2...2 {
            let layout = GardenWallComposition(seed: seed, index: index)
            #expect(layout.plants.count <= 6 && layout.pots.count <= 2)
            if index == 0 { #expect(layout.cat != nil) }
            if let cat = layout.cat {
                #expect(abs(cat.anchor.y - layout.masonry.capY) < 1e-12)
                #expect(cat.envelope.min.x >= 12 && cat.envelope.max.x <= 1188)
                #expect(cat.envelope.min.y >= 12 && cat.envelope.max.y <= 788)
                if index == 0 { #expect((560...640).contains(cat.anchor.x)) }
                for plant in layout.plants { #expect(!plant.envelope.intersects(cat.envelope)) }
                let ink = GardenWallCatElements.draw(cat)
                for point in ink.flatMap(\.points) where !cat.envelope.contains(point, padding: 4 * cat.scale) {
                    Issue.record("Cat envelope violation: pose=\(cat.pose) local=\((point - cat.anchor) / cat.scale)")
                }
            }
            for plant in layout.plants {
                #expect(GardenWallPlantElements.draw(plant).flatMap(\.points).allSatisfy {
                    plant.envelope.contains($0, padding: 2 * plant.scale)
                })
            }
            let scene = GardenWallChunkGenerator().generate(seed: seed, index: index).scene
            #expect(!scene.primitives.isEmpty)
            for ink in scene.primitives {
                #expect(ink.points.allSatisfy {
                    $0.x.isFinite && $0.y.isFinite && (0...1200).contains($0.x) && (0...800).contains($0.y)
                })
                #expect([ink.color.x, ink.color.y, ink.color.z, ink.opacity].allSatisfy {
                    $0.isFinite && (0...1).contains($0)
                })
                if case let .colorStroke(points, widths, _, _) = ink {
                    #expect(points.count == widths.count && widths.allSatisfy { $0.isFinite && $0 >= 0 })
                }
            }
        }
    }

    @Test func subjectDrawingDoesNotConsumeAnotherSubjectsStream() throws {
        let layout = GardenWallComposition(seed: 42, index: 0)
        let cat = try #require(layout.cat)
        let first = GardenWallCatElements.draw(cat)
        for plant in layout.plants { _ = GardenWallPlantElements.draw(plant) }
        for pot in layout.pots { _ = GardenWallPlantElements.pot(pot) }
        expectGardenInkEqual(InkScene(seed: 42, bounds: [1200, 800], primitives: first),
                            InkScene(seed: 42, bounds: [1200, 800], primitives: GardenWallCatElements.draw(cat)))
    }
}

private func expectGardenInkEqual(_ a: InkScene, _ b: InkScene) {
    #expect(abs(a.bounds.x - b.bounds.x) < 1e-12 && abs(a.bounds.y - b.bounds.y) < 1e-12)
    #expect(a.primitives.count == b.primitives.count)
    for (p, q) in zip(a.primitives, b.primitives) {
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
