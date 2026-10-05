/// Subjects for inspecting the drawing vocabulary independently of a landscape.
public enum ShanShuiElement: String, CaseIterable, Hashable, Sendable {
    case leafyTree
    case bareTree
    case pavilion
    case boat
}

/// A single subject in an 800 × 600 paper study, using the landscape's ink format.
public struct ShanShuiElementGenerator: BackgroundGenerator {
    public let element: ShanShuiElement

    public init(element: ShanShuiElement) {
        self.element = element
    }

    /// Generates one subject with a local seed stream; other studies consume none
    /// of its state. See `elementReplayIsIndependentOfOtherSubjects`.
    /// - Complexity: O(P) time/space for P generated points. Bare-tree recursion
    ///   is limited to three levels; no drawing operation recurses without a limit.
    public func generate(seed: UInt64) -> ShanShuiScene {
        let primitives: [InkPrimitive]
        switch element {
        case .leafyTree:
            primitives = ShanShuiTreeElements.leafy(seed: seed, root: [400, 500], height: 320)
        case .bareTree:
            primitives = ShanShuiTreeElements.bare(seed: seed, root: [400, 500], height: 245)
        case .pavilion:
            primitives = ShanShuiArchitectureElements.pavilion(seed: seed, base: [400, 500], width: 300)
        case .boat:
            primitives = ShanShuiArchitectureElements.boat(seed: seed, origin: [245, 430], length: 330)
        }
        return ShanShuiScene(seed: seed, bounds: [800, 600], primitives: primitives)
    }
}
