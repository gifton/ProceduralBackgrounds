import BackgroundCore
import SwiftUI

public struct ShanShuiDesign: BackgroundDesign {
    public static let title: String = "Shan Shui"

    public init() {}

    public func makeView(seed: UInt64) -> some View {
        InkSceneView(seed: seed, generator: ShanShuiGenerator())
    }
}

public struct ShanShuiLandscapeDesign: BackgroundDesign {
    public static let title: String = "Shan Shui landscape"

    public init() {}

    public func makeView(seed: UInt64) -> some View {
        InkSceneView(seed: seed, generator: ShanShuiLandscapeGenerator())
    }
}

public struct ShanShuiElementDesign: BackgroundDesign {
    public static let title: String = "Shan Shui elements"
    public let element: ShanShuiElement

    public init(element: ShanShuiElement = .leafyTree) {
        self.element = element
    }

    public func makeView(seed: UInt64) -> some View {
        InkSceneView(seed: seed, generator: ShanShuiElementGenerator(element: element))
            .id(element)
    }
}

public extension ShanShuiElement {
    var title: String {
        switch self {
        case .leafyTree: "Leafy tree"
        case .bareTree: "Bare tree"
        case .pavilion: "Pavilion"
        case .boat: "Boat with figure"
        }
    }
}

