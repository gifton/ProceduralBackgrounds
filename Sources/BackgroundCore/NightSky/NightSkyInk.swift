import Foundation

enum NightSkyInk {
    static func ellipse(anchor: SIMD2<Double>, radii: SIMD2<Double>,
                        rotation: Double = 0, samples: Int = 32) -> [SIMD2<Double>] {
        let c: Double = cos(rotation), s: Double = sin(rotation)
        return (0..<samples).map { sample in
            let angle: Double = Double(sample) * 2 * .pi / Double(samples)
            let x: Double = cos(angle) * radii.x, y: Double = sin(angle) * radii.y
            return anchor + [x * c - y * s, x * s + y * c]
        }
    }

    static func group(_ value: NightSkyWashGroup) -> [InkPrimitive] {
        value.lobes.map { lobe in
            .colorWash(points: ellipse(anchor: lobe.anchor, radii: lobe.radii, rotation: lobe.rotation),
                       color: lobe.color, opacity: lobe.opacity)
        }
    }

    static func star(_ value: NightSkyStar) -> [InkPrimitive] {
        var random = InkRandom(state: value.seed)
        let color = random.unit() < 0.2 ? NightSkyPalette.gold : NightSkyPalette.cream
        let radius: Double = value.radius * (value.isAccent ? 0.3 : 0.9)
        var ink: [InkPrimitive] = [
            .colorWash(points: ellipse(anchor: value.anchor, radii: [radius, radius * (0.65 + random.unit() * 0.25)],
                                      rotation: random.unit() * .pi, samples: 12),
                       color: color, opacity: 0.7 + random.unit() * 0.28)
        ]
        if value.isAccent {
            for direction: SIMD2<Double> in [[1, 0], [0, 1]] {
                let reach: SIMD2<Double> = direction * value.radius * 0.82
                ink.append(.colorStroke(points: [value.anchor - reach, value.anchor, value.anchor + reach],
                                        widths: [0.15, value.radius * 0.24, 0.15], color: color,
                                        opacity: 0.75 + random.unit() * 0.2))
            }
        }
        return ink
    }
}
