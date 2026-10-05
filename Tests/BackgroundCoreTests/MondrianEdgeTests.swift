@testable import BackgroundCore
import Testing

struct MondrianEdgeTests {
    @Test func longBoundaryIsSplitOnceAtEachJunction() {
        let cells: [MondrianCell] = [
            .init(id: 1, rect: .init(min: [0, 0], max: [600, 800]), color: .red),
            .init(id: 2, rect: .init(min: [600, 0], max: [1200, 200]), color: .white),
            .init(id: 3, rect: .init(min: [600, 200], max: [1200, 500]), color: .blue),
            .init(id: 4, rect: .init(min: [600, 500], max: [1200, 800]), color: .yellow)
        ]
        let edges = MondrianEdges.make(cells: cells)
        #expect(Set(edges).count == edges.count)
        let middle = edges.filter { $0.axis == .vertical && $0.coordinate == 600 }
        #expect(middle.map(\.lower) == [0, 200, 500])
        #expect(middle.map(\.upper) == [200, 500, 800])
        #expect(edges.contains(.init(axis: .horizontal, coordinate: 200, lower: 600, upper: 1200)))
        #expect(MondrianEdges.make(cells: Array(cells.reversed())) == edges)
    }

    @Test(arguments: Array(UInt64(0)...UInt64(127)) + [.max - 1, .max])
    func everyCellBoundaryHasOneOrderedCoverage(seed: UInt64) {
        let cells = MondrianLayout(seed: seed).cells
        let edges = MondrianEdges.make(cells: cells)
        #expect(edges.count <= 8 * cells.count)
        #expect(Set(edges).count == edges.count)
        #expect(Set(edges.map { MondrianEdges.identity($0) }).count == edges.count)
        #expect(MondrianEdges.make(cells: Array(cells.reversed())) == edges)
        for edge in edges {
            #expect(edge.lower >= 0 && edge.upper > edge.lower)
            #expect(edge.upper <= (edge.axis == .horizontal ? 1200 : 800))
            #expect(edge.coordinate >= 0 && edge.coordinate <= (edge.axis == .horizontal ? 800 : 1200))
            let sameLine = edges.filter { $0 != edge && $0.axis == edge.axis && $0.coordinate == edge.coordinate }
            #expect(sameLine.allSatisfy { min(edge.upper, $0.upper) <= max(edge.lower, $0.lower) })
        }
        for cell in cells {
            let a = cell.rect.min, b = cell.rect.max
            let boundaries: [(MondrianAxis, Int, Int, Int)] = [
                (.horizontal, a.y, a.x, b.x), (.horizontal, b.y, a.x, b.x),
                (.vertical, a.x, a.y, b.y), (.vertical, b.x, a.y, b.y)
            ]
            for (axis, coordinate, lower, upper) in boundaries {
                let covered: Int = edges.filter { $0.axis == axis && $0.coordinate == coordinate }
                    .reduce(0) { $0 + max(0, min($1.upper, upper) - max($1.lower, lower)) }
                #expect(covered == upper - lower)
            }
        }
    }
}
