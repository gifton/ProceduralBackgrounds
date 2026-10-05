import BackgroundCore
@testable import BackgroundUI
import Metal
import Testing

@MainActor
struct ShanShuiWorldRenderingTests {
    @Test
    func cameraTranslationReusesBuffersAndRejectsMissingChunks() throws {
        let renderer = try makeRenderer()
        let viewport = try ShanShuiScrollViewport(size: [1200, 800])
        let camera = try ShanShuiCamera()
        let mark: InkPrimitive = .wash(points: [[280, 380], [320, 380], [320, 420], [280, 420]],
                                       tone: 0, opacity: 1)
        let chunks = try (-1...1).map { try fixture(index: Int64($0), ink: $0 == 0 ? [mark] : []) }
        try renderer.installWorld(seed: 42, chunks: chunks, camera: camera, viewport: viewport)
        let identity = try #require(renderer.worldBufferIdentity(for: 0))
        let before = try frame(renderer, width: 240, height: 160)
        #expect(try renderer.updateWorldCamera(camera.moving(by: 100), viewport: viewport))
        let after = try frame(renderer, width: 240, height: 160)
        #expect(renderer.worldBufferIdentity(for: 0) == identity)
        #expect(before[80 * 240 + 60].z < 10)
        #expect(after[80 * 240 + 40].z < 10)
        #expect(after[80 * 240 + 60].z > 220)
        #expect(try !renderer.updateWorldCamera(ShanShuiCamera(index: 10), viewport: viewport))
        #expect(try frame(renderer, width: 240, height: 160) == after)
        let overlapping = try (0...2).map { try fixture(index: Int64($0), ink: $0 == 0 ? [mark] : []) }
        try renderer.installWorld(seed: 42, chunks: overlapping,
                                  camera: camera.moving(by: 100), viewport: viewport)
        #expect(renderer.worldBufferIdentity(for: 0) == identity)
        let empty = ShanShuiScene(seed: 42, bounds: [800, 800], primitives: [])
        try renderer.install(empty, mesh: InkMeshCompiler().compile(empty))
        #expect(renderer.worldBufferIdentity(for: 0) == nil)
        #expect(try frame(renderer, width: 240, height: 160)[80 * 240 + 40].z > 220)
        try renderer.installWorld(seed: 42, chunks: chunks, camera: camera, viewport: viewport)
        #expect(try frame(renderer, width: 240, height: 160)[80 * 240 + 60].z < 10)
    }

    @Test
    func adjacentBandsMeetAtBothDirectionsAndLargeIndices() throws {
        let band: InkPrimitive = .wash(points: [[0, 360], [1200, 360], [1200, 440], [0, 440]],
                                       tone: 0, opacity: 1)
        let viewport = try ShanShuiScrollViewport(size: [1200, 800])
        for index: Int64 in [0, Int64.min + 10, Int64.max - 10] {
            let renderer = try makeRenderer()
            let chunks = try (-2...2).map { try fixture(index: index + Int64($0), ink: [band]) }
            for offset in [1199.99, 1200.0, 1200.01, 0.01, -0.01] {
                let camera = try ShanShuiCamera(index: index, offset: 0).moving(by: offset)
                try renderer.installWorld(seed: 42, chunks: chunks, camera: camera, viewport: viewport)
                let pixels = try frame(renderer, width: 241, height: 160)
                #expect((5..<236).allSatisfy { pixels[80 * 241 + $0].z < 10 })
            }
        }
    }

    @Test
    func paperIsStableAndResizeMarginsNeverDrawUnpreparedInk() throws {
        let renderer = try makeRenderer()
        let empty = try (-3...3).map { try fixture(index: Int64($0), ink: []) }
        let viewport = try ShanShuiScrollViewport(size: [2400, 800])
        try renderer.installWorld(seed: 42, chunks: empty, camera: ShanShuiCamera(), viewport: viewport)
        let paper = try frame(renderer, width: 240, height: 160)
        #expect(try renderer.updateWorldCamera(ShanShuiCamera(index: 1, offset: 10), viewport: viewport))
        #expect(try frame(renderer, width: 240, height: 160) == paper)

        let band: InkPrimitive = .wash(points: [[0, 360], [1200, 360], [1200, 440], [0, 440]],
                                       tone: 0, opacity: 1)
        let chunks = try (-3...3).map { try fixture(index: Int64($0), ink: [band]) }
        let resizedRenderer = try makeRenderer()
        for size: SIMD2<Int> in [[240, 160], [120, 240], [240, 160], [2000, 100]] {
            let viewport = try ShanShuiScrollViewport(size: SIMD2<Double>(size))
            try resizedRenderer.installWorld(seed: 42, chunks: chunks, camera: ShanShuiCamera(), viewport: viewport)
            let pixels = try frame(resizedRenderer, width: size.x, height: size.y)
            #expect(pixels[(size.y / 2) * size.x + size.x / 2].z < 10)
            #expect(pixels.allSatisfy { $0.w == 255 })
            if size.x > 1000 {
                #expect(pixels[50 * size.x + 650].z > 220)
                #expect(pixels[50 * size.x + 1350].z > 220)
            }
        }
        // Keep the accepted narrow span on a wider drawable until its window installs.
        try resizedRenderer.installWorld(seed: 42, chunks: [fixture(index: 0, ink: [band])],
                                  camera: ShanShuiCamera(),
                                  viewport: ShanShuiScrollViewport(size: [1200, 800]))
        let widening = try frame(resizedRenderer, width: 480, height: 160)
        #expect(widening[80 * 480 + 100].z > 220)
        #expect(widening[80 * 480 + 240].z < 10)
    }

    @Test
    func generatedWorldDrawsInkAcrossResize() async throws {
        let renderer = try makeRenderer()
        let builder = ShanShuiChunkBuilder()
        let chunks = try await builder.prepare(seed: 42, indices: [-3, -2, -1, 0, 1, 2, 3])
        for size: SIMD2<Int> in [[256, 128], [128, 256], [256, 128]] {
            try renderer.installWorld(seed: 42, chunks: chunks, camera: ShanShuiCamera(),
                                      viewport: ShanShuiScrollViewport(size: SIMD2<Double>(size)))
            let pixels = try frame(renderer, width: size.x, height: size.y)
            #expect(pixels.filter { $0.z < 200 }.count > 35)
        }
    }

    private func makeRenderer() throws -> ShanShuiRenderer {
        try ShanShuiRenderer(device: #require(MTLCreateSystemDefaultDevice()))
    }

    private func fixture(index: Int64, ink: [InkPrimitive]) throws -> ShanShuiPreparedChunk {
        let scene = ShanShuiScene(seed: 42, bounds: [1200, 800], primitives: ink)
        return ShanShuiPreparedChunk(chunk: .init(index: index, scene: scene),
                                    mesh: try InkMeshCompiler().compile(scene))
    }

    private func frame(_ renderer: ShanShuiRenderer, width: Int, height: Int) throws -> [SIMD4<UInt8>] {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = [.renderTarget, .shaderRead]
        let output = try #require(renderer.device.makeTexture(descriptor: descriptor))
        let command = try renderer.encodeFrame(into: output)
        command.commit()
        command.waitUntilCompleted()
        #expect(command.status == .completed)
        var pixels = [SIMD4<UInt8>](repeating: .zero, count: width * height)
        pixels.withUnsafeMutableBytes {
            output.getBytes($0.baseAddress!, bytesPerRow: width * 4,
                            from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        return pixels
    }
}
