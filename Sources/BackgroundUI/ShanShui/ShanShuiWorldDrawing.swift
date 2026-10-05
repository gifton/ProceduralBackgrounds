import BackgroundCore
import Metal

/// Resident local buffers; the renderer owns this helper on the main actor.
@MainActor
final class ShanShuiWorldDrawing {
    struct Buffer {
        let storage: (any MTLBuffer)?
        let count: Int
    }

    let seed: UInt64
    let sourceID: String
    private let buffers: [Int64: Buffer]
    private var camera: ShanShuiCamera
    private var viewport: ShanShuiScrollViewport

    init(device: any MTLDevice, seed: UInt64, chunks: [ShanShuiPreparedChunk],
         camera: ShanShuiCamera, viewport: ShanShuiScrollViewport,
         reusing previous: ShanShuiWorldDrawing?, sourceID: String = "shanShui") throws {
        try ShanShuiChunkBuilder.validate(chunks.map { $0.chunk.index })
        let indices = Set(chunks.map { $0.chunk.index })
        guard try camera.window(width: viewport.visibleWidth, prefetch: 0).allSatisfy(indices.contains) else {
            throw ShanShuiWorldError.invalidWindow
        }
        var next: [Int64: Buffer] = [:]
        for prepared in chunks {
            let scene = prepared.chunk.scene
            guard abs(scene.bounds.x - 1200) < 1e-12, abs(scene.bounds.y - 800) < 1e-12 else {
                throw ShanShuiWorldError.invalidWindow
            }
            let index: Int64 = prepared.chunk.index
            if previous?.seed == seed, previous?.sourceID == sourceID, let buffer = previous?.buffers[index] {
                next[index] = buffer
                continue
            }
            let mesh = prepared.mesh
            let storage: (any MTLBuffer)?
            if mesh.vertices.isEmpty {
                storage = nil
            } else {
                storage = mesh.vertices.withUnsafeBufferPointer { vertices in
                    guard let base = vertices.baseAddress else { return nil }
                    return device.makeBuffer(bytes: base,
                        length: vertices.count * MemoryLayout<InkVertex>.stride, options: .storageModeShared)
                }
                guard storage != nil else { throw ShanShuiRenderError.allocationFailed }
            }
            next[index] = Buffer(storage: storage, count: mesh.vertices.count)
        }
        self.seed = seed
        self.sourceID = sourceID
        self.buffers = next
        self.camera = camera
        self.viewport = viewport
    }

    func bufferIdentity(for index: Int64) -> ObjectIdentifier? {
        buffers[index]?.storage.map { ObjectIdentifier($0) }
    }

    /// Returns false without mutation when visible ink is unprepared.
    /// cameraTranslationReusesBuffersAndRejectsMissingChunks checks the prior frame.
    func update(camera: ShanShuiCamera, viewport: ShanShuiScrollViewport) throws -> Bool {
        guard try camera.window(width: viewport.visibleWidth, prefetch: 0)
            .allSatisfy({ buffers[$0] != nil }) else { return false }
        self.camera = camera
        self.viewport = viewport
        return true
    }

    func encode(into encoder: any MTLRenderCommandEncoder, width: Int, height: Int) throws {
        let scale: Double = Double(height) / 800
        let span: Double = min(viewport.visibleWidth, Double(width) / scale)
        let activePixels: Double = min(Double(width), span * scale)
        let left: Int = Int(ceil((Double(width) - activePixels) / 2))
        let right: Int = Int(floor((Double(width) + activePixels) / 2))
        guard right > left else { return }
        encoder.setScissorRect(MTLScissorRect(x: left, y: 0, width: right - left, height: height))
        for index in try camera.window(width: span, prefetch: 0) {
            guard let buffer = buffers[index] else { throw ShanShuiWorldError.invalidWindow }
            guard let storage = buffer.storage, buffer.count > 0 else { continue }
            let origin: Double = try camera.relativeOrigin(for: index)
            var transform: SIMD4<Float> = [
                Float(2 * scale / Double(width)), Float(-2 * scale / Double(height)),
                Float(2 * origin * scale / Double(width)), 1
            ]
            encoder.setVertexBuffer(storage, offset: 0, index: 0)
            encoder.setVertexBytes(&transform, length: MemoryLayout<SIMD4<Float>>.stride, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: buffer.count)
        }
    }
}
