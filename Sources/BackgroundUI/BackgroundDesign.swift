import SwiftUI

/// A pluggable background whose view may use SwiftUI, Canvas, or a Metal-backed host.
@MainActor
public protocol BackgroundDesign {
    associatedtype Content: View

    static var title: String { get }

    @ViewBuilder
    func makeView(seed: UInt64) -> Content
}
