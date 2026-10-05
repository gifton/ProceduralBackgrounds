@testable import BackgroundCore
@testable import BackgroundUI
import Testing

@MainActor
struct MondrianScrollSourceTests {
    @Test func actualMondrianFactoriesAreSeparateAndEvictedInkReturns() async throws {
        let source = InkScrollSource.mondrian
        let firstWorker = source.makePreparer(), secondWorker = source.makePreparer()
        let first = try await firstWorker.prepare(seed: 42, indices: [-1, 0, 1])
        try await firstWorker.commit(seed: 42, chunks: first)
        let other = try await secondWorker.prepare(seed: 42, indices: [-1, 0, 1])
        #expect(first[1] !== other[1])
        let overlap = try await firstWorker.prepare(seed: 42, indices: [0, 1, 2])
        #expect(overlap[0] === first[1] && overlap[1] === first[2])
        try await firstWorker.commit(seed: 42, chunks: overlap)
        let distant = try await firstWorker.prepare(seed: 42, indices: [20, 21, 22])
        try await firstWorker.commit(seed: 42, chunks: distant)
        let replay = try await firstWorker.prepare(seed: 42, indices: [0])
        #expect(replay[0] !== first[1])
        #expect(replay[0].mesh.vertices.count == first[1].mesh.vertices.count)
        for (a, b) in zip(replay[0].mesh.vertices, first[1].mesh.vertices) {
            #expect(abs(a.position.x - b.position.x) < 1e-6 && abs(a.position.y - b.position.y) < 1e-6)
            for channel in 0..<4 { #expect(abs(a.color[channel] - b.color[channel]) < 1e-6) }
        }
    }

    @Test func actualSourceSupportsReducedMotionDragResizeAndRestart() async throws {
        let model = ShanShuiScrollModel(seed: 42, source: .mondrian)
        model.request(camera: model.camera, viewport: try ShanShuiScrollViewport(size: [160, 320]))
        await model.settle()
        #expect(model.renderer != nil && model.failure == nil)
        model.setPlayback(requested: true, active: true, reduceMotion: true)
        #expect(!model.playbackAllowed)
        let initial = model.camera
        model.advance(elapsed: .milliseconds(50))
        #expect(model.camera.index == initial.index && abs(model.camera.offset - initial.offset) < 1e-9)
        model.beginDrag()
        model.drag(translation: 40)
        model.endDrag()
        #expect(abs(model.camera.offset - 500) < 1e-9)
        model.request(camera: model.camera, viewport: try ShanShuiScrollViewport(size: [1200, 800]))
        await model.settle()
        #expect(model.renderer != nil && model.failure == nil)
        model.stop()
        let returned = model.sessionForAppearance()
        #expect(returned !== model && returned.camera.index == 0)
        #expect(abs(returned.camera.offset - 600) < 1e-9)
        returned.request(camera: returned.camera, viewport: try ShanShuiScrollViewport(size: [160, 320]))
        await returned.settle()
        #expect(returned.renderer != nil && returned.failure == nil)
        returned.stop()
    }
}
