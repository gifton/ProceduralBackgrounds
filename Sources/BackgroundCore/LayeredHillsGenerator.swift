import Foundation

/// Example-specific geometry: back-to-front ridgelines in normalized view coordinates.
/// The origin is top-left; a renderer scales x and y by its viewport dimensions.
public struct LayeredHillsScene: Sendable {
    public let layers: [[SIMD2<Double>]]
}

/// A small example generator, independent of the planned Shan Shui implementation.
public struct LayeredHillsGenerator: BackgroundGenerator {
    public init() {}

    /// Samples y = b + a₁ sin(2πf₁x + φ₁) + a₂ sin(2πf₂x + φ₂).
    /// Two low-frequency waves keep this example small and visually smooth.
    /// - Complexity: O(L × S) time and space, for 4 layers and 97 samples per layer.
    /// - Note: Repeatability is exercised by `replayingSeedReproducesGeometry`;
    ///   viewport bounds and layer ordering by `geometryIsFiniteOrderedAndCoversViewport`.
    public func generate(seed: UInt64) -> LayeredHillsScene {
        var random: SeedSequence = SeedSequence(state: seed)
        let layers: [[SIMD2<Double>]] = (0..<4).map { layer in
            let phase: Double = random.nextUnit() * 2 * .pi
            let detailPhase: Double = random.nextUnit() * 2 * .pi
            let frequency: Double = 0.8 + random.nextUnit() * 0.8
            let detailFrequency: Double = 2.4 + random.nextUnit()
            let baseline: Double = 0.36 + Double(layer) * 0.16

            return (0...96).map { sample in
                let x: Double = Double(sample) / 96
                let y: Double = baseline
                    + 0.05 * sin(2 * .pi * frequency * x + phase)
                    + 0.02 * sin(2 * .pi * detailFrequency * x + detailPhase)
                return SIMD2<Double>(x, y)
            }
        }
        return LayeredHillsScene(layers: layers)
    }
}

/// Local SplitMix64 sequence. Wrapping arithmetic is intentional modulo 2⁶⁴.
private struct SeedSequence {
    var state: UInt64

    mutating func nextUnit() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var value: UInt64 = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31
        // The top 53 bits scaled by 2⁻⁵³ produce values in [0, 1).
        return Double(value >> 11) * 0x1.0p-53
    }
}
