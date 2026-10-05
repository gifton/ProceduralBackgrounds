import SwiftUI

public struct MondrianScrollingDesign: BackgroundDesign {
    public static let title: String = "Mondrian scrolling"
    private let isPlaying: Bool

    public init(isPlaying: Bool = true) { self.isPlaying = isPlaying }

    public func makeView(seed: UInt64) -> some View {
        InkScrollingView(seed: seed, isPlaying: isPlaying, source: .mondrian)
            .id(InkScrollIdentity(source: "mondrian", seed: seed))
    }
}
