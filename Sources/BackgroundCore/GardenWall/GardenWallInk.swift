import Foundation

/// Finite sampled shapes for Garden Wall. Leaves are monotone along their axis;
/// wholeGardenCompilesToFiniteBoundedTriangles exercises their polygon fills.
enum GardenWallInk {
    static func ellipse(center: SIMD2<Double>, radii: SIMD2<Double>,
                        angle: Double = 0) -> [SIMD2<Double>] {
        let axis: SIMD2<Double> = [cos(angle), sin(angle)]
        let normal: SIMD2<Double> = [-axis.y, axis.x]
        return (0..<24).map { i in
            let t: Double = Double(i) / 24 * .pi * 2
            return center + axis * (cos(t) * radii.x) + normal * (sin(t) * radii.y)
        }
    }

    static func curve(_ a: SIMD2<Double>, _ control: SIMD2<Double>,
                      _ b: SIMD2<Double>, samples: Int = 16) -> [SIMD2<Double>] {
        ShanShuiElementInk.curve(a, control, b, samples: samples)
    }

    static func line(_ points: [SIMD2<Double>], width: Double,
                     color: SIMD3<Double> = GardenWallPalette.ink,
                     opacity: Double = 0.65, taper: Bool = true,
                     random: inout InkRandom) -> InkPrimitive {
        let widths: [Double] = points.indices.map { index in
            let t: Double = Double(index) / Double(max(1, points.count - 1))
            let profile: Double = taper ? 0.15 + 0.85 * max(0, sin(t * .pi)) : 1
            return width * profile * (0.8 + random.unit() * 0.2)
        }
        return .colorStroke(points: points, widths: widths, color: color, opacity: opacity)
    }

    static func leaf(center: SIMD2<Double>, length: Double, width: Double,
                     angle: Double, color: SIMD3<Double>, random: inout InkRandom) -> InkPrimitive {
        let points = ShanShuiElementInk.leaf(center: center, length: length, width: width,
                                           angle: angle, random: &random).points
        return .colorWash(points: points, color: color, opacity: 0.32 + random.unit() * 0.25)
    }

    static func placed(_ ink: [InkPrimitive], anchor: SIMD2<Double>, scale: Double) -> [InkPrimitive] {
        ink.map { $0.mapGeometry({ anchor + $0 * scale }, widthScale: scale) }
    }
}
