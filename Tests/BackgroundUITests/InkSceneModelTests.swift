import BackgroundCore
@testable import BackgroundUI
import Metal
import Testing

@MainActor
struct InkSceneModelTests {
    @Test(arguments: [true, false])
    func newerSeedWinsBothCompletionOrders(oldFirst: Bool) async throws {
        let preparer = SuspendedInkScenePreparer()
        let model = InkSceneModel(preparer: preparer)
        let old = Task { await model.load(seed: 42, using: StaticFixtureGenerator()) }
        await preparer.waitForPendingCount(1)
        let new = Task { await model.load(seed: 43, using: StaticFixtureGenerator()) }
        await preparer.waitForPendingCount(2)
        if oldFirst {
            try await preparer.release(0); await old.value
            try await preparer.release(1); await new.value
        } else {
            try await preparer.release(1); await new.value
            try await preparer.release(0); await old.value
        }
        #expect(model.installedSeed == 43 && model.failure == nil)
        let pixels = try readInkFrame(try #require(model.renderer), width: 128, height: 128)
        let center = pixels[64 * 128 + 64]
        #expect(Int(center.x) > Int(center.z) + 50)
        model.stop()
    }

    @Test(arguments: [true, false])
    func olderCompletionCannotReplaceNewerFailureOrSuccess(newFails: Bool) async throws {
        let preparer = SuspendedInkScenePreparer()
        let model = InkSceneModel(preparer: preparer)
        let old = Task { await model.load(seed: 42, using: StaticFixtureGenerator()) }
        await preparer.waitForPendingCount(1)
        let new = Task { await model.load(seed: 43, using: StaticFixtureGenerator()) }
        await preparer.waitForPendingCount(2)
        try await preparer.release(1, failing: newFails)
        await new.value
        let newFailure = model.failure
        try await preparer.release(0, failing: !newFails)
        await old.value
        if newFails {
            #expect(newFailure != nil && model.failure == newFailure && model.renderer == nil)
        } else {
            #expect(model.failure == nil && model.installedSeed == 43)
            let pixels = try readInkFrame(try #require(model.renderer), width: 128, height: 128)
            #expect(Int(pixels[64 * 128 + 64].x) > Int(pixels[64 * 128 + 64].z) + 50)
        }
        model.stop()
    }

    @Test func failedReplacementRetainsFrameAndSuccessfulRetryClearsFailure() async throws {
        let preparer = SuspendedInkScenePreparer()
        let model = InkSceneModel(preparer: preparer)
        let first = Task { await model.load(seed: 42, using: StaticFixtureGenerator()) }
        await preparer.waitForPendingCount(1)
        try await preparer.release(0); await first.value
        let renderer = try #require(model.renderer)
        let before = try readInkFrame(renderer, width: 128, height: 128)
        let failed = Task { await model.load(seed: 43, using: StaticFixtureGenerator()) }
        await preparer.waitForPendingCount(1)
        try await preparer.release(1, failing: true); await failed.value
        let after = try readInkFrame(renderer, width: 128, height: 128)
        #expect(model.renderer === renderer && model.installedSeed == 42 && model.failure != nil)
        #expect(after == before)
        let retry = Task { await model.load(seed: 43, using: StaticFixtureGenerator()) }
        await preparer.waitForPendingCount(1)
        try await preparer.release(2); await retry.value
        let retried = try readInkFrame(try #require(model.renderer), width: 128, height: 128)
        #expect(model.failure == nil && model.installedSeed == 43 && retried != before)
        model.stop()
    }

    @Test func cancelledRequestNeverInstallsOrShowsFailure() async throws {
        let preparer = SuspendedInkScenePreparer()
        let model = InkSceneModel(preparer: preparer)
        let task = Task { await model.load(seed: 42, using: StaticFixtureGenerator()) }
        await preparer.waitForPendingCount(1)
        task.cancel()
        try await preparer.release(0); await task.value
        #expect(model.renderer == nil && model.failure == nil && model.installedSeed == nil)
        model.stop()
    }

    @Test func stoppedRequestCannotInstallAndSameSeedRestarts() async throws {
        let preparer = SuspendedInkScenePreparer()
        let model = InkSceneModel(preparer: preparer)
        let old = Task { await model.load(seed: 42, using: StaticFixtureGenerator()) }
        await preparer.waitForPendingCount(1)
        model.stop()
        try await preparer.release(0); await old.value
        #expect(model.renderer == nil && model.failure == nil)
        let restart = Task { await model.load(seed: 42, using: StaticFixtureGenerator()) }
        await preparer.waitForPendingCount(1)
        try await preparer.release(1); await restart.value
        #expect(model.installedSeed == 42 && model.failure == nil)
        let pixels = try readInkFrame(try #require(model.renderer), width: 128, height: 128)
        #expect(Int(pixels[64 * 128 + 64].z) > Int(pixels[64 * 128 + 64].x) + 50)
        model.stop()
    }

    @Test func realBuilderClipsOnlyWhenRequested() async throws {
        struct EdgeGenerator: BackgroundGenerator {
            func generate(seed: UInt64) -> InkScene {
                InkScene(seed: seed, bounds: [800, 800], primitives: [
                    .colorStroke(points: [[0, 0], [0, 800]], widths: [20, 20], color: .zero, opacity: 1)
                ])
            }
        }
        let builder = InkSceneBuilder()
        let unclipped = try await builder.prepare(seed: 42, using: EdgeGenerator(), clippingToBounds: false)
        let clipped = try await builder.prepare(seed: 42, using: EdgeGenerator(), clippingToBounds: true)
        #expect(unclipped.mesh.vertices.contains { $0.position.x < -1 })
        #expect(!clipped.mesh.vertices.isEmpty && clipped.mesh.vertices.allSatisfy { $0.position.x >= -1e-5 })
    }
}
