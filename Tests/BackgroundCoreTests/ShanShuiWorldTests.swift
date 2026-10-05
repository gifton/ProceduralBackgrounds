import BackgroundCore
import Testing

struct ShanShuiWorldTests {
    @Test(arguments: [UInt64(0), 42, UInt64.max])
    func indexedChunksReplayIndependentOfVisitOrder(seed: UInt64) {
        let indices: [Int64] = [.min, -2, -1, 0, 1, 2, .max]
        let generator = ShanShuiLandscapeChunkGenerator()
        let originals = indices.map { generator.generate(seed: seed, index: $0) }
        for (index, original) in zip(indices.reversed(), originals.reversed()) {
            let replay = ShanShuiLandscapeChunkGenerator().generate(seed: seed, index: index)
            compare(original.scene, replay.scene)
        }
        compare(originals[3].scene, ShanShuiLandscapeGenerator().generate(seed: seed))
        #expect(originals[2].scene.primitives.count != originals[3].scene.primitives.count
                || zip(originals[2].scene.primitives[0].points, originals[3].scene.primitives[0].points)
                    .contains { abs($0.x - $1.x) > 1e-6 || abs($0.y - $1.y) > 1e-6 })
    }

    @Test
    func cameraCrossesBothEdgesAndReturns() throws {
        let a = try ShanShuiCamera(offset: 1199.5)
        let b = try a.moving(by: 1)
        #expect(b.index == 1 && abs(b.offset - 0.5) < 1e-10)
        let back = try b.moving(by: -1)
        #expect(back.index == 0 && abs(back.offset - 1199.5) < 1e-10)
        let negative = try ShanShuiCamera(offset: 0.5).moving(by: -1)
        #expect(negative.index == -1 && abs(negative.offset - 1199.5) < 1e-10)
        for distance in [0.0, 1200, -1200, 1e9, -1e9] {
            let restored = try a.moving(by: distance).moving(by: -distance)
            #expect(restored.index == a.index && abs(restored.offset - a.offset) < 1e-8)
        }
        for index: Int64 in [Int64.min + 10, Int64.max - 10] {
            let large = try ShanShuiCamera(index: index, offset: 500.125).moving(by: 0.25)
            #expect(large.index == index && abs(large.offset - 500.375) < 1e-12)
            #expect(abs(try large.relativeOrigin(for: index + 1) - 699.625) < 1e-12)
        }
    }

    @Test
    func tinyBoundaryMovementsStayNormalizedAndReverseWithinRounding() throws {
        let distances: [Double] = [-Double.leastNonzeroMagnitude, -1e-14, -1e-13,
                                    -1200.0.ulp, Double.leastNonzeroMagnitude, 1e-14,
                                    1e-13, 1200.0.ulp]
        for index: Int64 in [Int64.min + 1, -1, 0, Int64.max - 1] {
            for offset in [0.0, Double.leastNonzeroMagnitude, 1e-14, 1200.0.nextDown] {
                let start = try ShanShuiCamera(index: index, offset: offset)
                for distance in distances {
                    let moved = try start.moving(by: distance)
                    #expect(moved.offset >= 0 && moved.offset < 1200)
                    let displacement: Double = Double(moved.index - start.index) * 1200
                        + moved.offset - start.offset
                    #expect(abs(displacement - distance) <= 2 * 1200.0.ulp)
                    let restored = try moved.moving(by: -distance)
                    let error: Double = Double(restored.index - start.index) * 1200
                        + restored.offset - start.offset
                    #expect(abs(error) <= 2 * 1200.0.ulp)
                }
            }
        }
    }

    @Test
    func windowsUseFloorAndExcludeTheirRightEdge() throws {
        #expect(try ShanShuiCamera().window(width: 1200, prefetch: 0) == [0])
        #expect(try ShanShuiCamera().window(width: 1200) == [-1, 0, 1])
        #expect(try ShanShuiCamera(index: -1, offset: 0).window(width: 1200, prefetch: 0) == [-2, -1])
        #expect(try ShanShuiCamera(offset: 600 - 1e-6).window(width: 1200, prefetch: 0) == [-1, 0])
        #expect(try ShanShuiCamera(offset: 600 + 1e-6).window(width: 1200, prefetch: 0) == [0, 1])
        #expect(try ShanShuiCamera(offset: 0).window(width: 4800) == [-3, -2, -1, 0, 1, 2])
        #expect(try ShanShuiCamera().window(width: 4800) == [-3, -2, -1, 0, 1, 2, 3])
        for offset in [0.0, 0.0.nextUp, 1199.0, 1200.0.nextDown] {
            let camera = try ShanShuiCamera(index: -50, offset: offset)
            let indices = try camera.window(width: 4800)
            #expect(indices.count <= 7)
            let first = try #require(indices.first)
            let last = try #require(indices.last)
            #expect(try camera.relativeOrigin(for: first) <= -2400)
            #expect(try camera.relativeOrigin(for: last) + 1200 >= 2400)
        }
    }

    @Test
    func tinySpansNeverCreateAnInvalidClosedRange() throws {
        #expect(throws: ShanShuiWorldError.self) {
            try ShanShuiCamera(offset: 0).window(width: Double.leastNonzeroMagnitude)
        }
        #expect(try ShanShuiCamera(offset: 0).window(width: 1e-320, prefetch: 0) == [-1, 0])
    }

    @Test
    func cameraRejectsInvalidInputsAndOverflow() throws {
        for offset in [Double.nan, .infinity, -.infinity, -1, 1200] {
            #expect(throws: ShanShuiWorldError.self) { try ShanShuiCamera(offset: offset) }
        }
        let camera = try ShanShuiCamera()
        for distance in [Double.nan, .infinity, -.infinity, 1e9 + 1, -1e9 - 1] {
            #expect(throws: ShanShuiWorldError.self) { try camera.moving(by: distance) }
        }
        for width in [0.0, -1, 4801, .nan, .infinity] {
            #expect(throws: ShanShuiWorldError.self) { try camera.window(width: width) }
        }
        for count in [-1, 2, Int.max] {
            #expect(throws: ShanShuiWorldError.self) { try camera.window(width: 1200, prefetch: count) }
        }
        #expect(throws: ShanShuiWorldError.self) { try ShanShuiCamera(index: .max).moving(by: 1200) }
        #expect(throws: ShanShuiWorldError.self) { try ShanShuiCamera(index: .min).moving(by: -1200) }
        #expect(throws: ShanShuiWorldError.self) { try ShanShuiCamera(index: .max).window(width: 4800) }
        #expect(throws: ShanShuiWorldError.self) { try ShanShuiCamera(index: .min).relativeOrigin(for: .max) }
    }

    @Test
    func viewportsFitHeightAndBoundChunkCount() throws {
        let portrait = try ShanShuiScrollViewport(size: [400, 800])
        #expect(abs(portrait.scale - 1) < 1e-12 && abs(portrait.visibleWidth - 400) < 1e-12)
        let wide = try ShanShuiScrollViewport(size: [2400, 800])
        #expect(abs(wide.visibleWidth - 2400) < 1e-12)
        let extreme = try ShanShuiScrollViewport(size: [10000, 100])
        #expect(abs(extreme.scale - 0.125) < 1e-12 && abs(extreme.visibleWidth - 4800) < 1e-12)
        for size: SIMD2<Double> in [[0, 0], [1, 0], [-1, 100], [.infinity, 1],
                                    [1, .nan], [1, Double.leastNonzeroMagnitude],
                                    [Double.greatestFiniteMagnitude, 1]] {
            #expect(throws: ShanShuiWorldError.self) { try ShanShuiScrollViewport(size: size) }
        }
    }

    private func compare(_ a: ShanShuiScene, _ b: ShanShuiScene) {
        #expect(a.primitives.count == b.primitives.count)
        for (p, q) in zip(a.primitives, b.primitives) {
            #expect(abs(p.tone - q.tone) < 1e-12 && abs(p.opacity - q.opacity) < 1e-12)
            #expect(p.points.count == q.points.count)
            for (x, y) in zip(p.points, q.points) {
                #expect(abs(x.x - y.x) < 1e-12 && abs(x.y - y.y) < 1e-12)
            }
            switch (p, q) {
            case let (.stroke(_, x, _, _), .stroke(_, y, _, _)):
                #expect(x.count == y.count)
                for (u, v) in zip(x, y) { #expect(abs(u - v) < 1e-12) }
            case (.wash, .wash): break
            default: Issue.record("Primitive kind changed on replay.")
            }
        }
    }
}
