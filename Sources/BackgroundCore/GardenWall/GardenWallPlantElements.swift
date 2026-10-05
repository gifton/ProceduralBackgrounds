import Foundation

enum GardenWallPlantElements {
    static func draw(_ placement: GardenWallPlantPlacement) -> [InkPrimitive] {
        var random = InkRandom(state: placement.seed)
        let ink: [InkPrimitive]
        switch placement.kind {
        case .ivy: ink = ivy(random: &random)
        case .grasses: ink = grasses(random: &random)
        case .blossom: ink = blossoms(random: &random)
        case .spike: ink = spikes(random: &random)
        }
        return GardenWallInk.placed(ink, anchor: placement.anchor, scale: placement.scale)
    }

    private static func ivy(random: inout InkRandom) -> [InkPrimitive] {
        var ink: [InkPrimitive] = []
        // Drawing-only variation leaves the existing composition cadence intact.
        // hangingPlantsDrawFullClumpsWithVaryingSprayCounts checks the 4–8 range.
        let count: Int = 4 + Int(random.unit() * 5)
        for spray in 0..<count {
            let direction: Double = spray.isMultiple(of: 2) ? -1 : 1
            let spread: Double = (Double(spray) / Double(count - 1) - 0.5) * 46
            let root: SIMD2<Double> = [spread + (random.unit() - 0.5) * 8, 0]
            let control: SIMD2<Double> = [root.x + direction * (15 + random.unit() * 10),
                                          55 + random.unit() * 18]
            let end: SIMD2<Double> = [root.x - direction * (5 + random.unit() * 15),
                                      175 + random.unit() * 30]
            ink.append(GardenWallInk.line(GardenWallInk.curve(root, control, end, samples: 24),
                                           width: 1.6, color: GardenWallPalette.sage, opacity: 0.6, random: &random))
            for twig in 0..<4 {
                let t: Double = 0.2 + Double(twig) * 0.19
                let start: SIMD2<Double> = root * ((1 - t) * (1 - t)) + control * (2 * t * (1 - t)) + end * (t * t)
                let side: Double = twig.isMultiple(of: 2) ? -1 : 1
                let tip: SIMD2<Double> = start + [side * (36 + random.unit() * 18), 18 + random.unit() * 12]
                ink.append(GardenWallInk.line(GardenWallInk.curve(start, start + [side * 35, 4], tip),
                                               width: 1, color: GardenWallPalette.sage, opacity: 0.55, random: &random))
                for leaf in 0..<3 {
                    let fraction: Double = 0.3 + Double(leaf) * 0.3
                    let center: SIMD2<Double> = start + (tip - start) * fraction
                    let angle: Double = side > 0 ? 0.85 : 2.3
                    ink.append(GardenWallInk.leaf(center: center, length: 17 + random.unit() * 7,
                                                  width: 10 + random.unit() * 4, angle: angle,
                                                  color: GardenWallPalette.sage, random: &random))
                    ink.append(GardenWallInk.line([center, center + [side * 7, 5]], width: 0.35,
                                                   color: GardenWallPalette.ink, opacity: 0.3, random: &random))
                }
            }
        }
        return ink
    }

    private static func grasses(random: inout InkRandom) -> [InkPrimitive] {
        (0..<18).map { blade in
            let x: Double = (Double(blade) / 17 - 0.5) * 92
            let height: Double = 20 + random.unit() * 38
            let tip: SIMD2<Double> = [x + (random.unit() - 0.5) * 12, -height]
            return GardenWallInk.line(GardenWallInk.curve([x, 0], [x + 5, -height * 0.55], tip),
                                      width: 0.65 + random.unit() * 0.5,
                                      color: GardenWallPalette.sage, opacity: 0.45 + random.unit() * 0.25,
                                      random: &random)
        }
    }

    private static func blossoms(random: inout InkRandom) -> [InkPrimitive] {
        var ink: [InkPrimitive] = []
        for flower in 0..<3 {
            let head: SIMD2<Double> = [(Double(flower) - 1) * 31 + (random.unit() - 0.5) * 8,
                                      -72 - random.unit() * 38]
            ink.append(GardenWallInk.line(GardenWallInk.curve([0, 0], [head.x * 0.2, -40], head),
                                           width: 1.1, color: GardenWallPalette.sage, opacity: 0.65, random: &random))
            for petal in 0..<5 {
                let angle: Double = Double(petal) / 5 * .pi * 2
                let center: SIMD2<Double> = head + [cos(angle) * 6, sin(angle) * 6]
                ink.append(.colorWash(points: GardenWallInk.ellipse(center: center, radii: [7, 4.5], angle: angle),
                                       color: GardenWallPalette.pink, opacity: 0.42))
            }
            ink.append(.colorWash(points: GardenWallInk.ellipse(center: head, radii: [3.5, 3.5]),
                                   color: GardenWallPalette.cream, opacity: 0.8))
            ink.append(GardenWallInk.leaf(center: head * 0.45 + [8, 1], length: 20, width: 7,
                                          angle: -0.8, color: GardenWallPalette.sage, random: &random))
        }
        return ink
    }

    private static func spikes(random: inout InkRandom) -> [InkPrimitive] {
        var ink: [InkPrimitive] = []
        for stem in 0..<2 {
            let x: Double = stem == 0 ? -15 : 15
            let height: Double = 115 + random.unit() * 30
            ink.append(GardenWallInk.line(GardenWallInk.curve([x, 0], [x + 8, -height * 0.5], [x, -height]),
                                           width: 1.1, color: GardenWallPalette.sage, opacity: 0.6, random: &random))
            for tier in 0..<8 {
                let y: Double = -height + 7 + Double(tier) * 8
                for side: Double in [-1, 1] {
                    let center: SIMD2<Double> = [x + side * 5, y]
                    ink.append(.colorWash(points: GardenWallInk.ellipse(center: center, radii: [5, 3], angle: side * -0.7),
                                           color: stem == 0 ? GardenWallPalette.pink : GardenWallPalette.cream, opacity: 0.52))
                }
            }
            ink.append(GardenWallInk.leaf(center: [x + 8, -35], length: 25, width: 8,
                                          angle: -0.7, color: GardenWallPalette.sage, random: &random))
        }
        return ink
    }

    static func pot(_ placement: GardenWallPotPlacement) -> [InkPrimitive] {
        var random = InkRandom(state: placement.seed)
        let w: Double = placement.width, h: Double = w * 0.78
        var ink: [InkPrimitive] = [
            .colorWash(points: [[-w * 0.48, -h], [w * 0.48, -h], [w * 0.34, 0], [-w * 0.34, 0]],
                       color: GardenWallPalette.terracotta, opacity: 0.6),
            .colorWash(points: GardenWallInk.ellipse(center: [0, -h], radii: [w * 0.51, 4]),
                       color: GardenWallPalette.terracotta, opacity: 0.55)
        ]
        ink.append(GardenWallInk.line([[-w * 0.48, -h], [-w * 0.34, 0], [w * 0.34, 0], [w * 0.48, -h]],
                                       width: 0.9, opacity: 0.4, random: &random))
        ink.append(GardenWallInk.line([[-w * 0.49, -h], [w * 0.49, -h]], width: 0.9,
                                       opacity: 0.4, random: &random))
        return GardenWallInk.placed(ink, anchor: placement.anchor, scale: 1)
    }
}
