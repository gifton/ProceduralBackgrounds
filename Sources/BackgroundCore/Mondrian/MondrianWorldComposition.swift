struct MondrianWorldComposition: Sendable {
    let seed: UInt64
    let index: Int64
    let origin: MondrianWorldAddress
    let reconstructedCellCount: Int
    let cells: [MondrianWorldCell]
    let edges: [MondrianWorldEdge]

    init(seed: UInt64, index: Int64) throws {
        self.seed = seed
        self.index = index
        let origin = MondrianWorldAddress(chunk: index)
        self.origin = origin
        // Chunk division halves the signed range; +/-2 and layout lookahead fit.
        let owners: [Int64] = try (-2...2).map { delta in
            let neighbor = origin.owner.addingReportingOverflow(Int64(delta))
            guard !neighbor.overflow else { throw MondrianWorldError.indexOverflow }
            return neighbor.partialValue
        }
        let fullCells = try owners.flatMap { try MondrianWorldLayout(seed: seed, owner: $0).cells }
        reconstructedCellCount = fullCells.count
        let fullEdges = try MondrianWorldEdges.make(cells: fullCells, relativeTo: origin.owner)
        cells = try fullCells.filter { cell in
            guard cell.id.owner >= owners[1], cell.id.owner <= owners[3] else { return false }
            let shift = try MondrianWorldAddress(owner: cell.id.owner, offset: 0).relativeX(to: origin.owner)
            return cell.rect.max.x + shift > origin.offset && cell.rect.min.x + shift < origin.offset + 1200
        }.sorted { $0.id < $1.id }
        edges = try fullEdges.filter { edge in
            let line = try edge.local(relativeTo: origin.owner)
            return min(line.start.x, line.end.x) - 6 <= Double(origin.offset + 1200)
                && max(line.start.x, line.end.x) + 6 >= Double(origin.offset)
        }
    }
}
