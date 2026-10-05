@testable import BackgroundCore
import Foundation
import Testing

struct NightSkyWashTests {
    @Test(arguments: Array(UInt64(0)...UInt64(63)) + [.max])
    func fullWashDescriptionsHaveFiniteBoundsAndCanonicalReservations(seed: UInt64) {
        for index: Int64 in [.min, -9, -1, 0, 1, 9, .max] {
            let layout = NightSkyComposition(seed: seed, index: index)
            for kind in NightSkyWashKind.allCases { #expect(layout.groups.filter { $0.id.kind == kind }.count <= 4) }
            for group in layout.groups {
                #expect(!group.lobes.isEmpty)
                #expect(group.lobes.count <= (group.id.kind == .pool ? 8 : 12))
                for lobe in group.lobes {
                    #expect(lobe.radii.x > 0 && lobe.radii.y > 0)
                    #expect([lobe.color.x, lobe.color.y, lobe.color.z, lobe.opacity].allSatisfy {
                        $0.isFinite && (0...1).contains($0)
                    })
                    for i in 0..<64 {
                        let angle: Double = Double(i) * 2 * .pi / 64
                        let local: SIMD2<Double> = [lobe.radii.x * cos(angle), lobe.radii.y * sin(angle)]
                        let p = lobe.anchor + [local.x * cos(lobe.rotation) - local.y * sin(lobe.rotation),
                                               local.x * sin(lobe.rotation) + local.y * cos(lobe.rotation)]
                        #expect(p.x.isFinite && p.y.isFinite && p.y >= -1e-9 && p.y <= 800 + 1e-9)
                        #expect(group.envelope.contains(p))
                    }
                }
                if group.id.kind == .cloud {
                    for delta: Int64 in [-1, 0, 1] {
                        let other = index.addingReportingOverflow(delta)
                        if !other.overflow, let moon = NightSkyMoonLayout.placement(seed: seed, index: other.partialValue) {
                            let offset: SIMD2<Double> = [Double(delta) * 1200, 0]
                            #expect(!group.envelope.intersects(.init(min: moon.envelope.min + offset,
                                                                    max: moon.envelope.max + offset)))
                        }
                    }
                }
            }
        }
    }

    @Test func sharedWashDescriptionsAndOrderAgreeAcrossJoins() {
        var crossing: Set<NightSkyWashKind> = []
        for seed: UInt64 in 0..<64 {
            for left: Int64 in [-1, 0, Int64.min + 10, Int64.max - 11] {
                let a = NightSkyComposition(seed: seed, index: left)
                let b = NightSkyComposition(seed: seed, index: left + 1)
                let sharedA = a.groups.filter { group in b.groups.contains { $0.id == group.id } }
                let sharedB = b.groups.filter { group in a.groups.contains { $0.id == group.id } }
                #expect(sharedA.map(\.id) == sharedB.map(\.id))
                for (first, second) in zip(sharedA, sharedB) {
                    let second = second.translated(by: [1200, 0])
                    #expect(first.lobes.count == second.lobes.count)
                    if first.envelope.min.x < 1200 && first.envelope.max.x > 1200 { crossing.insert(first.id.kind) }
                    for (p, q) in zip(first.lobes, second.lobes) {
                        #expect(abs(p.anchor.x - q.anchor.x) < 1e-9 && abs(p.anchor.y - q.anchor.y) < 1e-9)
                        #expect(abs(p.radii.x - q.radii.x) < 1e-12 && abs(p.radii.y - q.radii.y) < 1e-12)
                        #expect(abs(p.rotation - q.rotation) < 1e-12 && abs(p.opacity - q.opacity) < 1e-12)
                        for c in 0..<3 { #expect(abs(p.color[c] - q.color[c]) < 1e-12) }
                    }
                }
            }
        }
        #expect(crossing == Set([.pool, .cloud]))
    }
}
