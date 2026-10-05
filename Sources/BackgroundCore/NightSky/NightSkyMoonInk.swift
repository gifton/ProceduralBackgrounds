import Foundation

enum NightSkyMoonInk {
    static func silhouette(_ moon: NightSkyMoon) -> [SIMD2<Double>] {
        if moon.phase == .rounded {
            return NightSkyInk.ellipse(anchor: moon.anchor, radii: SIMD2(repeating: moon.radius), samples: 48)
        }
        let d: Double = 0.55, k: Double = 0.95
        let theta: Double = acos((1 + d*d - k*k) / (2*d))
        let phi: Double = acos((cos(theta) - d) / k)
        let outer: [SIMD2<Double>] = (0...48).map { sample in
            let angle: Double = theta + (2 * .pi - 2 * theta) * Double(sample) / 48
            return [cos(angle), sin(angle)]
        }
        let inner: [SIMD2<Double>] = (1..<48).map { sample in
            let angle: Double = (2 * .pi - phi) + (2 * phi - 2 * .pi) * Double(sample) / 48
            return [d + k * cos(angle), k * sin(angle)]
        }
        // The two arcs share intersection endpoints; no painted cutout disk.
        // crescentMeshLeavesItsOpeningClear tests the compiled body's opening.
        return (outer + inner).map { moon.anchor + $0 * moon.radius }
    }

    static func draw(_ moon: NightSkyMoon) -> [InkPrimitive] {
        var random = InkRandom(state: moon.seed)
        var ink: [InkPrimitive] = []
        for layer in 0..<6 {
            let radius: Double = moon.radius + 30 - Double(layer) * 4
            ink.append(.colorWash(points: NightSkyInk.ellipse(anchor: moon.anchor, radii: SIMD2(repeating: radius)),
                                  color: NightSkyPalette.cream, opacity: 0.006 + Double(layer) * 0.003))
        }
        let outline = silhouette(moon)
        ink.append(.colorWash(points: outline, color: NightSkyPalette.cream, opacity: 0.98))
        for _ in 0..<8 {
            let local: SIMD2<Double> = moon.phase == .crescent
                ? [-0.72 + (random.unit() - 0.5) * 0.2, (random.unit() - 0.5) * 0.7]
                : [(random.unit() - 0.5) * 1.2, (random.unit() - 0.5) * 1.2]
            let radius: Double = moon.radius * (0.03 + random.unit() * 0.05)
            let marks = NightSkyInk.ellipse(anchor: moon.anchor + local * moon.radius,
                                            radii: [radius, radius * 0.7], rotation: random.unit() * .pi, samples: 16)
            let inside: Bool = marks.allSatisfy { point in
                let p: SIMD2<Double> = (point - moon.anchor) / moon.radius
                let cutout: SIMD2<Double> = p - [0.55, 0]
                return p.x*p.x + p.y*p.y < 0.92 * 0.92
                    && (moon.phase == .rounded || cutout.x*cutout.x + cutout.y*cutout.y > 0.975 * 0.975)
            }
            if inside {
                ink.append(.colorWash(points: marks, color: NightSkyPalette.moonShadow, opacity: 0.05 + random.unit() * 0.04))
            }
        }
        let edgeCount: Int = moon.phase == .crescent ? 49 : 48
        for start in stride(from: 3, to: edgeCount - 4, by: 7) {
            let points: [SIMD2<Double>] = outline[start..<(start + 4)].map { point in
                let normal: SIMD2<Double> = (point - moon.anchor) / moon.radius
                return point + normal * (random.unit() - 0.5) * 1.2
            }
            ink.append(.colorStroke(points: points, widths: points.map { _ in 0.6 + random.unit() * 0.6 },
                                    color: NightSkyPalette.moonShadow, opacity: 0.12))
        }
        return ink
    }
}
