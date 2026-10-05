import BackgroundCore
import BackgroundUI
import SwiftUI

/// The harness owns discovery; adding a case requires adding its typed view below.
enum PreviewDesign: String, CaseIterable, Identifiable {
    case layeredHills
    case shanShui
    case shanShuiLandscape
    case shanShuiScrolling
    case shanShuiElements
    case gardenWall
    case nightSky
    case mondrian
    case mondrianScrolling
    case paper

    var id: String { rawValue }

    var supportsPlayback: Bool {
        switch self {
        case .shanShuiScrolling, .gardenWall, .nightSky, .mondrianScrolling: true
        case .layeredHills, .shanShui, .shanShuiLandscape, .shanShuiElements, .mondrian, .paper: false
        }
    }

    @MainActor var title: String {
        switch self {
        case .layeredHills: LayeredHillsDesign.title
        case .shanShui: ShanShuiDesign.title
        case .shanShuiLandscape: ShanShuiLandscapeDesign.title
        case .shanShuiScrolling: ShanShuiScrollingDesign.title
        case .shanShuiElements: ShanShuiElementDesign.title
        case .gardenWall: GardenWallDesign.title
        case .nightSky: NightSkyDesign.title
        case .mondrian: MondrianDesign.title
        case .mondrianScrolling: MondrianScrollingDesign.title
        case .paper: PaperDesign.title
        }
    }

    @MainActor @ViewBuilder
    func makeView(seed: UInt64, element: ShanShuiElement = .leafyTree,
                  isPlaying: Bool = true, scrollResetID: UInt64 = 0) -> some View {
        switch self {
        case .layeredHills: LayeredHillsDesign().makeView(seed: seed)
        case .shanShui: ShanShuiDesign().makeView(seed: seed)
        case .shanShuiLandscape: ShanShuiLandscapeDesign().makeView(seed: seed)
        case .shanShuiScrolling:
            ShanShuiScrollingDesign(isPlaying: isPlaying).makeView(seed: seed).id(scrollResetID)
        case .shanShuiElements: ShanShuiElementDesign(element: element).makeView(seed: seed)
        case .gardenWall:
            GardenWallDesign(isPlaying: isPlaying).makeView(seed: seed).id(scrollResetID)
        case .nightSky:
            NightSkyDesign(isPlaying: isPlaying).makeView(seed: seed).id(scrollResetID)
        case .mondrian: MondrianDesign().makeView(seed: seed)
        case .mondrianScrolling:
            MondrianScrollingDesign(isPlaying: isPlaying).makeView(seed: seed).id(scrollResetID)
        case .paper: PaperDesign().makeView(seed: seed)
        }
    }
}
