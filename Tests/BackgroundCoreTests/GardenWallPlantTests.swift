@testable import BackgroundCore
import Testing

struct GardenWallPlantTests {
    @Test
    func hangingPlantsDrawFullClumpsWithVaryingSprayCounts() {
        var counts: Set<Int> = []
        for seed: UInt64 in 0..<128 {
            let plant = placement(seed: seed)
            let ink = GardenWallPlantElements.draw(plant)
            // Each hanging spray has a long spine; the shorter twig and vein
            // runs are excluded so leaf density alone cannot stand in for a clump.
            let spines: [[SIMD2<Double>]] = ink.compactMap {
                guard case let .colorStroke(points, _, color, opacity) = $0,
                      abs(color.x - GardenWallPalette.sage.x) < 1e-12,
                      abs(color.y - GardenWallPalette.sage.y) < 1e-12,
                      abs(color.z - GardenWallPalette.sage.z) < 1e-12,
                      abs(opacity - 0.6) < 1e-12,
                      points.count > 20 else { return nil }
                return points
            }
            #expect((4...8).contains(spines.count))
            counts.insert(spines.count)
            let leaves = ink.filter { if case .colorWash = $0 { true } else { false } }
            #expect(leaves.count >= 48)
            #expect(spines.allSatisfy { $0.last!.y - $0.first!.y > 150 })
            let roots: [Double] = spines.map { $0.first!.x }
            for (index, root) in roots.enumerated() {
                #expect(roots.dropFirst(index + 1).allSatisfy { abs($0 - root) > 1e-6 })
            }
        }
        #expect(counts == Set(4...8))
    }

    @Test(arguments: Array(UInt64(0)...UInt64(127)) + [.max])
    func hangingClumpsFitTheExistingReservedEnvelope(seed: UInt64) {
        let plant = placement(seed: seed)
        let ink = GardenWallPlantElements.draw(plant)
        #expect(!ink.isEmpty)
        #expect(ink.flatMap(\.points).allSatisfy {
            $0.x.isFinite && $0.y.isFinite && plant.envelope.contains($0, padding: 2)
        })
    }

    private func placement(seed: UInt64) -> GardenWallPlantPlacement {
        .init(kind: .ivy, anchor: .zero, scale: 1, seed: seed,
              envelope: .init(min: [-132, -30], max: [132, 226]))
    }
}
