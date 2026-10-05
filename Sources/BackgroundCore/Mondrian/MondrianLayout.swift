struct MondrianRect: Sendable {
    let min: SIMD2<Int>
    let max: SIMD2<Int>
    var width: Int { max.x - min.x }
    var height: Int { max.y - min.y }
    var area: Int { width * height }

    func touches(_ other: MondrianRect) -> Bool {
        let vertical: Bool = (max.x == other.min.x || min.x == other.max.x)
            && Swift.min(max.y, other.max.y) > Swift.max(min.y, other.min.y)
        let horizontal: Bool = (max.y == other.min.y || min.y == other.max.y)
            && Swift.min(max.x, other.max.x) > Swift.max(min.x, other.min.x)
        return vertical || horizontal
    }
}

struct MondrianCell: Sendable {
    let id: UInt64
    let rect: MondrianRect
    let color: MondrianColor
}

/// Integral splits preserve the union of the parent and have disjoint interiors.
/// layoutsCoverTheWorldWithBoundedCells sweeps coverage, dimensions, and replay.
struct MondrianLayout: Sendable {
    let cells: [MondrianCell]

    private struct Leaf {
        let id: UInt64
        let rect: MondrianRect
    }

    init(seed: UInt64) {
        var random = InkRandom(state: MondrianSeeds.component(world: seed, identity: 0,
                                                              tag: MondrianSeeds.layout))
        let x: Int = 420 + Int(random.unit() * 201)
        let y: Int = 320 + Int(random.unit() * 161)
        var leaves: [Leaf] = [
            .init(id: 4, rect: .init(min: [0, 0], max: [x, y])),
            .init(id: 5, rect: .init(min: [0, y], max: [x, 800])),
            .init(id: 3, rect: .init(min: [x, 0], max: [1200, 800]))
        ]
        let target: Int = 10 + Int(random.unit() * 7)
        while leaves.count < target && leaves.count < 24 {
            var selected: Int?
            var best: Double = -1
            for i in leaves.indices where leaves[i].id != 4 {
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
            var lowerMax = rect.max
            var upperMin = rect.min
            let axis: Int = vertical ? 0 : 1
            lowerMax[axis] = rect.min[axis] + cut
            upperMin[axis] = lowerMax[axis]
            // At most 24 leaves means depth <= 23 and node IDs < 2^24.
            leaves += [.init(id: leaf.id * 2, rect: .init(min: rect.min, max: lowerMax)),
                       .init(id: leaf.id * 2 + 1, rect: .init(min: upperMin, max: rect.max))]
        }
        let reflectX: Bool = random.unit() < 0.5
        let reflectY: Bool = random.unit() < 0.5
        leaves = leaves.map { leaf in
            let a = leaf.rect.min, b = leaf.rect.max
            return Leaf(id: leaf.id, rect: .init(
                min: [reflectX ? 1200 - b.x : a.x, reflectY ? 800 - b.y : a.y],
                max: [reflectX ? 1200 - a.x : b.x, reflectY ? 800 - a.y : b.y]))
        }.sorted { $0.id < $1.id }
        cells = Self.assignColors(leaves, seed: seed)
    }

    private static func assignColors(_ leaves: [Leaf], seed: UInt64) -> [MondrianCell] {
        var random = InkRandom(state: MondrianSeeds.component(world: seed, identity: 0,
                                                              tag: MondrianSeeds.color))
        let others = leaves.filter { $0.id != 4 }
        let black = others.min {
            $0.rect.area < $1.rect.area || ($0.rect.area == $1.rect.area && $0.id < $1.id)
        }!
        let white = others.filter { $0.id != black.id }.max {
            $0.rect.area < $1.rect.area || ($0.rect.area == $1.rect.area && $0.id > $1.id)
        }!
        let focal = leaves.first { $0.id == 4 }!
        let focalColor: MondrianColor = random.unit() < 0.5 ? .red : .blue
        var colors: [UInt64: MondrianColor] = [black.id: .black, focal.id: focalColor]
        let missing: [MondrianColor] = [focalColor == .red ? .blue : .red, .yellow]
        for color in missing {
            let desired: Double = Double(1200 * 800) * (color == .yellow ? 0.08 : 0.12)
            let candidates = others.filter { $0.id != white.id && colors[$0.id] == nil }
            let scored = candidates.map { leaf in
                (leaf: leaf, score: abs(Double(leaf.rect.area) - desired) * (0.85 + random.unit() * 0.3))
            }
            let selected = scored.min { $0.score < $1.score }!.leaf
            colors[selected.id] = color
        }
        var primaryArea: Int = leaves.filter { colors[$0.id] != nil && $0.id != black.id }
            .reduce(0) { $0 + $1.rect.area }
        let target: Double = Double(1200 * 800) * MondrianPalette.areaTargets.primary
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
