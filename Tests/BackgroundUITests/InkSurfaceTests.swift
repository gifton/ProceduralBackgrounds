import BackgroundCore
@testable import BackgroundUI
import Metal
import Testing

@MainActor
struct InkSurfaceTests {
    private let blue: SIMD3<Double> = [0.115, 0.15, 0.27]

    @Test func darkSurfaceCoversMarginsAndStaticInstallationRestoresWhite() throws {
        let renderer = try makeRenderer()
        let chunks = try emptyChunks()
        for size: SIMD2<Int> in [[240, 160], [160, 320], [1024, 128], [240, 160]] {
            let viewport = try ShanShuiScrollViewport(size: SIMD2<Double>(size))
            try renderer.installWorld(seed: 42, chunks: chunks, camera: ShanShuiCamera(),
                                      viewport: viewport, sourceID: "darkFixture", surfaceColor: blue)
            expectDark(try readInkFrame(renderer, width: size.x, height: size.y))
            let scene = InkScene(seed: 42, bounds: [1200, 800], primitives: [])
            try renderer.install(scene, mesh: InkMeshCompiler().compile(scene))
            expectLight(try readInkFrame(renderer, width: size.x, height: size.y))
            try renderer.installWorld(seed: 42, chunks: chunks, camera: ShanShuiCamera(),
                                      viewport: viewport, sourceID: "lightFixture")
            expectLight(try readInkFrame(renderer, width: size.x, height: size.y))
        }
    }

    @Test(arguments: [0, 1, 2], [Double(-0.1), 1.1, .nan, .infinity, -.infinity])
    func invalidSurfaceLeavesInstalledWorldUntouched(channel: Int, value: Double) throws {
        let renderer = try makeRenderer()
        let chunks = try emptyChunks(withMark: true)
        let camera = try ShanShuiCamera()
        let viewport = try ShanShuiScrollViewport(size: [240, 160])
        try renderer.installWorld(seed: 42, chunks: chunks, camera: camera,
                                  viewport: viewport, sourceID: "darkFixture", surfaceColor: blue)
        let identity = try #require(renderer.worldBufferIdentity(for: 0))
        let before = try readInkFrame(renderer, width: 240, height: 160)
        var invalid = blue
        invalid[channel] = value
        #expect(throws: ShanShuiRenderError.invalidSurfaceColor) {
            try renderer.installWorld(seed: 43, chunks: chunks, camera: camera,
                                      viewport: viewport, sourceID: "bad", surfaceColor: invalid)
        }
        #expect(renderer.worldBufferIdentity(for: 0) == identity)
        #expect(try readInkFrame(renderer, width: 240, height: 160) == before)
    }

    @Test func failedWindowInstallationPreservesSurfaceAndGeometry() throws {
        let renderer = try makeRenderer()
        let chunks = try emptyChunks()
        let viewport = try ShanShuiScrollViewport(size: [240, 160])
        try renderer.installWorld(seed: 42, chunks: chunks, camera: ShanShuiCamera(),
                                  viewport: viewport, sourceID: "darkFixture", surfaceColor: blue)
        let before = try readInkFrame(renderer, width: 240, height: 160)
        #expect(throws: ShanShuiWorldError.invalidWindow) {
            try renderer.installWorld(seed: 43, chunks: [chunks[0], chunks[2]],
                                      camera: ShanShuiCamera(), viewport: viewport,
                                      sourceID: "bad", surfaceColor: [0.8, 0.2, 0.1])
        }
        #expect(try readInkFrame(renderer, width: 240, height: 160) == before)
    }

    @Test func modelForwardsItsSurfaceAndFailureRetainsLastFrame() async throws {
        let worker = SuspendedChunkPreparer(makeChunk: { seed, index in
            let scene = InkScene(seed: seed, bounds: [1200, 800], primitives: [])
            return ShanShuiPreparedChunk(chunk: .init(index: index, scene: scene),
                                        mesh: try InkMeshCompiler().compile(scene))
        })
        let source = InkScrollSource(id: "darkFixture", title: "Dark", loadingText: "Preparing",
                                     surfaceColor: blue, prefersDarkAppearance: true,
                                     makePreparer: { worker })
        let model = ShanShuiScrollModel(seed: 42, source: source)
        let viewport = try ShanShuiScrollViewport(size: [240, 160])
        model.request(camera: model.camera, viewport: viewport)
        await worker.waitForRequestCount(1)
        try await worker.releaseNext()
        await model.settle()
        let renderer = try #require(model.renderer)
        let before = try readInkFrame(renderer, width: 240, height: 160)
        expectDark(before)
        model.request(camera: try ShanShuiCamera(index: 10), viewport: viewport)
        await worker.waitForRequestCount(2)
        try await worker.releaseNext(failing: true)
        await model.settle()
        #expect(model.failure != nil && model.renderer === renderer)
        let after = try readInkFrame(renderer, width: 240, height: 160)
        #expect(after == before)
        model.stop()
        for light in [InkScrollSource.shanShui, .gardenWall] {
            #expect(!light.prefersDarkAppearance)
            for c in 0..<3 { #expect(abs(light.surfaceColor[c] - 1) < 1e-12) }
        }
    }

    private func makeRenderer() throws -> ShanShuiRenderer {
        try ShanShuiRenderer(device: #require(MTLCreateSystemDefaultDevice()))
    }

    @Test func actualNightSkySourceRestartsWithItsArtworkAndDarkSurface() async throws {
        _ = NightSkyDesign(isPlaying: false).makeView(seed: 42)
        let source = InkScrollSource.nightSky
        let original = ShanShuiScrollModel(seed: 42, source: source)
        let viewport = try ShanShuiScrollViewport(size: [160, 320])
        original.request(camera: try ShanShuiCamera(index: 4), viewport: viewport)
        await original.settle()
        let before = try readInkFrame(#require(original.renderer), width: 160, height: 320)
        expectDark([before[0], before[159], before[160*319], before.last!])
        original.stop()
        let returned = original.sessionForAppearance()
        returned.request(camera: returned.camera, viewport: viewport)
        await returned.settle()
        #expect(returned !== original && returned.camera.index == 0)
        let frame = try readInkFrame(#require(returned.renderer), width: 160, height: 320)
        expectDark([frame[0], frame[159], frame[160*319], frame.last!])
        #expect(frame.filter { $0.z > 180 && $0.y > 170 }.count > 100)
        #expect(original.renderer == nil && original.failure == nil)
        returned.stop()
    }
    private func emptyChunks(withMark: Bool = false) throws -> [ShanShuiPreparedChunk] {
        try (Int64(-3)...Int64(3)).map { index in
            let ink: [InkPrimitive] = withMark ? [
                .colorWash(points: [[500, 300], [700, 300], [700, 500], [500, 500]],
                           color: [0.8, 0.3, 0.1], opacity: 1)
            ] : []
            let scene = InkScene(seed: 42, bounds: [1200, 800], primitives: ink)
            return ShanShuiPreparedChunk(chunk: .init(index: index, scene: scene),
                                        mesh: try InkMeshCompiler().compile(scene))
        }
    }
    private func expectDark(_ frame: [SIMD4<UInt8>]) {
        #expect(frame.allSatisfy { $0.w == 255 && $0.x < 100 && $0.z < 60 })
        #expect(frame.allSatisfy { Int($0.x) > Int($0.z) + 20 })
    }
    private func expectLight(_ frame: [SIMD4<UInt8>]) {
        #expect(frame.allSatisfy { $0.x > 210 && $0.y > 210 && $0.z > 210 })
    }
}
