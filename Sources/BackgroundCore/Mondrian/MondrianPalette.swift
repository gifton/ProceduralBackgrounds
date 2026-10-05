enum MondrianColor: CaseIterable, Hashable, Sendable {
    case red, blue, yellow, white, black

    var rgb: SIMD3<Double> {
        switch self {
        case .red: [0.84, 0.10, 0.12]
        case .blue: [0.12, 0.27, 0.72]
        case .yellow: [0.98, 0.79, 0.12]
        case .white: [1, 1, 1]
        case .black: [0.07, 0.07, 0.08]
        }
    }
}

enum MondrianPalette {
    // Soft area goals; seedSampleHasVariedLayoutsAndReportsAreaBalance reports
    // the resulting proportions. A modest smallest-cell black block takes priority.
    static let areaTargets: (primary: Double, white: Double, black: Double) = (0.50, 0.45, 0.05)
}
