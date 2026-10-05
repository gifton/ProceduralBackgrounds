import SwiftUI

/// Painted moons, warm stars, and cloud wisps in a scrolling indigo sky.
public struct NightSkyDesign: BackgroundDesign {
    public static let title: String = "Night Sky"
    private let isPlaying: Bool

    public init(isPlaying: Bool = true) { self.isPlaying = isPlaying }

    public func makeView(seed: UInt64) -> some View {
        InkScrollingView(seed: seed, isPlaying: isPlaying, source: .nightSky)
            .id(InkScrollIdentity(source: "nightSky", seed: seed))
    }
}
