@testable import BackgroundCore
@testable import BackgroundUI
import Metal
import Testing

@MainActor
struct NightSkyRenderingTests {
    @Test(arguments: [UInt64(42), 43])
    func bothMoonShapesAndStarsRenderInTheInitialPortrait(seed: UInt64) async throws {
        let chunks = try await InkScrollSource.nightSky.makePreparer().prepare(seed: seed, indices: [-1, 0, 1])
        let renderer = try makeRenderer()
        try renderer.installWorld(seed: seed, chunks: chunks, camera: ShanShuiCamera(),
                                  viewport: ShanShuiScrollViewport(size: [160, 320]),
                                  sourceID: "nightSky", surfaceColor: NightSkyChunkGenerator.surfaceColor)
        let frame = try readInkFrame(renderer, width: 160, height: 320)
        #expect(frame.allSatisfy { $0.w == 255 })
        let moon = try #require(NightSkyComposition(seed: seed, index: 0).moon)
        let left: Double = (moon.envelope.min.x - 600) * 0.4 + 80
        let right: Double = (moon.envelope.max.x - 600) * 0.4 + 80
        let top: Double = moon.envelope.min.y * 0.4
        let bottom: Double = moon.envelope.max.y * 0.4
        var bodyCount: Int = 0, starCount: Int = 0
        for (i, pixel) in frame.enumerated() {
            let x: Double = Double(i % 160) + 0.5, y: Double = Double(i / 160) + 0.5
            let inside: Bool = x >= left && x <= right && y >= top && y <= bottom
            if inside && pixel.z > 180 && pixel.y > 170 { bodyCount += 1 }
            if !inside && max(pixel.x, max(pixel.y, pixel.z)) > 115 { starCount += 1 }
        }
        #expect(bodyCount >= 100)
        #expect(starCount >= 10)
    }

    @Test func crescentOpeningIsDarkThroughProductionGPU() throws {
        let moon = try #require(NightSkyComposition(seed: 42, index: 0).moon)
        let scene = InkScene(seed: 42, bounds: [1200, 800], primitives: NightSkyMoonInk.draw(moon))
        let renderer = try makeRenderer()
        try renderer.installWorld(seed: 42, chunks: [prepared(index: 0, scene: scene)],
                                  camera: ShanShuiCamera(), viewport: ShanShuiScrollViewport(size: [160, 320]),
                                  sourceID: "nightSky", surfaceColor: NightSkyChunkGenerator.surfaceColor)
        let frame = try readInkFrame(renderer, width: 160, height: 320)
        func pixel(_ local: SIMD2<Double>) -> SIMD4<UInt8> {
            let point = moon.anchor + local * moon.radius
            let x = Int((point.x - 600) * 0.4 + 80), y = Int(point.y * 0.4)
            return frame[y * 160 + x]
        }
        #expect(pixel([-0.75, 0]).z > 180)
        #expect(pixel([0.35, 0]).z < 90 && pixel([0.35, 0]).x < 100)
    }

    @Test func actualSkyJoinsMatchFullCanonicalReference() throws {
        var crossingKinds: Set<NightSkyWashKind> = []
        var maximumMean: Double = 0
        for seed: UInt64 in [42, 43] {
            for left: Int64 in [-1, 0, Int64.min + 10, Int64.max - 11] {
                let a = NightSkyComposition(seed: seed, index: left)
                let b = NightSkyComposition(seed: seed, index: left + 1)
                for group in a.groups where group.envelope.min.x < 1200 && group.envelope.max.x > 1200 {
                    crossingKinds.insert(group.id.kind)
                }
                let chunks = try [left, left + 1].map { index in
                    try prepared(index: index, scene: NightSkyChunkGenerator().generate(seed: seed, index: index).scene)
                }
                for width in [480, 481] {
                    for offset: Double in [0, 0.37] {
                        let renderer = try makeRenderer()
                        let camera = try ShanShuiCamera(index: left + 1, offset: offset)
                        let viewport = try ShanShuiScrollViewport(size: [Double(width), 320])
                        try renderer.installWorld(seed: seed, chunks: chunks, camera: camera, viewport: viewport,
                                                  sourceID: "nightSky", surfaceColor: NightSkyChunkGenerator.surfaceColor)
                        let actual = try readInkFrame(renderer, width: width, height: 320)
                        let empty = try [left, left + 1].map {
                            try prepared(index: $0, scene: .init(seed: seed, bounds: [1200, 800], primitives: []))
                        }
                        try renderer.installWorld(seed: seed, chunks: empty, camera: camera, viewport: viewport,
                                                  sourceID: "paperFixture")
                        let paper = try readInkFrame(renderer, width: width, height: 320)
                        let reference = canonicalReference(a, b, seed: seed, offset: offset)
                        let fullWidth: Int = width + 480
                        let referenceRenderer = try makeRenderer()
                        try referenceRenderer.install(reference, mesh: InkMeshCompiler().compile(reference))
                        let expected = try readInkFrame(referenceRenderer, width: fullWidth, height: 320)
                        let emptyReference = InkScene(seed: seed, bounds: [2400, 800], primitives: [])
                        try referenceRenderer.install(emptyReference, mesh: InkMeshCompiler().compile(emptyReference))
                        let expectedPaper = try readInkFrame(referenceRenderer, width: fullWidth, height: 320)
                        for x in (width / 2 - 4)...(width / 2 + 4) {
                            for channel in 0..<3 {
                                var total: Double = 0, run: Int = 0, longest: Int = 0
                                for y in 0..<320 {
                                    let i: Int = y * width + x, j: Int = y * fullWidth + x + 240
                                    let actualInk: Double = Double(actual[i][channel]) / Double(paper[i][channel]) * 255
                                    let referenceInk: Double = Double(expected[j][channel]) / Double(expectedPaper[j][channel]) * 255
                                    let error: Double = abs(actualInk - referenceInk)
                                    total += error
                                    run = error > 5 ? run + 1 : 0
                                    longest = max(longest, run)
                                }
                                let mean: Double = total / 320
                                maximumMean = max(maximumMean, mean)
                                #expect(mean < 3 && longest < 12,
                                        "seed \(seed) join \(left) width \(width) offset \(offset) channel \(channel) mean \(mean), run \(longest)")
                            }
                            #expect(actual[x].x < 110 && actual[319 * width + x].x < 110)
                        }
                    }
                }
            }
        }
        #expect(crossingKinds == Set([.pool, .cloud]))
        print("Night Sky canonical GPU joins: maximum mean channel error \(maximumMean)")
    }

    @Test func realSkyResizesMovesAndRestoresLightDesigns() async throws {
        let chunks = try await InkScrollSource.nightSky.makePreparer().prepare(seed: 42, indices: [-3, -2, -1, 0, 1, 2, 3])
        let renderer = try makeRenderer()
        for size: SIMD2<Int> in [[256, 128], [128, 256], [1024, 128], [256, 128]] {
            let viewport = try ShanShuiScrollViewport(size: SIMD2<Double>(size))
            let camera = try ShanShuiCamera()
            try renderer.installWorld(seed: 42, chunks: chunks, camera: camera, viewport: viewport,
                                      sourceID: "nightSky", surfaceColor: NightSkyChunkGenerator.surfaceColor)
            let identity = try #require(renderer.worldBufferIdentity(for: 0))
            let before = try readInkFrame(renderer, width: size.x, height: size.y)
            #expect(try renderer.updateWorldCamera(camera.moving(by: 100), viewport: viewport))
            let after = try readInkFrame(renderer, width: size.x, height: size.y)
            #expect(renderer.worldBufferIdentity(for: 0) == identity && before != after)
            #expect(Array(before.prefix(size.x)) == Array(after.prefix(size.x)))
            #expect(before[0].x < 100 && before[0].z < 60)
            let garden = try await InkScrollSource.gardenWall.makePreparer().prepare(seed: 42, indices: [-3, -2, -1, 0, 1, 2, 3])
            try renderer.installWorld(seed: 42, chunks: garden, camera: camera, viewport: viewport, sourceID: "gardenWall")
            #expect(try readInkFrame(renderer, width: size.x, height: size.y)[0].z > 210)
            let staticScene = ShanShuiGenerator().generate(seed: 42)
            try renderer.install(staticScene, mesh: InkMeshCompiler().compile(staticScene))
            #expect(try readInkFrame(renderer, width: size.x, height: size.y)[0].z > 210)
        }
    }

    private func makeRenderer() throws -> ShanShuiRenderer {
        try ShanShuiRenderer(device: #require(MTLCreateSystemDefaultDevice()))
    }
    private func prepared(index: Int64, scene: InkScene) throws -> ShanShuiPreparedChunk {
        .init(chunk: .init(index: index, scene: scene), mesh: try InkMeshCompiler().compile(scene, clippingToBounds: true))
    }
    private func canonicalReference(_ a: NightSkyComposition, _ b: NightSkyComposition,
                                    seed: UInt64, offset: Double) -> InkScene {
        var groups: [NightSkyWashID: NightSkyWashGroup] = [:]
        for (layout, translation) in [(a, 0.0), (b, 1200.0)] {
            for group in layout.groups where groups[group.id] == nil {
                groups[group.id] = group.translated(by: [translation - offset, 0])
            }
        }
        let ordered = groups.values.sorted {
            $0.id.kind == $1.id.kind ? $0.id.owner < $1.id.owner : $0.id.kind.rawValue < $1.id.kind.rawValue
        }
        var ink: [InkPrimitive] = [.colorWash(points: [[0, 0], [2400, 0], [2400, 800], [0, 800]],
                                             color: NightSkyChunkGenerator.surfaceColor, opacity: 1)]
        for group in ordered { ink += NightSkyInk.group(group) }
        for (layout, translation) in [(a, 0.0), (b, 1200.0)] {
            for star in layout.stars { ink += NightSkyInk.star(star).map { $0.mapGeometry { $0 + [translation - offset, 0] } } }
        }
        for (layout, translation) in [(a, 0.0), (b, 1200.0)] {
            if let moon = layout.moon { ink += NightSkyMoonInk.draw(moon).map { $0.mapGeometry { $0 + [translation - offset, 0] } } }
        }
        return .init(seed: seed, bounds: [2400, 800], primitives: ink)
    }
}
