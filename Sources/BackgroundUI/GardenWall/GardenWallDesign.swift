import SwiftUI

/// A scrolling stone garden with still plants and cats on textured paper.
public struct GardenWallDesign: BackgroundDesign {
    public static let title: String = "Garden Wall"
    private let isPlaying: Bool

    public init(isPlaying: Bool = true) { self.isPlaying = isPlaying }

    public func makeView(seed: UInt64) -> some View {
        InkScrollingView(seed: seed, isPlaying: isPlaying, source: .gardenWall)
            .id(InkScrollIdentity(source: "gardenWall", seed: seed))
    }
}
