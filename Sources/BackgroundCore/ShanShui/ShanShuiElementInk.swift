import Foundation

/// Drawing helpers used only by the element vocabulary. Adapted from upstream
/// `div`, `blob` and `stroke`; attribution is in THIRD_PARTY_NOTICES.md.
enum ShanShuiElementInk {
    /// Quadratic Bézier B(t) = (1−t)²a + 2(1−t)tc + t²b, sampled in O(N).
    static func curve(_ a: SIMD2<Double>, _ c: SIMD2<Double>, _ b: SIMD2<Double>,
                      samples: Int = 12) -> [SIMD2<Double>] {
        (0...samples).map { index in
            let t: Double = Double(index) / Double(samples)
            return a * ((1 - t) * (1 - t)) + c * (2 * (1 - t) * t) + b * (t * t)
        }
    }

    /// Subdivides the caller's polyline and varies interior points/widths locally.
    /// Caller contract: at least two finite points, finite nonnegative full width.
    static func line(_ controls: [SIMD2<Double>], width: Double, tone: Double = 0.39,
                     opacity: Double = 0.6, taper: Bool = false,
                     random: inout InkRandom) -> InkPrimitive {
        var points: [SIMD2<Double>] = []
        for index in 0..<(controls.count - 1) {
            for sample in 0..<8 {
                let t: Double = Double(sample) / 8
                let jitter: SIMD2<Double> = sample == 0 ? .zero
                    : [(random.unit() - 0.5) * width * 0.3,
                       (random.unit() - 0.5) * width * 0.3]
                points.append(controls[index] * (1 - t) + controls[index + 1] * t + jitter)
            }
        }
        points.append(controls[controls.count - 1])
        let widths: [Double] = points.indices.map { index in
            let t: Double = Double(index) / Double(points.count - 1)
            let profile: Double = taper ? max(0, cos(t * .pi / 2)) : 1
            return width * profile * (0.75 + random.unit() * 0.25)
        }
        return .stroke(points: points, widths: widths, tone: tone, opacity: opacity)
    }

    /// A pointed leaf with half-width proportional to √sin(πt). Each side is
    /// monotone along its unrotated axis; width variation does not alter that axis.
    static func leaf(center: SIMD2<Double>, length: Double, width: Double,
                     angle: Double, random: inout InkRandom) -> InkPrimitive {
        let axis: SIMD2<Double> = [cos(angle), sin(angle)]
        let normal: SIMD2<Double> = [-axis.y, axis.x]
        var upper: [SIMD2<Double>] = []
        var lower: [SIMD2<Double>] = []
        for index in 0...12 {
            let t: Double = Double(index) / 12
            let halfWidth: Double = sqrt(max(0, sin(t * .pi))) * width * 0.5
                * (0.8 + random.unit() * 0.2)
            let p: SIMD2<Double> = center + axis * ((t - 0.5) * length)
            upper.append(p + normal * halfWidth)
            lower.append(p - normal * halfWidth)
        }
        return .wash(points: upper + lower.dropFirst().dropLast().reversed(),
                     tone: 0.39, opacity: 0.45 + random.unit() * 0.18)
    }
}
