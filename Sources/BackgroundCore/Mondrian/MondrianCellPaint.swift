import Foundation

enum MondrianPaintStyle: Sendable { case restrained, layered }

enum MondrianCellPaint {
    /// Bounded convex washes in cell coordinates. paintingReplaysWithFiniteBoundedInk
    /// exercises cell envelopes and caps; pigmentStyleChangesActualPaintWithoutMovingLayoutOrDividers
    /// checks independence from the composition and divider streams.
    static func draw(_ cell: MondrianCell, seed: UInt64,
                     style: MondrianPaintStyle = .layered) -> [InkPrimitive] {
        guard cell.color != .white else { return [] }
        var random = InkRandom(state: MondrianSeeds.component(world: seed, identity: cell.id,
                                                              tag: MondrianSeeds.paint))
        let a: SIMD2<Double> = SIMD2<Double>(cell.rect.min)
        let b: SIMD2<Double> = SIMD2<Double>(cell.rect.max)
        let size: SIMD2<Double> = b - a
        let center: SIMD2<Double> = (a + b) * 0.5
        let outline: [SIMD2<Double>] = [a, [b.x, a.y], b, [a.x, b.y]]
        var ink: [InkPrimitive] = [.colorWash(points: outline, color: cell.color.rgb,
                                             opacity: cell.color == .black ? 0.94 : 0.84)]
        for i in 0..<4 {
            let start = outline[i], end = outline[(i + 1) % 4]
            let delta: SIMD2<Double> = end - start
            let length: Double = sqrt(delta.x * delta.x + delta.y * delta.y)
            let normal: SIMD2<Double> = [-delta.y / length, delta.x / length]
            let w0: Double = min(size.x, size.y) * (0.012 + random.unit() * 0.025)
            let w1: Double = min(size.x, size.y) * (0.012 + random.unit() * 0.025)
            let band: [SIMD2<Double>] = [start, end, end + normal * w1, start + normal * w0]
            ink.append(.colorWash(points: clip(band, to: cell.rect), color: cell.color.rgb,
                                  opacity: 0.04 + random.unit() * 0.04))
        }
        let poolCount: Int = style == .layered ? 2 : 1
        for _ in 0..<poolCount {
            var patchCenter: SIMD2<Double> = center + [
                (random.unit() - 0.5) * size.x * 0.6, (random.unit() - 0.5) * size.y * 0.6
            ]
            let side: Int = Int(random.unit() * 4)
            let axis: Int = side % 2
            patchCenter[axis] = side < 2 ? a[axis] - size[axis] * 0.28 : b[axis] + size[axis] * 0.28
            let radius: SIMD2<Double> = [size.x * (0.65 + random.unit() * 0.2),
                                        size.y * (0.65 + random.unit() * 0.2)]
            // Centers outside the cell leave broad deposits rather than closed oval stamps.
            let color: SIMD3<Double> = cell.color == .black ? [0.16, 0.16, 0.17] : SIMD3(repeating: 1)
            // Four low-opacity layers feather each pool within the existing eight-piece
            // budget. interiorPigmentHasNoAbruptHighContrastSteps checks rendered transitions.
            for layer in 0..<4 {
                let scale: Double = 1 - Double(layer) * 0.13
                let polygon: [SIMD2<Double>] = (0..<24).map { sample in
                    let angle: Double = Double(sample) * 2 * .pi / 24
                    let p: SIMD2<Double> = [cos(angle) * radius.x * scale, sin(angle) * radius.y * scale]
                    return patchCenter + p
                }
                let points = clip(polygon, to: cell.rect)
                if points.count >= 3 {
                    ink.append(.colorWash(points: points, color: color,
                                          opacity: 0.015 + Double(layer) * 0.004))
                }
            }
        }
        return ink
    }

    /// Caller contract: a convex polygon with finite coordinates and positive cell
    /// dimensions. clippingCrossesEveryCellSideAndRejectsOutsidePolygons exercises
    /// four-sided clipping and complete rejection. Four half-plane passes are O(V).
    static func clip(_ polygon: [SIMD2<Double>], to rect: MondrianRect) -> [SIMD2<Double>] {
        var points = polygon
        let planes: [(Int, Double, Bool)] = [
            (0, Double(rect.min.x), true), (0, Double(rect.max.x), false),
            (1, Double(rect.min.y), true), (1, Double(rect.max.y), false)
        ]
        for (axis, boundary, greater) in planes {
            guard var previous = points.last else { return [] }
            var result: [SIMD2<Double>] = []
            var wasInside: Bool = greater ? previous[axis] >= boundary : previous[axis] <= boundary
            for current in points {
                let inside: Bool = greater ? current[axis] >= boundary : current[axis] <= boundary
                if inside != wasInside {
                    let t: Double = (boundary - previous[axis]) / (current[axis] - previous[axis])
                    var crossing: SIMD2<Double> = previous + (current - previous) * t
                    crossing[axis] = boundary
                    result.append(crossing)
                }
                if inside { result.append(current) }
                previous = current
                wasInside = inside
            }
            points = result
        }
        return points
    }
}
