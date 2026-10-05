/// Horizontal clipping for the masonry vocabulary.
/// Caller contract: convex wash polygons, finite coordinates/widths and finite
/// minX <= maxX. Invalid primitive data is passed through for renderer validation.
enum InkClipping {
    static func horizontally(_ ink: [InkPrimitive], minX: Double, maxX: Double) -> [InkPrimitive] {
        var result: [InkPrimitive] = []
        for primitive in ink {
            guard primitive.points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
                result.append(primitive); continue
            }
            switch primitive {
            case .wash, .colorWash:
                var points = polygon(primitive.points, boundary: minX, greater: true)
                points = polygon(points, boundary: maxX, greater: false)
                guard points.count >= 3 else { continue }
                switch primitive {
                case let .wash(_, tone, a): result.append(.wash(points: points, tone: tone, opacity: a))
                case let .colorWash(_, c, a): result.append(.colorWash(points: points, color: c, opacity: a))
                default: break
                }
            case let .stroke(points, widths, _, _), let .colorStroke(points, widths, _, _):
                guard points.count == widths.count, widths.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
                    result.append(primitive); continue
                }
                var run: [SIMD2<Double>] = []
                var runWidths: [Double] = []
                func flush() {
                    guard run.count >= 2 else { run = []; runWidths = []; return }
                    switch primitive {
                    case let .stroke(_, _, tone, a):
                        result.append(.stroke(points: run, widths: runWidths, tone: tone, opacity: a))
                    case let .colorStroke(_, _, c, a):
                        result.append(.colorStroke(points: run, widths: runWidths, color: c, opacity: a))
                    default: break
                    }
                    run = []; runWidths = []
                }
                guard points.count >= 2 else { continue }
                for i in 0..<(points.count - 1) {
                    let a = points[i], b = points[i + 1]
                    let delta: SIMD2<Double> = b - a
                    if delta.x * delta.x + delta.y * delta.y < 1e-20 { continue }
                    var lo: Double = 0, hi: Double = 1
                    if abs(delta.x) < 1e-14 {
                        if a.x < minX || a.x > maxX { flush(); continue }
                    } else {
                        let t0: Double = (minX - a.x) / delta.x
                        let t1: Double = (maxX - a.x) / delta.x
                        lo = max(0, min(t0, t1))
                        hi = min(1, max(t0, t1))
                    }
                    guard hi - lo > 1e-12 else { flush(); continue }
                    var start: SIMD2<Double> = a + delta * lo
                    var end: SIMD2<Double> = a + delta * hi
                    start.x = min(maxX, max(minX, start.x))
                    end.x = min(maxX, max(minX, end.x))
                    let w0: Double = widths[i] + (widths[i + 1] - widths[i]) * lo
                    let w1: Double = widths[i] + (widths[i + 1] - widths[i]) * hi
                    if let last = run.last {
                        let d = last - start
                        if d.x * d.x + d.y * d.y > 1e-20 { flush() }
                    }
                    if run.isEmpty { run.append(start); runWidths.append(w0) }
                    run.append(end); runWidths.append(w1)
                    if hi < 1 - 1e-12 { flush() }
                }
                flush()
            }
        }
        return result
    }

    private static func polygon(_ points: [SIMD2<Double>], boundary: Double,
                                greater: Bool) -> [SIMD2<Double>] {
        guard var previous = points.last else { return [] }
        var output: [SIMD2<Double>] = []
        var wasInside: Bool = greater ? previous.x >= boundary : previous.x <= boundary
        for current in points {
            let inside: Bool = greater ? current.x >= boundary : current.x <= boundary
            if inside != wasInside {
                let t: Double = (boundary - previous.x) / (current.x - previous.x)
                var intersection: SIMD2<Double> = previous + (current - previous) * t
                intersection.x = boundary
                output.append(intersection)
            }
            if inside { output.append(current) }
            previous = current; wasInside = inside
        }
        return output
    }
}
