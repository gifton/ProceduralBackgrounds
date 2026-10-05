import BackgroundCore
import MetalKit

enum ShanShuiRenderError: Error, LocalizedError, Equatable {
    case unavailable
    case shaderResourceMissing
    case allocationFailed
    case invalidSurfaceColor

    var errorDescription: String? {
        switch self {
        case .unavailable: "Metal rendering is unavailable on this device."
        case .shaderResourceMissing: "The Shan Shui drawing resources could not be loaded."
        case .allocationFailed: "The drawing surface could not be created."
        case .invalidSurfaceColor: "The drawing surface color is invalid."
        }
    }
}

/// Main-actor ownership matches the SDK's main-actor MetalKit delegate callbacks.
/// Static buffers are replaced on seed changes; ordinary draws only encode two passes.
@MainActor
final class ShanShuiRenderer: NSObject, MTKViewDelegate {
    let device: any MTLDevice
    var onFailure: (@MainActor (String) -> Void)?
    private let queue: any MTLCommandQueue
    private let inkPipeline: any MTLRenderPipelineState
    private let paperPipeline: any MTLRenderPipelineState
    private let sampleCount: Int
    private var vertexBuffer: (any MTLBuffer)?
    private var vertexCount: Int = 0
    private var sceneBounds: SIMD2<Double> = [800, 800]
    private var world: ShanShuiWorldDrawing?
    private var seed: UInt32 = 0
    private var surfaceColor: SIMD3<Double> = SIMD3(repeating: 1)
    private var inkTexture: (any MTLTexture)?
    private var multisampleTexture: (any MTLTexture)?
    private weak var view: MTKView?

    init(device: any MTLDevice) throws {
        self.device = device
        guard let queue = device.makeCommandQueue() else { throw ShanShuiRenderError.unavailable }
        self.queue = queue
        self.sampleCount = device.supportsTextureSampleCount(4) ? 4 : 1

        let library: any MTLLibrary
        if Bundle.module.url(forResource: "default", withExtension: "metallib") != nil {
            library = try device.makeDefaultLibrary(bundle: .module)
        } else {
            // SwiftPM's command-line build copies source; Xcode compiles the resource.
            guard let url = Bundle.module.url(forResource: "ShanShui", withExtension: "metal") else {
                throw ShanShuiRenderError.shaderResourceMissing
            }
            library = try device.makeLibrary(source: String(contentsOf: url, encoding: .utf8), options: nil)
        }

        let ink = MTLRenderPipelineDescriptor()
        ink.vertexFunction = library.makeFunction(name: "inkVertex")
        ink.fragmentFunction = library.makeFunction(name: "inkFragment")
        ink.rasterSampleCount = sampleCount
        ink.colorAttachments[0].pixelFormat = .bgra8Unorm
        ink.colorAttachments[0].isBlendingEnabled = true
        ink.colorAttachments[0].sourceRGBBlendFactor = .one
        ink.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        ink.colorAttachments[0].sourceAlphaBlendFactor = .one
        ink.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        inkPipeline = try device.makeRenderPipelineState(descriptor: ink)

        let paper = MTLRenderPipelineDescriptor()
        paper.vertexFunction = library.makeFunction(name: "paperVertex")
        paper.fragmentFunction = library.makeFunction(name: "paperFragment")
        paper.colorAttachments[0].pixelFormat = .bgra8Unorm
        paperPipeline = try device.makeRenderPipelineState(descriptor: paper)
        super.init()
    }

    func install(_ scene: ShanShuiScene, mesh: InkMesh) throws {
        let buffer: (any MTLBuffer)?
        if mesh.vertices.isEmpty {
            buffer = nil
        } else {
            buffer = mesh.vertices.withUnsafeBufferPointer { vertices in
                guard let base = vertices.baseAddress else { return nil }
                return device.makeBuffer(bytes: base, length: vertices.count * MemoryLayout<InkVertex>.stride,
                                         options: .storageModeShared)
            }
            guard buffer != nil else { throw ShanShuiRenderError.allocationFailed }
        }
        vertexBuffer = buffer
        world = nil
        surfaceColor = SIMD3(repeating: 1)
        vertexCount = mesh.vertices.count
        sceneBounds = scene.bounds
        seed = UInt32(truncatingIfNeeded: scene.seed ^ (scene.seed >> 32))
        invalidate()
    }

    func installWorld(seed: UInt64, chunks: [ShanShuiPreparedChunk],
                      camera: ShanShuiCamera, viewport: ShanShuiScrollViewport,
                      sourceID: String = "shanShui",
                      surfaceColor: SIMD3<Double> = SIMD3(repeating: 1)) throws {
        guard [surfaceColor.x, surfaceColor.y, surfaceColor.z].allSatisfy({
            $0.isFinite && (0...1).contains($0)
        }) else { throw ShanShuiRenderError.invalidSurfaceColor }
        let drawing = try ShanShuiWorldDrawing(device: device, seed: seed, chunks: chunks,
                                              camera: camera, viewport: viewport, reusing: world, sourceID: sourceID)
        world = drawing
        self.surfaceColor = surfaceColor
        vertexBuffer = nil
        vertexCount = 0
        self.seed = UInt32(truncatingIfNeeded: seed ^ (seed >> 32))
        invalidate()
    }

    func updateWorldCamera(_ camera: ShanShuiCamera,
                           viewport: ShanShuiScrollViewport) throws -> Bool {
        guard let world, try world.update(camera: camera, viewport: viewport) else { return false }
        invalidate()
        return true
    }

    func worldBufferIdentity(for index: Int64) -> ObjectIdentifier? {
        world?.bufferIdentity(for: index)
    }

    func attach(to view: MTKView) {
        self.view = view
        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.autoResizeDrawable = true
        view.delegate = self
        invalidate()
    }

    private func invalidate() {
        #if os(macOS)
        view?.needsDisplay = true
        #else
        view?.setNeedsDisplay()
        #endif
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        invalidate()
    }

    func draw(in view: MTKView) {
        // Hidden/minimized views may have no drawable; wait for the next view event.
        guard view.drawableSize.width > 0, view.drawableSize.height > 0,
              let drawable = view.currentDrawable else { return }
        do {
            let command = try encodeFrame(into: drawable.texture)
            let reportFailure = frameFailureReporter()
            command.addCompletedHandler { completed in
                guard completed.status == .error else { return }
                let message = completed.error?.localizedDescription ?? "The background could not be drawn."
                Task { @MainActor in reportFailure(message) }
            }
            command.present(drawable)
            command.commit()
        } catch {
            onFailure?(error.localizedDescription)
        }
    }

    func frameFailureReporter() -> @MainActor @Sendable (String) -> Void {
        // Retain the callback from submission, not a newer installation's callback.
        // Tests: frameFailureUsesTheCallbackFromSubmission and
        // delayedFrameFailureCannotReplaceNewSceneOrRestart.
        let callback = onFailure
        return { message in callback?(message) }
    }

    /// The view and GPU readback tests use this same two-pass rendering path.
    /// Tests: `paperAndMountainRenderThroughProductionShaders` and
    /// `laterWhiteWashOccludesInkAndRetainsPaperTexture`.
    func encodeFrame(into output: any MTLTexture) throws -> any MTLCommandBuffer {
        try ensureTargets(width: output.width, height: output.height)
        guard let inkTexture, let command = queue.makeCommandBuffer() else {
            throw ShanShuiRenderError.allocationFailed
        }
        command.label = "Shan Shui ink and paper"

        let inkPass = MTLRenderPassDescriptor()
        let attachment = inkPass.colorAttachments[0]!
        attachment.texture = multisampleTexture ?? inkTexture
        attachment.clearColor = MTLClearColorMake(surfaceColor.x, surfaceColor.y, surfaceColor.z, 1)
        attachment.loadAction = .clear
        if sampleCount > 1 {
            attachment.resolveTexture = inkTexture
            attachment.storeAction = .multisampleResolve
        } else {
            attachment.storeAction = .store
        }
        guard let encoder = command.makeRenderCommandEncoder(descriptor: inkPass) else {
            throw ShanShuiRenderError.allocationFailed
        }
        encoder.label = "Ordered ink primitives"
        encoder.setRenderPipelineState(inkPipeline)
        if let world {
            try world.encode(into: encoder, width: output.width, height: output.height)
        } else if let vertexBuffer, vertexCount > 0 {
            let scale = min(Double(output.width) / sceneBounds.x, Double(output.height) / sceneBounds.y)
            var transform = SIMD4<Float>(
                Float(2 * scale / Double(output.width)), Float(-2 * scale / Double(output.height)),
                Float(-sceneBounds.x * scale / Double(output.width)),
                Float(sceneBounds.y * scale / Double(output.height)))
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.setVertexBytes(&transform, length: MemoryLayout<SIMD4<Float>>.stride, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
        }
        encoder.endEncoding()

        let paperPass = MTLRenderPassDescriptor()
        paperPass.colorAttachments[0].texture = output
        paperPass.colorAttachments[0].loadAction = .dontCare
        paperPass.colorAttachments[0].storeAction = .store
        guard let composite = command.makeRenderCommandEncoder(descriptor: paperPass) else {
            throw ShanShuiRenderError.allocationFailed
        }
        composite.label = "Paper composite"
        composite.setRenderPipelineState(paperPipeline)
        composite.setFragmentTexture(inkTexture, index: 0)
        var paperSeed = seed
        composite.setFragmentBytes(&paperSeed, length: MemoryLayout<UInt32>.stride, index: 0)
        composite.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        composite.endEncoding()
        return command
    }

    private func ensureTargets(width: Int, height: Int) throws {
        if inkTexture?.width == width, inkTexture?.height == height { return }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .private
        descriptor.usage = [.renderTarget, .shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw ShanShuiRenderError.allocationFailed
        }
        var multisample: (any MTLTexture)?
        if sampleCount > 1 {
            descriptor.textureType = .type2DMultisample
            descriptor.sampleCount = sampleCount
            descriptor.usage = .renderTarget
            multisample = device.makeTexture(descriptor: descriptor)
            guard multisample != nil else { throw ShanShuiRenderError.allocationFailed }
        }
        inkTexture = texture
        multisampleTexture = multisample
    }
}
