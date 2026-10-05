enum MondrianAxis: Int, Hashable, Sendable { case horizontal, vertical }

struct MondrianEdge: Hashable, Sendable {
    let axis: MondrianAxis
    let coordinate: Int
    let lower: Int
    let upper: Int

    var start: SIMD2<Double> {
        axis == .horizontal ? [Double(lower), Double(coordinate)] : [Double(coordinate), Double(lower)]
    }
    var end: SIMD2<Double> {
        axis == .horizontal ? [Double(upper), Double(coordinate)] : [Double(coordinate), Double(upper)]
    }
}

enum MondrianEdges {
    private struct Line: Hashable {
        let axis: MondrianAxis
        let coordinate: Int
    }

    /// Unions intervals and retains junction endpoints. With N cells, at most
    /// 8N endpoints yield at most 8N segments. Small bounded layouts use O(N²) work.
    /// Tests: longBoundaryIsSplitOnceAtEachJunction, everyCellBoundaryHasOneOrderedCoverage.
    static func make(cells: [MondrianCell]) -> [MondrianEdge] {
        var lines: [Line: [ClosedRange<Int>]] = [:]
        for cell in cells {
            let a = cell.rect.min, b = cell.rect.max
            for y in [a.y, b.y] {
                lines[Line(axis: .horizontal, coordinate: y), default: []].append(a.x...b.x)
            }
            for x in [a.x, b.x] {
                lines[Line(axis: .vertical, coordinate: x), default: []].append(a.y...b.y)
            }
        }
        var output: [MondrianEdge] = []
        for (line, intervals) in lines {
            let cuts: [Int] = Array(Set(intervals.flatMap { [$0.lowerBound, $0.upperBound] })).sorted()
            for (lower, upper) in zip(cuts, cuts.dropFirst()) {
                if intervals.contains(where: { $0.lowerBound <= lower && $0.upperBound >= upper }) {
                    output.append(.init(axis: line.axis, coordinate: line.coordinate, lower: lower, upper: upper))
                }
            }
        }
        return output.sorted {
            if $0.axis != $1.axis { return $0.axis.rawValue < $1.axis.rawValue }
            if $0.coordinate != $1.coordinate { return $0.coordinate < $1.coordinate }
            if $0.lower != $1.lower { return $0.lower < $1.lower }
            return $0.upper < $1.upper
        }
    }

    /// Generated-layout caller contract: nonnegative fields <= 1200, fitting
    /// 16 bits each. Test: everyCellBoundaryHasOneOrderedCoverage.
    static func identity(_ edge: MondrianEdge) -> UInt64 {
        UInt64(edge.axis.rawValue) << 48 | UInt64(edge.coordinate) << 32
            | UInt64(edge.lower) << 16 | UInt64(edge.upper)
    }
}
