/// Horizontal watercolor rectangles reconstructed in bounded local coordinates.
/// indexedInkReplaysAndKeepsItsBounds tests within-build replay and signed extrema.
/// The generated geometry is not a versioned or cross-platform format.
public struct MondrianChunkGenerator: Sendable {
    private let paintStyle: MondrianPaintStyle

    public init() { paintStyle = .layered }
    init(paintStyle: MondrianPaintStyle) { self.paintStyle = paintStyle }

    /// Returns complete primitives; the receiving renderer must clip expanded ink
    /// to the scene bounds. Throws if an internal address exceeds its local range.
    /// Reconstruction visits five groups, each capped at 24 cells; edge union is
    /// quadratic in that bounded cell count. No measured performance is implied.
    public func generate(seed: UInt64, index: Int64) throws -> InkChunk {
        let composition = try MondrianWorldComposition(seed: seed, index: index)
        let scene = try MondrianWorldInk.scene(seed: seed, cells: composition.cells,
            edges: composition.edges, relativeTo: composition.origin.owner,
            xOffset: Double(composition.origin.offset), bounds: [1200, 800], style: paintStyle)
        return InkChunk(index: index, scene: scene)
    }
}
