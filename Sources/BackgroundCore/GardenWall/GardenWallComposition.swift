enum GardenWallCatPose: CaseIterable, Hashable, Sendable { case sleeping, sitting }
enum GardenWallPlantKind: CaseIterable, Hashable, Sendable { case ivy, grasses, blossom, spike }

struct GardenWallRect: Sendable {
    let min: SIMD2<Double>
    let max: SIMD2<Double>
    func contains(_ point: SIMD2<Double>, padding: Double = 0) -> Bool {
        point.x >= min.x + padding - 1e-10 && point.x <= max.x - padding + 1e-10
            && point.y >= min.y + padding - 1e-10 && point.y <= max.y - padding + 1e-10
    }
    func intersects(_ other: GardenWallRect) -> Bool {
        min.x <= other.max.x && max.x >= other.min.x && min.y <= other.max.y && max.y >= other.min.y
    }
}

struct GardenWallCatPlacement: Sendable {
    let pose: GardenWallCatPose
    let anchor: SIMD2<Double>
    let scale: Double
    let seed: UInt64
    let envelope: GardenWallRect
}
struct GardenWallPlantPlacement: Sendable {
    let kind: GardenWallPlantKind
    let anchor: SIMD2<Double>
    let scale: Double
    let seed: UInt64
    let envelope: GardenWallRect
}
struct GardenWallPotPlacement: Sendable {
    let anchor: SIMD2<Double>
    let width: Double
    let seed: UInt64
    let envelope: GardenWallRect
}

/// Layout is completed before any subject is drawn. Drawing streams cannot
/// change reservations; populationsAreBoundedAndCatHasClearSupport checks them.
struct GardenWallComposition: Sendable {
    let masonry: GardenWallMasonry
    let cat: GardenWallCatPlacement?
    let plants: [GardenWallPlantPlacement]
    let pots: [GardenWallPotPlacement]

    init(seed: UInt64, index: Int64) {
        let wall = GardenWallMasonry(seed: seed, index: index)
        let catSeed = GardenWallSeeds.component(world: seed, index: index, tag: GardenWallSeeds.cats)
        var cats = InkRandom(state: catSeed)
        let hasCat: Bool = index == 0 || cats.unit() < 0.35
        let placement: GardenWallCatPlacement?
        if hasCat {
            let pose: GardenWallCatPose = index == 0
                ? (seed.isMultiple(of: 2) ? .sleeping : .sitting)
                : (cats.unit() < 0.5 ? .sleeping : .sitting)
            let scale: Double = 0.85 + cats.unit() * 0.2
            let x: Double = index == 0 ? 560 + cats.unit() * 80 : 220 + cats.unit() * 760
            let anchor: SIMD2<Double> = [x, wall.capY]
            let localMin: SIMD2<Double> = pose == .sleeping ? [-76, -70] : [-38, -146]
            let localMax: SIMD2<Double> = pose == .sleeping ? [76, 4] : [62, 80]
            placement = .init(pose: pose, anchor: anchor, scale: scale, seed: catSeed,
                              envelope: .init(min: anchor + localMin * scale, max: anchor + localMax * scale))
        } else { placement = nil }

        var vegetation = InkRandom(state: GardenWallSeeds.component(world: seed, index: index, tag: GardenWallSeeds.vegetation))
        var potRandom = InkRandom(state: GardenWallSeeds.component(world: seed, index: index, tag: GardenWallSeeds.pots))
        var foliage: [GardenWallPlantPlacement] = []
        var containers: [GardenWallPotPlacement] = []
        let count: Int = 3 + Int(vegetation.unit() * 4)
        let kindOffset: Int = Int(vegetation.unit() * 4)
        for slot in 0..<count {
            let kind = GardenWallPlantKind.allCases[(slot + kindOffset) % 4]
            let scale: Double = 0.72 + vegetation.unit() * 0.22
            let localMin: SIMD2<Double>
            let localMax: SIMD2<Double>
            switch kind {
            case .ivy: localMin = [-132, -30]; localMax = [132, 226]
            case .grasses: localMin = [-66, -68]; localMax = [66, 8]
            case .blossom: localMin = [-68, -140]; localMax = [68, 8]
            case .spike: localMin = [-58, -166]; localMax = [58, 8]
            }
            let plantSeed: UInt64 = GardenWallSeeds.mix(vegetation.state ^ UInt64(slot))
            for _ in 0..<4 {
                let baseX: Double = 110 + Double(slot) * 195 + (vegetation.unit() - 0.5) * 90
                let x: Double = min(1188 - localMax.x * scale, max(12 - localMin.x * scale, baseX))
                let y: Double = kind == .ivy ? wall.capY + 3 : wall.bottomY + 27
                var anchor: SIMD2<Double> = [x, y]
                var envelope = GardenWallRect(min: anchor + localMin * scale, max: anchor + localMax * scale)
                if let cat = placement, envelope.intersects(cat.envelope) { continue }
                if (kind == .blossom || kind == .spike), containers.count < 2, potRandom.unit() < 0.32 {
                    let width: Double = 43 + potRandom.unit() * 16
                    let potAnchor: SIMD2<Double> = [x, wall.bottomY + 33]
                    anchor.y = potAnchor.y - width * 0.78
                    envelope = .init(min: anchor + localMin * scale, max: anchor + localMax * scale)
                    containers.append(.init(anchor: potAnchor, width: width, seed: potRandom.state,
                                            envelope: .init(min: potAnchor + [-width * 0.65, -width],
                                                            max: potAnchor + [width * 0.65, 8])))
                }
                foliage.append(.init(kind: kind, anchor: anchor, scale: scale, seed: plantSeed, envelope: envelope))
                break
            }
        }
        masonry = wall; cat = placement; plants = foliage; pots = containers
    }
}
