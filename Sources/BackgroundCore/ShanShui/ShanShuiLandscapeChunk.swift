/// Compatibility name for the original indexed Shan Shui scene.
public typealias ShanShuiLandscapeChunk = InkChunk

public struct ShanShuiLandscapeChunkGenerator: Sendable {
    public init() {}

    /// O(P) generation for P local ink samples. Chunk zero preserves the still
    /// scene; visit-order replay is tested by indexedChunksReplayIndependentOfVisitOrder.
    public func generate(seed: UInt64, index: Int64) -> ShanShuiLandscapeChunk {
        var value: UInt64 = UInt64(bitPattern: index)
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31
        let chunkSeed: UInt64 = index == 0 ? seed : seed ^ value
        return ShanShuiLandscapeChunk(index: index,
            scene: ShanShuiLandscapeGenerator().generate(seed: chunkSeed))
    }
}
