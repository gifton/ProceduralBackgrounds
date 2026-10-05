/// A finite seeded watercolor composition in a 1200 by 800 world.
/// Within-build replay is tested by paintingReplaysWithFiniteBoundedInk; geometry
/// is not a versioned format. Layout and paint use separate identity-based streams.
public struct MondrianGenerator: BackgroundGenerator {
    private let paintStyle: MondrianPaintStyle

    public init() { paintStyle = .layered }
    init(paintStyle: MondrianPaintStyle) { self.paintStyle = paintStyle }

    public func generate(seed: UInt64) -> InkScene {
        let layout = MondrianLayout(seed: seed)
        var ink: [InkPrimitive] = layout.cells.flatMap {
            MondrianCellPaint.draw($0, seed: seed, style: paintStyle)
        }
        ink += MondrianEdges.make(cells: layout.cells).flatMap {
            MondrianDividerInk.draw($0, seed: seed)
        }
        return InkScene(seed: seed, bounds: [1200, 800], primitives: ink)
    }
}
