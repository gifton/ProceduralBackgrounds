import Foundation

/// Adaptations of upstream `Arch.roof`, `box`, `rail`, `boat01` and `Man.man`.
/// The study's positive dimensions are caller contracts, not external input.
enum ShanShuiArchitectureElements {
    static func pavilion(seed: UInt64, base: SIMD2<Double>, width: Double) -> [InkPrimitive] {
        var random: InkRandom = InkRandom(state: seed)
        let rotation: Double = 0.6 + random.unit() * 0.15
        let mid: Double = -width * 0.5 + width * rotation
        let perspective: Double = width / 30
        let postHeight: Double = width * (0.44 + random.unit() * 0.06)
        let roofHeight: Double = width * (0.23 + random.unit() * 0.04)
        let eaves: SIMD2<Double> = base + [0, -postHeight]
        let half: Double = width * 0.5
        let platform: [SIMD2<Double>] = [base + [-half * 0.86, 0],
                                        base + [mid, perspective],
                                        base + [half * 0.86, 0],
                                        base + [-mid, -perspective]]
        var ink: [InkPrimitive] = [.wash(points: platform, tone: 1, opacity: 1)]
        ink.append(ShanShuiElementInk.line(platform + [platform[0]], width: 2, random: &random))
        // Open posts retain the paper between them; the roof is painted last.
        for point in platform {
            ink.append(ShanShuiElementInk.line([point, point + [0, -postHeight]],
                                               width: 2.8, opacity: 0.7, random: &random))
        }
        for (a, b) in [(platform[0], platform[1]), (platform[1], platform[2])] {
            let topA: SIMD2<Double> = a + [0, -30]
            let topB: SIMD2<Double> = b + [0, -30]
            ink.append(ShanShuiElementInk.line([topA, topB], width: 1.6, random: &random))
            ink.append(ShanShuiElementInk.line([a + [0, -7], b + [0, -7]],
                                               width: 1.2, random: &random))
            for index in 1..<5 {
                let t: Double = Double(index) / 5
                let foot: SIMD2<Double> = a * (1 - t) + b * t
                ink.append(ShanShuiElementInk.line([foot + [0, -7], foot + [0, -30]],
                                                   width: 1.1, opacity: 0.5, random: &random))
            }
        }

        // Upstream's roof perspective uses a shifted ridge and curved eaves.
        let quarter: Double = (mid + half) * 0.5 - mid
        let corner: Double = width / 24
        let topLeft: SIMD2<Double> = eaves + [-half + quarter, -roofHeight - perspective / 2]
        let topRight: SIMD2<Double> = eaves + [mid + quarter, -roofHeight]
        let leftTip: SIMD2<Double> = eaves + [-half - corner, 0]
        let rightTip: SIMD2<Double> = eaves + [half + corner, 0]
        let frontTip: SIMD2<Double> = eaves + [mid + corner, perspective]
        let leftEdge: [SIMD2<Double>] = ShanShuiElementInk.curve(
            topLeft, eaves + [-half + quarter * 0.5, -roofHeight / 2 - perspective / 4], leftTip)
        let rightEdge: [SIMD2<Double>] = ShanShuiElementInk.curve(
            topRight, eaves + [(mid + quarter + half) / 2, -roofHeight / 2], rightTip)
        let frontEdge: [SIMD2<Double>] = ShanShuiElementInk.curve(
            topRight, eaves + [mid + quarter / 2, -roofHeight / 2 + perspective / 2], frontTip)
        let silhouette: [SIMD2<Double>] = Array(leftEdge.reversed()) + [topRight]
            + rightEdge.dropFirst() + [frontTip]
        ink.append(.wash(points: silhouette, tone: 1, opacity: 1))
        for edge in [leftEdge, rightEdge, frontEdge, [leftTip, frontTip],
                     [rightTip, frontTip], [topLeft, topRight]] {
            ink.append(ShanShuiElementInk.line(edge, width: 2.4, opacity: 0.65, random: &random))
        }
        for index in 1..<15 {
            let t: Double = Double(index) / 15
            let start: SIMD2<Double> = topLeft * (1 - t) + topRight * t
            let end: SIMD2<Double> = leftTip * (1 - t) + frontTip * t
            let control: SIMD2<Double> = (start + end) * 0.5 + [quarter * 0.08, -4]
            ink.append(ShanShuiElementInk.line(ShanShuiElementInk.curve(start, control, end),
                                               width: 0.8, opacity: 0.3, random: &random))
        }
        return ink
    }

    static func boat(seed: UInt64, origin: SIMD2<Double>, length: Double) -> [InkPrimitive] {
        var random: InkRandom = InkRandom(state: seed)
        let scale: Double = length / 120
        var ink: [InkPrimitive] = boatman(origin: origin + [20 * scale, 0],
                                        scale: scale * 0.5, random: &random)
        // Upstream's two hull profiles: y = s × {7,10} × √sin(πt).
        let upper: [SIMD2<Double>] = (0...36).map { index in
            let t: Double = Double(index) / 36
            return origin + [length * t, 7 * scale * sqrt(max(0, sin(t * .pi)))]
        }
        let lower: [SIMD2<Double>] = (0...36).map { index in
            let t: Double = Double(index) / 36
            return origin + [length * t, 10 * scale * sqrt(max(0, sin(t * .pi)))]
        }
        let hull: [SIMD2<Double>] = upper + lower.reversed()
        ink.append(.wash(points: hull, tone: 1, opacity: 1))
        ink.append(ShanShuiElementInk.line(upper, width: 2.3, opacity: 0.7, random: &random))
        ink.append(ShanShuiElementInk.line(lower, width: 2.3, opacity: 0.7, random: &random))
        for index in 0..<6 {
            let y: Double = 40 + Double(index) * 8
            let left: Double = 10 + random.unit() * 45
            let right: Double = length - 10 - random.unit() * 45
            ink.append(ShanShuiElementInk.line(
                [origin + [left, y], origin + [(left + right) / 2, y - 1], origin + [right, y]],
                width: 0.8, opacity: 0.18, taper: true, random: &random))
        }
        return ink
    }

    /// Nine-joint forward kinematics from `Man.man`: a child angle accumulates
    /// its parent's angle, then pᵢ = p_parent + ℓᵢ(cos θᵢ, sin θᵢ). O(J).
    private static func boatman(origin: SIMD2<Double>, scale: Double,
                                random: inout InkRandom) -> [InkPrimitive] {
        let parents: [Int] = [0, 0, 1, 0, 3, 1, 5, 1, 7]
        let lengths: [Double] = [0, 30, 20, 30, 10, 30, 30, 30, 30]
        let angles: [Double] = [0, -.pi / 2, 0, .pi / 4 * random.unit(),
                               .pi * 0.75 * random.unit(), .pi * 0.75, -.pi / 4,
                               -.pi * 0.75 - .pi / 4 * random.unit(), -.pi / 4]
        var rotations: [Double] = Array(repeating: 0, count: 9)
        var joints: [SIMD2<Double>] = Array(repeating: .zero, count: 9)
        for index in 1..<9 {
            let parent: Int = parents[index]
            rotations[index] = rotations[parent] + angles[index]
            joints[index] = joints[parent] + [cos(rotations[index]), sin(rotations[index])]
                * (lengths[index] * scale)
        }
        let footY: Double = joints[4].y
        joints = joints.map { origin + [-$0.x, $0.y - footY] }
        var ink: [InkPrimitive] = []
        let poleStart: SIMD2<Double> = joints[8]
        let poleEnd: SIMD2<Double> = poleStart + (joints[6] - poleStart) * 1.8
        ink.append(ShanShuiElementInk.line([poleStart, poleEnd], width: 1.5, random: &random))
        for controls in [[joints[1], joints[7], joints[8]],
                         [joints[1], joints[0], joints[3], joints[4]],
                         [joints[1], joints[5], joints[6]]] {
            let body: Bool = controls.count == 4
            ink += cloth(controls, scale: scale, body: body, random: &random)
        }
        let neck: SIMD2<Double> = joints[1]
        let crown: SIMD2<Double> = joints[2]
        let headCenter: SIMD2<Double> = (neck + crown) * 0.5
        let head: [SIMD2<Double>] = (0..<24).map { index in
            let angle: Double = Double(index) / 24 * .pi * 2
            return headCenter + [cos(angle) * 6 * scale, sin(angle) * 10 * scale]
        }
        ink.append(.wash(points: head, tone: 0.55, opacity: 0.7))
        ink.append(ShanShuiElementInk.line(head + [head[0]], width: 1.2, random: &random))
        // `hat02`'s broad brim in the neck→crown coordinate frame.
        let axis: SIMD2<Double> = crown - neck
        let normal: SIMD2<Double> = [-axis.y, axis.x]
        let hatLocal: [SIMD2<Double>] = [[-0.3, 0.5], [-1.1, 0.5], [-1.2, 0.6],
                                        [-1.1, 0.7], [-0.3, 0.8], [0.3, 0.8],
                                        [1, 0.7], [1.3, 0.6], [1.2, 0.5], [0.3, 0.5]]
        ink.append(.wash(points: hatLocal.map { neck + normal * $0.x + axis * $0.y },
                         tone: 0.39, opacity: 0.85))
        return ink
    }

    /// Midpoint quadratic smoothing and upstream's robe/sleeve width profile.
    /// Folded garments are the union of white ribbon triangles, followed by
    /// their ink boundaries. A whole offset polygon can cross itself at a knee;
    /// `eachElementCompilesToFiniteTriangles` exercises 130 seeds per subject.
    private static func cloth(_ controls: [SIMD2<Double>], scale: Double, body: Bool,
                               random: inout InkRandom) -> [InkPrimitive] {
        var center: [SIMD2<Double>] = []
        var start: SIMD2<Double> = controls[0]
        for index in 1..<(controls.count - 1) {
            let end: SIMD2<Double> = index == controls.count - 2 ? controls[index + 1]
                : (controls[index] + controls[index + 1]) * 0.5
            let segment = ShanShuiElementInk.curve(start, controls[index], end)
            center += center.isEmpty ? segment : Array(segment.dropFirst())
            start = end
        }
        var left: [SIMD2<Double>] = []
        var right: [SIMD2<Double>] = []
        for index in center.indices {
            let t: Double = Double(index) / Double(center.count - 1)
            let delta: SIMD2<Double> = center[min(index + 1, center.count - 1)]
                - center[max(index - 1, 0)]
            let magnitude: Double = hypot(delta.x, delta.y)
            let normal: SIMD2<Double> = magnitude > 1e-9 ? [-delta.y / magnitude, delta.x / magnitude] : [1, 0]
            let width: Double = scale * (body ? 11 : 8)
                * (sin(t * .pi / 2) * pow(max(0, sin(t * .pi)), 0.1) + (1 - t) * (body ? 0.5 : 0.4))
            left.append(center[index] + normal * width)
            right.append(center[index] - normal * width)
        }
        var ink: [InkPrimitive] = []
        for index in 0..<(center.count - 1) {
            ink.append(.wash(points: [left[index], right[index], left[index + 1]], tone: 1, opacity: 1))
            ink.append(.wash(points: [right[index], right[index + 1], left[index + 1]], tone: 1, opacity: 1))
        }
        ink.append(ShanShuiElementInk.line(left, width: 1.4, random: &random))
        ink.append(ShanShuiElementInk.line(right, width: 1.4, random: &random))
        return ink
    }
}
