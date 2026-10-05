enum GardenWallCatElements {
    static func draw(_ placement: GardenWallCatPlacement) -> [InkPrimitive] {
        var random = InkRandom(state: placement.seed)
        let ink: [InkPrimitive] = placement.pose == .sleeping
            ? sleeping(random: &random) : sitting(random: &random)
        return GardenWallInk.placed(ink, anchor: placement.anchor, scale: placement.scale)
    }

    private static func wash(_ points: [SIMD2<Double>]) -> InkPrimitive {
        .colorWash(points: points, color: GardenWallPalette.cat, opacity: 0.94)
    }

    private static func sleeping(random: inout InkRandom) -> [InkPrimitive] {
        let head = GardenWallInk.ellipse(center: [42, -27], radii: [23, 21])
        let leftEar: [SIMD2<Double>] = [[27, -41], [28, -65], [42, -46]]
        let rightEar: [SIMD2<Double>] = [[46, -47], [60, -63], [60, -36]]
        var ink: [InkPrimitive] = [
            wash(GardenWallInk.ellipse(center: [-8, -24], radii: [57, 23])),
            wash(head), wash(leftEar), wash(rightEar)
        ]
        let strokes: [[SIMD2<Double>]] = [
            GardenWallInk.curve([-65, -23], [-43, -65], [18, -39], samples: 24),
            GardenWallInk.curve([-60, -8], [-36, 1], [-7, -1]),
            head + [head[0]], leftEar, rightEar,
            GardenWallInk.curve([-47, -18], [-62, -35], [-20, -35]),
            GardenWallInk.curve([47, -31], [52, -26], [57, -31]),
            [[62, -26], [65, -25], [62, -23]],
            [[-25, 0], [-8, 0]], [[59, -20], [70, -19]], [[59, -17], [69, -13]]
        ]
        for (i, points) in strokes.enumerated() {
            ink.append(GardenWallInk.line(points, width: i < 6 ? 1.7 : 0.85,
                                           opacity: i < 6 ? 0.7 : 0.6, random: &random))
        }
        return ink
    }

    private static func sitting(random: inout InkRandom) -> [InkPrimitive] {
        let head = GardenWallInk.ellipse(center: [0, -100], radii: [24, 23])
        let leftEar: [SIMD2<Double>] = [[-21, -110], [-19, -142], [-5, -120]]
        let rightEar: [SIMD2<Double>] = [[5, -120], [21, -140], [22, -109]]
        var ink: [InkPrimitive] = [
            wash(GardenWallInk.ellipse(center: [0, -44], radii: [28, 44])),
            wash(head), wash(leftEar), wash(rightEar)
        ]
        let strokes: [[SIMD2<Double>]] = [
            GardenWallInk.curve([-14, -79], [-41, -25], [-20, 0], samples: 24),
            GardenWallInk.curve([14, -79], [38, -27], [20, 0], samples: 24),
            head + [head[0]], leftEar, rightEar,
            GardenWallInk.curve([24, -18], [53, 5], [44, 43])
                + GardenWallInk.curve([44, 43], [34, 76], [53, 69]).dropFirst(),
            GardenWallInk.curve([-9, -44], [-11, -21], [-9, 0]),
            GardenWallInk.curve([9, -44], [11, -21], [9, 0]),
            [[-20, 0], [-4, 0]], [[4, 0], [20, 0]],
            [[-12, -102], [-7, -102]], [[7, -102], [12, -102]],
            [[-2, -95], [0, -93], [2, -95]], [[0, -93], [0, -89]],
            [[-6, -92], [-32, -94]], [[6, -92], [32, -94]]
        ]
        for (i, points) in strokes.enumerated() {
            ink.append(GardenWallInk.line(points, width: i < 6 ? 1.7 : 0.8,
                                           opacity: i < 6 ? 0.72 : 0.55, random: &random))
        }
        return ink
    }
}
