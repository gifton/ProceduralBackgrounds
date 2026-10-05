/// A design-specific boundary between procedural generation and presentation.
public protocol BackgroundGenerator: Sendable {
    associatedtype Scene: Sendable

    /// Implementations should derive their scene from this seed without global RNG state.
    /// This is a contract for conformers; each generator must test its own repeatability.
    func generate(seed: UInt64) -> Scene
}
