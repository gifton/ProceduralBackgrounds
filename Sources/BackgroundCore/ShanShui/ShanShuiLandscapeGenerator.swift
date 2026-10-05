/// A seeded still landscape composed with the original mountain treatment.
public struct ShanShuiLandscapeGenerator: BackgroundGenerator {
    public init() {}

    /// Composes a 1200 × 800 landscape in painter order, from distant ink to shore.
    /// - Complexity: O(M × P + E) time/space, M = five mountains, P = mountain
    ///   samples, E = samples in water, shore and the bounded foreground population.
    /// - Note: Components use separate seed streams. Replay and coordinate bounds
    ///   are tested by `landscapeReplayPreservesAllInk` and
    ///   `landscapeGeometryStaysWithinWorld`.
    public func generate(seed: UInt64) -> ShanShuiScene {
        let layout: ShanShuiComposition = ShanShuiComposition(seed: seed)
        var primitives: [InkPrimitive] = []
        for placement in layout.distantMountains {
            primitives += mountain(placement, contrast: 0.42, inkOpacity: 0.55, distant: true)
        }
        // Overlapping white washes fade only the distant layer into the paper.
        // Near mountains and shore are appended after this mist.
        for band in 0..<25 {
            let y: Double = 280 + Double(band) * 8
            primitives.append(.wash(points: [[0, y], [1200, y], [1200, 800], [0, 800]],
                                    tone: 1, opacity: 0.08 + Double(band) * 0.008))
        }
        // Preserve each mountain's ink strength while painting farther feet
        // first. See `nearMountainsPaintInDepthOrder` for overlapping seed 60.
        let near: [(offset: Int, element: ShanShuiComposition.Mountain)] = layout.nearMountains.enumerated().sorted {
            if $0.element.anchor.y < $1.element.anchor.y { return true }
            if $1.element.anchor.y < $0.element.anchor.y { return false }
            return $0.offset < $1.offset
        }
        for (index, placement) in near {
            primitives += mountain(placement, contrast: index == 0 ? 1 : 0.82,
                                   inkOpacity: index == 0 ? 1 : 0.9, distant: false)
        }

        let boat: [InkPrimitive] = layout.boat.map { ink(for: $0) } ?? []
        primitives += ShanShuiLandscapeElements.water(seed: seed ^ 0xAA7E4001,
                                                      avoiding: boat.flatMap(\.points))
        primitives += boat
        primitives += ShanShuiLandscapeElements.shore(seed: seed ^ 0x5A04E001, land: layout.shore)
        for placement in layout.foreground { primitives += ink(for: placement) }

        if layout.mirrored {
            primitives = primitives.map { primitive in
                primitive.mapGeometry { [1200 - $0.x, $0.y] }
            }
        }

        return ShanShuiScene(seed: seed, bounds: [1200, 800], primitives: primitives)
    }

    /// Applies p′ = anchor + scale × (p − [400, 694]) and w′ = scale × w,
    /// preserving contours/taper. Depth changes grayscale/opacity only.
    private func mountain(_ placement: ShanShuiComposition.Mountain,
                          contrast: Double, inkOpacity: Double, distant: Bool) -> [InkPrimitive] {
        let study: ShanShuiScene = ShanShuiGenerator().generate(seed: placement.seed)
        return study.primitives.enumerated().map { index, primitive in
            let points: [SIMD2<Double>] = primitive.points.map {
                placement.anchor + ($0 - [400, 694]) * placement.scale
            }
            let tone: Double = 1 - (1 - primitive.tone) * contrast
            switch primitive {
            case .wash:
                if index == 0 {
                    // Near white silhouettes occlude the distant forms. Far washes
                    // give the background mountains a faint, continuous mass.
                    return .wash(points: points, tone: distant ? 0.91 : 1,
                                 opacity: distant ? 0.65 : 1)
                }
                return .wash(points: points, tone: tone, opacity: primitive.opacity * inkOpacity)
            case let .stroke(_, widths, _, _):
                return .stroke(points: points, widths: widths.map { $0 * placement.scale },
                               tone: tone, opacity: primitive.opacity * inkOpacity)
            case .colorWash:
                if index == 0 {
                    return .wash(points: points, tone: distant ? 0.91 : 1,
                                 opacity: distant ? 0.65 : 1)
                }
                let color = SIMD3<Double>(repeating: 1) - (SIMD3<Double>(repeating: 1) - primitive.color) * contrast
                return .colorWash(points: points, color: color, opacity: primitive.opacity * inkOpacity)
            case let .colorStroke(_, widths, color, _):
                let shaded = SIMD3<Double>(repeating: 1) - (SIMD3<Double>(repeating: 1) - color) * contrast
                return .colorStroke(points: points, widths: widths.map { $0 * placement.scale },
                                    color: shaded, opacity: primitive.opacity * inkOpacity)
            }
        }
    }

    /// Uses canonical study sizes so branch lengths, roof details and figure
    /// proportions all scale together. No drawing helper consumes layout state.
    private func ink(for placement: ShanShuiComposition.Placement) -> [InkPrimitive] {
        let source: [InkPrimitive]
        let origin: SIMD2<Double> = placement.subject == .boat ? [245, 430] : [400, 500]
        switch placement.subject {
        case .pine:
            source = ShanShuiLandscapeElements.pine(seed: placement.seed, root: [400, 500], height: 170)
        case .rock:
            source = ShanShuiLandscapeElements.rock(seed: placement.seed, center: [400, 500], width: 100, height: 60)
        case .leafyTree:
            source = ShanShuiElementGenerator(element: .leafyTree).generate(seed: placement.seed).primitives
        case .bareTree:
            source = ShanShuiElementGenerator(element: .bareTree).generate(seed: placement.seed).primitives
        case .pavilion:
            source = ShanShuiElementGenerator(element: .pavilion).generate(seed: placement.seed).primitives
        case .boat:
            source = ShanShuiElementGenerator(element: .boat).generate(seed: placement.seed).primitives
        }
        return source.map { primitive in
            primitive.mapGeometry({ placement.anchor + ($0 - origin) * placement.scale },
                                  widthScale: placement.scale)
        }
    }
}
