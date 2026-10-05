import BackgroundCore
import SwiftUI

@MainActor
struct InkScrollingView: View {
    private struct PreparationID: Hashable {
        let width: Double
        let height: Double
        let session: ObjectIdentifier
    }

    let isPlaying: Bool
    let source: InkScrollSource
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var model: ShanShuiScrollModel

    init(seed: UInt64, isPlaying: Bool, source: InkScrollSource) {
        self.source = source
        self.isPlaying = isPlaying
        _model = State(initialValue: ShanShuiScrollModel(seed: seed, source: source))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let failure = model.failure {
                    ContentUnavailableView("\(source.title) couldn’t draw", systemImage: "paintbrush",
                                           description: Text(failure))
                } else if let renderer = model.renderer {
                    ShanShuiMetalView(renderer: renderer).accessibilityHidden(true)
                } else {
                    ProgressView(source.loadingText)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(source.prefersDarkAppearance
                        ? Color(red: source.surfaceColor.x, green: source.surfaceColor.y, blue: source.surfaceColor.z)
                        : PaperDesign.color)
            .environment(\.colorScheme, source.prefersDarkAppearance ? .dark : colorScheme)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 3)
                .onChanged { value in
                    model.beginDrag()
                    model.drag(translation: Double(value.translation.width))
                }
                .onEnded { _ in model.endDrag() })
            .task(id: PreparationID(width: Double(geometry.size.width),
                                   height: Double(geometry.size.height),
                                   session: ObjectIdentifier(model))) {
                guard geometry.size.width > 0, geometry.size.height > 0 else { return }
                do {
                    let viewport = try ShanShuiScrollViewport(
                        size: [Double(geometry.size.width), Double(geometry.size.height)])
                    model.request(camera: model.camera, viewport: viewport)
                    await model.settle()
                } catch { model.report(error) }
            }
        }
        .onAppear {
            model = model.sessionForAppearance()
            updatePlayback()
        }
        .onChange(of: isPlaying) { updatePlayback() }
        .onChange(of: scenePhase) { updatePlayback() }
        .onChange(of: reduceMotion) { updatePlayback() }
        .onDisappear { model.stop() }
        .task(id: model.playbackAllowed) {
            guard model.playbackAllowed else { return }
            let clock = ContinuousClock()
            var previous = clock.now
            do {
                while !Task.isCancelled {
                    try await clock.sleep(for: .milliseconds(33))
                    try Task.checkCancellation()
                    let now = clock.now
                    model.advance(elapsed: previous.duration(to: now))
                    previous = now
                }
            } catch is CancellationError {
                // Paused, removed or inactive view: end this clock's lifetime.
            } catch { model.report(error) }
        }
    }

    private func updatePlayback() {
        model.setPlayback(requested: isPlaying, active: scenePhase == .active, reduceMotion: reduceMotion)
    }
}
