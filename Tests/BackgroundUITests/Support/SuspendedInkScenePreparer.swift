import BackgroundCore
@testable import BackgroundUI
import Foundation

/// Keeps real scene/mesh work, suspending only completion to exercise stale loads.
actor SuspendedInkScenePreparer: InkScenePreparing {
    private struct Pending {
        let prepared: InkPreparedScene
        let continuation: CheckedContinuation<InkPreparedScene, any Error>
    }
    private var requests: [Int: Pending] = [:]
    private var nextID: Int = 0
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func prepare<Generator: BackgroundGenerator>(seed: UInt64, using generator: Generator,
        clippingToBounds: Bool) async throws -> InkPreparedScene where Generator.Scene == InkScene {
        let scene = generator.generate(seed: seed)
        let prepared = InkPreparedScene(scene: scene,
            mesh: try InkMeshCompiler().compile(scene, clippingToBounds: clippingToBounds))
        let number: Int = nextID
        nextID += 1
        return try await withCheckedThrowingContinuation { continuation in
            requests[number] = Pending(prepared: prepared, continuation: continuation)
            let ready = waiters.filter { requests.count >= $0.0 }
            waiters.removeAll { requests.count >= $0.0 }
            for (_, waiter) in ready { waiter.resume() }
        }
    }

    func waitForPendingCount(_ count: Int) async {
        guard requests.count < count else { return }
        await withCheckedContinuation { waiters.append((count, $0)) }
    }

    func release(_ number: Int, failing: Bool = false) throws {
        guard let pending = requests.removeValue(forKey: number) else { throw FixtureError.missingRequest }
        if failing { pending.continuation.resume(throwing: FixtureError.injected) }
        else { pending.continuation.resume(returning: pending.prepared) }
    }

    private enum FixtureError: LocalizedError {
        case missingRequest, injected
        var errorDescription: String? {
            switch self {
            case .missingRequest: "The static fixture request does not exist."
            case .injected: "Injected static preparation failure."
            }
        }
    }
}

struct StaticFixtureGenerator: BackgroundGenerator {
    func generate(seed: UInt64) -> InkScene {
        let color: SIMD3<Double> = seed == 42 ? [0.8, 0.1, 0.1] : [0.1, 0.2, 0.8]
        return InkScene(seed: seed, bounds: [800, 800], primitives: [
            .colorWash(points: [[100, 100], [700, 100], [700, 700], [100, 700]], color: color, opacity: 1)
        ])
    }
}
