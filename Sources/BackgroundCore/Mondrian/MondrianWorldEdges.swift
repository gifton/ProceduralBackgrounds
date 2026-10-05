struct MondrianWorldEdgeID: Hashable, Comparable, Sendable {
    let axis: MondrianAxis
    let startX: MondrianWorldAddress
    let startY: Int
    let endX: MondrianWorldAddress
    let endY: Int

    static func < (a: Self, b: Self) -> Bool {
        if a.axis != b.axis { return a.axis.rawValue < b.axis.rawValue }
        if a.axis == .horizontal {
            if a.startY != b.startY { return a.startY < b.startY }
            if a.startX != b.startX { return a.startX < b.startX }
            if a.endX != b.endX { return a.endX < b.endX }
            return a.endY < b.endY
        }
        if a.startX != b.startX { return a.startX < b.startX }
        if a.startY != b.startY { return a.startY < b.startY }
        if a.endY != b.endY { return a.endY < b.endY }
        return a.endX < b.endX
    }
}

struct MondrianWorldEdge: Sendable {
    let id: MondrianWorldEdgeID

    func local(relativeTo anchor: Int64, xOffset: Double = 0) throws
        -> (start: SIMD2<Double>, end: SIMD2<Double>) {
        let start: SIMD2<Double> = [Double(try id.startX.relativeX(to: anchor)) - xOffset, Double(id.startY)]
        let end: SIMD2<Double> = [Double(try id.endX.relativeX(to: anchor)) - xOffset, Double(id.endY)]
        return (start, end)
    }
}

enum MondrianWorldEdges {
    /// Unions full cell sides before chunk selection. The five-group production
    /// neighborhood supplies the cuts checked by adjacentNeighborhoodsAgreeOnFullSegmentsAndSeeds.
    /// The bounded N-cell union uses the existing O(N²) interval algorithm.
    static func make(cells: [MondrianWorldCell], relativeTo anchor: Int64) throws -> [MondrianWorldEdge] {
        let localCells: [MondrianCell] = try cells.map { cell in
            let shift: Int = try MondrianWorldAddress(owner: cell.id.owner, offset: 0).relativeX(to: anchor)
            let rect = MondrianRect(min: [cell.rect.min.x + shift, cell.rect.min.y],
                                   max: [cell.rect.max.x + shift, cell.rect.max.y])
            // The union reads rectangles; this ID does not establish world identity.
            return MondrianCell(id: cell.id.paintID, rect: rect, color: cell.color)
        }
        var unique: [MondrianWorldEdgeID: MondrianWorldEdge] = [:]
        for edge in MondrianEdges.make(cells: localCells) {
            let x0: Int = edge.axis == .horizontal ? edge.lower : edge.coordinate
            let x1: Int = edge.axis == .horizontal ? edge.upper : edge.coordinate
            let id = MondrianWorldEdgeID(axis: edge.axis,
                startX: try MondrianWorldAddress(owner: anchor, offset: x0),
                startY: edge.axis == .horizontal ? edge.coordinate : edge.lower,
                endX: try MondrianWorldAddress(owner: anchor, offset: x1),
                endY: edge.axis == .horizontal ? edge.coordinate : edge.upper)
            unique[id] = MondrianWorldEdge(id: id)
        }
        return unique.values.sorted { $0.id < $1.id }
    }
}
