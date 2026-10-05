import BackgroundCore
@testable import BackgroundUI
import Testing

struct GardenWallMeshTests {
    @Test(arguments: Array(UInt64(0)...UInt64(15)) + [.max], [Int64.min, -2, 0, 2, .max])
    func wholeGardenCompilesToFiniteBoundedTriangles(seed: UInt64, index: Int64) throws {
        let scene = GardenWallChunkGenerator().generate(seed: seed, index: index).scene
        let mesh = try InkMeshCompiler().compile(scene, clippingToBounds: true)
        #expect(mesh.vertices.count > 100 && mesh.vertices.count.isMultiple(of: 3))
        #expect(mesh.vertices.allSatisfy {
            $0.position.x.isFinite && $0.position.y.isFinite
                && (-1e-5...1200.00001).contains($0.position.x)
                && (-1e-5...800.00001).contains($0.position.y)
        })
    }
}
