import BackgroundCore
import SwiftUI

public struct ShanShuiScrollingDesign: BackgroundDesign {
    public static let title: String = "Shan Shui scrolling"
    private let isPlaying: Bool

    public init(isPlaying: Bool = true) { self.isPlaying = isPlaying }

    public func makeView(seed: UInt64) -> some View {
        InkScrollingView(seed: seed, isPlaying: isPlaying, source: .shanShui)
            .id(InkScrollIdentity(source: "shanShui", seed: seed))
    }
}

