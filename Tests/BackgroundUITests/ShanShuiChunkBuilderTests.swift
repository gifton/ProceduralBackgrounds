import BackgroundCore
@testable import BackgroundUI
import Synchronization
import Testing

struct ShanShuiChunkBuilderTests {
    @Test
    func overlappingChunksReuseAndEvictedInkReplays() async throws {
        let calls = Mutex<[Int64]>([])
        let builder = ShanShuiChunkBuilder { seed, index in
            calls.withLock { $0.append(index) }
            return try Self.fixture(seed: seed, index: index)
        }
        let a = try await builder.prepare(seed: 42, indices: [-1, 0, 1])
        try await builder.commit(seed: 42, chunks: a)
        let b = try await builder.prepare(seed: 42, indices: [0, 1, 2])
        #expect(a[1] === b[0] && a[2] === b[1])
        #expect(calls.withLock { $0 } == [-1, 0, 1, 2])
        try await builder.commit(seed: 42, chunks: b)
        let distant = try await builder.prepare(seed: 42, indices: [10, 11, 12])
        try await builder.commit(seed: 42, chunks: distant)
        let replay = try await builder.prepare(seed: 42, indices: [0])
        #expect(replay[0] !== a[1])
        #expect(replay[0].mesh.vertices.count == a[1].mesh.vertices.count)
        for (u, v) in zip(replay[0].mesh.vertices, a[1].mesh.vertices) {
            #expect(abs(u.position.x - v.position.x) < 1e-6)
            #expect(abs(u.color.x - v.color.x) < 1e-6)
        }
        let changed = try await builder.prepare(seed: 43, indices: [0])
        #expect(changed[0] !== replay[0])
        #expect(abs(changed[0].mesh.vertices[0].color.x - replay[0].mesh.vertices[0].color.x) > 1e-3)
    }

    @Test
    func discardedPreparationDoesNotRetainAThirdWindow() async throws {
        let builder = ShanShuiChunkBuilder(makeChunk: Self.fixture)
        let accepted = try await builder.prepare(seed: 42, indices: [-1, 0, 1])
        try await builder.commit(seed: 42, chunks: accepted)
        var discarded: [ShanShuiPreparedChunk]? = try await builder.prepare(seed: 42, indices: [10, 11, 12])
        let reference = WeakPreparedChunk(discarded?.first)
        discarded = nil
        #expect(reference.value == nil)
        let reuse = try await builder.prepare(seed: 42, indices: [-1, 0, 1])
        #expect(reuse[0] === accepted[0])
    }

    @Test
    func invalidAndCancelledWindowsKeepTheAcceptedCache() async throws {
        let cancelNext = Mutex<Bool>(false)
        let builder = ShanShuiChunkBuilder { seed, index in
            let result = try Self.fixture(seed: seed, index: index)
            if cancelNext.withLock({ value in let old = value; value = false; return old }) {
                withUnsafeCurrentTask { $0?.cancel() }
            }
            return result
        }
        let accepted = try await builder.prepare(seed: 42, indices: [0])
        try await builder.commit(seed: 42, chunks: accepted)
        for invalid: [Int64] in [[], [0, 0], [1, 0], [0, 2], Array(0...7)] {
            await #expect(throws: ShanShuiWorldError.self) {
                try await builder.prepare(seed: 42, indices: invalid)
            }
        }
        cancelNext.withLock { $0 = true }
        let cancelled = Task { try await builder.prepare(seed: 42, indices: [5, 6, 7]) }
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        let reused = try await builder.prepare(seed: 42, indices: [0])
        #expect(reused[0] === accepted[0])
        for edge: [Int64] in [[.min, .min + 1], [.max - 1, .max]] {
            #expect(try await builder.prepare(seed: 42, indices: edge).count == 2)
        }
    }

    @Test(arguments: [UInt64(0), 42, UInt64.max, 793_993, 7_293_725_857_078_157_220])
    func generatedChunksCompileWithLocalCoordinates(seed: UInt64) async throws {
        let builder = ShanShuiChunkBuilder()
        for index: Int64 in [-8, -2, -1, 0, 1, 2, 8] {
            let prepared = try #require(try await builder.prepare(seed: seed, indices: [index]).first)
            #expect(prepared.mesh.vertices.count > 1000)
            #expect(prepared.mesh.vertices.allSatisfy {
                $0.position.x.isFinite && $0.position.y.isFinite
                    && $0.position.x >= -1e-4 && $0.position.x <= 1200.0001
                    && $0.position.y >= -1e-4 && $0.position.y <= 800.0001
            })
        }
    }

    private static func fixture(seed: UInt64, index: Int64) throws -> ShanShuiPreparedChunk {
        let scene = ShanShuiScene(seed: seed, bounds: [1200, 800], primitives: [
            .wash(points: [[100, 100], [200, 100], [200, 200], [100, 200]],
                  tone: Double(seed % 10) / 10, opacity: 1)
        ])
        return ShanShuiPreparedChunk(chunk: .init(index: index, scene: scene),
                                    mesh: try InkMeshCompiler().compile(scene))
    }
}

private final class WeakPreparedChunk {
    weak var value: ShanShuiPreparedChunk?
    init(_ value: ShanShuiPreparedChunk?) { self.value = value }
}
