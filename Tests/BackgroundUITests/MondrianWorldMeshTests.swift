@testable import BackgroundCore
@testable import BackgroundUI
import Testing

struct MondrianWorldMeshTests {
    @Test(arguments: Array(UInt64(0)...UInt64(31)) + [42, 43, .max],
          [Int64.min, .min + 1, -9, -3, -1, 0, 1, 3, 9, .max - 1, .max])
    func fullWorldInkCompilesToClippedBoundedTriangles(seed: UInt64, index: Int64) throws {
        let chunk = try MondrianChunkGenerator().generate(seed: seed, index: index)
        let mesh = try InkMeshCompiler().compile(chunk.scene, clippingToBounds: true)
        #expect(!mesh.vertices.isEmpty && mesh.vertices.count.isMultiple(of: 3))
        #expect(mesh.vertices.count <= 595_440)
        #expect(mesh.vertices.allSatisfy { vertex in
            vertex.position.x.isFinite && vertex.position.y.isFinite
                && vertex.position.x >= -1e-4 && vertex.position.x <= 1200 + 1e-4
                && vertex.position.y >= -1e-4 && vertex.position.y <= 800 + 1e-4
                && (0..<4).allSatisfy { channel in
                    vertex.color[channel].isFinite && (0...1).contains(vertex.color[channel])
                }
        })
    }
}
