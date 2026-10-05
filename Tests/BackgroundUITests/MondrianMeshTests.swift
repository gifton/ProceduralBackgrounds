@testable import BackgroundCore
@testable import BackgroundUI
import Testing

struct MondrianMeshTests {
    @Test(arguments: Array(UInt64(0)...UInt64(63)) + [.max], [MondrianPaintStyle.restrained, .layered])
    func completePaintingCompilesWithClippedExpandedGeometry(seed: UInt64, style: MondrianPaintStyle) throws {
        let scene = MondrianGenerator(paintStyle: style).generate(seed: seed)
        let mesh = try InkMeshCompiler().compile(scene, clippingToBounds: true)
        #expect(!mesh.vertices.isEmpty)
        for vertex in mesh.vertices {
            #expect(vertex.position.x.isFinite && vertex.position.y.isFinite)
            #expect(vertex.position.x >= -1e-4 && vertex.position.x <= 1200 + 1e-4)
            #expect(vertex.position.y >= -1e-4 && vertex.position.y <= 800 + 1e-4)
            #expect((0..<4).allSatisfy { vertex.color[$0].isFinite && (0...1).contains(vertex.color[$0]) })
        }
    }
}
