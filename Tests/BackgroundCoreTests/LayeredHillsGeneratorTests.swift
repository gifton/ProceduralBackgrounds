import BackgroundCore
import Testing

struct LayeredHillsGeneratorTests {
    private let generator: LayeredHillsGenerator = LayeredHillsGenerator()

    @Test(arguments: [UInt64(0), 1, 42, UInt64.max])
    func replayingSeedReproducesGeometry(seed: UInt64) {
        let first = generator.generate(seed: seed)
        _ = generator.generate(seed: seed &+ 1)
        let replay = generator.generate(seed: seed)

        #expect(!first.layers.isEmpty)
        #expect(first.layers.count == replay.layers.count)
        for (lhs, rhs) in zip(first.layers, replay.layers) {
            #expect(lhs.count == rhs.count)
            for (a, b) in zip(lhs, rhs) {
                #expect(abs(a.x - b.x) < 1e-12)
                #expect(abs(a.y - b.y) < 1e-12)
            }
        }
    }

    @Test
    func seedChangesGeometry() {
        let first = generator.generate(seed: 42)
        let second = generator.generate(seed: 43)
        let maximumDifference: Double = zip(first.layers.joined(), second.layers.joined())
            .map { abs($0.y - $1.y) }.max() ?? 0

        #expect(maximumDifference > 0.001)
    }

    @Test(arguments: Array(UInt64(0)..<128) + [UInt64.max - 1, UInt64.max])
    func geometryIsFiniteOrderedAndCoversViewport(seed: UInt64) throws {
        let scene = generator.generate(seed: seed)
        #expect(scene.layers.count >= 2)

        for layer in scene.layers {
            #expect(layer.count >= 2)
            let first = try #require(layer.first)
            let last = try #require(layer.last)
            #expect(abs(first.x) < 1e-12)
            #expect(abs(last.x - 1) < 1e-12)
            for point in layer {
                #expect(point.x.isFinite && point.y.isFinite)
                #expect((0...1).contains(point.x))
                #expect((0...1).contains(point.y))
            }
            for (a, b) in zip(layer, layer.dropFirst()) {
                #expect(a.x < b.x)
            }
        }

        for (back, front) in zip(scene.layers, scene.layers.dropFirst()) {
            #expect(back.count == front.count)
            for (a, b) in zip(back, front) {
                #expect(a.y < b.y)
            }
        }
    }
}
