enum NightSkyMoonLayout {
    static func placement(seed: UInt64, index: Int64) -> NightSkyMoon? {
        var region: Int64 = index / 8
        var local: Int64 = index % 8
        if local < 0 { region -= 1; local += 8 }
        var slots = InkRandom(state: NightSkySeeds.component(world: seed, index: region, tag: NightSkySeeds.moonSlots))
        let occupied: Bool = region == 0 || slots.unit() < 0.65
        let slot: Int64 = region == 0 ? 0 : 2 + Int64(slots.unit() * (region == -1 ? 2 : 4))
        // 8+2-5=5; region -1 ends at -5 before the forced zero moon.
        // initialMoonsAndSparseRegionsHaveClearSpacing exercises the negative and endpoint regions.
        guard occupied, local == slot else { return nil }
        var layout = InkRandom(state: NightSkySeeds.component(world: seed, index: index, tag: NightSkySeeds.moonLayout))
        let radius: Double = 45 + layout.unit() * 20
        let anchor: SIMD2<Double> = [index == 0 ? 560 + layout.unit() * 80 : 220 + layout.unit() * 760,
                                     200 + layout.unit() * 100]
        let phase: NightSkyMoonPhase = index == 0
            ? (seed.isMultiple(of: 2) ? .crescent : .rounded)
            : (layout.unit() < 0.5 ? .crescent : .rounded)
        let extent = SIMD2<Double>(repeating: radius + 32)
        return .init(anchor: anchor, radius: radius, phase: phase,
                     seed: NightSkySeeds.component(world: seed, index: index, tag: NightSkySeeds.moonInk),
                     envelope: .init(min: anchor - extent, max: anchor + extent))
    }
}
