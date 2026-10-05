import Foundation

/// Small drawing vocabulary for the landscape. Positions and dimensions
/// are supplied by the composer; generated-world bounds are tested there.
enum ShanShuiLandscapeElements {
    /// Samples waves in open water, excluding a 12-unit box around the boat ink.
    /// O(B + W × N), B = boat points, W ≤ 90 waves, N = 13 samples per wave.
    static func water(seed: UInt64, avoiding boat: [SIMD2<Double>]) -> [InkPrimitive] {
        var random: InkRandom = InkRandom(state: seed)
        let boatLeft: Double = (boat.map(\.x).min() ?? 1200) - 12
        let boatRight: Double = (boat.map(\.x).max() ?? 0) + 12
        let boatTop: Double = (boat.map(\.y).min() ?? 800) - 12
        let boatBottom: Double = (boat.map(\.y).max() ?? 0) + 12
        return (0..<90).compactMap { _ in
            let y: Double = 682 + random.unit() * 71
            let amplitude: Double = 0.4 + random.unit() * 0.8
            let spans: [SIMD2<Double>] = (!boat.isEmpty && y + amplitude >= boatTop && y - amplitude <= boatBottom)
                ? [[650, min(1160, boatLeft)], [max(650, boatRight), 1160]].filter { $0.y - $0.x > 20 }
                : [[650, 1160]]
            guard !spans.isEmpty else { return nil }
            let available: Double = spans.reduce(0) { $0 + $1.y - $1.x }
            // Thin candidates in proportion to the space left by the boat. This
            // avoids packing displaced waves into two narrow strips.
            guard random.unit() * 510 < available else { return nil }
            var choice: Double = random.unit() * available
            var span: SIMD2<Double> = spans.last!
            for candidate in spans {
                choice -= candidate.y - candidate.x
                if choice < 0 { span = candidate; break }
            }
            let length: Double = 18 + random.unit() * min(85, span.y - span.x - 20)
            let x: Double = span.x + 1 + random.unit() * (span.y - span.x - length - 2)
            let phase: Double = random.unit() * .pi * 2
            let points: [SIMD2<Double>] = (0...12).map { index in
                let t: Double = Double(index) / 12
                return [x + t * length, y + sin(t * .pi * 2 + phase) * amplitude]
            }
            return stroke(points, width: 0.45 + random.unit() * 0.4, tone: 0.35,
                          opacity: 0.1 + random.unit() * 0.13, random: &random)
        }
    }

    static func shore(seed: UInt64, land: ShanShuiComposition.Shore) -> [InkPrimitive] {
        var random: InkRandom = InkRandom(state: seed)
        var primitives: [InkPrimitive] = [.wash(points: land.polygon, tone: 1, opacity: 1)]
        primitives.append(stroke(land.ridge, width: 1.4, tone: 0.3, opacity: 0.5, random: &random))
        for _ in 0..<22 {
            let length: Double = 12 + random.unit() * 42
            let left: Double = land.ridge.first!.x + 30
            let right: Double = land.ridge.last!.x - 30
            let x: Double = left + random.unit() * (right - left - length)
            let top: Double = land.support(at: x + length * 0.5, radius: length * 0.5) + 8
            let y: Double = top + random.unit() * (land.bottom - 5 - top)
            let points: [SIMD2<Double>] = (0...8).map { index in
                let t: Double = Double(index) / 8
                return [x + t * length, y + sin(t * .pi * 2) * 0.8]
            }
            primitives.append(stroke(points, width: 0.8, tone: 0.3, opacity: 0.28, random: &random))
        }
        return primitives
    }

    static func rock(seed: UInt64, center: SIMD2<Double>, width: Double,
                     height: Double) -> [InkPrimitive] {
        var random: InkRandom = InkRandom(state: seed)
        let outline: [SIMD2<Double>] = (0..<28).map { index in
            let angle: Double = Double(index) / 28 * .pi * 2
            let radius: Double = 0.86 + random.unit() * 0.14
            return [center.x + cos(angle) * width * 0.5 * radius,
                    center.y + min(sin(angle) * height * 0.5 * radius, height * 0.3)]
        }
        var primitives: [InkPrimitive] = [.wash(points: outline, tone: 0.98, opacity: 1)]
        primitives.append(stroke(outline + [outline[0]], width: 1.6, tone: 0.22,
                                 opacity: 0.67, random: &random))
        for band in 0..<5 {
            let span: Double = width * (0.7 - Double(band) * 0.07)
            let points: [SIMD2<Double>] = (0...16).map { index in
                let t: Double = Double(index) / 16
                return [center.x + (t - 0.5) * span,
                        center.y + height * (Double(band) * 0.07 - 0.19)
                            - sin(t * .pi) * height * 0.16 + (random.unit() - 0.5) * 1.3]
            }
            primitives.append(stroke(points, width: 0.8, tone: 0.25,
                                     opacity: 0.3, random: &random))
        }
        return primitives
    }

    /// A curved tapered trunk, paired branches and irregular needle clusters.
    /// The fixed seven branch tiers give O(C × N) samples for C clusters of N needles.
    static func pine(seed: UInt64, root: SIMD2<Double>, height: Double) -> [InkPrimitive] {
        var random: InkRandom = InkRandom(state: seed)
        let lean: Double = 12 + random.unit() * 18
        func trunkPoint(_ t: Double) -> SIMD2<Double> {
            root + [lean * t + sin(t * .pi * 2) * 3, -height * t]
        }
        let trunk: [SIMD2<Double>] = (0...24).map { trunkPoint(Double($0) / 24) }
        let widths: [Double] = (0...24).map { 6.2 * (1 - Double($0) / 24) + 0.45 }
        var primitives: [InkPrimitive] = [.stroke(points: trunk, widths: widths,
                                                 tone: 0.18, opacity: 0.82)]
        for tier in 0..<7 {
            let t: Double = 0.27 + Double(tier) * 0.095
            let start: SIMD2<Double> = trunkPoint(t)
            for direction in [-1.0, 1.0] {
                let length: Double = (1 - t) * (65 + random.unit() * 25)
                let lift: Double = 10 + random.unit() * 10
                let branch: [SIMD2<Double>] = (0...12).map { index in
                    let s: Double = Double(index) / 12
                    return start + [direction * length * s, -lift * s + sin(s * .pi) * 4]
                }
                primitives.append(stroke(branch, width: 2.4 * (1 - t) + 0.4,
                                         tone: 0.18, opacity: 0.75, random: &random))
                for cluster in 0..<3 {
                    let s: Double = 0.45 + Double(cluster) * 0.25
                    let center: SIMD2<Double> = start + [direction * length * s, -lift * s - 3]
                    primitives += needles(center: center, random: &random)
                }
            }
        }
        return primitives
    }

    private static func needles(center: SIMD2<Double>, random: inout InkRandom) -> [InkPrimitive] {
        let width: Double = 10 + random.unit() * 7
        let height: Double = 4 + random.unit() * 3
        let cloud: [SIMD2<Double>] = (0..<12).map { index in
            let angle: Double = Double(index) / 12 * .pi * 2
            let radius: Double = 0.8 + random.unit() * 0.2
            return center + [cos(angle) * width * radius, sin(angle) * height * radius]
        }
        var primitives: [InkPrimitive] = [.wash(points: cloud, tone: 0.25, opacity: 0.15)]
        for _ in 0..<9 {
            let start: SIMD2<Double> = center + [(random.unit() - 0.5) * width * 1.7,
                                                (random.unit() - 0.5) * height]
            let delta: SIMD2<Double> = [(random.unit() - 0.5) * 12, -3 - random.unit() * 6]
            let points: [SIMD2<Double>] = [start, start + delta * 0.55 + [1, 0], start + delta]
            primitives.append(stroke(points, width: 0.55 + random.unit() * 0.4, tone: 0.18,
                                     opacity: 0.45 + random.unit() * 0.25, random: &random))
        }
        return primitives
    }

    /// Full width w(t) = w₀ sin(πt)^0.7 with the study's local ink variation.
    private static func stroke(_ points: [SIMD2<Double>], width: Double, tone: Double,
                               opacity: Double, random: inout InkRandom) -> InkPrimitive {
        let widths: [Double] = points.indices.map { index in
            let t: Double = Double(index) / Double(max(1, points.count - 1))
            return width * pow(max(0, sin(.pi * t)), 0.7) * (0.65 + random.unit() * 0.7)
        }
        return .stroke(points: points, widths: widths, tone: tone, opacity: opacity)
    }
}
