import BackgroundCore

/// Immutable CPU work can cross from the worker to the renderer's main actor.
final class ShanShuiPreparedChunk: Sendable {
    let chunk: ShanShuiLandscapeChunk
    let mesh: InkMesh

    init(chunk: ShanShuiLandscapeChunk, mesh: InkMesh) {
        self.chunk = chunk
        self.mesh = mesh
    }
}

protocol ShanShuiChunkPreparing: Sendable {
    func prepare(seed: UInt64, indices: [Int64]) async throws -> [ShanShuiPreparedChunk]
    func commit(seed: UInt64, chunks: [ShanShuiPreparedChunk]) async throws
}

/// Keeps the accepted window; a superseded preparation never becomes the cache.
/// Tested by discardedPreparationDoesNotRetainAThirdWindow.
actor ShanShuiChunkBuilder: ShanShuiChunkPreparing {
    private let makeChunk: @Sendable (UInt64, Int64) throws -> ShanShuiPreparedChunk
    private var cachedSeed: UInt64?
    private var cache: [Int64: ShanShuiPreparedChunk] = [:]

    init(makeChunk: @escaping @Sendable (UInt64, Int64) throws -> ShanShuiPreparedChunk) {
        self.makeChunk = makeChunk
    }

    init() {
        makeChunk = { seed, index in
            let chunk = ShanShuiLandscapeChunkGenerator().generate(seed: seed, index: index)
            return ShanShuiPreparedChunk(chunk: chunk, mesh: try InkMeshCompiler().compile(chunk.scene))
        }
    }

    func prepare(seed: UInt64, indices: [Int64]) throws -> [ShanShuiPreparedChunk] {
        try Self.validate(indices)
        let reusable: [Int64: ShanShuiPreparedChunk] = cachedSeed == seed ? cache : [:]
        var next: [ShanShuiPreparedChunk] = []
        for index in indices {
            try Task.checkCancellation()
            next.append(try reusable[index] ?? makeChunk(seed, index))
        }
        try Task.checkCancellation()
        return next
    }

    func commit(seed: UInt64, chunks: [ShanShuiPreparedChunk]) throws {
        try Task.checkCancellation()
        try Self.validate(chunks.map { $0.chunk.index })
        cache = Dictionary(uniqueKeysWithValues: chunks.map { ($0.chunk.index, $0) })
        cachedSeed = seed
    }

    static func validate(_ indices: [Int64]) throws {
        guard !indices.isEmpty, indices.count <= 7 else { throw ShanShuiWorldError.invalidWindow }
        for (a, b) in zip(indices, indices.dropFirst()) {
            let next = a.addingReportingOverflow(1)
            guard !next.overflow, next.partialValue == b else { throw ShanShuiWorldError.invalidWindow }
        }
    }
}
