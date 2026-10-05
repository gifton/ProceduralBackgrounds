@testable import BackgroundCore
@testable import BackgroundUI
import Metal
import Testing

@MainActor
struct GardenWallRenderingTests {
    @Test
    func publicDesignAndGeneratedWorldRetainColorPaperAndBuffers() async throws {
        #expect(GardenWallDesign.title == "Garden Wall")
        _ = GardenWallDesign(isPlaying: false).makeView(seed: 42)
        let renderer = try makeRenderer()
        let chunks = try await InkScrollSource.gardenWall.makePreparer()
            .prepare(seed: 42, indices: [-3, -2, -1, 0, 1, 2, 3])
        let camera = try ShanShuiCamera()
        for size: SIMD2<Int> in [[256, 128], [128, 256], [256, 128]] {
            let viewport = try ShanShuiScrollViewport(size: SIMD2<Double>(size))
            try renderer.installWorld(seed: 42, chunks: chunks, camera: camera,
                                      viewport: viewport, sourceID: "gardenWall")
            let identity = try #require(renderer.worldBufferIdentity(for: 0))
            let before = try readInkFrame(renderer, width: size.x, height: size.y)
            #expect(before.filter { $0.z < 210 }.count > 100)
            #expect(before.filter { abs(Int($0.z) - Int($0.x)) > 15 }.count > 30)
            #expect(before.allSatisfy { $0.w == 255 })
            #expect(try renderer.updateWorldCamera(camera.moving(by: 100), viewport: viewport))
            let after = try readInkFrame(renderer, width: size.x, height: size.y)
            #expect(renderer.worldBufferIdentity(for: 0) == identity)
            #expect(before != after)
            let paperRows: Int = Int(Double(size.y) * 0.2)
            #expect(Array(before.prefix(paperRows * size.x)) == Array(after.prefix(paperRows * size.x)))
        }
    }

    @Test(arguments: [UInt64(42), 43])
    func bothCatPosesRenderInsidePortraitEnvelope(seed: UInt64) throws {
        let layout = GardenWallComposition(seed: seed, index: 0)
        let cat = try #require(layout.cat)
        let scene = InkScene(seed: seed, bounds: [1200, 800],
                             primitives: layout.masonry.primitives + GardenWallCatElements.draw(cat))
        let renderer = try makeRenderer()
        let viewport = try ShanShuiScrollViewport(size: [160, 320])
        let camera = try ShanShuiCamera(index: 0, offset: cat.anchor.x)
        try renderer.installWorld(seed: seed, chunks: [prepared(index: 0, scene: scene)],
                                  camera: camera, viewport: viewport, sourceID: "gardenWall")
        let pixels = try readInkFrame(renderer, width: 160, height: 320)
        let dark = pixels.enumerated().filter { $0.element.z < 190 }
        #expect(dark.count > 50)
        // The silhouette is above the wall; mortar below it cannot satisfy this check.
        let aboveCap = dark.filter { Double($0.offset / 160) < layout.masonry.capY * 0.4 - 2 }
        #expect(aboveCap.count > 25)
        #expect(aboveCap.allSatisfy { $0.offset % 160 > 10 && $0.offset % 160 < 150 })
    }

    @Test
    func actualMasonryJoinsMatchUnclippedCanonicalReference() throws {
        for left: Int64 in [-1, 0, Int64.min + 10, Int64.max - 11] {
            let a = GardenWallMasonry(seed: 42, index: left)
            let b = GardenWallMasonry(seed: 42, index: left + 1)
            let chunks = try [prepared(index: left, scene: .init(seed: 42, bounds: [1200, 800], primitives: a.primitives)),
                              prepared(index: left + 1, scene: .init(seed: 42, bounds: [1200, 800], primitives: b.primitives))]
            let reference = canonicalReference(a, b)
            for width in [480, 481] {
                let renderer = try makeRenderer()
                let camera = try ShanShuiCamera(index: left + 1, offset: 0)
                let viewport = try ShanShuiScrollViewport(size: [Double(width), 320])
                try renderer.installWorld(seed: 42, chunks: chunks, camera: camera,
                                          viewport: viewport, sourceID: "gardenWall")
                let actual = try readInkFrame(renderer, width: width, height: 320)
                let emptyChunks = try [left, left + 1].map {
                    try prepared(index: $0, scene: .init(seed: 42, bounds: [1200, 800], primitives: []))
                }
                let paperRenderer = try makeRenderer()
                try paperRenderer.installWorld(seed: 42, chunks: emptyChunks, camera: camera,
                                               viewport: viewport, sourceID: "gardenWall")
                let paper = try readInkFrame(paperRenderer, width: width, height: 320)
                let referenceRenderer = try makeRenderer()
                try referenceRenderer.install(reference, mesh: InkMeshCompiler().compile(reference))
                let fullWidth: Int = width + 480
                let expected = try readInkFrame(referenceRenderer, width: fullWidth, height: 320)
                let referencePaper = InkScene(seed: 42, bounds: [2400, 800], primitives: [])
                try referenceRenderer.install(referencePaper, mesh: InkMeshCompiler().compile(referencePaper))
                let expectedPaper = try readInkFrame(referenceRenderer, width: fullWidth, height: 320)
                let lower: Int = Int(a.bottomY * 0.4) - 3
                let upper: Int = Int(a.capY * 0.4) + 3
                for x in (width / 2 - 4)...(width / 2 + 4) {
                    var errors: [Double] = []
                    for y in upper..<lower {
                        let i: Int = y * width + x
                        let j: Int = y * fullWidth + x + 240
                        // Normalize the stationary paper grain, which depends on output UV.
                        let error: Double = abs(inkRatio(actual[i], paper[i]) - inkRatio(expected[j], expectedPaper[j]))
                        errors.append(error)
                        #expect(actual[i].z < paper[i].z - 5)
                    }
                    #expect(errors.reduce(0, +) / Double(errors.count) < 6,
                            "join \(left), width \(width), column \(x), mean \(errors.reduce(0,+)/Double(errors.count))")
                    #expect(errors.filter { $0 > 4 }.count < 8,
                            "join \(left), width \(width), column \(x), errors \(errors.filter { $0 > 4 })")
                }
            }
        }
    }

    private func inkRatio(_ pixel: SIMD4<UInt8>, _ paper: SIMD4<UInt8>) -> Double {
        Double(pixel.z) / Double(paper.z) * 255
    }

    private func makeRenderer() throws -> ShanShuiRenderer {
        try ShanShuiRenderer(device: #require(MTLCreateSystemDefaultDevice()))
    }

    private func prepared(index: Int64, scene: InkScene) throws -> ShanShuiPreparedChunk {
        .init(chunk: .init(index: index, scene: scene),
              mesh: try InkMeshCompiler().compile(scene, clippingToBounds: true))
    }

    /// A monolithic scene from full canonical metadata, never clipped chunk ink.
    private func canonicalReference(_ a: GardenWallMasonry, _ b: GardenWallMasonry) -> InkScene {
        var ink: [InkPrimitive] = [
            .colorWash(points: [[0, a.capY], [2400, a.capY], [2400, a.bottomY], [0, a.bottomY]],
                       color: GardenWallPalette.stone, opacity: 0.27)
        ]
        var seen: Set<GardenWallCellID> = []
        for (wall, offset) in [(a, 0.0), (b, 1200.0)] {
            for stone in wall.stones where seen.insert(stone.id).inserted {
                let polygon: [SIMD2<Double>] = stone.polygon.map { $0 + [offset, 0] }
                let center: SIMD2<Double> = [(polygon[6].x + polygon[2].x) * 0.5,
                    (a.courses[stone.id.row] + a.courses[stone.id.row + 1]) * 0.5]
                ink.append(.colorWash(points: polygon, color: stone.color, opacity: stone.opacity))
                ink.append(.colorWash(points: polygon.map { center + ($0 - center) * 0.78 },
                                      color: stone.color, opacity: 0.08))
                ink += stone.cracks.map { $0.mapGeometry { $0 + [offset, 0] } }
            }
        }
        for (row, width) in [150.0, 200.0, 120.0, 200.0].enumerated() {
            let shift: Double = row.isMultiple(of: 2) ? 0 : width * 0.5
            for joint in 0...Int(2400 / width) {
                let x: Double = Double(joint) * width + shift
                if x > 2400 { continue }
                ink.append(.colorStroke(points: [[x, a.courses[row] + 5], [x, a.courses[row + 1] - 5]],
                                        widths: [0.55, 0.55], color: GardenWallPalette.mortar, opacity: 0.22))
            }
        }
        ink.append(.colorWash(points: [[0, a.capY], [2400, a.capY], [2400, a.capY + 12], [0, a.capY + 12]],
                              color: GardenWallPalette.stone, opacity: 0.35))
        for y in [a.capY] + a.courses {
            ink.append(.colorStroke(points: [[0, y], [2400, y]], widths: [0.9, 0.9],
                                    color: GardenWallPalette.mortar, opacity: 0.32))
        }
        return .init(seed: 42, bounds: [2400, 800], primitives: ink)
    }
}
