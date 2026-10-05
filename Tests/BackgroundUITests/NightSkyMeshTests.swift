@testable import BackgroundCore
@testable import BackgroundUI
import Testing

struct NightSkyMeshTests {
    @Test(arguments: Array(UInt64(0)...UInt64(31)) + [42, 43, .max],
          [Int64.min, -9, -1, 0, 1, 9, .max])
    func wholeSkyCompilesToFiniteBoundedTriangles(seed: UInt64, index: Int64) throws {
        let chunk = NightSkyChunkGenerator().generate(seed: seed, index: index)
        let mesh = try InkMeshCompiler().compile(chunk.scene, clippingToBounds: true)
        #expect(!mesh.vertices.isEmpty && mesh.vertices.count.isMultiple(of: 3))
        #expect(mesh.vertices.allSatisfy {
            $0.position.x.isFinite && $0.position.y.isFinite
                && $0.position.x >= -1e-5 && $0.position.x <= 1200 + 1e-5
                && $0.position.y >= -1e-5 && $0.position.y <= 800 + 1e-5
                && [$0.color.x, $0.color.y, $0.color.z, $0.color.w].allSatisfy { $0.isFinite && (0...1).contains($0) }
        })
    }

    @Test func crescentMeshLeavesItsOpeningClear() throws {
        let moon = try #require(NightSkyComposition(seed: 42, index: 0).moon)
        let scene = InkScene(seed: 42, bounds: [1200, 800], primitives: [
            .colorWash(points: NightSkyMoonInk.silhouette(moon), color: [1, 1, 1], opacity: 1)
        ])
        let mesh = try InkMeshCompiler().compile(scene)
        for local: SIMD2<Double> in [[-0.75, 0], [-0.7, 0.15], [-0.7, -0.15]] {
            #expect(covered(moon.anchor + local * moon.radius, by: mesh))
        }
        for local: SIMD2<Double> in [[0.35, 0], [0, 0], [0.6, 0.2]] {
            #expect(!covered(moon.anchor + local * moon.radius, by: mesh))
        }
        for i in stride(from: 0, to: mesh.vertices.count, by: 3) {
            let p = mesh.vertices[i].position, q = mesh.vertices[i+1].position, r = mesh.vertices[i+2].position
            #expect(abs((q.x-p.x)*(r.y-p.y)-(q.y-p.y)*(r.x-p.x)) > 1e-8)
        }
    }

    @Test(arguments: Array(UInt64(0)...UInt64(63)))
    func allMoonAndStarInkFitsReservedEnvelopes(seed: UInt64) throws {
        let layout = NightSkyComposition(seed: seed, index: 0)
        let moon = try #require(layout.moon)
        #expect(NightSkyMoonInk.draw(moon).flatMap(\.points).allSatisfy { moon.envelope.contains($0) })
        for star in layout.stars {
            let bounds = NightSkyBounds(min: star.anchor - SIMD2(repeating: star.radius),
                                        max: star.anchor + SIMD2(repeating: star.radius))
            #expect(NightSkyInk.star(star).flatMap(\.points).allSatisfy { bounds.contains($0) })
        }
    }

    private func covered(_ p: SIMD2<Double>, by mesh: InkMesh) -> Bool {
        for i in stride(from: 0, to: mesh.vertices.count, by: 3) {
            let a = SIMD2<Double>(mesh.vertices[i].position)
            let b = SIMD2<Double>(mesh.vertices[i+1].position)
            let c = SIMD2<Double>(mesh.vertices[i+2].position)
            let edges = [(a, b), (b, c), (c, a)].map { start, end in
                (end.x-start.x)*(p.y-start.y)-(end.y-start.y)*(p.x-start.x)
            }
            if edges.allSatisfy({ $0 >= -1e-5 }) || edges.allSatisfy({ $0 <= 1e-5 }) { return true }
        }
        return false
    }
}
