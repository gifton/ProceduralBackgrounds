import Foundation

/// Internal layout for one still landscape. It carries placement, not drawing
/// details; the existing studies supply the ink. No viewport or renderer state.
struct ShanShuiComposition: Sendable {
    struct Mountain: Sendable {
        let anchor: SIMD2<Double> // Center of the mountain's feet.
        let scale: Double
        let seed: UInt64
    }

    enum Subject: Hashable, Sendable {
        case pine, leafyTree, bareTree, pavilion, rock, boat
    }

    struct Placement: Sendable {
        let subject: Subject
        let anchor: SIMD2<Double> // Root, platform center, rock center or boat bow.
        let scale: Double
        let seed: UInt64
    }

    struct Shore: Sendable {
        let ridge: [SIMD2<Double>]
        let bottom: Double

        var polygon: [SIMD2<Double>] {
            ridge + [[ridge.last!.x, bottom], [ridge.first!.x, bottom]]
        }

        /// Piecewise linear surface y(x), O(R) for R ridge samples. The composer
        /// supplies x inside the ridge span; no extrapolation is required.
        func surface(at x: Double) -> Double {
            for index in 1..<ridge.count where x <= ridge[index].x {
                let a: SIMD2<Double> = ridge[index - 1]
                let b: SIMD2<Double> = ridge[index]
                let t: Double = (x - a.x) / (b.x - a.x)
                return a.y + (b.y - a.y) * t
            }
            return ridge.last!.y
        }

        /// Finds the lowest surface across a support interval, including its
        /// interior knots. A platform resting below this y stays inside the land.
        func support(at x: Double, radius: Double) -> Double {
            let interior: [Double] = ridge.filter { abs($0.x - x) < radius }.map(\.y)
            return max(surface(at: x - radius), surface(at: x + radius), interior.max() ?? 0)
        }
    }

    let mirrored: Bool
    let distantMountains: [Mountain]
    let nearMountains: [Mountain]
    let shore: Shore
    let foreground: [Placement]
    let boat: Placement?

    /// Bounded composition: five mountains, 3–5 trees, two rocks, at most one
    /// pavilion and boat. Stream separation keeps layout independent of ink
    /// sample counts. Placement constraints are exercised by
    /// `foregroundSupportsStayOnLand` and `boatsHaveOpenWaterAndWavesLeaveTheirSilhouetteClear`.
    init(seed: UInt64) {
        var terrain: InkRandom = InkRandom(state: seed ^ 0xC04F051710)
        mirrored = terrain.unit() < 0.5
        distantMountains = [
            Mountain(anchor: [205 + terrain.unit() * 30, 370 + terrain.unit() * 55],
                     scale: 0.40 + terrain.unit() * 0.10, seed: seed ^ 0xD157A000),
            Mountain(anchor: [540 + terrain.unit() * 110, 340 + terrain.unit() * 70],
                     scale: 0.39 + terrain.unit() * 0.12, seed: seed ^ 0xD157A001),
            Mountain(anchor: [990 + terrain.unit() * 35, 365 + terrain.unit() * 60],
                     scale: 0.35 + terrain.unit() * 0.09, seed: seed ^ 0xD157A002)
        ]
        nearMountains = [
            Mountain(anchor: [350 + terrain.unit() * 80, 610 + terrain.unit() * 35],
                     scale: 0.80 + terrain.unit() * 0.12, seed: seed ^ 0xF04E6001),
            Mountain(anchor: [740 + terrain.unit() * 130, 575 + terrain.unit() * 40],
                     scale: 0.48 + terrain.unit() * 0.16, seed: seed ^ 0xF04E6002)
        ]

        let left: Double = 40 + terrain.unit() * 30
        let span: Double = 430 + terrain.unit() * 90
        let height: Double = 48 + terrain.unit() * 30
        let ridge: [SIMD2<Double>] = (0...16).map { index in
            let t: Double = Double(index) / 16
            let envelope: Double = pow(max(0, sin(.pi * t)), 0.8)
            return [left + span * t, 735 - height * envelope
                    + (terrain.unit() - 0.5) * 10 * envelope]
        }
        let land: Shore = Shore(ridge: ridge, bottom: 770)
        shore = land

        var buildings: InkRandom = InkRandom(state: seed ^ 0xA4C417EC7)
        var items: [Placement] = []
        let hasPavilion: Bool = buildings.unit() < 0.65
        if hasPavilion {
            let scale: Double = 0.32 + buildings.unit() * 0.08
            let x: Double = left + span * (0.72 + buildings.unit() * 0.05)
            let y: Double = land.support(at: x, radius: 135 * scale) + 8
            items.append(Placement(subject: .pavilion, anchor: [x, y], scale: scale,
                                   seed: seed ^ 0xA4C40001))
        }

        var trees: InkRandom = InkRandom(state: seed ^ 0x741EE001)
        let count: Int = 3 + Int(trees.unit() * 3)
        for index in 0..<count {
            // Cluster roots on one side of a building; otherwise leave a gap
            // between two groves. Canopies may overlap within a grove.
            let t: Double = hasPavilion
                ? 0.18 + Double(index) * 0.075 + trees.unit() * 0.025
                : (index < 3 ? 0.18 + Double(index) * 0.07 : 0.68 + Double(index - 3) * 0.08)
                    + trees.unit() * 0.03
            let x: Double = left + span * t
            let subject: Subject = [Subject.pine, .leafyTree, .bareTree][Int(trees.unit() * 3)]
            let requestedScale: Double = switch subject {
            case .pine: 0.75 + trees.unit() * 0.25
            case .leafyTree: 0.36 + trees.unit() * 0.16
            default: 0.44 + trees.unit() * 0.16
            }
            // Canonical bare-tree reach is below 280: |lean| ≤ 39.2,
            // four shrinking segments total ≤ 64(1 + .9 + .9² + .9³) = 220.096,
            // bend ≤ 2, with room for trunk edges and capped stroke joins.
            // Fit before drawing; reflection has the same two horizontal margins.
            // `placedBareTreesFitIncludingStrokeJoins` exercises both directions.
            let scale: Double = subject == .bareTree
                ? min(requestedScale, (x - 12) / 280, (1188 - x) / 280)
                : requestedScale
            let y: Double = land.support(at: x, radius: 5) + 8 + trees.unit() * 8
            items.append(Placement(subject: subject, anchor: [x, y], scale: scale,
                                   seed: seed ^ (0x741EE100 &+ UInt64(index))))
        }

        var rocks: InkRandom = InkRandom(state: seed ^ 0x40CC0001)
        for index in 0..<2 {
            let scale: Double = 0.55 + rocks.unit() * 0.35
            let x: Double = left + span * (0.3 + Double(index) * 0.24 + rocks.unit() * 0.08)
            let y: Double = land.support(at: x, radius: 50 * scale) + 12
            items.append(Placement(subject: .rock, anchor: [x, y], scale: scale,
                                   seed: seed ^ (0x40CC0100 &+ UInt64(index))))
        }
        // Frontmost support is painted last. Tie-breaking uses insertion order.
        foreground = items.enumerated().sorted {
            if $0.element.anchor.y < $1.element.anchor.y { return true }
            if $1.element.anchor.y < $0.element.anchor.y { return false }
            return $0.offset < $1.offset
        }.map(\.element)

        var boats: InkRandom = InkRandom(state: seed ^ 0xB0A70001)
        if boats.unit() < 0.8 {
            boat = Placement(subject: .boat,
                             anchor: [790 + boats.unit() * 100, 680 + boats.unit() * 25],
                             scale: (145 + boats.unit() * 40) / 330,
                             seed: seed ^ 0xB0A70100)
        } else {
            boat = nil
        }
    }
}
