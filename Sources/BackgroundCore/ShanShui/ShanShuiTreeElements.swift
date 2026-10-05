import Foundation

/// Adaptations of upstream `Tree.tree03` and `Tree.tree08`/`fracTree`.
/// Dimensions are internal caller contracts; the study supplies positive sizes.
enum ShanShuiTreeElements {
    static func leafy(seed: UInt64, root: SIMD2<Double>, height: Double) -> [InkPrimitive] {
        var random: InkRandom = InkRandom(state: seed)
        let scale: Double = height / 50
        let width: Double = 5 * scale
        let lean: Double = (random.unit() - 0.5) * height * 0.12
        var left: [SIMD2<Double>] = []
        var right: [SIMD2<Double>] = []
        var leaves: [InkPrimitive] = []
        for tier in 0..<10 {
            let t: Double = Double(tier) / 10
            let center: SIMD2<Double> = root + [lean * t + sin(t * .pi) * scale, -height * t]
            let radius: Double = width * (1 - t) * 0.5
            left.append(center + [-radius * (0.8 + random.unit() * 0.4), 0])
            right.append(center + [radius * (0.8 + random.unit() * 0.4), 0])
            if tier >= 2 {
                // Upstream's logarithmic envelope spreads lower foliage and
                // narrows toward the tip: log(50(1−t)+1)/3.95.
                let envelope: Double = log(50 * (1 - t) + 1) / 3.95
                for _ in 0..<((10 - tier) * 2) {
                    let offset: Double = random.unit() * width * 2 * envelope
                    let direction: Double = random.unit() < 0.5 ? -1 : 1
                    leaves.append(ShanShuiElementInk.leaf(
                        center: center + [offset * direction, (random.unit() - 0.5) * width * 2],
                        length: max(3, offset * 2), width: (3 + random.unit() * 6) * scale,
                        angle: (random.unit() - 0.5) * .pi / 6, random: &random))
                }
            }
        }
        var ink: [InkPrimitive] = [.wash(points: left + right.reversed(), tone: 1, opacity: 1)]
        ink.append(ShanShuiElementInk.line(left, width: 2.2, random: &random))
        ink.append(ShanShuiElementInk.line(right, width: 2.2, random: &random))
        ink += leaves
        return ink
    }

    static func bare(seed: UInt64, root: SIMD2<Double>, height: Double) -> [InkPrimitive] {
        var random: InkRandom = InkRandom(state: seed)
        let lean: Double = (random.unit() - 0.5) * height * 0.32
        let center: [SIMD2<Double>] = ShanShuiElementInk.curve(
            root, root + [lean * 0.15 - 8, -height * 0.5], root + [lean, -height], samples: 24)
        let left: [SIMD2<Double>] = center.enumerated().map { index, p in
            p + [-4.5 * (1 - Double(index) / 30), 0]
        }
        let right: [SIMD2<Double>] = center.enumerated().map { index, p in
            p + [4.5 * (1 - Double(index) / 30), 0]
        }
        var ink: [InkPrimitive] = [.wash(points: left + right.reversed(), tone: 1, opacity: 1)]
        ink.append(ShanShuiElementInk.line(left, width: 1.8, opacity: 0.75, random: &random))
        ink.append(ShanShuiElementInk.line(right, width: 1.8, opacity: 0.75, random: &random))
        for tier in 0..<8 {
            let index: Int = 8 + tier * 2
            let direction: Double = tier.isMultiple(of: 2) ? -1 : 1
            let angle: Double = -.pi / 2 + direction * (0.65 + random.unit() * 0.25)
            ink += branch(start: center[index], angle: angle,
                          length: 42 + random.unit() * 22, depth: tier > 4 ? 2 : 3,
                          random: &random)
        }
        ink += branch(start: center[24], angle: -.pi / 2 + lean / height,
                      length: 34, depth: 2, random: &random)
        return ink
    }

    /// Fixed-depth branching follows upstream's curved segments, random fork,
    /// shrinking length and tapered terminal twig. O(2^d N), here d ≤ 3, N = 11.
    private static func branch(start: SIMD2<Double>, angle: Double, length: Double,
                               depth: Int, random: inout InkRandom) -> [InkPrimitive] {
        let axis: SIMD2<Double> = [cos(angle), sin(angle)]
        let normal: SIMD2<Double> = [-axis.y, axis.x]
        let bend: Double = random.unit() < 0.5 ? -2 : 2
        let points: [SIMD2<Double>] = (0...10).map { index in
            let t: Double = Double(index) / 10
            return start + axis * (length * t) + normal * (sin(t * .pi) * bend)
        }
        let widths: [Double] = (0...10).map { index in
            let t: Double = Double(index) / 10
            return (0.9 + Double(depth) * 0.35) * (0.8 + random.unit() * 0.2)
                * (depth == 0 ? max(0, cos(t * .pi / 2)) : 1)
        }
        var ink: [InkPrimitive] = [.stroke(points: points, widths: widths, tone: 0.39, opacity: 0.65)]
        guard depth > 0 else { return ink }
        let end: SIMD2<Double> = start + axis * length
        let fork: Bool = random.unit() < 0.65
        for direction in fork ? [-1.0, 1.0] : [0.0] {
            ink += branch(start: end, angle: angle + direction * (0.18 + random.unit() * 0.35),
                          length: length * (0.8 + random.unit() * 0.1), depth: depth - 1,
                          random: &random)
        }
        return ink
    }
}
