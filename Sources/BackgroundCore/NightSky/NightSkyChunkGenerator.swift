/// Indexed celestial illustrations in a local 1200 × 800 ink world.
public struct NightSkyChunkGenerator: Sendable {
    public init() {}

    /// Clear the drawing surface with this color before layering the generated ink.
    public static var surfaceColor: SIMD3<Double> { NightSkyPalette.sky }

    /// O(P) for the sampled points in the bounded scene population.
    /// skyReplaysWithFiniteLocalInk exercises replay and signed/seed extrema.
    /// No bit-identical output contract across code or math-library versions.
    public func generate(seed: UInt64, index: Int64) -> InkChunk {
        let layout = NightSkyComposition(seed: seed, index: index)
        var ink: [InkPrimitive] = []
        for group in layout.groups {
            ink += InkClipping.horizontally(NightSkyInk.group(group), minX: 0, maxX: 1200)
        }
        for star in layout.stars { ink += NightSkyInk.star(star) }
        if let moon = layout.moon { ink += NightSkyMoonInk.draw(moon) }
        return .init(index: index, scene: .init(
            seed: NightSkySeeds.component(world: seed, index: index, tag: NightSkySeeds.scene),
            bounds: [1200, 800], primitives: ink))
    }
}
