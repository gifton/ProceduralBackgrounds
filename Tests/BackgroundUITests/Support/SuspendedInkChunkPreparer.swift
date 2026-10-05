import BackgroundCore
@testable import BackgroundUI

func scrollFixture(seed: UInt64, index: Int64) throws -> ShanShuiPreparedChunk {
    let scene = ShanShuiScene(seed: seed, bounds: [1200, 800], primitives: [
        .wash(points: [[100, 100], [300, 100], [300, 300], [100, 300]],
              tone: Double(seed % 10) / 10, opacity: 1)
    ])
    return ShanShuiPreparedChunk(chunk: .init(index: index, scene: scene),
                                mesh: try InkMeshCompiler().compile(scene))
}

actor SuspendedChunkPreparer: ShanShuiChunkPreparing {
    struct Waiting {
        let seed: UInt64
        let indices: [Int64]
        let continuation: CheckedContinuation<[ShanShuiPreparedChunk], any Error>
    }
    private let makeChunk: @Sendable (UInt64, Int64) throws -> ShanShuiPreparedChunk
    init(makeChunk: @escaping @Sendable (UInt64, Int64) throws -> ShanShuiPreparedChunk = scrollFixture) {
        self.makeChunk = makeChunk
    }
    private var requests: [[Int64]] = []
    private var pending: [Waiting] = []
    private var observers: [(Int, CheckedContinuation<Void, Never>)] = []
    private(set) var committedIndices: [[Int64]] = []
    private(set) var committedSeeds: [UInt64] = []
    var requestCount: Int { requests.count }
    var lastIndices: [Int64] { requests.last ?? [] }

    func prepare(seed: UInt64, indices: [Int64]) async throws -> [ShanShuiPreparedChunk] {
        try await withCheckedThrowingContinuation { continuation in
            requests.append(indices)
            pending.append(Waiting(seed: seed, indices: indices, continuation: continuation))
            let ready = observers.filter { $0.0 <= requests.count }
            observers.removeAll { $0.0 <= requests.count }
            for (_, observer) in ready { observer.resume() }
        }
    }

    func commit(seed: UInt64, chunks: [ShanShuiPreparedChunk]) {
        committedIndices.append(chunks.map { $0.chunk.index })
        committedSeeds.append(seed)
    }

    func waitForRequestCount(_ count: Int) async {
        if requests.count >= count { return }
        await withCheckedContinuation { observers.append((count, $0)) }
    }

    func releaseNext(failing: Bool = false) throws {
        let waiting = pending.removeFirst()
        if failing {
            waiting.continuation.resume(throwing: ShanShuiWorldError.invalidWindow)
        } else {
            waiting.continuation.resume(returning: try waiting.indices.map {
                try makeChunk(waiting.seed, $0)
            })
        }
    }
}
