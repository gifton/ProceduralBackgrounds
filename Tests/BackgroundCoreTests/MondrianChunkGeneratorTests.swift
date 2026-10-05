@testable import BackgroundCore
import Testing

struct MondrianChunkGeneratorTests {
    @Test(arguments: Array(UInt64(0)...UInt64(31)) + [42, 43, .max],
          [Int64.min, .min + 1, -9, -3, -1, 0, 1, 3, 9, .max - 1, .max])
    func indexedInkReplaysAndKeepsItsBounds(seed: UInt64, index: Int64) throws {
        let generator = MondrianChunkGenerator()
        let first = try generator.generate(seed: seed, index: index)
        _ = try generator.generate(seed: seed &+ 1, index: index)
        let second = try generator.generate(seed: seed, index: index)
        #expect(first.index == index)
        #expect(abs(first.scene.bounds.x - 1200) < 1e-12 && abs(first.scene.bounds.y - 800) < 1e-12)
        expectMondrianInkEqual(first.scene.primitives, second.scene.primitives)
        #expect(!first.scene.primitives.isEmpty && first.scene.primitives.count <= 2856)
        let composition = try MondrianWorldComposition(seed: seed, index: index)
        #expect(composition.reconstructedCellCount <= 120 && composition.cells.count <= 72)
        #expect(composition.edges.count <= 960)
        for piece in first.scene.primitives {
            #expect(piece.points.allSatisfy {
                $0.x.isFinite && $0.y.isFinite && abs($0.x) < 10_000 && $0.y >= 0 && $0.y <= 800
            })
            #expect([piece.color.x, piece.color.y, piece.color.z, piece.opacity]
                .allSatisfy { $0.isFinite && (0...1).contains($0) })
            switch piece {
            case .colorWash: #expect(piece.points.count <= 28)
            case let .colorStroke(points, widths, _, _):
                #expect(points.count == 5 && widths.count == 5)
                #expect(widths.allSatisfy { $0.isFinite && $0 > 0 && $0 <= 11 })
            default: Issue.record("World ink must retain RGB primitives.")
            }
        }
    }

    @Test func crossingCellPaintAgreesAfterReceivingChunkTranslation() throws {
        var coloredWitnesses: Int = 0
        for seed: UInt64 in [0, 7, 42, 43] {
            for index: Int64 in -3...2 {
                let a = try MondrianWorldComposition(seed: seed, index: index)
                let b = try MondrianWorldComposition(seed: seed, index: index + 1)
                for cell in a.cells where cell.color != .white {
                    guard let counterpart = b.cells.first(where: { $0.id == cell.id }) else { continue }
                    let aa = try MondrianWorldInk.cell(cell, seed: seed, relativeTo: a.origin.owner,
                                                       xOffset: Double(a.origin.offset))
                    let bb = try MondrianWorldInk.cell(counterpart, seed: seed, relativeTo: b.origin.owner,
                                                       xOffset: Double(b.origin.offset))
                    #expect(!aa.isEmpty && aa.count == bb.count)
                    for (p, q) in zip(aa, bb) {
                        #expect(p.points.count == q.points.count)
                        #expect(abs(p.opacity - q.opacity) < 1e-12)
                        for channel in 0..<3 { #expect(abs(p.color[channel] - q.color[channel]) < 1e-12) }
                        for (x, y) in zip(p.points, q.points) {
                            #expect(abs(x.x - y.x - 1200) < 1e-9 && abs(x.y - y.y) < 1e-9)
                        }
                    }
                    coloredWitnesses += 1
                }
            }
        }
        #expect(coloredWitnesses > 0)
    }

    @Test func pigmentStyleChangesWashesWithoutMovingCompositionOrDividers() throws {
        let metadata = try MondrianWorldComposition(seed: 42, index: 0)
        let a = try MondrianChunkGenerator(paintStyle: .restrained).generate(seed: 42, index: 0)
        let b = try MondrianChunkGenerator(paintStyle: .layered).generate(seed: 42, index: 0)
        #expect(a.scene.primitives.count != b.scene.primitives.count)
        let strokes: (InkScene) -> [InkPrimitive] = { $0.primitives.filter { if case .colorStroke = $0 { true } else { false } } }
        expectMondrianInkEqual(strokes(a.scene), strokes(b.scene))
        let restored = try MondrianWorldComposition(seed: 42, index: 0)
        expectWorldCellsEqual(metadata.cells, restored.cells)
        #expect(metadata.edges.map(\.id) == restored.edges.map(\.id))
    }

    @Test func shuffledWorldVisitsReplaySelectedInk() throws {
        let initial = try MondrianChunkGenerator().generate(seed: 42, index: -1)
        for index: Int64 in [5, -9, 1, 0, -3, 9] {
            _ = try MondrianChunkGenerator().generate(seed: 42, index: index)
        }
        let restored = try MondrianChunkGenerator().generate(seed: 42, index: -1)
        expectMondrianInkEqual(initial.scene.primitives, restored.scene.primitives)
        let changed = try MondrianChunkGenerator().generate(seed: 43, index: -1)
        let a = initial.scene.primitives.flatMap(\.points), b = changed.scene.primitives.flatMap(\.points)
        #expect(a.count != b.count || zip(a, b).contains { abs($0.x - $1.x) > 1e-6 || abs($0.y - $1.y) > 1e-6 })
    }
}
