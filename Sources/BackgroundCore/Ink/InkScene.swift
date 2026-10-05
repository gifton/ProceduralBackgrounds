/// Ordered ink in a local 2D world with a top-left origin.
public struct InkScene: Sendable {
    public let seed: UInt64
    public let bounds: SIMD2<Double>
    public let primitives: [InkPrimitive]

    public init(seed: UInt64, bounds: SIMD2<Double>, primitives: [InkPrimitive]) {
        self.seed = seed
        self.bounds = bounds
        self.primitives = primitives
    }
}

/// An immutable scene at a signed horizontal world index.
public struct InkChunk: Sendable {
    public let index: Int64
    public let scene: InkScene

    public init(index: Int64, scene: InkScene) {
        self.index = index
        self.scene = scene
    }
}
