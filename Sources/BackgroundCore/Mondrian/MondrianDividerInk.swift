enum MondrianDividerInk {
    static func draw(_ edge: MondrianEdge, seed: UInt64) -> [InkPrimitive] {
        var random = InkRandom(state: MondrianSeeds.component(world: seed,
            identity: MondrianEdges.identity(edge), tag: MondrianSeeds.divider))
        let points: [SIMD2<Double>] = (0..<5).map { sample in
            edge.start + (edge.end - edge.start) * (Double(sample) / 4)
        }
        let base: Double = 7 + random.unit() * 2
        let widths: [Double] = (0..<5).map { _ in base + random.unit() * 2 }
        return [
            .colorStroke(points: points, widths: widths, color: MondrianColor.black.rgb, opacity: 1),
            .colorStroke(points: points, widths: widths.map { $0 * 0.24 },
                         color: [0.17, 0.17, 0.18], opacity: 0.12)
        ]
    }
}
