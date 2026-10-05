@testable import BackgroundCore
import Foundation
import Testing

struct MondrianGeneratorTests {
    @Test(arguments: Array(UInt64(0)...UInt64(63)) + [.max])
    func paintingReplaysWithFiniteBoundedInk(seed: UInt64) {
        let generator = MondrianGenerator()
        let first = generator.generate(seed: seed)
        _ = generator.generate(seed: seed &+ 1)
        let second = generator.generate(seed: seed)
        #expect(abs(first.bounds.x - 1200) < 1e-12 && abs(first.bounds.y - 800) < 1e-12)
        expectMondrianInkEqual(first.primitives, second.primitives)
        #expect(!first.primitives.isEmpty && first.primitives.count <= 24 * 13 + 2 * 8 * 24)
        for cell in MondrianLayout(seed: seed).cells {
            let paint = MondrianCellPaint.draw(cell, seed: seed)
            #expect(paint.count <= 13)
            for piece in paint {
                #expect(piece.points.allSatisfy {
                    $0.x.isFinite && $0.y.isFinite
                        && $0.x >= Double(cell.rect.min.x) - 1e-9 && $0.x <= Double(cell.rect.max.x) + 1e-9
                        && $0.y >= Double(cell.rect.min.y) - 1e-9 && $0.y <= Double(cell.rect.max.y) + 1e-9
                })
                #expect([piece.color.x, piece.color.y, piece.color.z, piece.opacity]
                    .allSatisfy { $0.isFinite && (0...1).contains($0) })
            }
        }
        for piece in first.primitives {
            #expect(piece.points.allSatisfy { $0.x.isFinite && $0.y.isFinite })
            if case let .colorStroke(points, widths, _, _) = piece {
                #expect(points.count == widths.count && widths.allSatisfy { $0.isFinite && $0 > 0 && $0 < 20 })
            }
        }
    }

    @Test func pigmentStyleChangesActualPaintWithoutMovingLayoutOrDividers() {
        let layout = MondrianLayout(seed: 42)
        let edges = MondrianEdges.make(cells: layout.cells)
        let original = edges.flatMap { MondrianDividerInk.draw($0, seed: 42) }
        var changed: Int = 0
        for cell in layout.cells where cell.color != .white {
            let a = MondrianCellPaint.draw(cell, seed: 42, style: .restrained)
            let b = MondrianCellPaint.draw(cell, seed: 42, style: .layered)
            if a.count != b.count { changed += 1 }
        }
        #expect(changed > 0)
        let a = MondrianGenerator(paintStyle: .restrained).generate(seed: 42)
        let b = MondrianGenerator(paintStyle: .layered).generate(seed: 42)
        #expect(a.primitives.count != b.primitives.count)
        let strokes: (InkScene) -> [InkPrimitive] = { scene in
            scene.primitives.filter { if case .colorStroke = $0 { true } else { false } }
        }
        expectMondrianInkEqual(original, strokes(a))
        expectMondrianInkEqual(strokes(a), strokes(b))
        let repeated = MondrianLayout(seed: 42)
        for (x, y) in zip(layout.cells, repeated.cells) {
            #expect(x.id == y.id && x.color == y.color && x.rect.min == y.rect.min && x.rect.max == y.rect.max)
        }
    }

    @Test func clippingCrossesEveryCellSideAndRejectsOutsidePolygons() {
        let rect = MondrianRect(min: [100, 100], max: [200, 200])
        let points: [SIMD2<Double>] = (0..<32).map { i in
            let t: Double = Double(i) * 2 * .pi / 32
            let p: SIMD2<Double> = [90 * cos(t), 80 * sin(t)]
            return [150 + p.x * cos(0.4) - p.y * sin(0.4),
                    150 + p.x * sin(0.4) + p.y * cos(0.4)]
        }
        let clipped = MondrianCellPaint.clip(points, to: rect)
        #expect(clipped.count == 4)
        let area: Double = abs(clipped.indices.reduce(0.0) { sum, i in
            let a = clipped[i], b = clipped[(i + 1) % clipped.count]
            return sum + a.x * b.y - a.y * b.x
        }) * 0.5
        #expect(abs(area - 10_000) < 1e-8)
        #expect(MondrianCellPaint.clip([[0, 0], [10, 0], [10, 10], [0, 10]], to: rect).isEmpty)
    }

    @Test func changedSeedChangesActualPaintGeometry() {
        let a = MondrianGenerator().generate(seed: 42).primitives.flatMap(\.points)
        let b = MondrianGenerator().generate(seed: 43).primitives.flatMap(\.points)
        #expect(a.count != b.count || zip(a, b).contains { abs($0.x - $1.x) > 1e-6 || abs($0.y - $1.y) > 1e-6 })
    }
}

func expectMondrianInkEqual(_ a: [InkPrimitive], _ b: [InkPrimitive]) {
    #expect(a.count == b.count)
    for (p, q) in zip(a, b) {
        #expect(abs(p.opacity - q.opacity) < 1e-12)
        for c in 0..<3 { #expect(abs(p.color[c] - q.color[c]) < 1e-12) }
        #expect(p.points.count == q.points.count)
        for (u, v) in zip(p.points, q.points) {
            #expect(abs(u.x - v.x) < 1e-12 && abs(u.y - v.y) < 1e-12)
        }
        switch (p, q) {
        case (.colorWash, .colorWash): break
        case let (.colorStroke(_, x, _, _), .colorStroke(_, y, _, _)):
            #expect(x.count == y.count)
            for (u, v) in zip(x, y) { #expect(abs(u - v) < 1e-12) }
        default: Issue.record("Replay changed the primitive case.")
        }
    }
}
