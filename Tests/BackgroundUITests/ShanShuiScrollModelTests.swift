import BackgroundCore
@testable import BackgroundUI
import Testing

@MainActor
struct ShanShuiScrollModelTests {
    @Test
    func rapidRequestsCoalesceAndOnlyLatestWindowInstalls() async throws {
        let source = SuspendedChunkPreparer()
        let sut = ShanShuiScrollModel(seed: 42, preparer: source)
        let viewport = try ShanShuiScrollViewport(size: [1200, 800])
        sut.request(camera: try ShanShuiCamera(), viewport: viewport)
        await source.waitForRequestCount(1)
        for index in 1...20 {
            sut.request(camera: try ShanShuiCamera(index: Int64(index)), viewport: viewport)
        }
        #expect(await source.requestCount == 1)
        #expect(sut.camera.index == 0)
        try await source.releaseNext()
        await source.waitForRequestCount(2)
        #expect(await source.lastIndices == [19, 20, 21])
        try await source.releaseNext()
        await sut.settle()
        #expect(sut.camera.index == 20)
        let renderer = try #require(sut.renderer)
        #expect(renderer.worldBufferIdentity(for: 20) != nil)
        #expect(renderer.worldBufferIdentity(for: 0) == nil)
        #expect(await source.committedIndices == [[19, 20, 21]])
        sut.request(camera: try ShanShuiCamera(index: 20, offset: 610), viewport: viewport)
        #expect(abs(sut.camera.offset - 610) < 1e-10)
        #expect(await source.requestCount == 2)
        sut.stop()
    }

    @Test(arguments: [UInt64(42), 43], [false, true])
    func removalAndSeedReplacementRejectOldCompletions(replacementSeed: UInt64,
                                                      oldCompletesFirst: Bool) async throws {
        let oldSource = SuspendedChunkPreparer()
        let old = ShanShuiScrollModel(seed: 42, preparer: oldSource)
        let viewport = try ShanShuiScrollViewport(size: [1200, 800])
        old.request(camera: try ShanShuiCamera(index: 10), viewport: viewport)
        await oldSource.waitForRequestCount(1)
        old.stop()
        let newSource = SuspendedChunkPreparer()
        let fresh = ShanShuiScrollModel(seed: replacementSeed, preparer: newSource)
        fresh.request(camera: try ShanShuiCamera(), viewport: viewport)
        await newSource.waitForRequestCount(1)
        if oldCompletesFirst {
            try await oldSource.releaseNext()
            await old.settle()
            #expect(fresh.renderer == nil)
            try await newSource.releaseNext()
            await fresh.settle()
        } else {
            try await newSource.releaseNext()
            await fresh.settle()
            let installed = try #require(fresh.renderer)
            try await oldSource.releaseNext()
            await old.settle()
            #expect(fresh.renderer === installed)
        }
        #expect(old.renderer == nil && old.failure == nil)
        #expect(fresh.renderer != nil && fresh.camera.index == 0)
        #expect(await oldSource.committedIndices.isEmpty)
        #expect(await newSource.committedIndices == [[-1, 0, 1]])
        #expect(await newSource.committedSeeds == [replacementSeed])
        fresh.stop()
    }

    @Test
    func retainedPreviewCreatesAFreshSessionAfterDisappearance() async throws {
        let source = SuspendedChunkPreparer()
        let original = ShanShuiScrollModel(seed: 42, preparer: source)
        #expect(original.sessionForAppearance() === original)
        let viewport = try ShanShuiScrollViewport(size: [1200, 800])
        original.request(camera: try ShanShuiCamera(index: 10), viewport: viewport)
        await source.waitForRequestCount(1)
        original.stop()
        let returned = original.sessionForAppearance()
        #expect(returned !== original)
        returned.request(camera: returned.camera, viewport: viewport)
        try await source.releaseNext()
        await original.settle()
        await returned.settle()
        #expect(returned.renderer != nil && returned.failure == nil)
        #expect(returned.camera.index == 0 && abs(returned.camera.offset - 600) < 1e-12)
        returned.setPlayback(requested: true, active: true, reduceMotion: false)
        #expect(returned.playbackAllowed)
        #expect(original.renderer == nil && original.failure == nil)
        #expect(await source.committedIndices.isEmpty)
        returned.stop()
    }

    @Test(arguments: ["shanShui", "gardenWall", "nightSky"])
    func enlargedViewportDuringPreparationKeepsLatestCameraCenter(sourceID: String) async throws {
        let source = SuspendedChunkPreparer()
        let sut = ShanShuiScrollModel(seed: 42, source: fixtureSource(sourceID, worker: source))
        let target = try ShanShuiCamera(index: 3, offset: 1199.5)
        sut.request(camera: target, viewport: try ShanShuiScrollViewport(size: [600, 800]))
        await source.waitForRequestCount(1)
        sut.request(camera: target, viewport: try ShanShuiScrollViewport(size: [3600, 800]))
        #expect(await source.requestCount == 1)
        try await source.releaseNext()
        await source.waitForRequestCount(2)
        #expect(sut.renderer == nil && sut.camera.index == 0)
        #expect(await source.lastIndices == [1, 2, 3, 4, 5, 6])
        try await source.releaseNext()
        await sut.settle()
        #expect(sut.camera.index == 3 && abs(sut.camera.offset - 1199.5) < 1e-12)
        #expect(await source.committedIndices == [[1, 2, 3, 4, 5, 6]])
        #expect(sut.renderer?.worldBufferIdentity(for: 6) != nil)
        sut.stop()
    }

    @Test(arguments: ["shanShui", "gardenWall", "nightSky"])
    func allPlaybackGatesStopMotionButResumeAfterPreparation(sourceID: String) async throws {
        let source = SuspendedChunkPreparer()
        let sut = ShanShuiScrollModel(seed: 42, source: fixtureSource(sourceID, worker: source))
        sut.request(camera: try ShanShuiCamera(),
                    viewport: try ShanShuiScrollViewport(size: [1200, 800]))
        await source.waitForRequestCount(1)
        for prepared in [false, true] {
            if prepared { try await source.releaseNext(); await sut.settle() }
            for playing in [false, true] {
                for active in [false, true] {
                    for reduced in [false, true] {
                        for dragging in [false, true] {
                            sut.setPlayback(requested: playing, active: active, reduceMotion: reduced)
                            if dragging { sut.beginDrag() }
                            let before = sut.camera
                            sut.advance(elapsed: .seconds(1))
                            let allowed = prepared && playing && active && !reduced && !dragging
                            #expect(sut.camera.index == before.index)
                            #expect(abs(sut.camera.offset - before.offset - (allowed ? 2 : 0)) < 1e-9)
                            if dragging { sut.endDrag() }
                        }
                    }
                }
            }
        }
        sut.setPlayback(requested: true, active: true, reduceMotion: false)
        let before = sut.camera.offset
        sut.advance(elapsed: .seconds(-1))
        sut.advance(elapsed: .zero)
        #expect(abs(sut.camera.offset - before) < 1e-12)
        sut.stop()
        sut.advance(elapsed: .seconds(1))
        #expect(abs(sut.camera.offset - before) < 1e-12)
    }

    @Test(arguments: ["shanShui", "gardenWall", "nightSky"])
    func draggingUsesCapturedCameraAndScaleWhilePaused(sourceID: String) async throws {
        let sut = ShanShuiScrollModel(seed: 42, source: fixtureSource(sourceID,
            worker: ShanShuiChunkBuilder(makeChunk: scrollFixture)))
        sut.request(camera: try ShanShuiCamera(), viewport: try ShanShuiScrollViewport(size: [1200, 800]))
        await sut.settle()
        sut.setPlayback(requested: false, active: true, reduceMotion: true)
        sut.beginDrag()
        sut.drag(translation: 10)
        sut.drag(translation: 20)
        #expect(abs(sut.camera.offset - 580) < 1e-10)
        sut.request(camera: sut.camera, viewport: try ShanShuiScrollViewport(size: [2400, 1600]))
        sut.drag(translation: 30)
        #expect(abs(sut.camera.offset - 570) < 1e-10)
        sut.setPlayback(requested: true, active: true, reduceMotion: false)
        sut.advance(elapsed: .seconds(1))
        #expect(abs(sut.camera.offset - 570) < 1e-10)
        sut.endDrag()
        sut.advance(elapsed: .milliseconds(50))
        #expect(abs(sut.camera.offset - 571) < 1e-10)
        sut.stop()
    }

    @Test(arguments: ["shanShui", "gardenWall", "nightSky"])
    func loadingHoldsCameraAndFailuresKeepThePriorRenderer(sourceID: String) async throws {
        let source = SuspendedChunkPreparer()
        let sut = ShanShuiScrollModel(seed: 42, source: fixtureSource(sourceID, worker: source))
        let viewport = try ShanShuiScrollViewport(size: [1200, 800])
        sut.request(camera: try ShanShuiCamera(), viewport: viewport)
        await source.waitForRequestCount(1)
        try await source.releaseNext()
        await sut.settle()
        let renderer = try #require(sut.renderer)
        sut.setPlayback(requested: true, active: true, reduceMotion: false)
        sut.request(camera: try ShanShuiCamera(index: 10), viewport: viewport)
        await source.waitForRequestCount(2)
        sut.advance(elapsed: .seconds(1))
        #expect(sut.camera.index == 0 && abs(sut.camera.offset - 600) < 1e-10)
        try await source.releaseNext(failing: true)
        await sut.settle()
        #expect(sut.failure != nil && sut.renderer === renderer)
        #expect(!sut.playbackAllowed)
        sut.stop()
    }
}


private func fixtureSource(_ id: String, worker: any ShanShuiChunkPreparing) -> InkScrollSource {
    InkScrollSource(id: id, title: id, loadingText: "Preparing",
                    surfaceColor: id == "nightSky" ? NightSkyChunkGenerator.surfaceColor : SIMD3(repeating: 1),
                    prefersDarkAppearance: id == "nightSky", makePreparer: { worker })
}
