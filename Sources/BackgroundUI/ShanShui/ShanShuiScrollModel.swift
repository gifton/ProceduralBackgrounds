import BackgroundCore
import MetalKit
import Observation

@MainActor @Observable
final class ShanShuiScrollModel {
    private struct Request {
        let camera: ShanShuiCamera
        let viewport: ShanShuiScrollViewport
        let indices: [Int64]
    }
    private struct Drag {
        let camera: ShanShuiCamera
        let scale: Double
    }

    private(set) var renderer: ShanShuiRenderer?
    private(set) var failure: String?
    // The literal 600 satisfies the camera initializer's [0,1200) guard.
    private(set) var camera: ShanShuiCamera = try! ShanShuiCamera()
    private let seed: UInt64
    private let source: InkScrollSource
    @ObservationIgnored private var preparer: (any ShanShuiChunkPreparing)?
    @ObservationIgnored private var loadingTask: Task<Void, Never>?
    private var desired: Request?
    private var pending: [Int64]?
    private var preparing: [Int64]?
    private var accepted: [Int64]?
    private var dragStart: Drag?
    private var buffering: Bool = true
    private var stopped: Bool = false
    private var playing: Bool = false
    private var active: Bool = false
    private var reducedMotion: Bool = false

    init(seed: UInt64, preparer: any ShanShuiChunkPreparing = ShanShuiChunkBuilder()) {
        self.seed = seed
        self.source = .shanShui
        self.preparer = preparer
    }

    init(seed: UInt64, source: InkScrollSource) {
        self.seed = seed
        self.source = source
        self.preparer = source.makePreparer()
    }

    var playbackAllowed: Bool {
        playing && active && !reducedMotion && dragStart == nil && !buffering
            && !stopped && failure == nil && renderer != nil
    }

    func setPlayback(requested: Bool, active: Bool, reduceMotion: Bool) {
        playing = requested
        self.active = active
        reducedMotion = reduceMotion
    }

    func request(camera: ShanShuiCamera, viewport: ShanShuiScrollViewport) {
        guard !stopped else { return }
        do {
            let indices = try camera.window(width: viewport.visibleWidth)
            desired = Request(camera: camera, viewport: viewport, indices: indices)
            let drawable: Bool = try renderer?.updateWorldCamera(camera, viewport: viewport) ?? false
            buffering = !drawable
            if drawable { self.camera = camera }
            if indices == accepted {
                pending = nil
                return
            }
            if indices == preparing {
                pending = nil
                return
            }
            pending = indices
            guard loadingTask == nil else { return }
            loadingTask = Task {
                self.preparing = self.pending
                await self.loadWindows()
            }
        } catch {
            failure = error.localizedDescription
        }
    }

    /// One active preparation plus one replaceable pending window. Tests:
    /// rapidRequestsCoalesceAndOnlyLatestWindowInstalls and
    /// removalAndSeedReplacementRejectOldCompletions.
    private func loadWindows() async {
        defer { loadingTask = nil; preparing = nil }
        while let indices = pending, let preparer, !stopped, !Task.isCancelled {
            pending = nil
            preparing = indices
            do {
                let chunks = try await preparer.prepare(seed: seed, indices: indices)
                try Task.checkCancellation()
                guard !stopped, let latest = desired else { return }
                guard latest.indices == indices else { continue }
                let current: ShanShuiRenderer
                if let renderer {
                    current = renderer
                } else {
                    guard let device = MTLCreateSystemDefaultDevice() else {
                        throw ShanShuiRenderError.unavailable
                    }
                    current = try ShanShuiRenderer(device: device)
                }
                current.onFailure = { [weak self] message in
                    guard let self, !self.stopped else { return }
                    self.failure = message
                }
                try current.installWorld(seed: seed, chunks: chunks, camera: latest.camera,
                                         viewport: latest.viewport, sourceID: source.id,
                                         surfaceColor: source.surfaceColor)
                renderer = current
                camera = latest.camera
                accepted = indices
                buffering = false
                failure = nil
                try await preparer.commit(seed: seed, chunks: chunks)
            } catch {
                if !stopped, !Task.isCancelled {
                    failure = error.localizedDescription
                    pending = nil
                }
                return
            }
        }
    }

    func beginDrag() {
        guard !stopped, dragStart == nil, let viewport = desired?.viewport else { return }
        dragStart = Drag(camera: camera, scale: viewport.scale)
    }

    func drag(translation: Double) {
        guard let dragStart, let viewport = desired?.viewport else { return }
        do {
            let moved = try dragStart.camera.moving(by: -translation / dragStart.scale)
            request(camera: moved, viewport: viewport)
        } catch { failure = error.localizedDescription }
    }

    func endDrag() { dragStart = nil }

    func advance(elapsed: Duration) {
        guard playbackAllowed, let viewport = desired?.viewport else { return }
        let components = elapsed.components
        let seconds: Double = Double(components.seconds) + Double(components.attoseconds) / 1e18
        guard seconds > 0 else { return }
        do {
            request(camera: try camera.moving(by: min(0.1, seconds) * 20), viewport: viewport)
        } catch { failure = error.localizedDescription }
    }

    func report(_ error: any Error) { if !stopped { failure = error.localizedDescription } }

    /// A retained view gets a new lifetime after stop; its cancelled model stays
    /// stopped. retainedPreviewCreatesAFreshSessionAfterDisappearance covers it.
    func sessionForAppearance() -> ShanShuiScrollModel {
        stopped ? ShanShuiScrollModel(seed: seed, source: source) : self
    }

    func stop() {
        stopped = true
        active = false
        pending = nil
        desired = nil
        loadingTask?.cancel()
        preparer = nil
        renderer = nil
    }

    /// Await the current loading cycle, including a coalesced replacement.
    func settle() async { await loadingTask?.value }
}
