/// A polygon wash or tapered stroke. Widths are full widths in world units.
/// RGB values are straight color; opacity is separate. Renderers validate geometry
/// and color and preserve the instruction array's painter order.
public enum InkPrimitive: Sendable {
    case wash(points: [SIMD2<Double>], tone: Double, opacity: Double)
    case stroke(points: [SIMD2<Double>], widths: [Double], tone: Double, opacity: Double)
    case colorWash(points: [SIMD2<Double>], color: SIMD3<Double>, opacity: Double)
    case colorStroke(points: [SIMD2<Double>], widths: [Double], color: SIMD3<Double>, opacity: Double)

    public var points: [SIMD2<Double>] {
        switch self {
        case let .wash(p, _, _), let .stroke(p, _, _, _),
             let .colorWash(p, _, _), let .colorStroke(p, _, _, _): p
        }
    }

    public var color: SIMD3<Double> {
        switch self {
        case let .wash(_, tone, _), let .stroke(_, _, tone, _): SIMD3(repeating: tone)
        case let .colorWash(_, color, _), let .colorStroke(_, _, color, _): color
        }
    }

    /// The original tone for grayscale ink; RGB ink returns its arithmetic mean
    /// as a compatibility projection. Renderers use color, not this projection.
    public var tone: Double {
        switch self {
        case let .wash(_, tone, _), let .stroke(_, _, tone, _): tone
        case let .colorWash(_, c, _), let .colorStroke(_, _, c, _): (c.x + c.y + c.z) / 3
        }
    }

    public var opacity: Double {
        switch self {
        case let .wash(_, _, a), let .stroke(_, _, _, a),
             let .colorWash(_, _, a), let .colorStroke(_, _, _, a): a
        }
    }

    func mapGeometry(_ transform: (SIMD2<Double>) -> SIMD2<Double>,
                     widthScale: Double = 1) -> InkPrimitive {
        let mapped = points.map(transform)
        switch self {
        case let .wash(_, tone, a): return .wash(points: mapped, tone: tone, opacity: a)
        case let .stroke(_, widths, tone, a):
            return .stroke(points: mapped, widths: widths.map { $0 * widthScale }, tone: tone, opacity: a)
        case let .colorWash(_, c, a): return .colorWash(points: mapped, color: c, opacity: a)
        case let .colorStroke(_, widths, c, a):
            return .colorStroke(points: mapped, widths: widths.map { $0 * widthScale }, color: c, opacity: a)
        }
    }
}
