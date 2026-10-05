import BackgroundCore
@testable import BackgroundUI
import Metal
import Testing

@MainActor
struct ShanShuiRenderingTests {
    @Test
    func paperAndMountainRenderThroughProductionShaders() throws {
        let device = try #require(MTLCreateSystemDefaultDevice(), "A Metal device is required for rendering tests.")
        let renderer = try ShanShuiRenderer(device: device)
        let paperScene = ShanShuiScene(seed: 42, bounds: [800, 800], primitives: [])
        let paper = try render(paperScene, with: renderer)
        #expect(paper.allSatisfy { $0.w == 255 })
        let tones = paper.map { Int($0.z) }
        #expect((tones.max() ?? 0) - (tones.min() ?? 0) > 2)
        #expect(paper[0].z > paper[0].y && paper[0].y > paper[0].x)

        let mountain = try render(ShanShuiGenerator().generate(seed: 42), with: renderer)
        let darkPixels = zip(paper, mountain).filter { Int($1.z) + 25 < Int($0.z) }.count
        #expect(darkPixels > 50)
    }

    @Test
    func laterWhiteWashOccludesInkAndRetainsPaperTexture() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let renderer = try ShanShuiRenderer(device: device)
        let black: InkPrimitive = .wash(points: [[100, 100], [700, 100], [700, 700], [100, 700]],
                                         tone: 0, opacity: 1)
        let white: InkPrimitive = .wash(points: [[300, 300], [600, 300], [600, 600], [300, 600]],
                                         tone: 1, opacity: 1)
        let pixels = try render(ShanShuiScene(seed: 42, bounds: [800, 800], primitives: [black, white]),
                                with: renderer)
        #expect(pixels[32 * 128 + 32].z < 10)
        #expect(pixels[70 * 128 + 70].z > 220)
        let inside = (60..<90).flatMap { y in (60..<90).map { Int(pixels[y * 128 + $0].z) } }
        #expect((inside.max() ?? 0) - (inside.min() ?? 0) > 2)
    }

    @Test
    func landscapeRendersAfterWideAndTallResize() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let renderer = try ShanShuiRenderer(device: device)
        let scene = ShanShuiLandscapeGenerator().generate(seed: 42)
        let paperScene = ShanShuiScene(seed: 42, bounds: scene.bounds, primitives: [])
        // A 1200 × 800 world fits 256 × 128 with a 32px side margin, and
        // 128 × 256 with an 85⅓px top margin. Sample well inside those margins.
        let sizes: [SIMD2<Int>] = [[256, 128], [128, 256]]
        for size in sizes {
            let paper = try render(paperScene, with: renderer, width: size.x, height: size.y)
            let landscape = try render(scene, with: renderer, width: size.x, height: size.y)
            #expect(landscape.allSatisfy { $0.w == 255 })
            #expect(zip(paper, landscape).filter { Int($1.z) + 20 < Int($0.z) }.count > 35)
            let marginSamples: [Int] = size.x > size.y
                ? (0..<size.y).flatMap { y in (0..<25).map { y * size.x + $0 } }
                : (0..<80).flatMap { y in (0..<size.x).map { y * size.x + $0 } }
            #expect(marginSamples.allSatisfy { abs(Int(paper[$0].z) - Int(landscape[$0].z)) <= 1 })
        }
    }

    @Test(arguments: ShanShuiElement.allCases)
    func eachElementDrawsVisibleInkWithoutClipping(element: ShanShuiElement) throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let renderer = try ShanShuiRenderer(device: device)
        let scene = ShanShuiElementGenerator(element: element).generate(seed: 42)
        let paperScene = ShanShuiScene(seed: 42, bounds: scene.bounds, primitives: [])
        let paper = try render(paperScene, with: renderer, width: 320, height: 240)
        let study = try render(scene, with: renderer, width: 320, height: 240)
        #expect(study.allSatisfy { $0.w == 255 })
        #expect(zip(paper, study).filter { Int($1.z) + 25 < Int($0.z) }.count > 100)
        // All four subjects are staged away from the edge of the 4:3 world.
        let border = (0..<240).flatMap { y in
            (0..<320).filter { x in x < 8 || x >= 312 || y < 8 || y >= 232 }
                .map { y * 320 + $0 }
        }
        #expect(border.allSatisfy { abs(Int(paper[$0].z) - Int(study[$0].z)) <= 1 })
    }

    private func render(_ scene: ShanShuiScene, with renderer: ShanShuiRenderer,
                        width: Int = 128, height: Int = 128) throws -> [SIMD4<UInt8>] {
        try renderer.install(scene, mesh: InkMeshCompiler().compile(scene))
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = [.renderTarget, .shaderRead]
        let output = try #require(renderer.device.makeTexture(descriptor: descriptor))
        let command = try renderer.encodeFrame(into: output)
        command.commit()
        command.waitUntilCompleted()
        #expect(command.status == .completed, "\(String(describing: command.error))")
        var pixels = [SIMD4<UInt8>](repeating: .zero, count: width * height)
        pixels.withUnsafeMutableBytes {
            output.getBytes($0.baseAddress!, bytesPerRow: width * 4,
                            from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        return pixels
    }
}
