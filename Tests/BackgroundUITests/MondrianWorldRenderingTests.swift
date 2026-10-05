@testable import BackgroundCore
@testable import BackgroundUI
import CoreGraphics
import Foundation
import ImageIO
import Metal
import Testing
import UniformTypeIdentifiers

@MainActor
struct MondrianWorldRenderingTests {
    @Test(arguments: [UInt64(0), UInt64(42), UInt64(43), UInt64.max],
          [Int64(-2), Int64(-1), Int64(0), Int64(1), Int64.min + 10,
           Int64.min + 11, Int64.max - 10, Int64.max - 11])
    func generatedJoinsMatchTheUnclippedCanonicalWorld(seed: UInt64, index: Int64) async throws {
        for size: SIMD2<Int> in [[241, 160], [480, 320]] {
            for offset: Double in [0, 0.37, 1199.75] {
                let camera = try ShanShuiCamera(index: index, offset: offset)
                let viewport = try ShanShuiScrollViewport(size: SIMD2<Double>(size))
                let indices = try camera.window(width: viewport.visibleWidth, prefetch: 0)
                let chunks = try await InkScrollSource.mondrian.makePreparer().prepare(seed: seed, indices: indices)
                let renderer = try makeRenderer()
                try renderer.installWorld(seed: seed, chunks: chunks, camera: camera,
                                          viewport: viewport, sourceID: "mondrian")
                let actual = try readInkFrame(renderer, width: size.x, height: size.y)
                let reference = try canonicalReference(seed: seed, camera: camera, size: size)
                let expected = try staticFrame(reference, size: size)
                try expectFramesAgree(actual, expected, size: size,
                    context: "seed-\(seed)-index-\(index)-offset-\(offset)-width-\(size.x)")
            }
        }
    }

    @Test func coloredFieldsActuallyCrossTransportJoins() throws {
        var witnesses: Int = 0
        for seed: UInt64 in [0, 7, 42, 43] {
            for index: Int64 in -3...2 {
                let a = try MondrianWorldComposition(seed: seed, index: index)
                let b = try MondrianWorldComposition(seed: seed, index: index + 1)
                witnesses += a.cells.filter { cell in
                    cell.color != .white && b.cells.contains { $0.id == cell.id }
                }.count
            }
        }
        #expect(witnesses > 0)
    }

    @Test func controlledBridgeAndWideDividerKeepTheirPaintAtFractionalJoins() throws {
        let bridge: [MondrianWorldCell] = [
            fixtureCell(slot: 0, min: [0, 0], max: [900, 800]),
            fixtureCell(slot: 1, min: [1500, 0], max: [2400, 800]),
            fixtureCell(slot: 2, min: [900, 0], max: [1500, 200]),
            fixtureCell(slot: 3, min: [900, 600], max: [1500, 800]),
            fixtureCell(slot: 0, min: [900, 200], max: [1500, 600], color: .red, kind: .bridge)
        ]
        let divider: [MondrianWorldCell] = [
            fixtureCell(slot: 0, min: [0, 0], max: [1197, 800]),
            fixtureCell(slot: 1, min: [1197, 0], max: [2400, 800], color: .red)
        ]
        let size: SIMD2<Int> = [480, 320]
        for (name, cells) in [("bridge", bridge), ("divider", divider)] {
            let edges = try MondrianWorldEdges.make(cells: cells, relativeTo: 0)
            for offset: Double in [0, 0.37] {
                let camera = try ShanShuiCamera(index: 1, offset: offset)
                let viewport = try ShanShuiScrollViewport(size: SIMD2<Double>(size))
                let chunks = try camera.window(width: viewport.visibleWidth, prefetch: 0).map { index in
                    let origin = MondrianWorldAddress(chunk: index)
                    let scene = try MondrianWorldInk.scene(seed: 42, cells: cells, edges: edges,
                        relativeTo: origin.owner, xOffset: Double(origin.offset), bounds: [1200, 800])
                    return ShanShuiPreparedChunk(chunk: .init(index: index, scene: scene),
                        mesh: try InkMeshCompiler().compile(scene, clippingToBounds: true))
                }
                let renderer = try makeRenderer()
                try renderer.installWorld(seed: 42, chunks: chunks, camera: camera, viewport: viewport,
                                          sourceID: "mondrian-fixture")
                let actual = try readInkFrame(renderer, width: size.x, height: size.y)
                let reference = try MondrianWorldInk.scene(seed: 42, cells: cells, edges: edges,
                    relativeTo: 0, xOffset: 600 + offset, bounds: [1200, 800])
                try expectFramesAgree(actual, staticFrame(reference, size: size), size: size,
                                      context: "fixture-\(name)-offset-\(offset)")
                let expected = try staticFrame(reference, size: size)
                // Inspect a full strip through the transport join, away from the outer frame.
                for y in 20..<300 {
                    for x in 232..<248 {
                        for channel in 0..<3 {
                            #expect(abs(Int(actual[y * 480 + x][channel]) - Int(expected[y * 480 + x][channel])) <= 3)
                        }
                    }
                }
                if name == "bridge" {
                    for x in [224, 256] {
                        let pixel = actual[160 * 480 + x]
                        #expect(Int(pixel.z) > Int(pixel.y) + 80 && Int(pixel.z) > Int(pixel.x) + 80)
                    }
                } else if abs(offset) < 1e-12 {
                    #expect(actual[160 * 480 + 239].z < 80)
                    #expect(actual[160 * 480 + 240].z < 180)
                }
            }
        }
    }

    @Test func realWorldResizesMovesAndRestoresPaperAfterNightSky() async throws {
        let source = InkScrollSource.mondrian
        let chunks = try await source.makePreparer().prepare(seed: 42, indices: [-3, -2, -1, 0, 1, 2, 3])
        let renderer = try makeRenderer()
        var wide: [SIMD4<UInt8>]?
        for size: SIMD2<Int> in [[480, 320], [160, 320], [480, 320]] {
            let camera = try ShanShuiCamera()
            let viewport = try ShanShuiScrollViewport(size: SIMD2<Double>(size))
            try renderer.installWorld(seed: 42, chunks: chunks, camera: camera, viewport: viewport,
                                      sourceID: source.id)
            let before = try readInkFrame(renderer, width: size.x, height: size.y)
            try expectFramesAgree(before, staticFrame(canonicalReference(seed: 42, camera: camera, size: size),
                                                      size: size), size: size, context: "resize-\(size.x)")
            if size.x == 480 {
                if let wide { #expect(before == wide) } else { wide = before }
            }
            let identity = try #require(renderer.worldBufferIdentity(for: 0))
            #expect(try renderer.updateWorldCamera(camera.moving(by: 100), viewport: viewport))
            #expect(renderer.worldBufferIdentity(for: 0) == identity)
            #expect(try readInkFrame(renderer, width: size.x, height: size.y) != before)
        }
        let night = try await InkScrollSource.nightSky.makePreparer().prepare(seed: 42, indices: [-1, 0, 1])
        let viewport = try ShanShuiScrollViewport(size: [480, 320])
        try renderer.installWorld(seed: 42, chunks: night, camera: ShanShuiCamera(), viewport: viewport,
            sourceID: "nightSky", surfaceColor: NightSkyChunkGenerator.surfaceColor)
        try renderer.installWorld(seed: 42, chunks: chunks, camera: ShanShuiCamera(), viewport: viewport,
                                  sourceID: source.id)
        #expect(try readInkFrame(renderer, width: 480, height: 320) == #require(wide))
        try exportSamplesIfRequested()
    }

    @Test func translucentPigmentHasNoGapOrDuplicateOpacityAtFractionalJoins() throws {
        let size: SIMD2<Int> = [241, 160]
        for offset: Double in [0, 0.37, 1199.75] {
            let camera = try ShanShuiCamera(index: 1, offset: offset)
            let viewport = try ShanShuiScrollViewport(size: SIMD2<Double>(size))
            let chunks = try camera.window(width: viewport.visibleWidth, prefetch: 0).map { index in
                let scene = InkScene(seed: 42, bounds: [1200, 800], primitives: [
                    .colorWash(points: [[-2400, -100], [3600, -100], [3600, 900], [-2400, 900]],
                               color: [0.9, 0.1, 0.2], opacity: 0.37)
                ])
                return ShanShuiPreparedChunk(chunk: .init(index: index, scene: scene),
                    mesh: try InkMeshCompiler().compile(scene, clippingToBounds: true))
            }
            let renderer = try makeRenderer()
            try renderer.installWorld(seed: 42, chunks: chunks, camera: camera,
                                      viewport: viewport, sourceID: "pigment-fixture")
            let reference = InkScene(seed: 42, bounds: [Double(size.x) * 5, 800], primitives: [
                .colorWash(points: [[-2400, -100], [3600, -100], [3600, 900], [-2400, 900]],
                           color: [0.9, 0.1, 0.2], opacity: 0.37)
            ])
            let actual = try readInkFrame(renderer, width: size.x, height: size.y)
            let expected = try staticFrame(reference, size: size)
            for (a, b) in zip(actual, expected) {
                #expect(a.w == 255 && b.w == 255)
                for channel in 0..<3 { #expect(abs(Int(a[channel]) - Int(b[channel])) <= 3) }
            }
        }
    }

    private func canonicalReference(seed: UInt64, camera: ShanShuiCamera,
                                    size: SIMD2<Int>) throws -> InkScene {
        let origin = MondrianWorldAddress(chunk: camera.index)
        var cells: [MondrianWorldCell] = []
        for delta: Int64 in -3...3 {
            let neighbor = origin.owner.addingReportingOverflow(delta)
            guard !neighbor.overflow else { throw MondrianWorldError.indexOverflow }
            cells += try MondrianWorldLayout(seed: seed, owner: neighbor.partialValue).cells
        }
        let edges = try MondrianWorldEdges.make(cells: cells, relativeTo: origin.owner)
        let worldWidth: Double = Double(size.x) * 800 / Double(size.y)
        let left: Double = Double(origin.offset) + camera.offset - worldWidth * 0.5
        return try MondrianWorldInk.scene(seed: seed, cells: cells, edges: edges,
            relativeTo: origin.owner, xOffset: left, bounds: [worldWidth, 800])
    }

    private func staticFrame(_ scene: InkScene, size: SIMD2<Int>) throws -> [SIMD4<UInt8>] {
        let renderer = try makeRenderer()
        try renderer.install(scene, mesh: InkMeshCompiler().compile(scene))
        return try readInkFrame(renderer, width: size.x, height: size.y)
    }

    // The unclipped and chunk-local paths triangulate/transform different Float meshes.
    // Recorded GPU diagnostics show at most eight isolated one-MSAA-sample changes
    // per frame (59/255 max channel error, <0.01 mean error); the join-strip and
    // translucent-pigment tests retain a strict three-unit tolerance.
    private func expectFramesAgree(_ actual: [SIMD4<UInt8>], _ expected: [SIMD4<UInt8>],
                                   size: SIMD2<Int>, context: String) throws {
        #expect(actual.count == expected.count)
        #expect(actual.allSatisfy { $0.w == 255 } && expected.allSatisfy { $0.w == 255 })
        var maximum: Int = 0, worst: Int = 0, outliers: Int = 0, total: Int = 0
        for (index, pair) in zip(actual, expected).enumerated() {
            var error: Int = 0
            for channel in 0..<3 { error = max(error, abs(Int(pair.0[channel]) - Int(pair.1[channel]))) }
            total += error
            if error > 3 { outliers += 1 }
            if error > maximum { maximum = error; worst = index }
        }
        if maximum > 64 || outliers > max(3, actual.count / 4_000) || Double(total) / Double(actual.count) >= 0.02 {
            print("Mondrian GPU \(context): max \(maximum), outliers \(outliers), mean \(Double(total)/Double(actual.count)), worst \(worst % size.x),\(worst / size.x), actual \(actual[worst]), reference \(expected[worst])")
            try exportPNG(actual, size: size, name: "failure-\(context)-actual")
            try exportPNG(expected, size: size, name: "failure-\(context)-reference")
        }
        #expect(maximum <= 64, "\(context): maximum channel error \(maximum)")
        #expect(outliers <= max(3, actual.count / 4_000), "\(context): outliers \(outliers)")
        #expect(Double(total) / Double(actual.count) < 0.02, "\(context): aggregate error")
    }

    private func makeRenderer() throws -> ShanShuiRenderer {
        try ShanShuiRenderer(device: #require(MTLCreateSystemDefaultDevice()))
    }

    private func fixtureCell(slot: UInt8, min: SIMD2<Int>, max: SIMD2<Int>,
                             color: MondrianColor = .white,
                             kind: MondrianWorldCellKind = .residual) -> MondrianWorldCell {
        .init(id: .init(owner: 0, kind: kind, root: slot, path: 1), rect: .init(min: min, max: max), color: color)
    }

    private func exportSamplesIfRequested() throws {
        guard ProcessInfo.processInfo.environment["MONDRIAN_PREVIEW_DIR"] != nil else { return }
        for seed: UInt64 in [0, 7, 42, 43, 99] {
            let chunks = try (-3...3).map { index in
                let chunk = try MondrianChunkGenerator().generate(seed: seed, index: Int64(index))
                return ShanShuiPreparedChunk(chunk: chunk,
                    mesh: try InkMeshCompiler().compile(chunk.scene, clippingToBounds: true))
            }
            for size: SIMD2<Int> in [[1200, 800], [400, 800]] {
                let renderer = try makeRenderer()
                try renderer.installWorld(seed: seed, chunks: chunks, camera: ShanShuiCamera(),
                    viewport: ShanShuiScrollViewport(size: SIMD2<Double>(size)), sourceID: "mondrian")
                try exportPNG(readInkFrame(renderer, width: size.x, height: size.y), size: size,
                              name: "mondrian-world-\(seed)-\(size.x)")
            }
        }
    }

    private func exportPNG(_ pixels: [SIMD4<UInt8>], size: SIMD2<Int>, name: String) throws {
        guard let directory = ProcessInfo.processInfo.environment["MONDRIAN_PREVIEW_DIR"] else { return }
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = pixels.withUnsafeBytes { Data($0) }
        let provider = try #require(CGDataProvider(data: data as CFData))
        let bitmap = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue
            | CGImageAlphaInfo.premultipliedFirst.rawValue)
        let image = try #require(CGImage(width: size.x, height: size.y, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: size.x * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmap,
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let destination = try #require(CGImageDestinationCreateWithURL(
            folder.appendingPathComponent(name + ".png") as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }
}
