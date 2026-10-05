import BackgroundCore
import MetalKit
import Observation

@MainActor @Observable
final class InkSceneModel {
    private(set) var renderer: ShanShuiRenderer?
    private(set) var failure: String?
    private(set) var installedSeed: UInt64?
    @ObservationIgnored private let preparer: any InkScenePreparing
    @ObservationIgnored private var generation: UInt64 = 0

    init(preparer: any InkScenePreparing = InkSceneBuilder()) { self.preparer = preparer }

    /// Newer requests and stop invalidate previous work; exercised by
    /// newerSeedWinsBothCompletionOrders and stoppedRequestCannotInstallAndSameSeedRestarts.
    func load<Generator: BackgroundGenerator>(seed: UInt64, using generator: Generator,
        clippingToBounds: Bool = false) async where Generator.Scene == InkScene {
        generation &+= 1
        let ticket: UInt64 = generation
        failure = nil
        do {
            let prepared = try await preparer.prepare(seed: seed, using: generator,
                                                     clippingToBounds: clippingToBounds)
            try Task.checkCancellation()
            guard ticket == generation else { return }
            let current: ShanShuiRenderer
            if let renderer { current = renderer }
            else {
                guard let device = MTLCreateSystemDefaultDevice() else { throw ShanShuiRenderError.unavailable }
                current = try ShanShuiRenderer(device: device)
            }
            try current.install(prepared.scene, mesh: prepared.mesh)
            current.onFailure = { [weak self] message in
                guard let self, self.generation == ticket else { return }
                self.failure = message
            }
            renderer = current
            installedSeed = seed
            failure = nil
        } catch is CancellationError {
            // Cancellation is a view lifecycle event, with no failure presentation.
        } catch {
            if ticket == generation && !Task.isCancelled { failure = error.localizedDescription }
        }
    }

    func stop() {
        generation &+= 1
        renderer?.onFailure = nil
        renderer = nil
        installedSeed = nil
        failure = nil
    }
}
