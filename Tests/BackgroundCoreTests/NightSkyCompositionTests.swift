@testable import BackgroundCore
import Testing

struct NightSkyCompositionTests {
    @Test func initialMoonsAndSparseRegionsHaveClearSpacing() throws {
        #expect(try #require(NightSkyComposition(seed: 42, index: 0).moon).phase == .crescent)
        #expect(try #require(NightSkyComposition(seed: 43, index: 0).moon).phase == .rounded)
        var phases: Set<NightSkyMoonPhase> = []
        for seed: UInt64 in 0..<64 {
            let occupied = (Int64(-64)...Int64(64)).filter {
                if let moon = NightSkyMoonLayout.placement(seed: seed, index: $0) {
                    phases.insert(moon.phase); return true
                }
                return false
            }
            #expect(occupied.contains(0) && occupied.count < 20)
            for (a, b) in zip(occupied, occupied.dropFirst()) { #expect(b - a >= 5) }
            for origin: Int64 in stride(from: -64, through: 56, by: 8) {
                #expect(occupied.filter { $0 >= origin && $0 < origin + 8 }.count <= 1)
            }
            for origin: Int64 in [Int64.min, Int64.min + 8, Int64.max - 15, Int64.max - 7] {
                let moons = (0..<8).compactMap { step in
                    NightSkyMoonLayout.placement(seed: seed, index: origin + Int64(step))
                }
                #expect(moons.count <= 1)
            }
        }
        #expect(phases.count == 2)
    }

    @Test(arguments: Array(UInt64(0)...UInt64(63)) + [.max])
    func starAndMoonEnvelopesStayBounded(seed: UInt64) throws {
        let scene = NightSkyBounds(min: [0, 0], max: [1200, 800])
        for index: Int64 in [.min, -17, -9, -8, -1, 0, 1, 7, 8, 17, .max] {
            let layout = NightSkyComposition(seed: seed, index: index)
            #expect(layout.stars.filter { !$0.isAccent }.count <= 96)
            #expect(layout.stars.filter(\.isAccent).count <= 6)
            if index == 0 { #expect(layout.moon != nil) }
            if let moon = layout.moon {
                #expect(scene.contains(moon.envelope.min) && scene.contains(moon.envelope.max))
                #expect(moon.radius >= 45 && moon.radius <= 65)
                if index == 0 { #expect((560...640).contains(moon.anchor.x)) }
            }
            for star in layout.stars {
                let low = star.anchor - SIMD2(repeating: star.radius)
                let high = star.anchor + SIMD2(repeating: star.radius)
                #expect(scene.contains(low) && scene.contains(high))
                #expect(star.radius.isFinite && star.radius > 0 && star.radius <= 6)
                if let moon = layout.moon {
                    #expect(!NightSkyBounds(min: low, max: high).intersects(moon.envelope))
                }
            }
        }
    }

    @Test func starCountsVaryAcrossSeeds() {
        let counts = Set((UInt64(0)..<64).map { NightSkyComposition(seed: $0, index: 0).stars.count })
        #expect(counts.count > 5)
    }
}
