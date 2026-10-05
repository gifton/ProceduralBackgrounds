import BackgroundCore
@testable import BackgroundUI
import Metal
import Synchronization
import Testing

private final class FactoryCount: Sendable {
    private let state = Mutex<Int>(0)
    func record() { state.withLock { $0 += 1 } }
    var value: Int { state.withLock { $0 } }
}

@MainActor
struct InkScrollSourceTests {
    @Test func scrollingIdentitiesKeepTheTransitionMatrixComplete() {
        #expect(Set(sourceIDs).count == 4)
        #expect(sourcePairs.count == 12)
        #expect(Set(sourcePairs.map { $0.joined(separator: ":") }).count == 12)
    }
    @Test(arguments: sourcePairs, [false, true])
    func sameSeedDifferentDesignRejectsLateCompletion(pair: [String], oldCompletesFirst: Bool) async throws {
        let oldID = pair[0], freshID = pair[1]
        let oldWorker = SuspendedChunkPreparer(makeChunk: { try sourceMark(seed: $0, index: $1, color: sourceColor(oldID)) })
        let freshWorker = SuspendedChunkPreparer(makeChunk: { try sourceMark(seed: $0, index: $1, color: sourceColor(freshID)) })
        let oldSource = InkScrollSource(id: oldID, title: oldID, loadingText: "Preparing", surfaceColor: sourceSurface(oldID), prefersDarkAppearance: oldID == "nightSky", makePreparer: { oldWorker })
        let freshSource = InkScrollSource(id: freshID, title: freshID, loadingText: "Preparing", surfaceColor: sourceSurface(freshID), prefersDarkAppearance: freshID == "nightSky", makePreparer: { freshWorker })
        let old = ShanShuiScrollModel(seed: 42, source: oldSource)
        let viewport = try ShanShuiScrollViewport(size: [1200, 800])
        old.request(camera: try ShanShuiCamera(index: 10), viewport: viewport)
        await oldWorker.waitForRequestCount(1)
        old.stop()
        let fresh = ShanShuiScrollModel(seed: 42, source: freshSource)
        fresh.request(camera: fresh.camera, viewport: viewport)
        await freshWorker.waitForRequestCount(1)
        if oldCompletesFirst {
            try await oldWorker.releaseNext()
            await old.settle()
            #expect(fresh.renderer == nil)
            try await freshWorker.releaseNext()
            await fresh.settle()
        } else {
            try await freshWorker.releaseNext()
            await fresh.settle()
            let installed = try #require(fresh.renderer)
            try await oldWorker.releaseNext()
            await old.settle()
            #expect(fresh.renderer === installed)
        }
        #expect(old.renderer == nil && old.failure == nil)
        #expect(await oldWorker.committedIndices.isEmpty)
        #expect(await freshWorker.committedIndices == [[-1, 0, 1]])
        #expect(await freshWorker.committedSeeds == [42])
        let frame = try readInkFrame(#require(fresh.renderer), width: 240, height: 160)
        checkSourcePixel(frame[80 * 240 + 120], id: freshID)
        checkSurfacePixel(frame[0], id: freshID)
        fresh.stop()
    }

    @Test(arguments: sourceIDs)
    func retainedDesignRestartsWithItsOwnFactory(sourceID: String) async throws {
        let counter = FactoryCount()
        let source = InkScrollSource(id: sourceID, title: sourceID, loadingText: "Preparing", surfaceColor: sourceSurface(sourceID), prefersDarkAppearance: sourceID == "nightSky", makePreparer: {
            counter.record()
            return ShanShuiChunkBuilder(makeChunk: {
                try sourceMark(seed: $0, index: $1, color: sourceColor(sourceID))
            })
        })
        let original = ShanShuiScrollModel(seed: 42, source: source)
        #expect(original.sessionForAppearance() === original)
        let viewport = try ShanShuiScrollViewport(size: [1200, 800])
        original.request(camera: try ShanShuiCamera(index: 4), viewport: viewport)
        await original.settle()
        #expect(counter.value == 1)
        original.stop()
        let returned = original.sessionForAppearance()
        #expect(returned !== original)
        #expect(counter.value == 2)
        returned.request(camera: returned.camera, viewport: viewport)
        await returned.settle()
        #expect(returned.camera.index == 0 && abs(returned.camera.offset - 600) < 1e-12)
        #expect(original.renderer == nil && original.failure == nil)
        let frame = try readInkFrame(#require(returned.renderer), width: 240, height: 160)
        checkSourcePixel(frame[80 * 240 + 120], id: sourceID)
        checkSurfacePixel(frame[0], id: sourceID)
        returned.setPlayback(requested: true, active: true, reduceMotion: false)
        #expect(returned.playbackAllowed)
        returned.advance(elapsed: .milliseconds(50))
        #expect(abs(returned.camera.offset - 601) < 1e-9)
        returned.setPlayback(requested: false, active: true, reduceMotion: true)
        returned.beginDrag()
        returned.drag(translation: 20)
        #expect(abs(returned.camera.offset - 581) < 1e-9)
        returned.endDrag()
        #expect(counter.value == 2)
        returned.stop()
    }

    @Test(arguments: sourcePairs)
    func sameSeedDifferentSourceDoesNotReuseWorldBuffers(pair: [String]) throws {
        let oldSourceID = pair[0], nextSourceID = pair[1]
        let renderer = try ShanShuiRenderer(device: #require(MTLCreateSystemDefaultDevice()))
        let viewport = try ShanShuiScrollViewport(size: [1200, 800])
        let camera = try ShanShuiCamera()
        let old = try [-1, 0, 1].map { try sourceMark(seed: 42, index: Int64($0), color: sourceColor(oldSourceID)) }
        try renderer.installWorld(seed: 42, chunks: old, camera: camera, viewport: viewport, sourceID: oldSourceID, surfaceColor: sourceSurface(oldSourceID))
        let oldID = try #require(renderer.worldBufferIdentity(for: 0))
        let replacement = try [-1, 0, 1].map { try sourceMark(seed: 42, index: Int64($0), color: sourceColor(nextSourceID)) }
        try renderer.installWorld(seed: 42, chunks: replacement, camera: camera, viewport: viewport, sourceID: nextSourceID, surfaceColor: sourceSurface(nextSourceID))
        let newID = try #require(renderer.worldBufferIdentity(for: 0))
        #expect(oldID != newID)
        checkSourcePixel(try readInkFrame(renderer, width: 240, height: 160)[80 * 240 + 120], id: nextSourceID)
        let overlapping = try [0, 1, 2].map { try sourceMark(seed: 42, index: Int64($0), color: sourceColor(nextSourceID)) }
        try renderer.installWorld(seed: 42, chunks: overlapping, camera: camera, viewport: viewport, sourceID: nextSourceID, surfaceColor: sourceSurface(nextSourceID))
        #expect(renderer.worldBufferIdentity(for: 0) == newID)
    }
}

private func sourceColor(_ id: String) -> SIMD3<Double> {
    switch id {
    case "shanShui": return [0.1, 0.1, 0.1]
    case "gardenWall": return [0.2, 0.7, 0.3]
    case "nightSky": return [0.9, 0.8, 0.35]
    case "mondrian": return [0.8, 0.12, 0.16]
    default:
        Issue.record("Unknown scrolling source fixture: \(id)")
        return [1, 0, 1]
    }
}
private func sourceMark(seed: UInt64, index: Int64, color: SIMD3<Double>) throws -> ShanShuiPreparedChunk {
    let scene = InkScene(seed: seed, bounds: [1200, 800], primitives: [
        .colorWash(points: [[500, 300], [700, 300], [700, 500], [500, 500]], color: color, opacity: 1)
    ])
    return ShanShuiPreparedChunk(chunk: InkChunk(index: index, scene: scene), mesh: try InkMeshCompiler().compile(scene))
}
private func checkSourcePixel(_ pixel: SIMD4<UInt8>, id: String) {
    if id == "gardenWall" { #expect(Int(pixel.y) > Int(pixel.z) + 80) }
    else if id == "nightSky" { #expect(Int(pixel.z) > Int(pixel.x) + 80) }
    else if id == "mondrian" {
        #expect(Int(pixel.z) > Int(pixel.y) + 80 && Int(pixel.z) > Int(pixel.x) + 80)
    } else if id == "shanShui" { #expect(pixel.z < 40 && pixel.y < 40) }
    else { Issue.record("Unknown scrolling source pixel: \(id)") }
}

private let scrollingSources: [InkScrollSource] = [.shanShui, .gardenWall, .nightSky, .mondrian]
private let sourceIDs: [String] = scrollingSources.map(\.id)
private let sourcePairs: [[String]] = sourceIDs.flatMap { from in
    sourceIDs.filter { $0 != from }.map { [from, $0] }
}
private func sourceSurface(_ id: String) -> SIMD3<Double> {
    id == "nightSky" ? NightSkyChunkGenerator.surfaceColor : SIMD3(repeating: 1)
}
private func checkSurfacePixel(_ pixel: SIMD4<UInt8>, id: String) {
    if id == "nightSky" { #expect(pixel.x < 100 && pixel.z < 60 && Int(pixel.x) > Int(pixel.z) + 20) }
    else { #expect(pixel.x > 210 && pixel.y > 210 && pixel.z > 210) }
}
