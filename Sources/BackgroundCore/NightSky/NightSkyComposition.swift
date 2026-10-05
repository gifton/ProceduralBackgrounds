import Foundation

enum NightSkyMoonPhase: Hashable, Sendable { case crescent, rounded }
enum NightSkyWashKind: Int, CaseIterable, Hashable, Sendable { case pool, cloud }
struct NightSkyWashID: Hashable, Sendable {
    let kind: NightSkyWashKind
    let owner: Int64
}
struct NightSkyBounds: Sendable {
    let min: SIMD2<Double>
    let max: SIMD2<Double>
    func contains(_ point: SIMD2<Double>, padding: Double = 0) -> Bool {
        point.x >= min.x + padding - 1e-9 && point.x <= max.x - padding + 1e-9
            && point.y >= min.y + padding - 1e-9 && point.y <= max.y - padding + 1e-9
    }
    func intersects(_ other: NightSkyBounds) -> Bool {
        min.x <= other.max.x && max.x >= other.min.x && min.y <= other.max.y && max.y >= other.min.y
    }
}
struct NightSkyStar: Sendable {
    let anchor: SIMD2<Double>
    let radius: Double
    let isAccent: Bool
    let seed: UInt64
}
struct NightSkyMoon: Sendable {
    let anchor: SIMD2<Double>
    let radius: Double
    let phase: NightSkyMoonPhase
    let seed: UInt64
    let envelope: NightSkyBounds
}
struct NightSkyWashLobe: Sendable {
    let anchor: SIMD2<Double>
    let radii: SIMD2<Double>
    let rotation: Double
    let color: SIMD3<Double>
    let opacity: Double
    var envelope: NightSkyBounds {
        let c: Double = abs(cos(rotation)), s: Double = abs(sin(rotation))
        let extent: SIMD2<Double> = [radii.x * c + radii.y * s, radii.x * s + radii.y * c]
        return .init(min: anchor - extent, max: anchor + extent)
    }
}
struct NightSkyWashGroup: Sendable {
    let id: NightSkyWashID
    let lobes: [NightSkyWashLobe]
    let envelope: NightSkyBounds
    func translated(by offset: SIMD2<Double>) -> NightSkyWashGroup {
        .init(id: id, lobes: lobes.map {
            .init(anchor: $0.anchor + offset, radii: $0.radii, rotation: $0.rotation,
                  color: $0.color, opacity: $0.opacity)
        }, envelope: .init(min: envelope.min + offset, max: envelope.max + offset))
    }
}

/// Layout precedes drawing; starAndMoonEnvelopesStayBounded checks reservations.
struct NightSkyComposition: Sendable {
    let groups: [NightSkyWashGroup]
    let stars: [NightSkyStar]
    let moon: NightSkyMoon?

    init(seed: UInt64, index: Int64) {
        moon = NightSkyMoonLayout.placement(seed: seed, index: index)
        var washes: [NightSkyWashGroup] = []
        let scene = NightSkyBounds(min: [0, 0], max: [1200, 800])
        for kind in NightSkyWashKind.allCases {
            for delta: Int64 in [-1, 0, 1] {
                let owner = index.addingReportingOverflow(delta)
                guard !owner.overflow,
                      let group = NightSkyCanonicalWashes.group(seed: seed, owner: owner.partialValue, kind: kind) else { continue }
                let local = group.translated(by: [Double(delta) * 1200, 0])
                if local.envelope.intersects(scene) { washes.append(local) }
            }
        }
        groups = washes
        let placementSeed: UInt64 = NightSkySeeds.component(world: seed, index: index, tag: NightSkySeeds.stars)
        let drawingSeed: UInt64 = NightSkySeeds.component(world: seed, index: index, tag: NightSkySeeds.starInk)
        var positions: [NightSkyStar] = []
        var accents: Int = 0
        for cell in 0..<96 {
            var random = InkRandom(state: NightSkySeeds.mix(placementSeed ^ UInt64(cell)))
            guard random.unit() < 0.72 else { continue }
            let anchor: SIMD2<Double> = [50 + Double(cell % 12) * 100 + (random.unit() - 0.5) * 80,
                                         50 + Double(cell / 12) * 100 + (random.unit() - 0.5) * 80]
            let accent: Bool = accents < 6 && random.unit() < 0.09
            let radius: Double = accent ? 3.8 + random.unit() * 2 : 1.2 + random.unit() * 1.6
            let envelope = NightSkyBounds(min: anchor - SIMD2(repeating: radius), max: anchor + SIMD2(repeating: radius))
            if let moon, envelope.intersects(moon.envelope) { continue }
            if accent { accents += 1 }
            positions.append(.init(anchor: anchor, radius: radius, isAccent: accent,
                                   seed: NightSkySeeds.mix(drawingSeed ^ UInt64(cell))))
        }
        stars = positions
    }
}
