@testable import BackgroundCore
import Testing

struct MondrianWorldLayoutTests {
    @Test(arguments: Array(UInt64(0)...UInt64(63)) + [.max], [Int64(-3), -1, 0, 1, 3])
    func ownershipGroupsCoverTheirRegionsWithDisjointCells(seed: UInt64, owner: Int64) throws {
        let layout = try MondrianWorldLayout(seed: seed, owner: owner)
        #expect((16...24).contains(layout.cells.count))
        #expect(Set(layout.cells.map(\.id)).count == layout.cells.count)
        #expect(Set(layout.cells.map(\.color)) == Set(MondrianColor.allCases))
        for cell in layout.cells {
            #expect(cell.id.owner == owner)
            #expect((80...2960).contains(cell.rect.width) && (80...800).contains(cell.rect.height))
            #expect(cell.rect.min.y >= 0 && cell.rect.max.y <= 800)
        }
        let boundary = MondrianWorldBoundary(seed: seed, owner: owner)
        #expect((320...880).contains(boundary.jitter))
        #expect((240...560).contains(boundary.leftReach) && (240...560).contains(boundary.rightReach))
        #expect([80, 160, 240].contains(boundary.top) && [320, 400, 480].contains(boundary.height))
        let bridge = try #require(layout.cells.first { $0.id.kind == .bridge })
        #expect(bridge.color == .red || bridge.color == .blue)
        #expect(bridge.rect.min == boundary.bridge.min && bridge.rect.max == boundary.bridge.max)
        #expect((480...1120).contains(bridge.rect.width) && (320...480).contains(bridge.rect.height))
        let rectangles = try worldRectangles(seed: seed, anchor: owner, deltas: -1...1)
        assertWorldCoverage(rectangles, bounds: layout.bounds)
        _ = try MondrianWorldLayout(seed: seed &+ 1, owner: owner + 7)
        let replay = try MondrianWorldLayout(seed: seed, owner: owner)
        expectWorldCellsEqual(layout.cells, replay.cells)
    }

    @Test(arguments: [UInt64(0), 7, 42, 43, .max],
          [Int64.min, .min + 1, -3, -1, 0, 1, .max - 1, .max])
    func fullSignedChunkRangeHasExactCoverage(seed: UInt64, index: Int64) throws {
        let origin = MondrianWorldAddress(chunk: index)
        let rectangles = try worldRectangles(seed: seed, anchor: origin.owner, deltas: -2...2)
        assertWorldCoverage(rectangles,
            bounds: MondrianRect(min: [origin.offset, 0], max: [origin.offset + 1200, 800]))
    }

    @Test func invalidOwnerLookaheadReportsOverflow() {
        #expect(throws: MondrianWorldError.indexOverflow) {
            try MondrianWorldLayout(seed: 42, owner: .max)
        }
    }

    @Test func layoutsVaryAndReportSoftAreaBalance() throws {
        var descriptions: Set<String> = []
        var areas: [MondrianColor: Int] = [:]
        for seed: UInt64 in 0..<32 {
            let cells = try MondrianWorldLayout(seed: seed, owner: 0).cells
            descriptions.insert(cells.map {
                "\($0.rect.min.x),\($0.rect.min.y),\($0.rect.max.x),\($0.rect.max.y)"
            }.joined(separator: ";"))
            for cell in cells { areas[cell.color, default: 0] += cell.rect.area }
        }
        #expect(descriptions.count >= 8)
        let total: Double = Double(areas.values.reduce(0, +))
        let primary: Double = Double((areas[.red] ?? 0) + (areas[.blue] ?? 0) + (areas[.yellow] ?? 0)) / total
        print("Mondrian world area balance: primary \(primary), white \(Double(areas[.white] ?? 0) / total), black \(Double(areas[.black] ?? 0) / total)")
    }
}

private func worldRectangles(seed: UInt64, anchor: Int64, deltas: ClosedRange<Int64>) throws -> [MondrianRect] {
    try deltas.flatMap { delta in
        let neighbor = anchor.addingReportingOverflow(delta)
        #expect(!neighbor.overflow)
        let cells = try MondrianWorldLayout(seed: seed, owner: neighbor.partialValue).cells
        let shift: Int = Int(delta) * 2400
        return cells.map {
            MondrianRect(min: [$0.rect.min.x + shift, $0.rect.min.y],
                         max: [$0.rect.max.x + shift, $0.rect.max.y])
        }
    }
}

private func worldIntersection(_ a: MondrianRect, _ b: MondrianRect) -> MondrianRect? {
    let lo: SIMD2<Int> = [max(a.min.x, b.min.x), max(a.min.y, b.min.y)]
    let hi: SIMD2<Int> = [min(a.max.x, b.max.x), min(a.max.y, b.max.y)]
    return hi.x > lo.x && hi.y > lo.y ? MondrianRect(min: lo, max: hi) : nil
}

private func assertWorldCoverage(_ rectangles: [MondrianRect], bounds: MondrianRect) {
    let pieces = rectangles.compactMap { worldIntersection($0, bounds) }
    #expect(pieces.reduce(0) { $0 + $1.area } == bounds.area)
    for i in pieces.indices {
        for j in pieces.indices where j > i {
            #expect(worldIntersection(pieces[i], pieces[j])?.area == nil)
        }
    }
}

func expectWorldCellsEqual(_ a: [MondrianWorldCell], _ b: [MondrianWorldCell]) {
    #expect(a.count == b.count)
    for (x, y) in zip(a, b) {
        #expect(x.id == y.id && x.color == y.color)
        #expect(x.rect.min == y.rect.min && x.rect.max == y.rect.max)
    }
}
