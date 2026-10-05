import BackgroundCore
@testable import BackgroundUI
import Metal
import Testing

struct ColorInkTests {
    @Test func colorWashAndStrokePreserveStraightRGBAndOrder() throws {
        let scene = InkScene(seed: 42, bounds: [100, 100], primitives: [
            .colorWash(points: [[10, 10], [40, 10], [10, 40]], color: [0.7, 0.2, 0.3], opacity: 0.4),
            .colorStroke(points: [[60, 20], [80, 20]], widths: [4, 4], color: [0.2, 0.6, 0.3], opacity: 0.8),
            .wash(points: [[10, 60], [40, 60], [10, 90]], tone: 0.5, opacity: 1)
        ])
        let vertices = try InkMeshCompiler().compile(scene).vertices
        #expect(vertices.count == 12)
        let expected: [SIMD4<Float>] = [[0.7, 0.2, 0.3, 0.4], [0.2, 0.6, 0.3, 0.8], [0.5, 0.5, 0.5, 1]]
        for (range, color) in zip([0..<3, 3..<9, 9..<12], expected) {
            for vertex in vertices[range] {
                for c in 0..<4 { #expect(abs(vertex.color[c] - color[c]) < 1e-6) }
            }
        }
    }

    @Test(arguments: [false, true], [-0.1, 1.1, Double.nan, .infinity, -.infinity])
    func rejectsInvalidColorAndOpacity(stroke: Bool, bad: Double) {
        for channel in 0..<4 {
            var color: SIMD3<Double> = [0.2, 0.6, 0.3]
            if channel < 3 { color[channel] = bad }
            let opacity: Double = channel == 3 ? bad : 0.5
            let ink: InkPrimitive = stroke
                ? .colorStroke(points: [[0, 0], [10, 10]], widths: [2, 2], color: color, opacity: opacity)
                : .colorWash(points: [[0, 0], [10, 0], [0, 10]], color: color, opacity: opacity)
            #expect(throws: InkMeshError.self) {
                try InkMeshCompiler().compile(InkScene(seed: 0, bounds: [20, 20], primitives: [ink]))
            }
        }
    }

    @Test func coloredGeometryUsesTheSameValidation() {
        let invalid: [InkPrimitive] = [
            .colorWash(points: [[.nan, 0], [10, 0], [0, 10]], color: [0.2, 0.6, 0.3], opacity: 1),
            .colorStroke(points: [[0, 0], [10, 10]], widths: [1], color: [0.2, 0.6, 0.3], opacity: 1),
            .colorStroke(points: [[0, 0], [10, 10]], widths: [-1, 1], color: [0.2, 0.6, 0.3], opacity: 1),
            .colorStroke(points: [[0, 0], [10, 10]], widths: [1, .infinity], color: [0.2, 0.6, 0.3], opacity: 1)
        ]
        for ink in invalid {
            #expect(throws: InkMeshError.self) {
                try InkMeshCompiler().compile(InkScene(seed: 0, bounds: [20, 20], primitives: [ink]))
            }
        }
    }

    @MainActor @Test func productionColorBlendsOverPaperInPainterOrder() throws {
        let renderer = try ShanShuiRenderer(device: #require(MTLCreateSystemDefaultDevice()))
        func render(_ ink: [InkPrimitive]) throws -> [SIMD4<UInt8>] {
            let scene = InkScene(seed: 42, bounds: [800, 800], primitives: ink)
            try renderer.install(scene, mesh: InkMeshCompiler().compile(scene))
            return try readInkFrame(renderer, width: 160, height: 160)
        }
        let paper = try render([])
        let points: [SIMD2<Double>] = [[100, 100], [700, 100], [700, 700], [100, 700]]
        let wash: InkPrimitive = .colorWash(points: points, color: [0.7, 0.2, 0.3], opacity: 0.4)
        let stroke: InkPrimitive = .colorStroke(points: [[100, 400], [700, 400]], widths: [100, 100],
                                               color: [0.2, 0.6, 0.3], opacity: 0.8)
        let sample = 80 * 160 + 80
        for (ink, rgb, alpha) in [([wash], SIMD3<Double>(0.7, 0.2, 0.3), 0.4),
                                   ([stroke], SIMD3<Double>(0.2, 0.6, 0.3), 0.8)] {
            let image = try render(ink)
            for c in 0..<3 {
                let expected = Double(paper[sample][c]) * (1 - alpha + alpha * rgb[2 - c])
                #expect(abs(Double(image[sample][c]) - expected) <= 3)
            }
        }
        let image = try render([wash, stroke])
        for c in 0..<3 {
            let first: Double = 0.6 + 0.4 * [0.3, 0.2, 0.7][c]
            let second: Double = first * 0.2 + 0.8 * [0.3, 0.6, 0.2][c]
            #expect(abs(Double(image[sample][c]) - Double(paper[sample][c]) * second) <= 3)
        }
        let white: InkPrimitive = .wash(points: points, tone: 1, opacity: 1)
        let restored = try render([wash, stroke, white])
        for c in 0..<4 { #expect(abs(Int(restored[sample][c]) - Int(paper[sample][c])) <= 1) }
    }
}
