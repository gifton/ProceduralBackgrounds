enum MondrianWorldInk {
    /// Paint before translation; crossingCellPaintAgreesAfterReceivingChunkTranslation
    /// checks that receiving chunks retain the full cell-local pigment geometry.
    static func cell(_ cell: MondrianWorldCell, seed: UInt64, relativeTo anchor: Int64,
                     xOffset: Double = 0, style: MondrianPaintStyle = .layered) throws -> [InkPrimitive] {
        let local = MondrianCell(id: cell.id.paintID, rect: cell.rect, color: cell.color)
        let paintSeed = MondrianWorldSeeds.owner(seed: seed, owner: cell.id.owner,
                                                tag: MondrianWorldSeeds.paint)
        let shift: Double = Double(try MondrianWorldAddress(owner: cell.id.owner, offset: 0)
            .relativeX(to: anchor)) - xOffset
        return MondrianCellPaint.draw(local, seed: paintSeed, style: style).map {
            $0.mapGeometry { $0 + [shift, 0] }
        }
    }

    static func divider(_ edge: MondrianWorldEdge, seed: UInt64, relativeTo anchor: Int64,
                        xOffset: Double = 0) throws -> [InkPrimitive] {
        let line = try edge.local(relativeTo: anchor, xOffset: xOffset)
        var random = InkRandom(state: MondrianWorldSeeds.edge(seed: seed, id: edge.id))
        let points: [SIMD2<Double>] = (0..<5).map {
            line.start + (line.end - line.start) * (Double($0) / 4)
        }
        let base: Double = 7 + random.unit() * 2
        let widths: [Double] = (0..<5).map { _ in base + random.unit() * 2 }
        return [
            .colorStroke(points: points, widths: widths, color: MondrianColor.black.rgb, opacity: 1),
            .colorStroke(points: points, widths: widths.map { $0 * 0.24 },
                         color: [0.17, 0.17, 0.18], opacity: 0.12)
        ]
    }

    /// Caller contract: repeated identities describe the same canonical geometry;
    /// finite positive bounds and finite xOffset. Receiving bounds do not clip ink.
    static func scene(seed: UInt64, cells: [MondrianWorldCell], edges: [MondrianWorldEdge],
                      relativeTo anchor: Int64, xOffset: Double, bounds: SIMD2<Double>,
                      style: MondrianPaintStyle = .layered) throws -> InkScene {
        var uniqueCells: [MondrianWorldCellID: MondrianWorldCell] = [:]
        var uniqueEdges: [MondrianWorldEdgeID: MondrianWorldEdge] = [:]
        for cell in cells where uniqueCells[cell.id] == nil { uniqueCells[cell.id] = cell }
        for edge in edges where uniqueEdges[edge.id] == nil { uniqueEdges[edge.id] = edge }
        var ink: [InkPrimitive] = []
        for item in uniqueCells.values.sorted(by: { $0.id < $1.id }) {
            ink += try cell(item, seed: seed, relativeTo: anchor, xOffset: xOffset, style: style)
        }
        for item in uniqueEdges.values.sorted(by: { $0.id < $1.id }) {
            ink += try divider(item, seed: seed, relativeTo: anchor, xOffset: xOffset)
        }
        return InkScene(seed: seed, bounds: bounds, primitives: ink)
    }
}
