enum MondrianWorldPalette {
    /// Caller contract: sorted unique leaves, one bridge and at least four residual
    /// cells. ownershipGroupsCoverTheirRegionsWithDisjointCells checks generated groups.
    static func assign(_ leaves: [MondrianWorldLeaf], seed: UInt64, owner: Int64) -> [MondrianWorldCell] {
        var random = InkRandom(state: MondrianWorldSeeds.owner(seed: seed, owner: owner,
                                                               tag: MondrianWorldSeeds.color))
        let bridge = leaves.first { $0.id.kind == .bridge }!
        let residual = leaves.filter { $0.id.kind == .residual }
        let black = residual.min {
            $0.rect.area == $1.rect.area ? $0.id < $1.id : $0.rect.area < $1.rect.area
        }!
        let white = residual.filter { $0.id != black.id }.max {
            $0.rect.area == $1.rect.area ? $0.id > $1.id : $0.rect.area < $1.rect.area
        }!
        let focalColor: MondrianColor = random.unit() < 0.5 ? .red : .blue
        var colors: [MondrianWorldCellID: MondrianColor] = [bridge.id: focalColor, black.id: .black]
        let total: Int = leaves.reduce(0) { $0 + $1.rect.area }
        for color: MondrianColor in [focalColor == .red ? .blue : .red, .yellow] {
            let desired: Double = Double(total) * (color == .yellow ? 0.08 : 0.12)
            let candidates = residual.filter { $0.id != white.id && colors[$0.id] == nil }
            let scored = candidates.map {
                (leaf: $0, score: abs(Double($0.rect.area) - desired) * (0.85 + random.unit() * 0.3))
            }
            let selected = scored.min { $0.score < $1.score }!.leaf
            colors[selected.id] = color
        }
        var primaryArea: Int = leaves.filter { colors[$0.id] != nil && $0.id != black.id }
            .reduce(0) { $0 + $1.rect.area }
        let target: Double = Double(total) * MondrianPalette.areaTargets.primary
        while true {
            let distance: Double = abs(Double(primaryArea) - target)
            let candidates = leaves.filter { colors[$0.id] == nil && $0.id != white.id }
            let improving = candidates.filter { abs(Double(primaryArea + $0.rect.area) - target) < distance }
            guard let selected = improving.min(by: {
                abs(Double(primaryArea + $0.rect.area) - target)
                    < abs(Double(primaryArea + $1.rect.area) - target)
            }) else { break }
            let neighbors = Set(leaves.filter { selected.rect.touches($0.rect) }.compactMap { colors[$0.id] })
            let distinct: [MondrianColor] = [.red, .blue, .yellow].filter { !neighbors.contains($0) }
            let choices: [MondrianColor] = distinct.isEmpty ? [.red, .blue, .yellow] : distinct
            colors[selected.id] = choices[Int(random.unit() * Double(choices.count))]
            primaryArea += selected.rect.area
        }
        return leaves.map { .init(id: $0.id, rect: $0.rect, color: colors[$0.id] ?? .white) }
    }
}
