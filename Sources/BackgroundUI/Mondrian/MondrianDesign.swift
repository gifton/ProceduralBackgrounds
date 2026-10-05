import BackgroundCore
import SwiftUI

public struct MondrianDesign: BackgroundDesign {
    public static let title: String = "Mondrian watercolor"
    static let presentation = InkScenePresentation(title: title, loadingText: "Preparing painting…")

    public init() {}

    public func makeView(seed: UInt64) -> some View {
        InkSceneView(seed: seed, generator: MondrianGenerator(),
                     presentation: Self.presentation, clippingToBounds: true)
    }
}
