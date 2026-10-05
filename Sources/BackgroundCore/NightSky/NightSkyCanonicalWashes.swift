enum NightSkyCanonicalWashes {
    /// The same owner is constructed before receiving-chunk clipping.
    /// sharedWashDescriptionsAndOrderAgreeAcrossJoins checks the translated result.
    static func group(seed: UInt64, owner: Int64, kind: NightSkyWashKind) -> NightSkyWashGroup? {
        var random = InkRandom(state: NightSkySeeds.component(world: seed, index: owner,
                            tag: kind == .pool ? NightSkySeeds.pools : NightSkySeeds.clouds))
        if kind == .cloud && random.unit() < 0.25 { return nil }
        var moons: [NightSkyBounds] = []
        if kind == .cloud {
            for delta: Int64 in [-1, 0, 1] {
                let neighbor = owner.addingReportingOverflow(delta)
                if !neighbor.overflow, let moon = NightSkyMoonLayout.placement(seed: seed, index: neighbor.partialValue) {
                    let offset: SIMD2<Double> = [Double(delta) * 1200, 0]
                    moons.append(.init(min: moon.envelope.min + offset, max: moon.envelope.max + offset))
                }
            }
        }
        for _ in 0..<(kind == .pool ? 1 : 6) {
            let center: SIMD2<Double> = kind == .pool
                ? [200 + random.unit() * 800, 350 + random.unit() * 100]
                : [100 + random.unit() * 1000, 100 + random.unit() * 600]
            var lobes: [NightSkyWashLobe] = []
            if kind == .pool {
                let radii: SIMD2<Double> = [640 + random.unit() * 80, 160 + random.unit() * 100]
                let color = random.unit() < 0.5 ? NightSkyPalette.blueWash : NightSkyPalette.violetWash
                for layer in 0..<8 {
                    let scale: Double = 1 - Double(layer) * 0.065
                    lobes.append(.init(anchor: center + [(random.unit() - 0.5) * 16, (random.unit() - 0.5) * 16],
                                       radii: radii * scale, rotation: (random.unit() - 0.5) * 0.07,
                                       color: color, opacity: 0.018 + random.unit() * 0.013))
                }
            } else {
                for puff in 0..<6 {
                    let anchor = center + [-250 + Double(puff) * 100, (random.unit() - 0.5) * 16]
                    let radii: SIMD2<Double> = [80 + random.unit() * 70, 9 + random.unit() * 15]
                    let angle: Double = (random.unit() - 0.5) * 0.06
                    lobes.append(.init(anchor: anchor, radii: radii, rotation: angle,
                                       color: NightSkyPalette.cloud, opacity: 0.025))
                    lobes.append(.init(anchor: anchor + [5, -2], radii: radii * 0.65, rotation: angle,
                                       color: NightSkyPalette.cloud, opacity: 0.04))
                }
            }
            var low = SIMD2<Double>(repeating: .infinity)
            var high = SIMD2<Double>(repeating: -.infinity)
            for lobe in lobes {
                low = [min(low.x, lobe.envelope.min.x), min(low.y, lobe.envelope.min.y)]
                high = [max(high.x, lobe.envelope.max.x), max(high.y, lobe.envelope.max.y)]
            }
            let envelope = NightSkyBounds(min: low, max: high)
            if kind == .cloud && moons.contains(where: { envelope.intersects($0) }) { continue }
            return .init(id: .init(kind: kind, owner: owner), lobes: lobes, envelope: envelope)
        }
        return nil
    }
}
