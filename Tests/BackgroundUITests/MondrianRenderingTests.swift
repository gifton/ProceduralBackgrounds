@testable import BackgroundCore
@testable import BackgroundUI
import Foundation
import Metal
import Testing

@MainActor
struct MondrianRenderingTests {
    @Test(arguments: [UInt64(0), 42, 43, .max])
    func allPaletteFieldsAndPigmentRenderThroughProductionShaders(seed: UInt64) throws {
        let renderer = try makeRenderer()
        let scene = MondrianGenerator().generate(seed: seed)
        let paperScene = InkScene(seed: seed, bounds: scene.bounds, primitives: [])
        try renderer.install(paperScene, mesh: InkMeshCompiler().compile(paperScene))
        let paper = try readInkFrame(renderer, width: 480, height: 320)
        try renderer.install(scene, mesh: InkMeshCompiler().compile(scene, clippingToBounds: true))
        let pixels = try readInkFrame(renderer, width: 480, height: 320)
        #expect(pixels.allSatisfy { $0.w == 255 })
        let cells = MondrianLayout(seed: seed).cells
        for cell in cells {
            let indices = interior(cell, inset: 20)
            #expect(!indices.isEmpty)
            let mean: SIMD3<Double> = indices.reduce(SIMD3<Double>.zero) {
                let p = pixels[$1]
                return $0 + [Double(p.z), Double(p.y), Double(p.x)]
            } / Double(indices.count)
            switch cell.color {
            case .red: #expect(mean.x > mean.y + 40 && mean.x > mean.z + 40)
            case .blue: #expect(mean.z > mean.x + 40 && mean.z > mean.y + 25)
            case .yellow: #expect(mean.x > mean.z + 50 && mean.y > mean.z + 40)
            case .white: #expect(min(mean.x, min(mean.y, mean.z)) > 210)
            case .black: #expect(max(mean.x, max(mean.y, mean.z)) < 100)
            }
        }
        let focal = try #require(cells.filter { [.red, .blue, .yellow].contains($0.color) }
            .max(by: { $0.rect.area < $1.rect.area }))
        let ranges: [Double] = (0..<3).map { channel in
            let values = interior(focal, inset: 25).map { index in
                Double(pixels[index][channel]) / Double(paper[index][channel]) * 255
            }
            return (values.max() ?? 0) - (values.min() ?? 0)
        }
        #expect((ranges.max() ?? 0) > 6)
    }

    @Test(arguments: [UInt64(0), 42, 43, .max])
    func interiorPigmentHasNoAbruptHighContrastSteps(seed: UInt64) throws {
        let renderer = try makeRenderer()
        let scene = MondrianGenerator().generate(seed: seed)
        let empty = InkScene(seed: seed, bounds: scene.bounds, primitives: [])
        try renderer.install(empty, mesh: InkMeshCompiler().compile(empty))
        let paper = try readInkFrame(renderer, width: 480, height: 320)
        try renderer.install(scene, mesh: InkMeshCompiler().compile(scene, clippingToBounds: true))
        let pixels = try readInkFrame(renderer, width: 480, height: 320)
        for cell in MondrianLayout(seed: seed).cells where cell.color != .white {
            let indices = Set(interior(cell, inset: 20))
            var largestStep: Double = 0
            for index in indices {
                for neighbor in [index + 1, index + 480] where indices.contains(neighbor) {
                    for channel in 0..<3 {
                        let a = Double(pixels[index][channel]) / Double(paper[index][channel]) * 255
                        let b = Double(pixels[neighbor][channel]) / Double(paper[neighbor][channel]) * 255
                        largestStep = max(largestStep, abs(a - b))
                    }
                }
            }
            #expect(largestStep < 10, "seed \(seed), cell \(cell.id), pigment step \(largestStep)")
        }
    }

    @Test func dividerTJunctionsConnectWithoutCrossingTheUnsplitCell() throws {
        let cells: [MondrianCell] = [
            .init(id: 1, rect: .init(min: [0, 0], max: [600, 800]), color: .red),
            .init(id: 2, rect: .init(min: [600, 0], max: [1200, 200]), color: .white),
            .init(id: 3, rect: .init(min: [600, 200], max: [1200, 500]), color: .blue),
            .init(id: 4, rect: .init(min: [600, 500], max: [1200, 800]), color: .yellow)
        ]
        let scene = InkScene(seed: 42, bounds: [1200, 800], primitives:
            MondrianEdges.make(cells: cells).flatMap { MondrianDividerInk.draw($0, seed: 42) })
        let renderer = try makeRenderer()
        try renderer.install(scene, mesh: InkMeshCompiler().compile(scene, clippingToBounds: true))
        let pixels = try readInkFrame(renderer, width: 480, height: 320)
        func region(_ point: SIMD2<Int>) -> [SIMD4<UInt8>] {
            let x = Int(Double(point.x) * 0.4), y = Int(Double(point.y) * 0.4)
            return [pixels[y * 480 + x], pixels[y * 480 + x + 1],
                    pixels[(y + 1) * 480 + x], pixels[(y + 1) * 480 + x + 1]]
        }
        let witnesses: [SIMD2<Int>] = [[600, 200], [630, 200], [600, 170], [600, 230],
                                     [600, 500], [630, 500], [600, 470], [600, 530]]
        for point in witnesses {
            #expect(region(point).contains { max($0.x, max($0.y, $0.z)) < 80 })
        }
        for point: SIMD2<Int> in [[570, 200], [570, 500]] {
            #expect(region(point).allSatisfy { min($0.x, min($0.y, $0.z)) > 210 })
        }
    }

    @Test func darkWorldToStillPaintingRestoresPaperAndSurvivesResize() async throws {
        let renderer = try makeRenderer()
        let chunks = try await InkScrollSource.nightSky.makePreparer().prepare(
            seed: 42, indices: [-3, -2, -1, 0, 1, 2, 3])
        try renderer.installWorld(seed: 42, chunks: chunks, camera: ShanShuiCamera(),
                                  viewport: ShanShuiScrollViewport(size: [480, 320]),
                                  sourceID: "nightSky", surfaceColor: NightSkyChunkGenerator.surfaceColor)
        let night = try readInkFrame(renderer, width: 480, height: 320)
        #expect(night[0].z < 60)
        let scene = MondrianGenerator().generate(seed: 42)
        let mesh = try InkMeshCompiler().compile(scene, clippingToBounds: true)
        try renderer.install(scene, mesh: mesh)
        let wide = try readInkFrame(renderer, width: 480, height: 320)
        let portrait = try readInkFrame(renderer, width: 160, height: 320)
        let restored = try readInkFrame(renderer, width: 480, height: 320)
        #expect(wide == restored)
        #expect(portrait.allSatisfy { $0.w == 255 })
        #expect(portrait.contains { Int($0.z) > Int($0.y) + 40 && Int($0.z) > Int($0.x) + 40 })
        let empty = InkScene(seed: 42, bounds: scene.bounds, primitives: [])
        try renderer.install(empty, mesh: InkMeshCompiler().compile(empty))
        let paper = try readInkFrame(renderer, width: 160, height: 320)
        for row in Array(0..<80) + Array(240..<320) {
            for x in 0..<160 {
                let index = row * 160 + x
                for channel in 0..<4 {
                    #expect(abs(Int(portrait[index][channel]) - Int(paper[index][channel])) <= 1)
                }
            }
        }
    }

    private func makeRenderer() throws -> ShanShuiRenderer {
        try ShanShuiRenderer(device: #require(MTLCreateSystemDefaultDevice()))
    }

    private func interior(_ cell: MondrianCell, inset: Int) -> [Int] {
        let minX = Int(ceil(Double(cell.rect.min.x + inset) * 0.4))
        let maxX = Int(floor(Double(cell.rect.max.x - inset) * 0.4))
        let minY = Int(ceil(Double(cell.rect.min.y + inset) * 0.4))
        let maxY = Int(floor(Double(cell.rect.max.y - inset) * 0.4))
        return (minY..<maxY).flatMap { y in (minX..<maxX).map { y * 480 + $0 } }
    }
}
