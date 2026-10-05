@testable import BackgroundCore
import Testing

struct GardenWallMasonryTests {
    @Test(arguments: [Int64.min, -2, -1, 0, 1, Int64.max - 1], [UInt64(0), 42, 43, .max])
    func adjacentMasonrySharesCanonicalCells(index: Int64, seed: UInt64) throws {
        let left = GardenWallMasonry(seed: seed, index: index)
        let next = index.addingReportingOverflow(1)
        #expect(!next.overflow)
        let right = GardenWallMasonry(seed: seed, index: next.partialValue)
        #expect(abs(left.capY - right.capY) < 1e-12)
        #expect(left.courses.count == right.courses.count)
        for (a, b) in zip(left.courses, right.courses) { #expect(abs(a - b) < 1e-12) }
        let crossing = left.stones.filter { $0.polygon.contains { $0.x > 1200 } }
        #expect(!crossing.isEmpty)
        for a in crossing {
            let b = try #require(right.stones.first { $0.id == a.id })
            #expect(a.polygon.count == b.polygon.count)
            for (p, q) in zip(a.polygon, b.polygon) {
                #expect(abs(p.x - 1200 - q.x) < 1e-12 && abs(p.y - q.y) < 1e-12)
            }
            for c in 0..<3 { #expect(abs(a.color[c] - b.color[c]) < 1e-12) }
            #expect(abs(a.opacity - b.opacity) < 1e-12)
        }
    }

    @Test(arguments: [Int64.min, Int64.max])
    func endpointMasonryIsFiniteAndLocal(index: Int64) {
        let wall = GardenWallMasonry(seed: .max, index: index)
        #expect(Set(wall.stones.map(\.id)).count == wall.stones.count)
        #expect(!wall.primitives.isEmpty)
        #expect(wall.primitives.flatMap(\.points).allSatisfy {
            $0.x.isFinite && $0.y.isFinite && (0...1200).contains($0.x) && (0...800).contains($0.y)
        })
    }

    @Test(arguments: [false, true])
    func washClippingPreservesKnownAreaInBothWindings(reversed: Bool) throws {
        let p: [SIMD2<Double>] = [[-5, 2], [15, 2], [15, 8], [-5, 8]]
        let ink: InkPrimitive = .colorWash(points: reversed ? p.reversed() : p, color: [0.2, 0.6, 0.3], opacity: 0.4)
        let clipped = InkClipping.horizontally([ink], minX: 0, maxX: 10)
        let shape = try #require(clipped.first)
        let area: Double = zip(shape.points, shape.points.dropFirst() + [shape.points[0]])
            .reduce(0) { $0 + $1.0.x * $1.1.y - $1.1.x * $1.0.y } * 0.5
        #expect(abs(abs(area) - 60) < 1e-10)
        #expect((reversed ? area < 0 : area > 0))
        #expect(shape.points.allSatisfy { (0...10).contains($0.x) })
        let outside: InkPrimitive = .wash(points: [[20, 2], [25, 2], [20, 8]], tone: 0, opacity: 1)
        #expect(InkClipping.horizontally([outside], minX: 0, maxX: 10).isEmpty)
    }

    @Test func strokeClippingInterpolatesWidthsAndNeverBridgesGaps() throws {
        let ink: InkPrimitive = .colorStroke(points: [[-10, 5], [20, 5]], widths: [2, 8],
                                              color: [0.2, 0.6, 0.3], opacity: 0.4)
        let clipped = InkClipping.horizontally([ink], minX: 0, maxX: 10)
        guard case let .colorStroke(points, widths, _, _) = try #require(clipped.first) else {
            Issue.record("Lost stroke/color."); return
        }
        #expect(abs(points[0].x) < 1e-12 && abs(points[1].x - 10) < 1e-12)
        #expect(abs(widths[0] - 4) < 1e-12 && abs(widths[1] - 6) < 1e-12)
        let separate: InkPrimitive = .stroke(points: [[5, 2], [20, 2], [20, 8], [5, 8]],
                                             widths: [2, 2, 2, 2], tone: 0, opacity: 1)
        let runs = InkClipping.horizontally([separate], minX: 0, maxX: 10)
        #expect(runs.count == 2)
        #expect(runs[0].points.allSatisfy { abs($0.y - 2) < 1e-12 })
        #expect(runs[1].points.allSatisfy { abs($0.y - 8) < 1e-12 })
        let vertical: InkPrimitive = .stroke(points: [[5, 2], [5, 2], [5, 8]], widths: [2, 2, 2], tone: 0, opacity: 1)
        #expect(InkClipping.horizontally([vertical], minX: 0, maxX: 10).count == 1)
        let touch: InkPrimitive = .stroke(points: [[-5, 2], [0, 5], [-5, 8]], widths: [2, 2, 2], tone: 0, opacity: 1)
        #expect(InkClipping.horizontally([touch], minX: 0, maxX: 10).isEmpty)
    }
}
