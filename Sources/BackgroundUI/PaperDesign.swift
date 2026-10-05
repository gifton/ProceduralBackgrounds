import SwiftUI

/// A plain comparison surface for evaluating the procedural examples.
public struct PaperDesign: BackgroundDesign {
    public static let title: String = "Plain paper"
    static let color: Color = Color(red: 0.96, green: 0.94, blue: 0.89)

    public init() {}

    public func makeView(seed: UInt64) -> some View {
        Self.color.accessibilityHidden(true)
    }
}
