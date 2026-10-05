@testable import BackgroundCore
import Testing

struct ShanShuiCompositionTests {
    private static let seeds = (0..<128).map { UInt64($0) } + [9_999, UInt64.max - 1, UInt64.max]

    @Test
    func compositionVariesTerrainAndReachesEverySubject() {
        let plans = Self.seeds.map { ShanShuiComposition(seed: $0) }
        #expect(Set(plans.map { $0.mirrored }).count == 2)
        #expect(plans.contains { $0.boat == nil } && plans.contains { $0.boat != nil })
        #expect(plans.contains { $0.foreground.contains { $0.subject == .pavilion } })
        #expect(plans.contains { !$0.foreground.contains { $0.subject == .pavilion } })
        let subjects = Set(plans.flatMap { $0.foreground.map(\.subject) })
        #expect(subjects.isSuperset(of: [.pine, .leafyTree, .bareTree, .pavilion, .rock]))
        let treeCounts = Set(plans.map { plan in
            plan.foreground.filter { [.pine, .leafyTree, .bareTree].contains($0.subject) }.count
        })
        #expect(treeCounts.count > 1)
        let first = ShanShuiComposition(seed: 42)
        let next = ShanShuiComposition(seed: 43)
        #expect(abs(first.nearMountains[0].anchor.x - next.nearMountains[0].anchor.x) > 10)
        #expect(zip(first.shore.ridge, next.shore.ridge).contains {
            abs($0.x - $1.x) + abs($0.y - $1.y) > 10
        })
    }

    @Test(arguments: seeds)
    func foregroundSupportsStayOnLand(seed: UInt64) {
        let plan = ShanShuiComposition(seed: seed)
        for placement in plan.foreground {
            #expect(contains(placement.anchor, in: plan.shore.polygon))
            if placement.subject == .pavilion {
                // The first wash is the pavilion's actual four-corner platform.
                let study = ShanShuiElementGenerator(element: .pavilion).generate(seed: placement.seed)
                for point in study.primitives[0].points {
                    let support = placement.anchor + (point - [400, 500]) * placement.scale
                    #expect(contains(support, in: plan.shore.polygon))
                }
            }
        }
    }

    @Test(arguments: [UInt64(0), 1, 2, 3, 42, 43, 9_999, UInt64.max])
    func composedLandscapePaintsItsPlannedSubjects(seed: UInt64) {
        let plan = ShanShuiComposition(seed: seed)
        let scene = ShanShuiLandscapeGenerator().generate(seed: seed)
        for placement in plan.foreground + (plan.boat.map { [$0] } ?? []) {
            let study: [InkPrimitive]
            let origin: SIMD2<Double>
            switch placement.subject {
            case .pine:
                study = ShanShuiLandscapeElements.pine(seed: placement.seed, root: [400, 500], height: 170)
                origin = [400, 500]
            case .rock:
                study = ShanShuiLandscapeElements.rock(seed: placement.seed, center: [400, 500], width: 100, height: 60)
                origin = [400, 500]
            default:
                let element: ShanShuiElement = switch placement.subject {
                case .leafyTree: .leafyTree
                case .bareTree: .bareTree
                case .pavilion: .pavilion
                default: .boat
                }
                study = ShanShuiElementGenerator(element: element).generate(seed: placement.seed).primitives
                origin = element == .boat ? [245, 430] : [400, 500]
            }
            // Match the start and end of the actual study after an independently
            // calculated affine transform. Dropping a subject or its tail fails.
            for ink in [study.first!, study.last!] {
                let expected = ink.points.map { point in
                    let p = placement.anchor + (point - origin) * placement.scale
                    return SIMD2<Double>(plan.mirrored ? 1200 - p.x : p.x, p.y)
                }
                #expect(scene.primitives.contains { candidate in
                    candidate.points.count == expected.count
                        && abs(candidate.tone - ink.tone) < 1e-12
                        && abs(candidate.opacity - ink.opacity) < 1e-12
                        && zip(candidate.points, expected).allSatisfy {
                            abs($0.x - $1.x) < 1e-10 && abs($0.y - $1.y) < 1e-10
                        }
                })
            }
        }
    }

    @Test(arguments: [UInt64(42), 43, 60, UInt64.max])
    func nearMountainsPaintInDepthOrder(seed: UInt64) throws {
        let plan = ShanShuiComposition(seed: seed)
        let scene = ShanShuiLandscapeGenerator().generate(seed: seed)
        var painted: [(depth: Double, index: Int)] = []
        for (identity, mountain) in plan.nearMountains.enumerated() {
            let study = ShanShuiGenerator().generate(seed: mountain.seed)
            let outline = study.primitives[0].points.map { point in
                let p = mountain.anchor + (point - [400, 694]) * mountain.scale
                return SIMD2<Double>(plan.mirrored ? 1200 - p.x : p.x, p.y)
            }
            let index = try #require(scene.primitives.firstIndex { ink in
                guard case .wash = ink, ink.points.count == outline.count else { return false }
                return zip(ink.points, outline).allSatisfy {
                    abs($0.x - $1.x) < 1e-10 && abs($0.y - $1.y) < 1e-10
                }
            })
            // The first interior wash keeps its mountain's original depth style
            // even when the silhouettes exchange their painting order.
            let washTones: [Double] = [0.65, 0.713]
            let washOpacities: [Double] = [0.035, 0.0315]
            #expect(abs(scene.primitives[index + 1].tone - washTones[identity]) < 1e-12)
            #expect(abs(scene.primitives[index + 1].opacity - washOpacities[identity]) < 1e-12)
            painted.append((mountain.anchor.y, index))
        }
        let backToFront = painted.sorted { $0.depth < $1.depth }
        #expect(backToFront[0].index < backToFront[1].index)
    }

    @Test(arguments: seeds)
    func boatsHaveOpenWaterAndWavesLeaveTheirSilhouetteClear(seed: UInt64) {
        let plan = ShanShuiComposition(seed: seed)
        let boat = plan.boat.map { placement in
            ShanShuiElementGenerator(element: .boat).generate(seed: placement.seed).primitives.map { primitive in
                primitive.points.map { placement.anchor + ($0 - [245, 430]) * placement.scale }
            }.flatMap { $0 }
        } ?? []
        if let placement = plan.boat {
            #expect(placement.anchor.x > 700 && placement.anchor.y > 650)
            #expect(placement.anchor.x + 330 * placement.scale < 1160)
            #expect(boat.allSatisfy { !contains($0, in: plan.shore.polygon) })
        }
        let water = ShanShuiLandscapeElements.water(seed: seed ^ 0xAA7E4001, avoiding: boat)
        #expect(!water.isEmpty)
        for wave in water {
            #expect(wave.points.allSatisfy { !contains($0, in: plan.shore.polygon) })
            if !boat.isEmpty {
                let left = boat.map(\.x).min()! - 12
                let right = boat.map(\.x).max()! + 12
                let top = boat.map(\.y).min()! - 12
                let bottom = boat.map(\.y).max()! + 12
                let xs = wave.points.map(\.x)
                let ys = wave.points.map(\.y)
                #expect(xs.max()! < left || xs.min()! > right || ys.max()! < top || ys.min()! > bottom)
            }
        }
    }

    @Test
    func waterDensityDropsWhenBoatReservesSpace() {
        let unobstructed = ShanShuiLandscapeElements.water(seed: 42, avoiding: [])
        let occupied = ShanShuiLandscapeElements.water(seed: 42, avoiding: [[760, 640], [1090, 760]])
        // The reservation leaves less than a third of the horizontal water span.
        // Moving all 90 waves to its sides would make those patches too dense.
        #expect(occupied.count < unobstructed.count / 2)
        #expect(!occupied.isEmpty)
    }

    // Independent point-in-polygon check for the generated land support.
    private func contains(_ p: SIMD2<Double>, in polygon: [SIMD2<Double>]) -> Bool {
        var inside = false
        for index in polygon.indices {
            let a = polygon[index]
            let b = polygon[(index + 1) % polygon.count]
            if (a.y > p.y) != (b.y > p.y),
               p.x < a.x + (p.y - a.y) * (b.x - a.x) / (b.y - a.y) {
                inside.toggle()
            }
        }
        return inside
    }
}
