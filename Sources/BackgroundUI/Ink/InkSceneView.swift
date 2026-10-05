import BackgroundCore
import SwiftUI

struct InkScenePresentation: Sendable {
    let title: String
    let loadingText: String
    var failureTitle: String { "\(title) couldn’t draw" }
    static let shanShui = InkScenePresentation(title: "Shan Shui", loadingText: "Preparing ink…")
}

@MainActor
struct InkSceneView<Generator: BackgroundGenerator>: View where Generator.Scene == InkScene {
    let seed: UInt64
    let generator: Generator
    let presentation: InkScenePresentation
    let clippingToBounds: Bool
    @State private var model = InkSceneModel()

    init(seed: UInt64, generator: Generator,
         presentation: InkScenePresentation = .shanShui, clippingToBounds: Bool = false) {
        self.seed = seed
        self.generator = generator
        self.presentation = presentation
        self.clippingToBounds = clippingToBounds
    }

    var body: some View {
        ZStack {
            if let failure = model.failure {
                ContentUnavailableView(presentation.failureTitle, systemImage: "paintbrush",
                                       description: Text(failure))
            } else if let renderer = model.renderer {
                ShanShuiMetalView(renderer: renderer).accessibilityHidden(true)
            } else {
                ProgressView(presentation.loadingText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PaperDesign.color)
        .task(id: seed) {
            await model.load(seed: seed, using: generator, clippingToBounds: clippingToBounds)
        }
        .onDisappear { model.stop() }
    }
}
