/// A deterministic horizontal garden of local 1200 × 800 ink chunks.
public struct GardenWallChunkGenerator: Sendable {
    public init() {}

    /// O(P) generation for P sampled points in the bounded subject population.
    /// Replay and signed-index behavior are exercised by gardenReplaysRegardlessOfVisitOrder.
    /// No promise of bit-identical geometry across math-library or code versions.
    public func generate(seed: UInt64, index: Int64) -> InkChunk {
        let layout = GardenWallComposition(seed: seed, index: index)
        var ink = layout.masonry.primitives
        for pot in layout.pots { ink += GardenWallPlantElements.pot(pot) }
        for plant in layout.plants { ink += GardenWallPlantElements.draw(plant) }
        if let cat = layout.cat { ink += GardenWallCatElements.draw(cat) }
        return InkChunk(index: index, scene: InkScene(
            seed: GardenWallSeeds.component(world: seed, index: index, tag: GardenWallSeeds.masonry),
            bounds: [1200, 800], primitives: ink))
    }
}
