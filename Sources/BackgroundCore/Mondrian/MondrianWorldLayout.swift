struct MondrianWorldBoundary: Sendable {
    let owner: Int64
    let jitter: Int
    let leftReach: Int
    let rightReach: Int
    let top: Int
    let height: Int

    var bridge: MondrianRect {
        .init(min: [jitter - leftReach, top], max: [jitter + rightReach, top + height])
    }

    init(seed: UInt64, owner: Int64) {
        self.owner = owner
        var random = InkRandom(state: MondrianWorldSeeds.owner(seed: seed, owner: owner,
                                                               tag: MondrianWorldSeeds.boundary))
        jitter = 320 + Int(random.unit() * 561)
        leftReach = 240 + Int(random.unit() * 321)
        rightReach = 240 + Int(random.unit() * 321)
        top = 80 * (1 + Int(random.unit() * 3))
        height = 80 * (4 + Int(random.unit() * 3))
    }
}

/// Bridges interrupt composition borders without introducing transport borders.
/// ownershipGroupsCoverTheirRegionsWithDisjointCells checks exact area and overlap;
/// fullSignedChunkRangeHasExactCoverage checks reconstruction at signed extrema.
struct MondrianWorldLayout: Sendable {
    let owner: Int64
    let bounds: MondrianRect
    let cells: [MondrianWorldCell]

    init(seed: UInt64, owner: Int64) throws {
        self.owner = owner
        let left = MondrianWorldBoundary(seed: seed, owner: owner)
        let next = owner.addingReportingOverflow(1)
        guard !next.overflow else { throw MondrianWorldError.indexOverflow }
        let right = MondrianWorldBoundary(seed: seed, owner: next.partialValue)
        bounds = .init(min: [left.jitter, 0], max: [2400 + right.jitter, 800])
        let roots = Self.residualRoots(left: left, right: right)
        var leaves: [MondrianWorldLeaf] = [
            .init(id: .init(owner: owner, kind: .bridge, root: 0, path: 1), rect: left.bridge)
        ]
        leaves += roots.enumerated().map { slot, rect in
            .init(id: .init(owner: owner, kind: .residual, root: UInt8(slot), path: 1), rect: rect)
        }
        var random = InkRandom(state: MondrianWorldSeeds.owner(seed: seed, owner: owner,
                                                               tag: MondrianWorldSeeds.layout))
        let target: Int = 16 + Int(random.unit() * 9)
        while leaves.count < target && leaves.count < 24 {
            var selected: Int?
            var best: Double = -1
            for i in leaves.indices where leaves[i].id.kind == .residual {
                let rect = leaves[i].rect
                guard rect.width >= 160 || rect.height >= 160 else { continue }
                let score: Double = Double(rect.area) * (0.75 + random.unit() * 0.5)
                if score > best { selected = i; best = score }
            }
            guard let selected else { break }
            let leaf = leaves.remove(at: selected)
            let rect = leaf.rect
            var vertical: Bool = rect.width >= rect.height
            if rect.width < 160 { vertical = false }
            else if rect.height < 160 { vertical = true }
            else if random.unit() < 0.22 { vertical.toggle() }
            let length: Int = vertical ? rect.width : rect.height
            let available: Int = length - 160
            var cut: Int = 80 + Int(random.unit() * Double(available + 1))
            if random.unit() < 0.16 {
                cut = 80 + Int(random.unit() * Double(min(41, available + 1)))
                if random.unit() < 0.5 { cut = length - cut }
            }
            let axis: Int = vertical ? 0 : 1
            var lowerMax = rect.max
            var upperMin = rect.min
            lowerMax[axis] = rect.min[axis] + cut
            upperMin[axis] = lowerMax[axis]
            // At most 23 residual leaves imply depth <= 22 and IDs below 2^23.
            leaves += [
                .init(id: .init(owner: owner, kind: .residual, root: leaf.id.root,
                                path: leaf.id.path * 2), rect: .init(min: rect.min, max: lowerMax)),
                .init(id: .init(owner: owner, kind: .residual, root: leaf.id.root,
                                path: leaf.id.path * 2 + 1), rect: .init(min: upperMin, max: rect.max))
            ]
        }
        cells = MondrianWorldPalette.assign(leaves.sorted { $0.id < $1.id }, seed: seed, owner: owner)
    }

    private static func residualRoots(left: MondrianWorldBoundary,
                                      right: MondrianWorldBoundary) -> [MondrianRect] {
        let cuts: [Int] = Array(Set([0, 800, left.top, left.top + left.height,
                                    right.top, right.top + right.height])).sorted()
        var roots: [MondrianRect] = []
        for (lo, hi) in zip(cuts, cuts.dropFirst()) {
            let occupiedLeft: Bool = lo >= left.top && hi <= left.top + left.height
            let occupiedRight: Bool = lo >= right.top && hi <= right.top + right.height
            let x0: Int = left.jitter + (occupiedLeft ? left.rightReach : 0)
            let x1: Int = 2400 + right.jitter - (occupiedRight ? right.leftReach : 0)
            if let last = roots.last, last.min.x == x0, last.max.x == x1, last.max.y == lo {
                roots[roots.count - 1] = .init(min: last.min, max: [x1, hi])
            } else {
                roots.append(.init(min: [x0, lo], max: [x1, hi]))
            }
        }
        return roots
    }
}
