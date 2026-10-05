import Foundation

/// Milestone 1: one mountain for evaluating contours and ink texture.
/// Mountain envelope and tapered-stroke ideas follow Lingdong Huang's shan-shui-inf;
/// see THIRD_PARTY_NOTICES.md. This generator uses its own random sequence.
public struct ShanShuiGenerator: BackgroundGenerator {
    public init() {}

    /// Builds an 800 × 800 study. Seed replay is tested by `seedReplayPreservesInk`.
    /// - Complexity: O(S + K × T) time and space: S = 129 ridge samples,
    ///   K = 480 interior marks, T ≤ 21 samples per mark.
    /// - Note: Noise interpolates bounded values; the envelope vanishes at both feet.
    ///   Geometry/width bounds are tested by `generatedInkHasFiniteMatchingSamples`.
    public func generate(seed: UInt64) -> ShanShuiScene {
        var random: InkRandom = InkRandom(state: seed)
        let noise: InkNoise = InkNoise(seed: seed ^ 0xC0A701A7)
        let width: Double = 560 + random.unit() * 60
        let height: Double = 390 + random.unit() * 75
        let baseline: Double = 694
        let sampleCount: Int = 128

        let ridge: [SIMD2<Double>] = (0...sampleCount).map { index in
            let t: Double = Double(index) / Double(sampleCount)
            let envelope: Double = pow(max(0, sin(.pi * t)), 0.78)
            let shape: Double = 0.62 + 0.6 * noise.fractal(t * 7.2 + 3)
            let x: Double = 400 + (t - 0.5) * width
            return SIMD2<Double>(x, baseline - height * envelope * shape)
        }

        func surface(_ sample: Int, depth: Double) -> SIMD2<Double> {
            let p: SIMD2<Double> = ridge[sample]
            let x: Double = 400 + (p.x - 400) * (1 - 0.28 * depth)
            let y: Double = baseline - (baseline - p.y) * (1 - 0.88 * depth)
                + 12 * depth * noise.value(Double(sample) * 0.06 + depth * 2)
            return SIMD2<Double>(x, y)
        }

        // The white silhouette blocks earlier ink; the renderer multiplies paper afterward.
        var primitives: [InkPrimitive] = [.wash(
            points: ridge + [SIMD2<Double>(400 + width * 0.5, 713),
                             SIMD2<Double>(400 - width * 0.5, 713)],
            tone: 1, opacity: 1
        )]

        // Quiet overlapping washes supply a little mass beneath the line work.
        for band in 0..<7 {
            let depth: Double = Double(band + 1) / 10
            let top: [SIMD2<Double>] = (0...sampleCount).map { surface($0, depth: depth) }
            let bottom: [SIMD2<Double>] = (0...sampleCount).reversed().map {
                surface($0, depth: min(1, depth + 0.2))
            }
            primitives.append(.wash(points: top + bottom, tone: 0.65, opacity: 0.035))
        }

        primitives.append(stroke(ridge, width: 2.1, opacity: 0.63, random: &random))

        for _ in 0..<480 {
            let depth: Double = 0.035 + random.unit() * 0.94
            let sample: Int = min(123, 4 + Int(random.unit() * 120))
            let span: Int = 3 + Int(random.unit() * 18)
            let start: Int = max(1, sample - span / 2)
            let end: Int = min(sampleCount - 1, start + span)
            let points: [SIMD2<Double>] = (start...end).map { index in
                var p: SIMD2<Double> = surface(index, depth: depth)
                p.x += (noise.value(Double(index) * 0.53 + depth * 50) - 0.5) * 3.5
                p.y += (noise.value(Double(index) * 0.71 + depth * 70) - 0.5) * 3.5
                return p
            }
            primitives.append(stroke(points, width: 0.6 + random.unit() * 1.15,
                                     opacity: 0.08 + random.unit() * 0.26,
                                     random: &random))
        }

        // Short ground marks interrupt the base without adding another scene element.
        for _ in 0..<28 {
            let center: Double = 400 + (random.unit() - 0.5) * width * 0.93
            let length: Double = 12 + random.unit() * 45
            let y: Double = 703 + random.unit() * 18
            let points: [SIMD2<Double>] = (0...12).map { index in
                let t: Double = Double(index) / 12
                return SIMD2<Double>(center + (t - 0.5) * length,
                                     y + (noise.value(t * 4 + center) - 0.5) * 4)
            }
            primitives.append(stroke(points, width: 1.1, opacity: 0.27, random: &random))
        }

        return ShanShuiScene(seed: seed, bounds: SIMD2<Double>(800, 800), primitives: primitives)
    }

    /// Taper w(t) = w₀ sin(πt)^0.7 with bounded local variation.
    private func stroke(_ points: [SIMD2<Double>], width: Double, opacity: Double,
                        random: inout InkRandom) -> InkPrimitive {
        let widths: [Double] = points.indices.map { index in
            let t: Double = Double(index) / Double(max(1, points.count - 1))
            return width * pow(max(0, sin(.pi * t)), 0.7) * (0.65 + random.unit() * 0.7)
        }
        return .stroke(points: points, widths: widths, tone: 0.28, opacity: opacity)
    }
}

/// Seeded value noise with smooth interpolation. The table wraps every 256 cells.
private struct InkNoise {
    let table: [Double]

    init(seed: UInt64) {
        var random: InkRandom = InkRandom(state: seed)
        table = (0..<256).map { _ in random.unit() }
    }

    func value(_ x: Double) -> Double {
        let cell: Int = Int(floor(x))
        let t: Double = x - floor(x)
        let u: Double = t * t * (3 - 2 * t)
        return table[cell & 255] * (1 - u) + table[(cell + 1) & 255] * u
    }

    func fractal(_ x: Double) -> Double {
        (value(x) + 0.5 * value(x * 2) + 0.25 * value(x * 4)) / 1.75
    }
}
