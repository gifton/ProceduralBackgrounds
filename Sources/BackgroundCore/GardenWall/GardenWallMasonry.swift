struct GardenWallCellID: Hashable, Sendable {
    let ownerIndex: Int64
    let row: Int
    let slot: Int
}

struct GardenWallStone: Sendable {
    let id: GardenWallCellID
    let polygon: [SIMD2<Double>]
    let color: SIMD3<Double>
    let opacity: Double
    let cracks: [InkPrimitive]
}

/// World-seeded courses and locally expressed canonical cells.
/// adjacentMasonrySharesCanonicalCells exercises shared identities at both
/// signed endpoints without converting absolute world indices to floating point.
struct GardenWallMasonry: Sendable {
    let capY: Double
    let bottomY: Double
    let courses: [Double]
    let stones: [GardenWallStone]
    let primitives: [InkPrimitive]

    init(seed: UInt64, index: Int64) {
        var world = InkRandom(state: GardenWallSeeds.mix(seed ^ GardenWallSeeds.masonry))
        let top: Double = 400 + world.unit() * 20
        var levels: [Double] = [top + 12]
        for base: Double in [65, 70, 68, 65] { levels.append(levels.last! + base + world.unit() * 10) }
        var cells: [GardenWallStone] = []
        var ink: [InkPrimitive] = [
            .colorWash(points: [[0, top], [1200, top], [1200, levels.last!], [0, levels.last!]],
                       color: GardenWallPalette.stone, opacity: 0.27)
        ]
        for (row, width) in [150.0, 200.0, 120.0, 200.0].enumerated() {
            let count: Int = Int(1200 / width)
            let shift: Double = row.isMultiple(of: 2) ? 0 : width * 0.5
            let first: Int = row.isMultiple(of: 2) ? 0 : -1
            for slot in first..<count {
                let owner: Int64
                let canonicalSlot: Int
                let translation: Double
                if slot < 0 {
                    let previous = index.subtractingReportingOverflow(1)
                    owner = previous.overflow ? index : previous.partialValue
                    canonicalSlot = previous.overflow ? -1 : count - 1
                    translation = previous.overflow ? 0 : -1200
                } else {
                    owner = index; canonicalSlot = slot; translation = 0
                }
                let id = GardenWallCellID(ownerIndex: owner, row: row, slot: canonicalSlot)
                var random = InkRandom(state: GardenWallSeeds.cell(world: seed, id: id))
                let x: Double = Double(canonicalSlot) * width + shift + translation
                let left: Double = x + 3, right: Double = x + width - 3
                let upper: Double = levels[row] + 3, lower: Double = levels[row + 1] - 3
                let radius: Double = 5 + random.unit() * 5
                let jitter: [Double] = (0..<4).map { _ in (random.unit() - 0.5) * radius * 0.4 }
                let outline: [SIMD2<Double>] = [
                    [left + radius, upper + jitter[0]], [right - radius, upper + jitter[1]],
                    [right, upper + radius], [right, lower - radius],
                    [right - radius, lower + jitter[2]], [left + radius, lower + jitter[3]],
                    [left, lower - radius], [left, upper + radius]
                ]
                let delta: Double = (random.unit() - 0.5) * 0.09
                let color: SIMD3<Double> = GardenWallPalette.stone + SIMD3(repeating: delta)
                let opacity: Double = 0.23 + random.unit() * 0.24
                var cracks: [InkPrimitive] = []
                if random.unit() < 0.22 {
                    let start: SIMD2<Double> = [x + width * (0.3 + random.unit() * 0.4), upper + 9]
                    let p: [SIMD2<Double>] = [start, start + [3, 8], start + [-1, 17], start + [5, 25]]
                    cracks.append(.colorStroke(points: p, widths: [0.4, 0.65, 0.55, 0.1],
                                               color: GardenWallPalette.mortar, opacity: 0.24))
                }
                cells.append(.init(id: id, polygon: outline, color: color, opacity: opacity, cracks: cracks))
                ink.append(.colorWash(points: outline, color: color, opacity: opacity))
                // A smaller second wash gives uneven ink density inside the same convex stone.
                let center: SIMD2<Double> = [(left + right) * 0.5, (upper + lower) * 0.5]
                let inner: [SIMD2<Double>] = outline.map { center + ($0 - center) * 0.78 }
                ink.append(.colorWash(points: inner, color: color, opacity: 0.08))
                ink += cracks
            }
            for joint in first...count {
                let x: Double = Double(joint) * width + shift
                if x < 0 || x > 1200 { continue }
                ink.append(.colorStroke(points: [[x, levels[row] + 5], [x, levels[row + 1] - 5]],
                                        widths: [0.55, 0.55], color: GardenWallPalette.mortar, opacity: 0.22))
            }
        }
        ink.append(.colorWash(points: [[0, top], [1200, top], [1200, top + 12], [0, top + 12]],
                              color: GardenWallPalette.stone, opacity: 0.35))
        for y in [top] + levels {
            ink.append(.colorStroke(points: [[0, y], [1200, y]], widths: [0.9, 0.9],
                                    color: GardenWallPalette.mortar, opacity: 0.32))
        }
        capY = top; bottomY = levels.last!; courses = levels; stones = cells
        primitives = InkClipping.horizontally(ink, minX: 0, maxX: 1200)
    }
}
