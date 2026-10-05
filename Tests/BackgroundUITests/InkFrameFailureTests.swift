@testable import BackgroundUI
import Metal
import Testing

@MainActor
struct InkFrameFailureTests {
    @Test(arguments: [true, false])
    func frameFailureUsesTheCallbackFromSubmission(hadCallback: Bool) throws {
        let renderer = try ShanShuiRenderer(device: #require(MTLCreateSystemDefaultDevice()))
        var oldMessages: [String] = []
        var newMessages: [String] = []
        if hadCallback { renderer.onFailure = { oldMessages.append($0) } }
        let oldFrame = renderer.frameFailureReporter()
        renderer.onFailure = { newMessages.append($0) }
        oldFrame("Old frame failed")
        #expect(newMessages.isEmpty)
        #expect(oldMessages == (hadCallback ? ["Old frame failed"] : []))
        let currentFrame = renderer.frameFailureReporter()
        currentFrame("Current frame failed")
        #expect(newMessages == ["Current frame failed"])
    }

    @Test func delayedFrameFailureCannotReplaceNewSceneOrRestart() async throws {
        let model = InkSceneModel()
        await model.load(seed: 42, using: StaticFixtureGenerator())
        let renderer = try #require(model.renderer)
        let oldFrame = renderer.frameFailureReporter()
        await model.load(seed: 43, using: StaticFixtureGenerator())
        #expect(model.renderer === renderer && model.installedSeed == 43)
        let before = try readInkFrame(renderer, width: 128, height: 128)
        oldFrame("Old seed failed")
        #expect(model.failure == nil)
        let after = try readInkFrame(renderer, width: 128, height: 128)
        #expect(after == before)
        let currentFrame = renderer.frameFailureReporter()
        currentFrame("Current seed failed")
        #expect(model.failure == "Current seed failed")
        model.stop()
        currentFrame("Stopped scene failed")
        #expect(model.failure == nil && model.renderer == nil)
        await model.load(seed: 42, using: StaticFixtureGenerator())
        oldFrame("Old lifetime failed")
        currentFrame("Other old lifetime failed")
        #expect(model.failure == nil && model.installedSeed == 42)
        let restarted = try readInkFrame(try #require(model.renderer), width: 128, height: 128)
        #expect(Int(restarted[64 * 128 + 64].z) > Int(restarted[64 * 128 + 64].x) + 50)
        model.stop()
    }
}
