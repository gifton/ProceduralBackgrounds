@testable import BackgroundCore
import Testing

struct MondrianWorldEdgeTests {
    @Test func unequalTJunctionsHaveOneCompleteDividerAndNoTransportBorder() throws {
        let cells: [MondrianWorldCell] = [
            edgeCell(slot: 0, min: [0, 0], max: [1197, 800]),
            edgeCell(slot: 1, min: [1197, 0], max: [2400, 200]),
            edgeCell(slot: 2, min: [1197, 200], max: [2400, 500]),
            edgeCell(slot: 3, min: [1197, 500], max: [2400, 800])
        ]
        let edges = try MondrianWorldEdges.make(cells: cells, relativeTo: 0)
        let x = try MondrianWorldAddress(owner: 0, offset: 1197)
        let vertical = edges.filter { $0.id.axis == .vertical && $0.id.startX == x }
        #expect(vertical.map { $0.id.startY } == [0, 200, 500])
        #expect(vertical.map { $0.id.endY } == [200, 500, 800])
        #expect(Set(edges.map(\.id)).count == edges.count)
        #expect(edges.allSatisfy { $0.id.axis != .vertical || $0.id.startX.offset != 1200 })
        #expect(try MondrianWorldEdges.make(cells: cells.reversed(), relativeTo: 0).map(\.id) == edges.map(\.id))
        try expectAllSidesCovered(cells: cells, edges: edges, anchor: 0)
    }

    @Test(arguments: [UInt64(0), 7, 42, 43, .max], [Int64(-3), -2, -1, 0, 1, 2])
    func adjacentNeighborhoodsAgreeOnFullSegmentsAndSeeds(seed: UInt64, left: Int64) throws {
        let a = MondrianWorldAddress(chunk: left)
        let b = MondrianWorldAddress(chunk: left + 1)
        let boundary: Double = Double(try b.relativeX(to: a.owner))
        let first = try edgesInNeighborhood(seed: seed, anchor: a.owner)
        let second = try edgesInNeighborhood(seed: seed, anchor: b.owner)
        func touching(_ edges: [MondrianWorldEdge]) throws -> [MondrianWorldEdge] {
            try edges.filter {
                let line = try $0.local(relativeTo: a.owner)
                return min(line.start.x, line.end.x) <= boundary + 6
                    && max(line.start.x, line.end.x) >= boundary - 6
            }
        }
        let aa = try touching(first), bb = try touching(second)
        #expect(!aa.isEmpty && aa.map(\.id) == bb.map(\.id))
        #expect(first.count <= 960 && second.count <= 960)
        for (x, y) in zip(aa, bb) {
            let p = try x.local(relativeTo: a.owner), q = try y.local(relativeTo: a.owner)
            #expect(abs(p.start.x - q.start.x) < 1e-12 && abs(p.start.y - q.start.y) < 1e-12)
            #expect(abs(p.end.x - q.end.x) < 1e-12 && abs(p.end.y - q.end.y) < 1e-12)
            #expect(MondrianWorldSeeds.edge(seed: seed, id: x.id) == MondrianWorldSeeds.edge(seed: seed, id: y.id))
        }
    }

    @Test(arguments: [UInt64(0), 42, .max])
    func everyCanonicalCellSideHasUniqueOrderedCoverage(seed: UInt64) throws {
        let cells = try (-2...2).flatMap { try MondrianWorldLayout(seed: seed, owner: Int64($0)).cells }
        let edges = try MondrianWorldEdges.make(cells: cells, relativeTo: 0)
        #expect(Set(edges.map(\.id)).count == edges.count && edges.count <= 8 * cells.count)
        try expectAllSidesCovered(cells: cells, edges: edges, anchor: 0)
    }
}

private func edgeCell(slot: UInt8, min: SIMD2<Int>, max: SIMD2<Int>) -> MondrianWorldCell {
    .init(id: .init(owner: 0, kind: .residual, root: slot, path: 1),
          rect: .init(min: min, max: max), color: .white)
}

private func edgesInNeighborhood(seed: UInt64, anchor: Int64) throws -> [MondrianWorldEdge] {
    let cells = try (-2...2).flatMap { delta in
        let next = anchor.addingReportingOverflow(Int64(delta))
        #expect(!next.overflow)
        return try MondrianWorldLayout(seed: seed, owner: next.partialValue).cells
    }
    return try MondrianWorldEdges.make(cells: cells, relativeTo: anchor)
}

private func expectAllSidesCovered(cells: [MondrianWorldCell], edges: [MondrianWorldEdge], anchor: Int64) throws {
    let lines = try edges.map { ($0.id.axis, try $0.local(relativeTo: anchor)) }
    for cell in cells {
        let shift = try MondrianWorldAddress(owner: cell.id.owner, offset: 0).relativeX(to: anchor)
        let a: SIMD2<Int> = [cell.rect.min.x + shift, cell.rect.min.y]
        let b: SIMD2<Int> = [cell.rect.max.x + shift, cell.rect.max.y]
        for (axis, coordinate, lower, upper) in [
            (MondrianAxis.horizontal, a.y, a.x, b.x), (.horizontal, b.y, a.x, b.x),
            (.vertical, a.x, a.y, b.y), (.vertical, b.x, a.y, b.y)
        ] {
            var intervals: [(Int, Int)] = []
            for (lineAxis, line) in lines where lineAxis == axis {
                let c = axis == .horizontal ? line.start.y : line.start.x
                guard abs(c - Double(coordinate)) < 1e-12 else { continue }
                let lo = axis == .horizontal ? line.start.x : line.start.y
                let hi = axis == .horizontal ? line.end.x : line.end.y
                let start = max(lower, Int(lo)), end = min(upper, Int(hi))
                if end > start { intervals.append((start, end)) }
            }
            intervals.sort { $0.0 < $1.0 }
            var cursor = lower
            for interval in intervals { #expect(interval.0 == cursor); cursor = interval.1 }
            #expect(cursor == upper)
        }
    }
}
